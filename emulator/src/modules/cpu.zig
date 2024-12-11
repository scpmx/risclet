const std = @import("std");
const Instruction = @import("./instruction.zig").Instruction;
const Memory = @import("./memory.zig").Memory;
const encode = @import("./encoder.zig");

const Privilege = enum { Machine, Supervisor, User };

pub const SStatus = struct {};

pub const CPUState = struct {
    // Current Privilege Level
    privilege: Privilege = .Machine,

    // General Purpose Registers
    gprs: [32]u32 = [_]u32{0} ** 32,

    // Program Counter
    pc: u32 = 0,

    // Supervisor Registers
    sstatus: u32 = 0,

    // Supervisor Trap Vector Register
    stvec: u32 = 0,

    // Supervisor Exception Program Counter
    sepc: u32 = 0,

    // Supervisor Cause Register
    scause: u32 = 0,
    stval: u32 = 0,

    pub fn default() CPUState {
        return CPUState{};
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
            } else if (funct3 == 0b001) { // CSRRW
                std.debug.print("CSRRW\n", .{});
            } else if (funct3 == 0b010) { // CSRRS
                std.debug.print("CSRRS\n", .{});
            } else if (funct3 == 0b011) { // CSRRC
                std.debug.print("CSRRC\n", .{});
            } else {
                return error.UnknownFunct3;
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

test "Execute ADD" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple addition (1 + 2 = 3)
    cpuState.gprs[1] = 1;
    cpuState.gprs[2] = 2;

    // ADD x3, x1, x2
    const add1 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add1, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.gprs[3]); // Expect x3 = 3
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Addition with zero (5 + 0 = 5)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5;
    cpuState.gprs[2] = 0;

    // ADD x3, x1, x2
    const add2 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add2, &cpuState, &memory);

    try std.testing.expectEqual(5, cpuState.gprs[3]); // Expect x3 = 5
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Negative number addition (-7 + 10 = 3)
    const v1: i32 = -7;
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(v1);
    cpuState.gprs[2] = 10;

    // ADD x3, x1, x2
    const add3 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add3, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.gprs[3]); // Expect x3 = 3
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Addition with two negative numbers (-8 + -9 = -17)
    const v2: i32 = -8;
    const v3: i32 = -9;
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(v2);
    cpuState.gprs[2] = @bitCast(v3);

    // ADD x3, x1, x2
    const add4 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add4, &cpuState, &memory);

    const actual0: i32 = @bitCast(cpuState.gprs[3]);
    try std.testing.expectEqual(-17, actual0); // Expect x3 = -17
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Addition causing unsigned overflow (0xFFFFFFFF + 1 = 0)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xFFFFFFFF;
    cpuState.gprs[2] = 1;

    // ADD x3, x1, x2
    const add5 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[3]); // Expect x3 = 0 (unsigned overflow)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 6: Large positive and negative numbers (0x7FFFFFFF + 0x80000000 = -1)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x7FFFFFFF; // Largest positive 32-bit number
    cpuState.gprs[2] = 0x80000000; // Largest negative 32-bit number (in two's complement)

    // ADD x3, x1, x2
    const add6 = Instruction{ .value = encode.ADD(3, 1, 2) };

    try execute(add6, &cpuState, &memory);

    const actual1: i32 = @bitCast(cpuState.gprs[3]);
    try std.testing.expectEqual(-1, actual1); // Expect x3 = -1
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SUB" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple subtraction
    cpuState.gprs[1] = 10; // x1 = 10
    cpuState.gprs[2] = 4; // x2 = 4

    // SUB x5, x1, x2
    const sub1 = Instruction{ .value = encode.SUB(5, 1, 2) };

    try execute(sub1, &cpuState, &memory);

    try std.testing.expectEqual(6, cpuState.gprs[5]); // x5 = 6
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Subtract to zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20
    cpuState.gprs[2] = 20; // x2 = 20

    // SUB x5, x1, x2
    const sub2 = Instruction{ .value = encode.SUB(5, 1, 2) };

    try execute(sub2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Subtract with negative result
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // SUB x5, x1, x2
    const sub3 = Instruction{ .value = encode.SUB(5, 1, 2) };

    try execute(sub3, &cpuState, &memory);

    const actual3: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-5, actual3); // x5 = -5
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Subtract with large unsigned values (no underflow)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xFFFFFFFF; // x1 = 0xFFFFFFFF (max unsigned)
    cpuState.gprs[2] = 1; // x2 = 1

    // SUB x5, x1, x2
    const sub4 = Instruction{ .value = encode.SUB(5, 1, 2) };

    try execute(sub4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFE, cpuState.gprs[5]); // x5 = 0xFFFFFFFE
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Subtract zero (identity)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 123456; // x1 = 123456
    cpuState.gprs[2] = 0; // x2 = 0

    // SUB x5, x1, x2
    const sub5 = Instruction{ .value = encode.SUB(5, 1, 2) };

    try execute(sub5, &cpuState, &memory);

    try std.testing.expectEqual(123456, cpuState.gprs[5]); // x5 = 123456
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute ADDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple addition (1 + 10 = 11)
    cpuState.gprs[1] = 1;

    // ADDI x5, x1, 10
    const addi1 = Instruction{ .value = encode.ADDI(5, 1, 10) };

    try execute(addi1, &cpuState, &memory);

    try std.testing.expectEqual(11, cpuState.gprs[5]); // Expect x5 = 11
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Addition with zero immediate (5 + 0 = 5)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5;

    // ADDI x5, x1, 0
    const addi2 = Instruction{ .value = encode.ADDI(5, 1, 0) };

    try execute(addi2, &cpuState, &memory);

    try std.testing.expectEqual(5, cpuState.gprs[5]); // Expect x5 = 5
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Addition with negative immediate (10 + (-3) = 7)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 10;

    // ADDI x5, x1, -3
    const addi3 = Instruction{ .value = encode.ADDI(5, 1, -3) };

    try execute(addi3, &cpuState, &memory);

    try std.testing.expectEqual(7, cpuState.gprs[5]); // Expect x5 = 7
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Negative register value and positive immediate (-5 + 3 = -2)
    const regVal4: i32 = -5;
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(regVal4);

    // ADDI x5, x1, 3
    const addi4 = Instruction{ .value = encode.ADDI(5, 1, 3) };

    try execute(addi4, &cpuState, &memory);

    const actual0: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-2, actual0); // Expect x5 = -2
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Negative register value and negative immediate (-5 + (-5) = -10)
    const regVal5: i32 = -5;
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(regVal5);

    // ADDI x5, x1, -5
    const addi5 = Instruction{ .value = encode.ADDI(5, 1, -5) };

    try execute(addi5, &cpuState, &memory);

    const actua1: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-10, actua1); // Expect x5 = -10
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 6: Immediate value that requires sign extension (-2048)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0;

    // ADDI x5, x1, -2048
    const addi6 = Instruction{ .value = encode.ADDI(5, 1, -2048) };

    try execute(addi6, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-2048, actual2); // Expect x5 = -2048
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 7: Maximum positive immediate (0x7FF)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1;

    // ADDI x5, x1, 2047
    const addi7 = Instruction{ .value = encode.ADDI(5, 1, 2047) };

    try execute(addi7, &cpuState, &memory);

    try std.testing.expectEqual(2048, cpuState.gprs[5]); // Expect x5 = 2048
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 8: Immediate overflow (0xFFF + 1) should wrap to negative immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5;

    // ADDI x5, x1, -1
    const addi8 = Instruction{ .value = encode.ADDI(5, 1, -1) };

    try execute(addi8, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.gprs[5]); // Expect x5 = 4 (5 + (-1))
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute LW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16); // Allocate 16 bytes of memory
    defer memory.deinit(alloc);

    // Write test values into memory
    try memory.write32(4, 0x12345678); // Address 4: 0x12345678
    try memory.write32(8, 0xDEADBEEF); // Address 8: 0xDEADBEEF
    try memory.write32(12, 0x00000000); // Address 12: 0x00000000

    var cpuState = CPUState.default();

    // Case 1: Basic load (x2 = MEM[x1 + 4])
    cpuState.gprs[1] = 0; // Base address in x1

    // LW x2, 4(x1)
    const lw1 = Instruction{ .value = encode.LW(2, 1, 4) };

    try execute(lw1, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[2]); // Expect x2 = 0x12345678
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load with positive offset (x2 = MEM[x1 + 8])
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0;

    // LW x2, 8(x1)
    const lw2 = Instruction{ .value = encode.LW(2, 1, 8) };

    try execute(lw2, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.gprs[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load with negative offset (x2 = MEM[x1 - 4])
    const baseAddress: u32 = 12;
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = baseAddress;

    // LW x2, -4(x1)
    const lw3 = Instruction{ .value = encode.LW(2, 1, -4) };

    try execute(lw3, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.gprs[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Load from zeroed memory (x2 = MEM[x1 + 12])
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0;

    // LW x2, 12(x1)
    const lw4 = Instruction{ .value = encode.LW(2, 1, 12) };

    try execute(lw4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.gprs[2]); // Expect x2 = 0x00000000
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Unaligned memory address
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // Base address in x1 (unaligned address)

    // LW x2, 2(x1)
    const lw5 = Instruction{ .value = encode.LW(2, 1, 2) };
    const err = execute(lw5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
}

test "Execute SW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16); // Allocate 16 bytes of memory
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Basic store (x2 -> MEM[x1 + 4])
    cpuState.gprs[1] = 0; // Base address in x1
    cpuState.gprs[2] = 0xDEADBEEF; // Value to store in x2

    // SW x2, 4(x1)
    const sw1 = Instruction{ .value = encode.SW(2, 4, 1) };

    try execute(sw1, &cpuState, &memory);

    const storedWord1 = try memory.read32(4);

    try std.testing.expectEqual(0xDEADBEEF, storedWord1); // Expect memory[4] = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Store with zero offset (x2 -> MEM[x1 + 0])
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 8; // Base address in x1
    cpuState.gprs[2] = 0xCAFEBABE; // Value to store in x2

    // SW x2, 0(x1)
    const sw2 = Instruction{ .value = encode.SW(2, 0, 1) };

    try execute(sw2, &cpuState, &memory);

    const storedWord2 = try memory.read32(8);

    try std.testing.expectEqual(0xCAFEBABE, storedWord2); // Expect memory[8] = 0xCAFEBABE
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Store with negative offset (x2 -> MEM[x1 - 4])
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 12; // Base address in x1
    cpuState.gprs[2] = 0xBADC0DE; // Value to store in x2

    // SW x2, -4(x1)
    const sw3 = Instruction{ .value = encode.SW(2, -4, 1) };

    try execute(sw3, &cpuState, &memory);

    const storedWord3 = try memory.read32(8);

    try std.testing.expectEqual(0xBADC0DE, storedWord3); // Expect memory[8] = 0xBADC0DE
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Overlapping stores (multiple writes to the same address)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 4; // Base address in x1
    cpuState.gprs[2] = 0x11111111; // First value to store in x2

    // SW x2, 0(x1)
    const sw4a = Instruction{ .value = encode.SW(2, 0, 1) };

    try execute(sw4a, &cpuState, &memory);

    const storedWord4a = try memory.read32(4);

    try std.testing.expectEqual(0x11111111, storedWord4a); // Expect memory[4] = 0x11111111

    // Write a second value to the same address
    cpuState.gprs[2] = 0x22222222; // Second value to store in x2

    // SW x2, 0(x1)
    const sw4b = Instruction{ .value = encode.SW(2, 0, 1) };

    try execute(sw4b, &cpuState, &memory);

    const storedWord4b = try memory.read32(4);

    try std.testing.expectEqual(0x22222222, storedWord4b); // Expect memory[4] = 0x22222222
    try std.testing.expectEqual(8, cpuState.pc);

    // Case 5: Unaligned memory address (should panic or handle error)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 3; // Base address in x1 (unaligned address)
    cpuState.gprs[2] = 0x55555555; // Value to store in x2

    // SW x2, 0(x1)
    const sw5 = Instruction{ .value = encode.SW(2, 0, 1) };

    const err = execute(sw5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
}

test "Execute BEQ" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Operands are equal (should branch to PC + imm)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5;
    cpuState.gprs[2] = 5;

    // BEQ x1, x2, 12
    const beq1 = Instruction{ .value = encode.BEQ(1, 2, 12) };

    try execute(beq1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 2: Operands are not equal (should fall through)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 10;
    cpuState.gprs[2] = 20;

    // BEQ x1, x2, 12
    const beq2 = Instruction{ .value = encode.BEQ(1, 2, 12) };

    try execute(beq2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should increment by 4

    // Case 3: Negative immediate (should branch backward)
    cpuState.pc = 0x00000020; // Start at address 32
    cpuState.gprs[1] = 0x1234;
    cpuState.gprs[2] = 0x1234;

    // BEQ x1, x2, -16
    const beq3 = Instruction{ .value = encode.BEQ(1, 2, -16) };

    try execute(beq3, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.pc); // PC should branch back to 16

    // Case 4: Zero immediate (should fall through)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 42;
    cpuState.gprs[2] = 42;

    // BEQ x1, x2, 0
    const beq4 = Instruction{ .value = encode.BEQ(1, 2, 0) };

    try execute(beq4, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should increment by 4
}

test "Execute J/JAL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Forward jump without link (rd = 0)
    cpuState.pc = 12;

    // J 12
    const j1 = Instruction{ .value = encode.JAL(0, 12) };

    try execute(j1, &cpuState, &memory);

    try std.testing.expectEqual(24, cpuState.pc); // PC should jump forward by 12
    try std.testing.expectEqual(0, cpuState.gprs[0]); // Ensure x0 is always 0

    // Case 2: Backward jump without link (rd = 0)
    cpuState.pc = 24;

    // J -16
    const j2 = Instruction{ .value = encode.JAL(0, -16) };

    try execute(j2, &cpuState, &memory);

    try std.testing.expectEqual(8, cpuState.pc); // PC should jump backward to 8
    try std.testing.expectEqual(0, cpuState.gprs[0]); // Ensure x0 is always 0

    // Case 3: Forward jump with link (rd != 0)
    cpuState.pc = 16;

    // JAL  x1, 12
    const j3 = Instruction{ .value = encode.JAL(1, 12) };

    try execute(j3, &cpuState, &memory);

    try std.testing.expectEqual(28, cpuState.pc); // PC should jump forward to 28
    try std.testing.expectEqual(20, cpuState.gprs[1]); // x1 should hold the return address (16 + 4)

    // Case 4: Backward jump with link (rd != 0)
    cpuState.pc = 40;

    // JAL x2, -24
    const j4 = Instruction{ .value = encode.JAL(2, -24) };

    try execute(j4, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.pc); // PC should jump backward to 16
    try std.testing.expectEqual(44, cpuState.gprs[2]); // x2 should hold the return address (40 + 4)
}

test "Execute SLT" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: rs1 < rs2 (positive values)
    cpuState.gprs[1] = 1; // rs1
    cpuState.gprs[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt1 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: rs1 == rs2
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5; // rs1
    cpuState.gprs[2] = 5; // rs2

    // SLT x3, x1, x2
    const slt2 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: rs1 > rs2 (positive values)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 10; // rs1
    cpuState.gprs[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt3 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: rs1 < rs2 (negative values)
    cpuState.pc = 0x00000000;
    const v0: i32 = -3; // Is there not a way to do this inline?
    cpuState.gprs[1] = @bitCast(v0); // rs1
    cpuState.gprs[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt4 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: rs1 > rs2 (negative and positive values)
    cpuState.pc = 0x00000000;
    const v1: i32 = -10;
    cpuState.gprs[1] = 5; // rs1
    cpuState.gprs[2] = @bitCast(v1); // rs2

    // SLT x3, x1, x2
    const slt5 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 6: rs1 == rs2 (negative values)
    cpuState.pc = 0x00000000;
    const v2: i32 = -7;
    cpuState.gprs[1] = @bitCast(v2); // rs1
    cpuState.gprs[2] = @bitCast(v2); // rs2

    // SLT x3, x1, x2
    const slt6 = Instruction{ .value = encode.SLT(3, 1, 2) };

    try execute(slt6, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute ANDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple AND operation
    cpuState.gprs[1] = 0b11011011; // x1 = 219

    // ANDI x5, x1, 0b11110000
    const andi1 = Instruction{ .value = encode.ANDI(5, 1, 0b11110000) };

    try execute(andi1, &cpuState, &memory);

    try std.testing.expectEqual(0b11010000, cpuState.gprs[5]); // x5 = 208
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: AND with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b11011011; // x1 = 219

    // ANDI x5, x1, 0
    const andi2 = Instruction{ .value = encode.ANDI(5, 1, 0) };

    try execute(andi2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: AND with all bits set in immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xDEADBEEF; // x1 = 0xDEADBEEF

    // ANDI x5, x1, -1
    const andi3 = Instruction{ .value = encode.ANDI(5, 1, -1) };

    try execute(andi3, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.gprs[5]); // x5 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Negative immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b10101010; // x1 = 170

    // ANDI x5, x1, -16
    const andi4 = Instruction{ .value = encode.ANDI(5, 1, -16) };

    try execute(andi4, &cpuState, &memory);

    try std.testing.expectEqual(0b10100000, cpuState.gprs[5]); // x5 = 160
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Immediate overflow (mask effect)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678

    // ANDI x5, x1, 0x7FF
    const andi5 = Instruction{ .value = encode.ANDI(5, 1, 0x7FF) };

    try execute(andi5, &cpuState, &memory);

    try std.testing.expectEqual(0x678, cpuState.gprs[5]); // x5 = 0x678
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute OR" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple OR operation
    cpuState.gprs[1] = 0b11001100; // x1 = 204
    cpuState.gprs[2] = 0b10101010; // x2 = 170

    // OR x5, x1, x2
    const or1 = Instruction{ .value = encode.OR(5, 1, 2) };

    try execute(or1, &cpuState, &memory);

    try std.testing.expectEqual(0b11101110, cpuState.gprs[5]); // x5 = 238
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: OR with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x0; // x1 = 0
    cpuState.gprs[2] = 0xCAFEBABE; // x2 = 0xCAFEBABE

    // OR x5, x1, x2
    const or2 = Instruction{ .value = encode.OR(5, 1, 2) };

    try execute(or2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.gprs[5]); // x5 = 0xCAFEBABE
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: OR with all bits set
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xFFFFFFFF; // x1 = all bits set
    cpuState.gprs[2] = 0x12345678; // x2 = 0x12345678

    // OR x5, x1, x2
    const or3 = Instruction{ .value = encode.OR(5, 1, 2) };

    try execute(or3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFF, cpuState.gprs[5]); // x5 = all bits set
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Mixed values
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b10010001; // x1 = 145
    cpuState.gprs[2] = 0b01110110; // x2 = 118

    // OR x5, x1, x2
    const or4 = Instruction{ .value = encode.OR(5, 1, 2) };

    try execute(or4, &cpuState, &memory);

    try std.testing.expectEqual(0b11110111, cpuState.gprs[5]); // x5 = 247
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: OR with itself
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x55555555; // x1 = alternating bits
    cpuState.gprs[2] = 0x55555555; // x2 = same value

    // OR x5, x1, x2
    const or5 = Instruction{ .value = encode.OR(5, 1, 2) };

    try execute(or5, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.gprs[5]); // x5 = 0x55555555
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SLL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple left shift
    cpuState.gprs[1] = 0b00001111; // x1 = 15
    cpuState.gprs[2] = 2; // x2 = shift amount = 2

    // SLL x5, x1, x2
    const sll1 = Instruction{ .value = encode.SLL(5, 1, 2) };

    try execute(sll1, &cpuState, &memory);

    try std.testing.expectEqual(0b00111100, cpuState.gprs[5]); // x5 = 60
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Left shift by 0 (no change)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678
    cpuState.gprs[2] = 0; // x2 = shift amount = 0

    // SLL x5, x1, x2
    const sll2 = Instruction{ .value = encode.SLL(5, 1, 2) };

    try execute(sll2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Shift larger than 32 bits (uses lower 5 bits of rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x1; // x1 = 1
    cpuState.gprs[2] = 35; // x2 = shift amount = 35 (35 & 0b11111 = 3)

    // SLL x5, x1, x2
    const sll3 = Instruction{ .value = encode.SLL(5, 1, 2) };

    try execute(sll3, &cpuState, &memory);

    try std.testing.expectEqual(0b1000, cpuState.gprs[5]); // x5 = 8
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Shift a negative number (interpreted as unsigned shift)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xFFFFFFFF; // x1 = -1
    cpuState.gprs[2] = 1; // x2 = shift amount = 1

    // SLL x5, x1, x2
    const sll5 = Instruction{ .value = encode.SLL(5, 1, 2) };

    try execute(sll5, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFE, cpuState.gprs[5]); // x5 = -2 (0xFFFFFFFE)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute XOR" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple XOR
    cpuState.gprs[1] = 0b11001100; // x1 = 204
    cpuState.gprs[2] = 0b10101010; // x2 = 170

    // XOR x5, x1, x2
    const xor1 = Instruction{ .value = encode.XOR(5, 1, 2) };

    try execute(xor1, &cpuState, &memory);

    try std.testing.expectEqual(0b01100110, cpuState.gprs[5]); // x5 = 102
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: XOR with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.gprs[2] = 0x0; // x2 = 0

    // XOR x5, x1, x2
    const xor2 = Instruction{ .value = encode.XOR(5, 1, 2) };

    try execute(xor2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: XOR with all bits set
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678
    cpuState.gprs[2] = 0xFFFFFFFF; // x2 = all bits set

    // XOR x5, x1, x2
    const xor3 = Instruction{ .value = encode.XOR(5, 1, 2) };

    try execute(xor3, &cpuState, &memory);

    try std.testing.expectEqual(0xEDCBA987, cpuState.gprs[5]); // x5 = inverted bits
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: XOR with itself
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x55555555; // x1 = alternating bits
    cpuState.gprs[2] = 0x55555555; // x2 = same value

    // XOR x5, x1, x2
    const xor4 = Instruction{ .value = encode.XOR(5, 1, 2) };

    try execute(xor4, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Mixed values
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b11110000; // x1 = 240
    cpuState.gprs[2] = 0b00001111; // x2 = 15

    // XOR x5, x1, x2
    const xor5 = Instruction{ .value = encode.XOR(5, 1, 2) };

    try execute(xor5, &cpuState, &memory);

    try std.testing.expectEqual(0b11111111, cpuState.gprs[5]); // x5 = 255
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SLTU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: rs1 < rs2 (unsigned)
    cpuState.gprs[1] = 10; // x1 = 10
    cpuState.gprs[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu1 = Instruction{ .value = encode.SLTU(5, 1, 2) };

    try execute(sltu1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: rs1 == rs2
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20
    cpuState.gprs[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu2 = Instruction{ .value = encode.SLTU(5, 1, 2) };

    try execute(sltu2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: rs1 > rs2 (unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 30; // x1 = 30
    cpuState.gprs[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu3 = Instruction{ .value = encode.SLTU(5, 1, 2) };

    try execute(sltu3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Comparison with signed values treated as unsigned
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // x1 = 1
    cpuState.gprs[2] = 0xFFFFFFFF; // (-1 as unsigned)

    // SLTU x5, x1, x2
    const sltu4 = Instruction{ .value = encode.SLTU(5, 1, 2) };

    try execute(sltu4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (1 < 0xFFFFFFFF)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: rs1 == 0 and rs2 == large unsigned value
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0; // x1 = 0
    cpuState.gprs[2] = 0x80000000; // x2 = 2^31 (large unsigned value)

    // SLTU x5, x1, x2
    const sltu5 = Instruction{ .value = encode.SLTU(5, 1, 2) };

    try execute(sltu5, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SRL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple right shift
    cpuState.gprs[1] = 0b11110000; // x1 = 240
    cpuState.gprs[2] = 4; // x2 = shift amount = 4

    // SRL x5, x1, x2
    const srl1 = Instruction{ .value = encode.SRL(5, 1, 2) };

    try execute(srl1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.gprs[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Right shift by 0 (no change)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678
    cpuState.gprs[2] = 0; // x2 = shift amount = 0

    // SRL x5, x1, x2
    const srl2 = Instruction{ .value = encode.SRL(5, 1, 2) };

    try execute(srl2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Shift larger than 32 bits (uses lower 5 bits of rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x80000000; // x1 = 0x80000000
    cpuState.gprs[2] = 35; // x2 = shift amount = 35 (35 & 0b11111 = 3)

    // SRL x5, x1, x2
    const srl3 = Instruction{ .value = encode.SRL(5, 1, 2) };

    try execute(srl3, &cpuState, &memory);

    try std.testing.expectEqual(0x10000000, cpuState.gprs[5]); // x5 = 0x10000000
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Shift a negative number (treated as unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xFFFFFFFF;
    cpuState.gprs[2] = 1; // x2 = shift amount = 1

    // SRL x5, x1, x2
    const srl5 = Instruction{ .value = encode.SRL(5, 1, 2) };

    try execute(srl5, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFFFFFF, cpuState.gprs[5]); // x5 = 0x7FFFFFFF
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SRA" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple arithmetic right shift (positive number)
    cpuState.gprs[1] = 0b01111000; // x1 = 120
    cpuState.gprs[2] = 3; // x2 = shift amount = 3

    // SRA x5, x1, x2
    const sra1 = Instruction{ .value = encode.SRA(5, 1, 2) };

    try execute(sra1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.gprs[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Simple arithmetic right shift (negative number)
    const negValue: i32 = -120; // 0b11111000 (two's complement)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(negValue); // x1 = -120
    cpuState.gprs[2] = 3; // x2 = shift amount = 3

    // SRA x5, x1, x2
    const sra2 = Instruction{ .value = encode.SRA(5, 1, 2) };

    try execute(sra2, &cpuState, &memory);

    const expected2: i32 = -15; // Result: 0b11111111 11111111 11111111 11110001
    const actual2: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(expected2, actual2); // x5 = -15
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Arithmetic shift by 0 (no change)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.gprs[2] = 0; // x2 = shift amount = 0

    // SRA x5, x1, x2
    const sra3 = Instruction{ .value = encode.SRA(5, 1, 2) };

    try execute(sra3, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Shift larger than 32 bits (uses lower 5 bits of rs2)
    const negValue4: i32 = -1; // x1 = 0xFFFFFFFF
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = @bitCast(negValue4); // x1 = -1
    cpuState.gprs[2] = 33; // x2 = shift amount = 33 (33 & 0b11111 = 1)

    // SRA x5, x1, x2
    const sra4 = Instruction{ .value = encode.SRA(5, 1, 2) };

    try execute(sra4, &cpuState, &memory);

    const expected4: i32 = -1; // Result stays -1 due to sign extension
    const actual4: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(expected4, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: All bits shifted out (positive value)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x7FFFFFFF; // x1 = largest positive value
    cpuState.gprs[2] = 31; // x2 = shift amount = 31

    // SRA x5, x1, x2
    const sra5 = Instruction{ .value = encode.SRA(5, 1, 2) };

    try execute(sra5, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute AND" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple AND operation
    cpuState.gprs[1] = 0b11001100; // x1 = 204
    cpuState.gprs[2] = 0b10101010; // x2 = 170

    // AND x5, x1, x2
    const and1 = Instruction{ .value = encode.AND(5, 1, 2) };

    try execute(and1, &cpuState, &memory);

    try std.testing.expectEqual(0b10001000, cpuState.gprs[5]); // x5 = 136
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: AND with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.gprs[2] = 0x0; // x2 = 0

    // AND x5, x1, x2
    const and2 = Instruction{ .value = encode.AND(5, 1, 2) };

    try execute(and2, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: AND with all bits set
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678
    cpuState.gprs[2] = 0xFFFFFFFF; // x2 = all bits set

    // AND x5, x1, x2
    const and3 = Instruction{ .value = encode.AND(5, 1, 2) };

    try execute(and3, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[5]); // x5 = 0x12345678
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: AND with itself
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x55555555; // x1 = alternating bits
    cpuState.gprs[2] = 0x55555555; // x2 = same value

    // AND x5, x1, x2
    const and4 = Instruction{ .value = encode.AND(5, 1, 2) };

    try execute(and4, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.gprs[5]); // x5 = 0x55555555
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Mixed values
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b11110000; // x1 = 240
    cpuState.gprs[2] = 0b00001111; // x2 = 15

    // AND x5, x1, x2
    const and5 = Instruction{ .value = encode.AND(5, 1, 2) };

    try execute(and5, &cpuState, &memory);

    try std.testing.expectEqual(0b00000000, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SLLI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple left shift
    cpuState.gprs[1] = 0b00001111; // x1 = 15

    // SLLI x5, x1, 2
    const slli1 = Instruction{ .value = encode.SLLI(5, 1, 2) };

    try execute(slli1, &cpuState, &memory);

    try std.testing.expectEqual(0b00111100, cpuState.gprs[5]); // x5 = 60
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Shift by 0 (no change)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678

    // SLLI x5, x1, 0
    const slli2 = Instruction{ .value = encode.SLLI(5, 1, 0) };

    try execute(slli2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Shift by 31 (maximum allowed by shamt)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // x1 = 1

    // SLLI x5, x1, 31
    const slli3 = Instruction{ .value = encode.SLLI(5, 1, 31) };

    try execute(slli3, &cpuState, &memory);

    try std.testing.expectEqual(0x80000000, cpuState.gprs[5]); // x5 = 2^31
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Shift left by -1 (interpreted as 31 due to bit truncation)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // x1 = 1

    // SLLI x5, x1, -1
    const slli5 = Instruction{ .value = encode.SLLI(5, 1, 0b11111) };

    try execute(slli5, &cpuState, &memory);

    try std.testing.expectEqual(0x80000000, cpuState.gprs[5]); // x5 = 2^31
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SLTI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: rs1 < imm (positive comparison)
    cpuState.gprs[1] = 10; // x1 = 10

    // SLTI x5, x1, 20
    const slti1 = Instruction{ .value = encode.SLTI(5, 1, 20) };

    try execute(slti1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: rs1 == imm
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20

    // SLTI x5, x1, 20
    const slti2 = Instruction{ .value = encode.SLTI(5, 1, 20) };

    try execute(slti2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: rs1 > imm
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 30; // x1 = 30

    // SLTI x5, x1, 20
    const slti3 = Instruction{ .value = encode.SLTI(5, 1, 20) };

    try execute(slti3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: rs1 is negative, imm is positive
    cpuState.pc = 0x00000000;
    const negRs1: i32 = -10;
    cpuState.gprs[1] = @bitCast(negRs1); // x1 = -10

    // SLTI x5, x1, 5
    const slti4 = Instruction{ .value = encode.SLTI(5, 1, 5) };

    try execute(slti4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: rs1 is positive, imm is negative
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 10; // x1 = 10

    // SLTI x5, x1, -20
    const slti5 = Instruction{ .value = encode.SLTI(5, 1, -20) };

    try execute(slti5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 6: rs1 and imm are negative
    cpuState.pc = 0x00000000;
    const negRs16: i32 = -10;
    cpuState.gprs[1] = @bitCast(negRs16); // x1 = -10

    // SLTI x5, x1, -5
    const slti6 = Instruction{ .value = encode.SLTI(5, 1, -5) };

    try execute(slti6, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SLTIU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: rs1 < imm (unsigned)
    cpuState.gprs[1] = 10; // x1 = 10

    // SLTIU x5, x1, 20
    const sltiu1 = Instruction{ .value = encode.SLTIU(5, 1, 20) };

    try execute(sltiu1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: rs1 == imm
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20

    // SLTIU x5, x1, 20
    const sltiu2 = Instruction{ .value = encode.SLTIU(5, 1, 20) };

    try execute(sltiu2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: rs1 > imm (unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 30; // x1 = 30

    // SLTIU x5, x1, 20
    const sltiu3 = Instruction{ .value = encode.SLTIU(5, 1, 20) };

    try execute(sltiu3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.gprs[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Signed negative value treated as unsigned
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // x1 = 1

    // SLTIU x5, x1, -1
    const sltiu4 = Instruction{ .value = encode.SLTIU(5, 1, -1) };

    try execute(sltiu4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.gprs[5]); // x5 = 1 (1 < 0xFFFFFFFF)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute XORI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple XORI operation
    cpuState.gprs[1] = 0b11001100; // x1 = 204

    // XORI x5, x1, 0b10101010
    const xori1 = Instruction{ .value = encode.XORI(5, 1, 0b10101010) };

    try execute(xori1, &cpuState, &memory);

    try std.testing.expectEqual(0b01100110, cpuState.gprs[5]); // x5 = 102
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: XORI with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE

    // XORI x5, x1, 0
    const xori2 = Instruction{ .value = encode.XORI(5, 1, 0) };

    try execute(xori2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: XORI with all bits set
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678

    // XORI x5, x1, -1
    const xori3 = Instruction{ .value = encode.XORI(5, 1, -1) };

    try execute(xori3, &cpuState, &memory);

    try std.testing.expectEqual(0xEDCBA987, cpuState.gprs[5]); // x5 = inverted bits
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: XORI with zero register (x1 = 0)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x0; // x1 = 0

    // XORI x5, x1, 0x3F
    const xori5 = Instruction{ .value = encode.XORI(5, 1, 0x3F) };

    try execute(xori5, &cpuState, &memory);

    try std.testing.expectEqual(0x3F, cpuState.gprs[5]); // x5 = 0x3F
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SRLI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple right shift
    cpuState.gprs[1] = 0b11110000; // x1 = 240

    // SRLI x5, x1, 4
    const srli1 = Instruction{ .value = encode.SRLI(5, 1, 4) };

    try execute(srli1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.gprs[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Shift by 0 (no change)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678

    // SRLI x5, x1, 0
    const srli2 = Instruction{ .value = encode.SRLI(5, 1, 0) };

    try execute(srli2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Edge case: Input with alternating bits
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xAAAAAAAA; // x1 = alternating bits

    // SRLI x5, x1, 1
    const srli5 = Instruction{ .value = encode.SRLI(5, 1, 1) };

    try execute(srli5, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.gprs[5]); // x5 = shifted right
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute ORI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Simple ORI
    cpuState.gprs[1] = 0b11001100; // x1 = 204

    // ORI x5, x1, 0b10101010
    const ori1 = Instruction{ .value = encode.ORI(5, 1, 0b10101010) };

    try execute(ori1, &cpuState, &memory);

    try std.testing.expectEqual(0b11101110, cpuState.gprs[5]); // x5 = 238
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: ORI with zero
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE

    // ORI x5, x1, 0
    const ori2 = Instruction{ .value = encode.ORI(5, 1, 0) };

    try execute(ori2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.gprs[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: ORI with all bits set in immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x12345678; // x1 = 0x12345678

    // ORI x5, x1, -1
    const ori3 = Instruction{ .value = encode.ORI(5, 1, -1) };

    try execute(ori3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFF, cpuState.gprs[5]); // x5 = all bits set
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: ORI with a negative immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0b11110000; // x1 = 240

    // ORI x5, x1, -16
    const ori4 = Instruction{ .value = encode.ORI(5, 1, -16) };

    try execute(ori4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFF0, cpuState.gprs[5]); // x5 = OR with immediate
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: ORI with a positive immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x0; // x1 = 0

    // ORI x5, x1, 0x7FF
    const ori5 = Instruction{ .value = encode.ORI(5, 1, 0x7FF) };

    try execute(ori5, &cpuState, &memory);

    try std.testing.expectEqual(0x7FF, cpuState.gprs[5]); // x5 = 0x7FF
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute LB" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    // Initialize memory for tests
    try memory.write8(0, 0x7F); // Address 0: 127 (positive signed byte)
    try memory.write8(1, 0x80); // Address 1: -128 (negative signed byte)
    try memory.write8(2, 0x01); // Address 2: 1
    try memory.write8(3, 0xFF); // Address 3: -1

    var cpuState = CPUState.default();

    // Case 1: Load a positive signed byte
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LB x5, 0(x1)
    const lb1 = Instruction{ .value = encode.LB(5, 1, 0) };

    try execute(lb1, &cpuState, &memory);

    try std.testing.expectEqual(0x7F, cpuState.gprs[5]); // x5 = 127
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load a negative signed byte
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // Base address in x1

    // LB x5, 0(x1)
    const lb2 = Instruction{ .value = encode.LB(5, 1, 0) };

    try execute(lb2, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-128, actual2); // x5 = -128
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load with non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LB x5, 2(x1)
    const lb3 = Instruction{ .value = encode.LB(5, 1, 2) };

    try execute(lb3, &cpuState, &memory);

    try std.testing.expectEqual(0x01, cpuState.gprs[5]); // x5 = 1
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Load from address with negative immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000004; // Base address in x1

    // LB x5, -1(x1)
    const lb4 = Instruction{ .value = encode.LB(5, 1, -1) };

    try execute(lb4, &cpuState, &memory);

    const actual4: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-1, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.pc);

    // TODO: Test misalign error
    // Case 5: Load with out-of-bound memory (should panic or error)
    // cpuState.pc = 0x00000000;
    // cpuState.gprs[1] = 0x00000010; // Address beyond allocated memory

    // // LB x5, 0(x1)
    // const lb5: DecodedInstruction = .{
    //     .IType = .{ .opcode = 0b0000011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 0 },
    // };

    // try std.testing.expectPanic(@async execute(lb5, &cpuState, &memory)); // Expect panic on invalid access
}

test "Execute LH" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    // Initialize memory for tests
    try memory.write16(0, 0x7FFF); // Address 0: 32767 (positive signed halfword)
    try memory.write16(2, 0x8000); // Address 2: -32768 (negative signed halfword)
    try memory.write16(4, 0x1234); // Address 4: 4660
    try memory.write16(6, 0xFFFF); // Address 6: -1 (negative signed halfword)

    var cpuState = CPUState.default();

    // Case 1: Load a positive signed halfword
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LH x5, 0(x1)
    const lh1 = Instruction{ .value = encode.LH(5, 1, 0) };

    try execute(lh1, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFF, cpuState.gprs[5]); // x5 = 32767
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load a negative signed halfword
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000002; // Base address in x1

    // LH x5, 0(x1)
    const lh2 = Instruction{ .value = encode.LH(5, 1, 0) };

    try execute(lh2, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-32768, actual2); // x5 = -32768
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load with a non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LH x5, 4(x1)
    const lh3 = Instruction{ .value = encode.LH(5, 1, 4) };

    try execute(lh3, &cpuState, &memory);

    try std.testing.expectEqual(0x1234, cpuState.gprs[5]); // x5 = 4660
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Load a negative halfword and check sign-extension
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000006; // Base address in x1

    // LH x5, 0(x1)
    const lh4 = Instruction{ .value = encode.LH(5, 1, 0) };

    try execute(lh4, &cpuState, &memory);

    const actual4: i32 = @bitCast(cpuState.gprs[5]);
    try std.testing.expectEqual(-1, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Misaligned address (should panic or error)
    // cpuState.pc = 0x00000000;
    // cpuState.gprs[1] = 0x00000001; // Misaligned address in x1

    // // LH x5, 0(x1)
    // const lh5: DecodedInstruction = .{
    //     .IType = .{ .opcode = 0b0000011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 0 },
    // };

    // try std.testing.expectPanic(@async execute(lh5, &cpuState, &memory)); // Expect panic on misaligned access
}

test "Execute LBU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    // Initialize memory for tests
    try memory.write8(0, 0x80); // Address 0: 128 (unsigned byte)
    try memory.write8(1, 0x7F); // Address 1: 127 (unsigned byte)
    try memory.write8(2, 0xFF); // Address 2: 255 (unsigned byte)
    try memory.write8(3, 0x00); // Address 3: 0 (unsigned byte)

    var cpuState = CPUState.default();

    // Case 1: Load an unsigned byte
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LBU x5, 0(x1)
    const lbu1 = Instruction{ .value = encode.LBU(5, 1, 0) };

    try execute(lbu1, &cpuState, &memory);

    try std.testing.expectEqual(0x00000080, cpuState.gprs[5]); // x5 = 128
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load a small unsigned byte
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // Base address in x1

    // LBU x5, 0(x1)
    const lbu2 = Instruction{ .value = encode.LBU(5, 1, 0) };

    try execute(lbu2, &cpuState, &memory);

    try std.testing.expectEqual(0x0000007F, cpuState.gprs[5]); // x5 = 127
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load a maximum unsigned byte
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000002; // Base address in x1

    // LBU x5, 0(x1)
    const lbu3 = Instruction{ .value = encode.LBU(5, 1, 0) };

    try execute(lbu3, &cpuState, &memory);

    try std.testing.expectEqual(0x000000FF, cpuState.gprs[5]); // x5 = 255
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Load a zero byte
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000003; // Base address in x1

    // LBU x5, 0(x1)
    const lbu4 = Instruction{ .value = encode.LBU(5, 1, 0) };

    try execute(lbu4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.gprs[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Load with a non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // Base address in x1

    // LBU x5, 1(x1)
    const lbu5 = Instruction{ .value = encode.LBU(5, 1, 1) };

    try execute(lbu5, &cpuState, &memory);

    try std.testing.expectEqual(0x000000FF, cpuState.gprs[5]); // x5 = 255 (address 2)
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute LHU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    // Initialize memory for tests
    try memory.write16(0, 0x7FFF); // Address 0: 32767 (positive unsigned halfword)
    try memory.write16(2, 0x8000); // Address 2: 32768 (unsigned)
    try memory.write16(4, 0xFFFF); // Address 4: 65535 (all bits set)

    var cpuState = CPUState.default();

    // Case 1: Load a positive unsigned halfword
    cpuState.gprs[1] = 0x00000000; // Base address in x1

    // LHU x5, 0(x1)
    const lhu1 = Instruction{ .value = encode.LHU(5, 1, 0) };

    try execute(lhu1, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFF, cpuState.gprs[5]); // x5 = 32767
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load an unsigned halfword with high bit set
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000002; // Base address in x1

    // LHU x5, 0(x1)
    const lhu2 = Instruction{ .value = encode.LHU(5, 1, 0) };

    try execute(lhu2, &cpuState, &memory);

    try std.testing.expectEqual(0x8000, cpuState.gprs[5]); // x5 = 32768
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load all bits set (maximum unsigned halfword)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000004; // Base address in x1

    // LHU x5, 0(x1)
    const lhu3 = Instruction{ .value = encode.LHU(5, 1, 0) };

    try execute(lhu3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFF, cpuState.gprs[5]); // x5 = 65535
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Load with non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000001; // Base address in x1

    // LHU x5, 3(x1) -> Address = 1 + 3 = 4
    const lhu4 = Instruction{ .value = encode.LHU(5, 1, 3) };

    try execute(lhu4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFF, cpuState.gprs[5]); // x5 = 65535
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Load from unaligned address (should work for `LHU`)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000003; // Base address in x1

    // LHU x5, 0(x1) -> Address = 3
    const lhu5 = Instruction{ .value = encode.LHU(5, 1, 0) };

    const err = execute(lhu5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
    // TODO: Should PC increment if misaligned memory access error occurs?
    //try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute SB" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Store a positive byte
    cpuState.gprs[1] = 0x00000000; // Base address in x1
    cpuState.gprs[2] = 0x0000007F; // Value to store in x2 (127)

    // SB x2, 0(x1)
    const sb1 = Instruction{ .value = encode.SB(2, 0, 1) };

    try execute(sb1, &cpuState, &memory);

    const storedByte1 = try memory.read8(0x00000000);
    try std.testing.expectEqual(0x7F, storedByte1); // Expect 127 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Store a negative byte
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000004; // Base address in x1
    const neg128: i32 = -128;
    cpuState.gprs[2] = @bitCast(neg128); // Value to store in x2 (-128)

    // SB x2, 0(x1)
    const sb2 = Instruction{ .value = encode.SB(2, 0, 1) };

    try execute(sb2, &cpuState, &memory);

    const storedByte2 = try memory.read8(0x00000004);
    try std.testing.expectEqual(0x80, storedByte2); // Expect 0x80 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Store with a non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000000; // Base address in x1
    cpuState.gprs[2] = 0x00000001; // Value to store in x2 (1)

    // SB x2, 2(x1)
    const sb3 = Instruction{ .value = encode.SB(2, 2, 1) };

    try execute(sb3, &cpuState, &memory);

    const storedByte3 = try memory.read8(0x00000002);
    try std.testing.expectEqual(0x01, storedByte3); // Expect 1 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Store with a negative offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000008; // Base address in x1
    cpuState.gprs[2] = 0x000000FF; // Value to store in x2 (255)

    // SB x2, -4(x1)
    const sb4 = Instruction{ .value = encode.SB(2, -4, 1) };

    try execute(sb4, &cpuState, &memory);

    const storedByte4 = try memory.read8(0x00000004);
    try std.testing.expectEqual(0xFF, storedByte4); // Expect 255 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Out-of-bound memory access (should panic or error)
    // cpuState.pc = 0x00000000;
    // cpuState.gprs[1] = 0x00000010; // Address beyond allocated memory
    // cpuState.gprs[2] = 0x12345678; // Value to store in x2

    // // SB x2, 0(x1)
    // const sb5: DecodedInstruction = .{
    //     .SType = .{ .opcode = 0b0100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 0 },
    // };

    // try std.testing.expectPanic(@async execute(sb5, &cpuState, &memory)); // Expect panic on invalid access
}

test "Execute SH" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Store a positive halfword
    cpuState.gprs[1] = 0x00000000; // Base address in x1
    cpuState.gprs[2] = 0x00007FFF; // Value to store in x2 (32767)

    // SH x2, 0(x1)
    const sh1 = Instruction{ .value = encode.SH(2, 0, 1) };

    try execute(sh1, &cpuState, &memory);

    const storedHalf1 = try memory.read16(0x00000000);
    try std.testing.expectEqual(0x7FFF, storedHalf1); // Expect 32767 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Store a negative halfword
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000004; // Base address in x1
    cpuState.gprs[2] = 0xFFFFFFFF; // Value to store in x2 (-1, 0xFFFF)

    // SH x2, 0(x1)
    const sh2 = Instruction{ .value = encode.SH(2, 0, 1) };

    try execute(sh2, &cpuState, &memory);

    const storedHalf2 = try memory.read16(0x00000004);
    try std.testing.expectEqual(0xFFFF, storedHalf2); // Expect 0xFFFF in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Store with a non-zero offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000000; // Base address in x1
    cpuState.gprs[2] = 0x00001234; // Value to store in x2 (4660)

    // SH x2, 6(x1)
    const sh3 = Instruction{ .value = encode.SH(2, 6, 1) };

    try execute(sh3, &cpuState, &memory);

    const storedHalf3 = try memory.read16(0x00000006);
    try std.testing.expectEqual(0x1234, storedHalf3); // Expect 4660 in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Store with a negative offset
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x00000008; // Base address in x1
    cpuState.gprs[2] = 0xABCD; // Value to store in x2

    // SH x2, -2(x1)
    const sh4 = Instruction{ .value = encode.SH(2, -2, 1) };

    try execute(sh4, &cpuState, &memory);

    const storedHalf4 = try memory.read16(0x00000006);
    try std.testing.expectEqual(0xABCD, storedHalf4); // Expect 0xABCD in memory
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 5: Out-of-bound memory access (should panic or error)
    // cpuState.pc = 0x00000000;
    // cpuState.gprs[1] = 0x00000010; // Address beyond allocated memory
    // cpuState.gprs[2] = 0x5678;     // Value to store in x2

    // // SH x2, 0(x1)
    // const sh5: DecodedInstruction = .{
    //     .SType = .{ .opcode = 0b0100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 0 },
    // };

    // try std.testing.expectPanic(@async execute(sh5, &cpuState, &memory)); // Expect panic on invalid access
}

test "Execute BNE" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Branch taken (values not equal)
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // BNE x1, x2, 12
    const bne1 = Instruction{ .value = encode.BNE(1, 2, 12) };

    try execute(bne1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 2: Branch not taken (values equal)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 15; // x1 = 15
    cpuState.gprs[2] = 15; // x2 = 15

    // BNE x1, x2, 8
    const bne2 = Instruction{ .value = encode.BNE(1, 2, 8) };

    try execute(bne2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 3: Negative immediate offset
    cpuState.pc = 0x00000010;
    cpuState.gprs[1] = 25; // x1 = 25
    cpuState.gprs[2] = 35; // x2 = 35

    // BNE x1, x2, -8
    const bne3 = Instruction{ .value = encode.BNE(1, 2, -8) };

    try execute(bne3, &cpuState, &memory);

    try std.testing.expectEqual(0x00000008, cpuState.pc); // PC should branch to 8

    // Case 4: Zero branch offset (should not branch)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // x1 = 1
    cpuState.gprs[2] = 2; // x2 = 2

    // BNE x1, x2, 0
    const bne4 = Instruction{ .value = encode.BNE(1, 2, 0) };

    try execute(bne4, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 5: Large positive immediate
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 100; // x1 = 100
    cpuState.gprs[2] = 50; // x2 = 50

    // BNE x1, x2, 2048
    const bne5 = Instruction{ .value = encode.BNE(1, 2, 2048) };

    try execute(bne5, &cpuState, &memory);

    try std.testing.expectEqual(2048, cpuState.pc); // PC should branch to 2048
}

test "Execute BLT" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Branch taken (rs1 < rs2)
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // BLT x1, x2, 12
    const blt1 = Instruction{ .value = encode.BLT(1, 2, 12) };

    try execute(blt1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 2: Branch not taken (rs1 == rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 15; // x1 = 15
    cpuState.gprs[2] = 15; // x2 = 15

    // BLT x1, x2, 8
    const blt2 = Instruction{ .value = encode.BLT(1, 2, 8) };

    try execute(blt2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 3: Branch not taken (rs1 > rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20
    cpuState.gprs[2] = 10; // x2 = 10

    // BLT x1, x2, 16
    const blt3 = Instruction{ .value = encode.BLT(1, 2, 16) };

    try execute(blt3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 4: Branch taken (negative rs1 < positive rs2)
    cpuState.pc = 0x00000000;
    const neg5: i32 = -5;
    cpuState.gprs[1] = @bitCast(neg5); // x1 = -5
    cpuState.gprs[2] = 5; // x2 = 5

    // BLT x1, x2, 20
    const blt4 = Instruction{ .value = encode.BLT(1, 2, 20) };

    try execute(blt4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.pc); // PC should branch to 20

    // Case 5: Branch not taken (negative rs1 > negative rs2)
    cpuState.pc = 0x00000000;
    const neg10: i32 = -10;
    cpuState.gprs[1] = @bitCast(neg5); // x1 = -5
    cpuState.gprs[2] = @bitCast(neg10); // x2 = -10

    // BLT x1, x2, -8
    const blt5 = Instruction{ .value = encode.BLT(1, 2, -8) };

    try execute(blt5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction
}

test "Execute BGE" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Branch taken (rs1 > rs2)
    cpuState.gprs[1] = 10; // x1 = 10
    cpuState.gprs[2] = 5; // x2 = 5

    // BGE x1, x2, 16
    const bge1 = Instruction{ .value = encode.BGE(1, 2, 16) };

    try execute(bge1, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.pc); // PC should branch to 16

    // Case 2: Branch taken (rs1 == rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 15; // x1 = 15
    cpuState.gprs[2] = 15; // x2 = 15

    // BGE x1, x2, 12
    const bge2 = Instruction{ .value = encode.BGE(1, 2, 12) };

    try execute(bge2, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 3: Branch not taken (rs1 < rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // BGE x1, x2, 8
    const bge3 = Instruction{ .value = encode.BGE(1, 2, 8) };

    try execute(bge3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 4: Branch taken (negative rs1 >= negative rs2)
    cpuState.pc = 0x00000000;
    const neg5: i32 = -5;
    const neg10: i32 = -10;
    cpuState.gprs[1] = @bitCast(neg5); // x1 = -5
    cpuState.gprs[2] = @bitCast(neg10); // x2 = -10

    // BGE x1, x2, 20
    const bge4 = Instruction{ .value = encode.BGE(1, 2, 20) };

    try execute(bge4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.pc); // PC should branch to 20

    // Case 5: Branch not taken (negative rs1 < positive rs2)
    cpuState.pc = 0x00000000;
    const neg15: i32 = -15;
    cpuState.gprs[1] = @bitCast(neg15); // x1 = -15
    cpuState.gprs[2] = 10; // x2 = 10

    // BGE x1, x2, -12
    const bge5 = Instruction{ .value = encode.BGE(1, 2, -12) };

    try execute(bge5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction
}

test "Execute BLTU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Branch taken (rs1 < rs2, unsigned)
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // BLTU x1, x2, 12
    const bltu1 = Instruction{ .value = encode.BLTU(1, 2, 12) };

    try execute(bltu1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 2: Branch not taken (rs1 == rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 15; // x1 = 15
    cpuState.gprs[2] = 15; // x2 = 15

    // BLTU x1, x2, 8
    const bltu2 = Instruction{ .value = encode.BLTU(1, 2, 8) };

    try execute(bltu2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 3: Branch not taken (rs1 > rs2, unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 20; // x1 = 20
    cpuState.gprs[2] = 10; // x2 = 10

    // BLTU x1, x2, 16
    const bltu3 = Instruction{ .value = encode.BLTU(1, 2, 16) };

    try execute(bltu3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 4: Branch taken (rs1 < rs2, unsigned with wraparound)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // x1 = 1
    cpuState.gprs[2] = 0xFFFFFFFF; // x2 = max unsigned (4294967295)

    // BLTU x1, x2, 20
    const bltu4 = Instruction{ .value = encode.BLTU(1, 2, 20) };

    try execute(bltu4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.pc); // PC should branch to 20

    // Case 5: Branch not taken (large unsigned rs1 >= small unsigned rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x80000000; // x1 = 2147483648 (unsigned)
    cpuState.gprs[2] = 100; // x2 = 100 (unsigned)

    // BLTU x1, x2, -8
    const bltu5 = Instruction{ .value = encode.BLTU(1, 2, -8) };

    try execute(bltu5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction
}

test "Execute BGEU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Branch taken (rs1 > rs2, unsigned)
    cpuState.gprs[1] = 20; // x1 = 20
    cpuState.gprs[2] = 10; // x2 = 10

    // BGEU x1, x2, 16
    const bgeu1 = Instruction{ .value = encode.BGEU(1, 2, 16) };

    try execute(bgeu1, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.pc); // PC should branch to 16

    // Case 2: Branch taken (rs1 == rs2, unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 15; // x1 = 15
    cpuState.gprs[2] = 15; // x2 = 15

    // BGEU x1, x2, 12
    const bgeu2 = Instruction{ .value = encode.BGEU(1, 2, 12) };

    try execute(bgeu2, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.pc); // PC should branch to 12

    // Case 3: Branch not taken (rs1 < rs2, unsigned)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 5; // x1 = 5
    cpuState.gprs[2] = 10; // x2 = 10

    // BGEU x1, x2, 8
    const bgeu3 = Instruction{ .value = encode.BGEU(1, 2, 8) };

    try execute(bgeu3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction

    // Case 4: Branch taken (large unsigned rs1 >= small unsigned rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 0x80000000; // x1 = 2147483648 (unsigned)
    cpuState.gprs[2] = 100; // x2 = 100 (unsigned)

    // BGEU x1, x2, 20
    const bgeu4 = Instruction{ .value = encode.BGEU(1, 2, 20) };

    try execute(bgeu4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.pc); // PC should branch to 20

    // Case 5: Branch not taken (small unsigned rs1 < large unsigned rs2)
    cpuState.pc = 0x00000000;
    cpuState.gprs[1] = 1; // x1 = 1
    cpuState.gprs[2] = 0xFFFFFFFF; // x2 = 4294967295 (unsigned)

    // BGEU x1, x2, -8
    const bgeu5 = Instruction{ .value = encode.BGEU(1, 2, -8) };

    try execute(bgeu5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.pc); // PC should move to next instruction
}

test "Execute LUI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    // Case 1: Load a positive immediate value
    // LUI x5, 0x12345
    const lui1 = Instruction{ .value = encode.LUI(5, 0x12345) };

    try execute(lui1, &cpuState, &memory);

    try std.testing.expectEqual(0x12345000, cpuState.gprs[5]); // x5 = 0x12345000
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 2: Load a negative immediate value
    cpuState.pc = 0;

    // LUI x6, -1 (0xFFFFF)
    const lui2 = Instruction{ .value = encode.LUI(6, -1) };

    try execute(lui2, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFF000, cpuState.gprs[6]); // x6 = 0xFFFFF000
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 3: Load with imm = 0
    cpuState.pc = 0;

    // LUI x7, 0x0
    const lui3 = Instruction{ .value = encode.LUI(7, 0) };

    try execute(lui3, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.gprs[7]); // x7 = 0x00000000
    try std.testing.expectEqual(4, cpuState.pc);

    // Case 4: Write to x0 (should remain 0)
    cpuState.pc = 0;

    // LUI x0, 0x12345
    const lui4 = Instruction{ .value = encode.LUI(0, 0x12345) };

    try execute(lui4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.gprs[0]); // x0 = 0x00000000
    try std.testing.expectEqual(4, cpuState.pc);
}

test "Execute AUIPC" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState = CPUState.default();

    cpuState.pc = 0x1000;

    // Case 1: Add a positive immediate value
    // AUIPC x5, 0x12345
    const auipc1 = Instruction{ .value = encode.AUIPC(5, 0x12345) };

    try execute(auipc1, &cpuState, &memory);

    try std.testing.expectEqual(0x12346000, cpuState.gprs[5]); // x5 = PC + 0x12345000 = 0x12346000
    try std.testing.expectEqual(0x1004, cpuState.pc);

    // Case 2: Add a negative immediate value
    // AUIPC x6, -1 (0xFFFFF)
    cpuState.pc = 0x00002000;
    const auipc2 = Instruction{ .value = encode.AUIPC(6, -1) };

    try execute(auipc2, &cpuState, &memory);

    try std.testing.expectEqual(0x00001000, cpuState.gprs[6]); // x6 = PC + 0xFFFFF000 = 0x00001000
    try std.testing.expectEqual(0x00002004, cpuState.pc);

    // Case 3: Add with imm = 0
    // AUIPC x7, 0x0
    cpuState.pc = 0x00003000;
    const auipc3 = Instruction{ .value = encode.AUIPC(7, 0x0) };

    try execute(auipc3, &cpuState, &memory);

    try std.testing.expectEqual(0x00003000, cpuState.gprs[7]); // x7 = PC + 0x00000000 = 0x00003000
    try std.testing.expectEqual(0x00003004, cpuState.pc);

    // Case 4: Write to x0 (should remain 0)
    // AUIPC x0, 0x12345
    cpuState.pc = 0x00004000;
    const auipc4 = Instruction{ .value = encode.AUIPC(0, 0x12334) };

    try execute(auipc4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.gprs[0]); // x0 = 0 (unchanged)
    try std.testing.expectEqual(0x00004004, cpuState.pc);
}
