const std = @import("std");
const Instruction = @import("./instruction.zig").Instruction;
const Memory = @import("./memory.zig").Memory;
const encode = @import("./encoder.zig");
const Csrs = @import("./csrs.zig").Csrs;

const Privilege = enum { Supervisor, User };

pub const CPUState = struct {
    // Current Privilege Level
    privilege: Privilege = .Supervisor,

    // General Purpose Registers
    gprs: [32]u32 = [_]u32{0} ** 32,

    // Program Counter
    pc: u32 = 0,

    // Control and Status Registers
    csrs: Csrs = Csrs{},

    pub fn default(entry_pointer: u32, stack_pointer: u32) CPUState {
        var state = CPUState{};
        state.pc = entry_pointer;
        state.gprs[2] = stack_pointer;
        return state;
    }
};

pub fn execute(instruction: Instruction, cpuState: *CPUState, memory: *Memory) !void {
    switch (instruction.opcode()) {
        0b0110011 => { // R-Type
            const rd = instruction.rd();
            if (rd != 0) {
                const rs1Value = cpuState.gprs[instruction.rs1()];
                const rs2Value = cpuState.gprs[instruction.rs2()];
                switch (instruction.funct3()) {
                    0b000 => {
                        switch (instruction.funct7()) {
                            0b0000000 => { // ADD
                                const value = @addWithOverflow(rs1Value, rs2Value);
                                cpuState.gprs[rd] = value[0];
                            },
                            0b0100000 => { // SUB
                                const value = @subWithOverflow(rs1Value, rs2Value);
                                cpuState.gprs[rd] = value[0];
                            },
                            else => return error.UnknownFunct7,
                        }
                    },
                    0b001 => { // SLL
                        const shiftAmount: u5 = @truncate(rs2Value);
                        cpuState.gprs[rd] = rs1Value << shiftAmount;
                    },
                    0b010 => { // SLT
                        const rs1Signed: i32 = @bitCast(rs1Value);
                        const rs2Signed: i32 = @bitCast(rs2Value);
                        if (rs1Signed < rs2Signed) {
                            cpuState.gprs[rd] = 1;
                        } else {
                            cpuState.gprs[rd] = 0;
                        }
                    },
                    0b011 => { // SLTU
                        if (rs1Value < rs2Value) {
                            cpuState.gprs[rd] = 1;
                        } else {
                            cpuState.gprs[rd] = 0;
                        }
                    },
                    0b100 => { // XOR
                        cpuState.gprs[rd] = rs1Value ^ rs2Value;
                    },
                    0b101 => {
                        switch (instruction.funct7()) {
                            0b0000000 => { // SRL
                                const shiftAmount: u5 = @truncate(rs2Value);
                                cpuState.gprs[rd] = rs1Value >> shiftAmount;
                            },
                            0b0100000 => { // SRA
                                const shiftAmount: u5 = @truncate(rs2Value);
                                const signedRs1Value: i32 = @bitCast(rs1Value);
                                const result: i32 = signedRs1Value >> shiftAmount;
                                cpuState.gprs[rd] = @bitCast(result);
                            },
                            else => return error.UnknownFunct7,
                        }
                    },
                    0b110 => { // OR
                        cpuState.gprs[rd] = rs1Value | rs2Value;
                    },
                    0b111 => { // AND
                        cpuState.gprs[rd] = rs1Value & rs2Value;
                    },
                }
            }
            cpuState.pc += 4;
        },
        0b0010011 => { // I-Type
            const rd = instruction.rd();
            if (rd != 0) {
                const rs1Value = cpuState.gprs[instruction.rs1()];
                const imm = instruction.immIType();
                switch (instruction.funct3()) {
                    0b000 => { // ADDI
                        const rs1Signed: i32 = @bitCast(rs1Value);
                        const newValue = @addWithOverflow(rs1Signed, imm);
                        cpuState.gprs[rd] = @bitCast(newValue[0]);
                    },
                    0b001 => { // SLLI
                        const immUnsigned: u32 = @bitCast(instruction.immIType());
                        const shiftAmount: u5 = @truncate(immUnsigned);
                        cpuState.gprs[rd] = rs1Value << shiftAmount;
                    },
                    0b010 => { // SLTI
                        const rs1Signed: i32 = @bitCast(rs1Value);
                        if (rs1Signed < imm) {
                            cpuState.gprs[rd] = 1;
                        } else {
                            cpuState.gprs[rd] = 0;
                        }
                    },
                    0b011 => { // SLTIU
                        const immUnsigned: u32 = @bitCast(imm);
                        if (rs1Value < immUnsigned) {
                            cpuState.gprs[rd] = 1;
                        } else {
                            cpuState.gprs[rd] = 0;
                        }
                    },
                    0b100 => { // XORI
                        const immUnsigned: u32 = @bitCast(imm);
                        cpuState.gprs[rd] = rs1Value ^ immUnsigned;
                    },
                    0b101 => { // SRLI
                        const immUnsigned: u32 = @bitCast(imm);
                        const shiftAmount: u5 = @truncate(immUnsigned);
                        cpuState.gprs[rd] = rs1Value >> shiftAmount;
                    },
                    0b110 => { // ORI
                        const immUnsigned: u32 = @bitCast(imm);
                        cpuState.gprs[rd] = rs1Value | immUnsigned;
                    },
                    0b111 => { // ANDI
                        const immUnsigned: u32 = @bitCast(imm);
                        cpuState.gprs[rd] = rs1Value & immUnsigned;
                    },
                }
            }
            cpuState.pc += 4;
        },
        0b0000011 => { // I-Type
            const rd = instruction.rd();
            if (rd != 0) {
                const rs1Value: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                const imm = instruction.immIType();
                switch (instruction.funct3()) {
                    0b000 => { // LB
                        const address: u32 = @bitCast(rs1Value + imm);

                        const loadedByte = try memory.read8(address);
                        const byteAsWord = @as(u32, loadedByte);

                        if (loadedByte & 0x80 != 0) {
                            const signedValue = 0xFFFFFF00 | byteAsWord;
                            cpuState.gprs[rd] = signedValue;
                        } else {
                            cpuState.gprs[rd] = byteAsWord;
                        }
                    },
                    0b001 => { // LH
                        const address: u32 = @bitCast(rs1Value + imm);

                        if (address & 0b1 != 0) {
                            return error.MisalignedAddress;
                        }

                        const loadedU16 = try memory.read16(address);
                        const u16AsWord = @as(u32, loadedU16);

                        if (u16AsWord & 0x8000 != 0) {
                            const signedValue = 0xFFFF0000 | u16AsWord;
                            cpuState.gprs[rd] = signedValue;
                        } else {
                            cpuState.gprs[rd] = u16AsWord;
                        }
                    },
                    0b010 => { // LW
                        const address = rs1Value + imm;

                        if (address & 0b11 != 0) {
                            return error.MisalignedAddress;
                        }

                        const addressUnsigned: u32 = @bitCast(address);
                        cpuState.gprs[rd] = try memory.read32(addressUnsigned);
                    },
                    0b100 => { // LBU
                        const address: u32 = @bitCast(rs1Value + imm);

                        const loadedByte = try memory.read8(address);
                        const byteAsWord = @as(u32, loadedByte);

                        cpuState.gprs[rd] = byteAsWord;
                    },
                    0b101 => { // LHU
                        const address: u32 = @bitCast(rs1Value + imm);

                        if (address & 0b1 != 0) {
                            return error.MisalignedAddress;
                        }

                        const loadedU16 = try memory.read16(address);
                        const u16AsWord = @as(u32, loadedU16);

                        cpuState.gprs[rd] = u16AsWord;
                    },
                    else => return error.UnknownFunct3,
                }
            }
            cpuState.pc += 4;
        },
        0b1100111 => { // I-Type
            if (instruction.funct3() == 0) { // JALR
                const rs1Signed: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                const target: u32 = @bitCast(rs1Signed + instruction.immIType());
                const aligned = target & 0xFFFFFFFE; // Clear LSB to ensure alignment
                const rd = instruction.rd();
                if (rd != 0) {
                    cpuState.gprs[rd] = cpuState.pc + 4; // Save return address
                }
                cpuState.pc = aligned;
            } else {
                return error.UnknownFunct3;
            }
        },
        0b0100011 => { // S-Type
            switch (instruction.funct3()) {
                0b000 => { // SB
                    const rs1Value: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                    const address: u32 = @bitCast(rs1Value + instruction.immSType());
                    try memory.write8(address, @truncate(cpuState.gprs[instruction.rs2()]));
                },
                0b001 => { // SH
                    const rs1Value: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                    const address: u32 = @bitCast(rs1Value + instruction.immSType());

                    if (address & 0b1 != 0) {
                        return error.MisalignedAddress;
                    } else {
                        try memory.write16(address, @truncate(cpuState.gprs[instruction.rs2()]));
                    }
                },
                0b010 => { // SW
                    const rs1Value: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                    const address: u32 = @bitCast(rs1Value + instruction.immSType());

                    if (address & 0b11 != 0) {
                        return error.MisalignedAddress;
                    } else {
                        try memory.write32(address, cpuState.gprs[instruction.rs2()]);
                    }
                },
                else => return error.UnknownFunct3,
            }
            cpuState.pc += 4;
        },
        0b1100011 => { // B-Type
            switch (instruction.funct3()) {
                0b000 => { // BEQ
                    const rs1Value = cpuState.gprs[instruction.rs1()];
                    const rs2Value = cpuState.gprs[instruction.rs2()];
                    const imm = instruction.immBType();
                    if (rs1Value == rs2Value and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                0b001 => { // BNE
                    const rs1Value = cpuState.gprs[instruction.rs1()];
                    const rs2Value = cpuState.gprs[instruction.rs2()];
                    const imm = instruction.immBType();
                    if (rs1Value != rs2Value and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                0b100 => { // BLT
                    const rs1Signed: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                    const rs2Signed: i32 = @bitCast(cpuState.gprs[instruction.rs2()]);
                    const imm = instruction.immBType();
                    if (rs1Signed < rs2Signed and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                0b101 => { // BGE
                    const rs1Signed: i32 = @bitCast(cpuState.gprs[instruction.rs1()]);
                    const rs2Signed: i32 = @bitCast(cpuState.gprs[instruction.rs2()]);
                    const imm = instruction.immBType();
                    if (rs1Signed >= rs2Signed and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                0b110 => { // BLTU
                    const rs1Value = cpuState.gprs[instruction.rs1()];
                    const rs2Value = cpuState.gprs[instruction.rs2()];
                    const imm = instruction.immBType();
                    if (rs1Value < rs2Value and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                0b111 => { // BGEU
                    const rs1Value = cpuState.gprs[instruction.rs1()];
                    const rs2Value = cpuState.gprs[instruction.rs2()];
                    const imm = instruction.immBType();
                    if (rs1Value >= rs2Value and imm != 0) {
                        const pcAsI32: i32 = @bitCast(cpuState.pc);
                        const nextPcValue = pcAsI32 + imm;
                        cpuState.pc = @bitCast(nextPcValue);
                    } else {
                        cpuState.pc += 4;
                    }
                },
                else => return error.UnknownFunct3,
            }
        },
        0b0110111 => { // U-Type
            const rd = instruction.rd();
            if (rd != 0) { // LUI
                cpuState.gprs[rd] = @bitCast(instruction.immUType() << 12);
            }
            cpuState.pc += 4;
        },
        0b0010111 => { // U-Type
            const rd = instruction.rd();
            if (rd != 0) { // AUIPC
                const immShifted: u32 = @bitCast(instruction.immUType() << 12);
                const ret = @addWithOverflow(cpuState.pc, immShifted);
                cpuState.gprs[rd] = ret[0];
            }
            cpuState.pc += 4;
        },
        0b1101111 => { // J-Type
            const rd = instruction.rd();
            if (rd != 0) { // J/JAL
                cpuState.gprs[rd] = cpuState.pc + 4;
            }
            const pcAsSigned: i32 = @bitCast(cpuState.pc);
            cpuState.pc = @bitCast(pcAsSigned + instruction.immJType());
        },
        0b1110011 => { // System
            const funct7 = instruction.funct7();
            const funct3 = instruction.funct3();
            const imm = instruction.immSystem();
            if (funct7 == 0b0001000) {
                if (funct3 == 0b000) {
                    switch (imm) {
                        0x000 => { // WFI
                            std.debug.print("WFI\n", .{});
                        },
                        0x102 => { // SRET
                            std.debug.print("SRET\n", .{});
                        },
                        else => return error.UnknownImm,
                    }
                }
            } else if (funct3 == 0b000) {
                switch (imm) {
                    0x000 => { // ECALL
                        std.debug.print("ECALL\n", .{});
                    },
                    0x001 => { // EBREAK
                        std.debug.print("EBREAK\n", .{});
                    },
                    else => return error.UnknownImm,
                }
            } else {
                const csrAddress = instruction.immSystem();
                const rd = instruction.rd();
                const rs1Value = cpuState.gprs[instruction.rs1()];

                const csr: *u32 = switch (csrAddress) {
                    0x100 => &cpuState.csrs.sstatus,
                    0x104 => &cpuState.csrs.sie,
                    0x105 => &cpuState.csrs.stvec,
                    0x106 => &cpuState.csrs.scounteren,
                    0x140 => &cpuState.csrs.sscratch,
                    0x141 => &cpuState.csrs.sepc,
                    0x142 => &cpuState.csrs.scause,
                    0x143 => &cpuState.csrs.stval,
                    0x144 => &cpuState.csrs.sip,
                    0x180 => &cpuState.csrs.satp,
                    else => return error.UnknownCSR,
                };

                const oldValue = csr.*;

                switch (funct3) {
                    0b001 => { // CSRRW
                        std.debug.print("CSRRW", .{});
                        csr.* = rs1Value;
                    },
                    0b010 => { // CSRRS
                        std.debug.print("CSRRS", .{});
                        csr.* |= rs1Value;
                    },
                    0b011 => { // CSRRC
                        std.debug.print("CSRRC", .{});
                        csr.* &= ~rs1Value;
                    },
                    0b101 => { // CSRRWI
                        std.debug.print("CSRRWI", .{});
                    },
                    0b110 => { // CSRRSI
                        std.debug.print("CSRRSI", .{});
                    },
                    0b111 => { // CSRRCI
                        std.debug.print("CSRRCI", .{});
                    },
                    // Already covered funct3 == 0 in previous else case
                    else => unreachable,
                }

                cpuState.gprs[rd] = oldValue;
            }
            cpuState.pc += 4;
        },
        0b0001111 => { // I-Type
            switch (instruction.funct3()) {
                0b000 => {
                    // FENCE
                    std.debug.print("FENCE\n", .{});
                },
                0b001 => {
                    // FENCE.I
                    std.debug.print("FENCE.I\n", .{});
                },
                else => return error.UnknownFunct3,
            }
            cpuState.pc += 4;
        },
        else => return error.UnknownOpcode,
    }
}

test "idk" {
    const allocator = std.testing.allocator;

    var mem = try Memory.init(allocator, 4);
    defer mem.deinit(allocator);

    var cpu = CPUState.default(0, 0);

    cpu.gprs[2] = 11;
    cpu.csrs.sstatus = 55;

    const ins = Instruction{ .value = encode.CSRRW(1, 2, 0x100) };

    try execute(ins, &cpu, &mem);

    try std.testing.expectEqual(11, cpu.csrs.sstatus);
    try std.testing.expectEqual(55, cpu.gprs[1]);
}
