const std = @import("std");
const instruction = @import("./instruction.zig");
const DecodedInstruction = instruction.DecodedInstruction;
const RawInstruction = instruction.RawInstruction;
const Memory = @import("./memory.zig").Memory;

pub const CPUState = struct {
    ProgramCounter: u32,
    Registers: [32]u32,
};

pub fn execute(decodedInstruction: DecodedInstruction, cpuState: *CPUState, memory: *Memory) !void {
    switch (decodedInstruction) {
        .RType => |inst| {
            if (inst.rd != 0) {
                const rs1Value = cpuState.Registers[inst.rs1];
                const rs2Value = cpuState.Registers[inst.rs2];
                switch (inst.opcode) {
                    0b0110011 => {
                        switch (inst.funct3) {
                            0b000 => {
                                switch (inst.funct7) {
                                    0b0000000 => { // ADD
                                        const value = @addWithOverflow(rs1Value, rs2Value);
                                        cpuState.Registers[inst.rd] = value[0];
                                    },
                                    0b0100000 => { // SUB
                                        const value = @subWithOverflow(rs1Value, rs2Value);
                                        cpuState.Registers[inst.rd] = value[0];
                                    },
                                    else => return error.UnknownFunct7,
                                }
                            },
                            0b001 => { // SLL
                                const shiftAmount: u5 = @truncate(rs2Value);
                                cpuState.Registers[inst.rd] = rs1Value << shiftAmount;
                            },
                            0b010 => { // SLT
                                const rs1Signed: i32 = @bitCast(rs1Value);
                                const rs2Signed: i32 = @bitCast(rs2Value);
                                if (rs1Signed < rs2Signed) {
                                    cpuState.Registers[inst.rd] = 1;
                                } else {
                                    cpuState.Registers[inst.rd] = 0;
                                }
                            },
                            0b011 => { // SLTU
                                if (rs1Value < rs2Value) {
                                    cpuState.Registers[inst.rd] = 1;
                                } else {
                                    cpuState.Registers[inst.rd] = 0;
                                }
                            },
                            0b100 => { // XOR
                                cpuState.Registers[inst.rd] = rs1Value ^ rs2Value;
                            },
                            0b101 => {
                                switch (inst.funct7) {
                                    0b0000000 => { // SRL
                                        const shiftAmount: u5 = @truncate(rs2Value);
                                        cpuState.Registers[inst.rd] = rs1Value >> shiftAmount;
                                    },
                                    0b0100000 => { // SRA
                                        const shiftAmount: u5 = @truncate(rs2Value);
                                        const signedRs1Value: i32 = @bitCast(rs1Value);
                                        const result: i32 = signedRs1Value >> shiftAmount;
                                        cpuState.Registers[inst.rd] = @bitCast(result);
                                    },
                                    else => return error.UnknownFunct7,
                                }
                            },
                            0b110 => { // OR
                                cpuState.Registers[inst.rd] = rs1Value | rs2Value;
                            },
                            0b111 => { // AND
                                cpuState.Registers[inst.rd] = rs1Value & rs2Value;
                            },
                        }
                    },
                    else => return error.UnknownOpcode,
                }
            }
            cpuState.ProgramCounter += 4;
        },
        .IType => |inst| {
            switch (inst.opcode) {
                0b0010011 => {
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        switch (inst.funct3) {
                            0b000 => { // ADDI
                                const rs1Signed: i32 = @bitCast(rs1Value);
                                const newValue = @addWithOverflow(rs1Signed, inst.imm);
                                cpuState.Registers[inst.rd] = @bitCast(newValue[0]);
                            },
                            0b001 => { // SLLI
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                const shiftAmount: u5 = @truncate(immUnsigned);
                                cpuState.Registers[inst.rd] = rs1Value << shiftAmount;
                            },
                            0b010 => { // SLTI
                                const rs1Signed: i32 = @bitCast(rs1Value);
                                if (rs1Signed < inst.imm) {
                                    cpuState.Registers[inst.rd] = 1;
                                } else {
                                    cpuState.Registers[inst.rd] = 0;
                                }
                            },
                            0b011 => { // SLTIU
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                if (rs1Value < immUnsigned) {
                                    cpuState.Registers[inst.rd] = 1;
                                } else {
                                    cpuState.Registers[inst.rd] = 0;
                                }
                            },
                            0b100 => { // XORI
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                cpuState.Registers[inst.rd] = rs1Value ^ immUnsigned;
                            },
                            0b101 => { // SRLI
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                const shiftAmount: u5 = @truncate(immUnsigned);
                                cpuState.Registers[inst.rd] = rs1Value >> shiftAmount;
                            },
                            0b110 => { // ORI
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                cpuState.Registers[inst.rd] = rs1Value | immUnsigned;
                            },
                            0b111 => { // ANDI
                                const immUnsigned: u32 = @bitCast(inst.imm);
                                cpuState.Registers[inst.rd] = rs1Value & immUnsigned;
                            },
                        }
                    }
                },
                0b0000011 => {
                    switch (inst.funct3) {
                        0b000 => { // LB
                            if (inst.rd != 0) {
                                const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                                const address: u32 = @bitCast(rs1Value + inst.imm);

                                const loadedByte = try memory.read8(address);
                                const byteAsWord = @as(u32, loadedByte);

                                if (loadedByte & 0x80 != 0) {
                                    const signedValue = 0xFFFFFF00 | byteAsWord;
                                    cpuState.Registers[inst.rd] = signedValue;
                                } else {
                                    cpuState.Registers[inst.rd] = byteAsWord;
                                }
                            }
                        },
                        0b001 => { // LH
                            if (inst.rd != 0) {
                                const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                                const address: u32 = @bitCast(rs1Value + inst.imm);

                                if (address & 0b1 != 0) {
                                    return error.MisalignedAddress;
                                }

                                const loadedU16 = try memory.read16(address);
                                const u16AsWord = @as(u32, loadedU16);

                                if (u16AsWord & 0x8000 != 0) {
                                    const signedValue = 0xFFFF0000 | u16AsWord;
                                    cpuState.Registers[inst.rd] = signedValue;
                                } else {
                                    cpuState.Registers[inst.rd] = u16AsWord;
                                }
                            }
                        },
                        0b010 => { // LW
                            if (inst.rd != 0) {
                                const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                                const address = rs1Value + inst.imm;

                                if (address & 0b11 != 0) {
                                    return error.MisalignedAddress;
                                }

                                const addressUnsigned: u32 = @bitCast(address);
                                cpuState.Registers[inst.rd] = try memory.read32(addressUnsigned);
                            }
                        },
                        0b100 => { // LBU
                            if (inst.rd != 0) {
                                const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                                const address: u32 = @bitCast(rs1Value + inst.imm);

                                const loadedByte = try memory.read8(address);
                                const byteAsWord = @as(u32, loadedByte);

                                cpuState.Registers[inst.rd] = byteAsWord;
                            }
                        },
                        0b101 => { // LHU
                            if (inst.rd != 0) {
                                const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                                const address: u32 = @bitCast(rs1Value + inst.imm);

                                if (address & 0b1 != 0) {
                                    return error.MisalignedAddress;
                                }

                                const loadedU16 = try memory.read16(address);
                                const u16AsWord = @as(u32, loadedU16);

                                cpuState.Registers[inst.rd] = u16AsWord;
                            }
                        },
                        else => return error.UnknownFunct3,
                    }
                },
                else => return error.UnknownOpcode,
            }
            cpuState.ProgramCounter += 4;
        },
        .SType => |inst| {
            switch (inst.opcode) {
                0b0100011 => {
                    switch (inst.funct3) {
                        0b000 => { // SB
                            const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                            const address: u32 = @intCast(rs1Value + inst.imm);
                            try memory.write8(address, @truncate(cpuState.Registers[inst.rs2]));
                        },
                        0b001 => { // SH
                            const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                            const address: u32 = @intCast(rs1Value + inst.imm);

                            if (address & 0b1 != 0) {
                                return error.MisalignedAddress;
                            } else {
                                try memory.write16(address, @truncate(cpuState.Registers[inst.rs2]));
                            }
                        },
                        0b010 => { // SW
                            const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                            const address: u32 = @intCast(rs1Value + inst.imm);

                            if (address & 0b11 != 0) {
                                return error.MisalignedAddress;
                            } else {
                                try memory.write32(address, cpuState.Registers[inst.rs2]);
                            }
                        },
                        else => return error.UnknownFunct3,
                    }
                },
                else => return error.UnknownOpcode,
            }
            cpuState.ProgramCounter += 4;
        },
        .BType => |inst| {
            switch (inst.opcode) {
                0b1100011 => {
                    switch (inst.funct3) {
                        0b000 => { // BEQ
                            const rs1Value = cpuState.Registers[inst.rs1];
                            const rs2Value = cpuState.Registers[inst.rs2];
                            if (rs1Value == rs2Value and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        0b001 => { // BNE
                            const rs1Value = cpuState.Registers[inst.rs1];
                            const rs2Value = cpuState.Registers[inst.rs2];
                            if (rs1Value != rs2Value and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        0b100 => { // BLT
                            const rs1Signed: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                            const rs2Signed: i32 = @bitCast(cpuState.Registers[inst.rs2]);
                            if (rs1Signed < rs2Signed and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        0b101 => { // BGE
                            const rs1Signed: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                            const rs2Signed: i32 = @bitCast(cpuState.Registers[inst.rs2]);
                            if (rs1Signed >= rs2Signed and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        0b110 => { // BLTU
                            const rs1Value = cpuState.Registers[inst.rs1];
                            const rs2Value = cpuState.Registers[inst.rs2];
                            if (rs1Value < rs2Value and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        0b111 => { // BGEU
                            const rs1Value = cpuState.Registers[inst.rs1];
                            const rs2Value = cpuState.Registers[inst.rs2];
                            if (rs1Value >= rs2Value and inst.imm != 0) {
                                const pcAsI32: i32 = @bitCast(cpuState.ProgramCounter);
                                const nextPcValue = pcAsI32 + inst.imm;
                                cpuState.ProgramCounter = @bitCast(nextPcValue);
                            } else {
                                cpuState.ProgramCounter += 4;
                            }
                        },
                        else => return error.UnknownFunct3,
                    }
                },
                else => return error.UnknownOpcode,
            }
        },
        .UType => |inst| {
            switch (inst.opcode) {
                0b0110111 => { // LUI
                    if (inst.rd != 0) {
                        cpuState.Registers[inst.rd] = @bitCast(inst.imm << 12);
                    }
                },
                0b0010111 => { // AUIPC
                    if (inst.rd != 0) {
                        const immShifted: u32 = @bitCast(inst.imm << 12);
                        const ret = @addWithOverflow(cpuState.ProgramCounter, immShifted);
                        cpuState.Registers[inst.rd] = ret[0];
                    }
                },
                else => return error.UnknownOpcode,
            }
            cpuState.ProgramCounter += 4;
        },
        .JType => |inst| {
            switch (inst.opcode) {
                0b1101111 => { // J/JAL
                    // If rd = 0, the instruction is J. Otherwise, it's JAL
                    if (inst.rd != 0) {
                        cpuState.Registers[inst.rd] = cpuState.ProgramCounter + 4;
                    }
                    const pcAsSigned: i32 = @bitCast(cpuState.ProgramCounter);
                    cpuState.ProgramCounter = @bitCast(pcAsSigned + inst.imm);
                },
                else => return error.UnknownOpcode,
            }
        },
        .System => |inst| {
            switch (inst.opcode) {
                0b1110011 => {
                    switch (inst.imm) {
                        // Not tested as this is a sample implementation
                        0b00000 => { // ECALL
                            const syscallNumber = cpuState.Registers[17]; // a7 is 17 in RISC-V ABI
                            const arg0 = cpuState.Registers[10]; // a0 is x10 in RISC-V ABI

                            switch (syscallNumber) {
                                1 => { // Print integer
                                    std.debug.print("ECALL: Print Integer - {d}\n", .{arg0});
                                },
                                2 => { // Exit emulator
                                    std.debug.print("ECALL: Exit with code {d}\n", .{arg0});
                                    std.process.exit(@intCast(arg0));
                                },
                                else => {
                                    std.debug.print("ECALL: Unsupported system call {d}\n", .{syscallNumber});
                                },
                            }
                        },
                        // Not tested
                        0b00001 => { // EBREAK
                        },
                        else => return error.UnknownImm,
                    }
                },
                else => return error.UnknownOpcode,
            }
            cpuState.ProgramCounter += 4;
        },
        .Fence => |_| {
            // Since we're not simulating memory realistically, there's nothing to do here
            cpuState.ProgramCounter += 4;
        },
        .FenceI => |_| {
            // Since we're not simulating memory realistically, there's nothing to do here
            cpuState.ProgramCounter += 4;
        },
    }
}

test "Execute ADD" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // Case 1: Simple addition (1 + 2 = 3)
    cpuState.Registers[1] = 1;
    cpuState.Registers[2] = 2;

    // ADD x3, x1, x2
    const add1: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add1, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.Registers[3]); // Expect x3 = 3
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Addition with zero (5 + 0 = 5)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;
    cpuState.Registers[2] = 0;

    // ADD x3, x1, x2
    const add2: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add2, &cpuState, &memory);

    try std.testing.expectEqual(5, cpuState.Registers[3]); // Expect x3 = 5
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Negative number addition (-7 + 10 = 3)
    const v1: i32 = -7;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(v1);
    cpuState.Registers[2] = 10;

    // ADD x3, x1, x2
    const add3: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add3, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.Registers[3]); // Expect x3 = 3
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Addition with two negative numbers (-8 + -9 = -17)
    const v2: i32 = -8;
    const v3: i32 = -9;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(v2);
    cpuState.Registers[2] = @bitCast(v3);

    // ADD x3, x1, x2
    const add4: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add4, &cpuState, &memory);

    const actual0: i32 = @bitCast(cpuState.Registers[3]);
    try std.testing.expectEqual(-17, actual0); // Expect x3 = -17
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Addition causing unsigned overflow (0xFFFFFFFF + 1 = 0)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF;
    cpuState.Registers[2] = 1;

    // ADD x3, x1, x2
    const add5: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (unsigned overflow)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: Large positive and negative numbers (0x7FFFFFFF + 0x80000000 = -1)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x7FFFFFFF; // Largest positive 32-bit number
    cpuState.Registers[2] = 0x80000000; // Largest negative 32-bit number (in two's complement)

    // ADD x3, x1, x2
    const add6: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add6, &cpuState, &memory);

    const actual1: i32 = @bitCast(cpuState.Registers[3]);
    try std.testing.expectEqual(-1, actual1); // Expect x3 = -1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SUB" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple subtraction
    cpuState.Registers[1] = 10; // x1 = 10
    cpuState.Registers[2] = 4; // x2 = 4

    // SUB x5, x1, x2
    const sub1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sub1, &cpuState, &memory);

    try std.testing.expectEqual(6, cpuState.Registers[5]); // x5 = 6
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Subtract to zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    cpuState.Registers[2] = 20; // x2 = 20

    // SUB x5, x1, x2
    const sub2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sub2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Subtract with negative result
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // SUB x5, x1, x2
    const sub3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sub3, &cpuState, &memory);

    const actual3: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-5, actual3); // x5 = -5
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Subtract with large unsigned values (no underflow)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF; // x1 = 0xFFFFFFFF (max unsigned)
    cpuState.Registers[2] = 1; // x2 = 1

    // SUB x5, x1, x2
    const sub4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sub4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFE, cpuState.Registers[5]); // x5 = 0xFFFFFFFE
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Subtract zero (identity)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 123456; // x1 = 123456
    cpuState.Registers[2] = 0; // x2 = 0

    // SUB x5, x1, x2
    const sub5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sub5, &cpuState, &memory);

    try std.testing.expectEqual(123456, cpuState.Registers[5]); // x5 = 123456
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute ADDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple addition (1 + 10 = 11)
    cpuState.Registers[1] = 1;

    // ADDI x5, x1, 10
    const addi1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 10 },
    };

    try execute(addi1, &cpuState, &memory);

    try std.testing.expectEqual(11, cpuState.Registers[5]); // Expect x5 = 11
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Addition with zero immediate (5 + 0 = 5)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;

    // ADDI x5, x1, 0
    const addi2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(addi2, &cpuState, &memory);

    try std.testing.expectEqual(5, cpuState.Registers[5]); // Expect x5 = 5
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Addition with negative immediate (10 + (-3) = 7)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10;
    const imm3: i32 = -3;

    // ADDI x5, x1, -3
    const addi3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm3 },
    };

    try execute(addi3, &cpuState, &memory);

    try std.testing.expectEqual(7, cpuState.Registers[5]); // Expect x5 = 7
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Negative register value and positive immediate (-5 + 3 = -2)
    const regVal4: i32 = -5;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(regVal4);
    const imm4 = 3;

    // ADDI x5, x1, 3
    const addi4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm4 },
    };

    try execute(addi4, &cpuState, &memory);

    const actual0: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-2, actual0); // Expect x5 = -2
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Negative register value and negative immediate (-5 + (-5) = -10)
    const regVal5: i32 = -5;
    const imm5: i32 = -5;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(regVal5);

    // ADDI x5, x1, -5
    const addi5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm5 },
    };

    try execute(addi5, &cpuState, &memory);

    const actua1: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-10, actua1); // Expect x5 = -10
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: Immediate value that requires sign extension (-2048)
    const imm6: i32 = -2048;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0;

    // ADDI x5, x1, -2048
    const addi6: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm6 },
    };

    try execute(addi6, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-2048, actual2); // Expect x5 = -2048
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 7: Maximum positive immediate (0x7FF)
    const imm7 = 0x7FF; // 2047
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1;

    // ADDI x5, x1, 2047
    const addi7: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm7 },
    };

    try execute(addi7, &cpuState, &memory);

    try std.testing.expectEqual(2048, cpuState.Registers[5]); // Expect x5 = 2048
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 8: Immediate overflow (0xFFF + 1) should wrap to negative immediate
    const imm8 = -1;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;

    // ADDI x5, x1, -1
    const addi8: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm8 },
    };

    try execute(addi8, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.Registers[5]); // Expect x5 = 4 (5 + (-1))
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute LW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16); // Allocate 16 bytes of memory
    defer memory.deinit(alloc);

    // Write test values into memory
    try memory.write32(4, 0x12345678); // Address 4: 0x12345678
    try memory.write32(8, 0xDEADBEEF); // Address 8: 0xDEADBEEF
    try memory.write32(12, 0x00000000); // Address 12: 0x00000000

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Basic load (x2 = MEM[x1 + 4])
    cpuState.Registers[1] = 0; // Base address in x1

    // LW x2, 4(x1)
    const lw1: DecodedInstruction = .{ .IType = .{ .opcode = 0b0000011, .funct3 = 0b010, .imm = 4, .rd = 2, .rs1 = 1 } };

    try execute(lw1, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[2]); // Expect x2 = 0x12345678
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load with positive offset (x2 = MEM[x1 + 8])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0;

    // LW x2, 8(x1)
    const lw2: DecodedInstruction = .{ .IType = .{ .opcode = 0b0000011, .funct3 = 0b010, .imm = 8, .rd = 2, .rs1 = 1 } };

    try execute(lw2, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.Registers[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load with negative offset (x2 = MEM[x1 - 4])
    const baseAddress: u32 = 12;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = baseAddress;
    const imm3: i32 = -4;

    // LW x2, -4(x1)
    const lw3: DecodedInstruction = .{ .IType = .{ .opcode = 0b0000011, .funct3 = 0b010, .imm = imm3, .rd = 2, .rs1 = 1 } };

    try execute(lw3, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.Registers[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load from zeroed memory (x2 = MEM[x1 + 12])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0;

    // LW x2, 12(x1)
    const lw4: DecodedInstruction = .{ .IType = .{ .opcode = 0b0000011, .funct3 = 0b010, .imm = 12, .rd = 2, .rs1 = 1 } };

    try execute(lw4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[2]); // Expect x2 = 0x00000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // TODO: How to assert panic?
    // Case 5: Unaligned memory address (should panic or handle error)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // Base address in x1 (unaligned address)

    // LW x2, 2(x1)
    const lw5: DecodedInstruction = .{ .IType = .{ .opcode = 0b0000011, .funct3 = 0b010, .imm = 2, .rd = 2, .rs1 = 1 } };
    const err = execute(lw5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
}

test "Execute SW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16); // Allocate 16 bytes of memory
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Basic store (x2 -> MEM[x1 + 4])
    cpuState.Registers[1] = 0; // Base address in x1
    cpuState.Registers[2] = 0xDEADBEEF; // Value to store in x2

    // SW x2, 4(x1)
    const sw1: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = 4, .rs2 = 2 },
    };

    try execute(sw1, &cpuState, &memory);

    const storedWord1 = try memory.read32(4);

    try std.testing.expectEqual(0xDEADBEEF, storedWord1); // Expect memory[4] = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Store with zero offset (x2 -> MEM[x1 + 0])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 8; // Base address in x1
    cpuState.Registers[2] = 0xCAFEBABE; // Value to store in x2

    // SW x2, 0(x1)
    const sw2: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
    };

    try execute(sw2, &cpuState, &memory);

    const storedWord2 = try memory.read32(8);

    try std.testing.expectEqual(0xCAFEBABE, storedWord2); // Expect memory[8] = 0xCAFEBABE
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Store with negative offset (x2 -> MEM[x1 - 4])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 12; // Base address in x1
    cpuState.Registers[2] = 0xBADC0DE; // Value to store in x2
    const imm3: i32 = -4;

    // SW x2, -4(x1)
    const sw3: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = imm3, .rs2 = 2 },
    };

    try execute(sw3, &cpuState, &memory);

    const storedWord3 = try memory.read32(8);

    try std.testing.expectEqual(0xBADC0DE, storedWord3); // Expect memory[8] = 0xBADC0DE
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Overlapping stores (multiple writes to the same address)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 4; // Base address in x1
    cpuState.Registers[2] = 0x11111111; // First value to store in x2

    // SW x2, 0(x1)
    const sw4a: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
    };

    try execute(sw4a, &cpuState, &memory);

    const storedWord4a = try memory.read32(4);

    try std.testing.expectEqual(0x11111111, storedWord4a); // Expect memory[4] = 0x11111111

    // Write a second value to the same address
    cpuState.Registers[2] = 0x22222222; // Second value to store in x2

    // SW x2, 0(x1)
    const sw4b: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
    };

    try execute(sw4b, &cpuState, &memory);

    const storedWord4b = try memory.read32(4);

    try std.testing.expectEqual(0x22222222, storedWord4b); // Expect memory[4] = 0x22222222
    try std.testing.expectEqual(8, cpuState.ProgramCounter);

    // Case 5: Unaligned memory address (should panic or handle error)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 3; // Base address in x1 (unaligned address)
    cpuState.Registers[2] = 0x55555555; // Value to store in x2

    // SW x2, 0(x1)
    const sw5: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
    };

    const err = execute(sw5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
}

test "Execute BEQ" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Operands are equal (should branch to PC + imm)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;
    cpuState.Registers[2] = 5;

    // BEQ x1, x2, 12
    const beq1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(beq1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 2: Operands are not equal (should fall through)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10;
    cpuState.Registers[2] = 20;

    // BEQ x1, x2, 12
    const beq2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(beq2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should increment by 4

    // Case 3: Negative immediate (should branch backward)
    cpuState.ProgramCounter = 0x00000020; // Start at address 32
    cpuState.Registers[1] = 0x1234;
    cpuState.Registers[2] = 0x1234;

    const imm3: i32 = -16;

    // BEQ x1, x2, -16
    const beq3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = imm3 },
    };

    try execute(beq3, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should branch back to 16

    // Case 4: Zero immediate (should fall through)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 42;
    cpuState.Registers[2] = 42;

    // BEQ x1, x2, 0
    const beq4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(beq4, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should increment by 4
}

test "Execute J/JAL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 12,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Forward jump without link (rd = 0)
    cpuState.ProgramCounter = 12;

    // J 12
    const j1: DecodedInstruction = .{ .JType = .{ .opcode = 0b1101111, .rd = 0, .imm = 12 } };

    try execute(j1, &cpuState, &memory);

    try std.testing.expectEqual(24, cpuState.ProgramCounter); // PC should jump forward by 12
    try std.testing.expectEqual(0, cpuState.Registers[0]); // Ensure x0 is always 0

    // Case 2: Backward jump without link (rd = 0)
    cpuState.ProgramCounter = 24;

    // J -16
    const imm2: i32 = -16;
    const j2: DecodedInstruction = .{ .JType = .{ .opcode = 0b1101111, .rd = 0, .imm = imm2 } };

    try execute(j2, &cpuState, &memory);

    try std.testing.expectEqual(8, cpuState.ProgramCounter); // PC should jump backward to 8
    try std.testing.expectEqual(0, cpuState.Registers[0]); // Ensure x0 is always 0

    // Case 3: Forward jump with link (rd != 0)
    cpuState.ProgramCounter = 16;

    // J 12, link to x1
    const j3: DecodedInstruction = .{ .JType = .{ .opcode = 0b1101111, .rd = 1, .imm = 12 } };

    try execute(j3, &cpuState, &memory);

    try std.testing.expectEqual(28, cpuState.ProgramCounter); // PC should jump forward to 28
    try std.testing.expectEqual(20, cpuState.Registers[1]); // x1 should hold the return address (16 + 4)

    // Case 4: Backward jump with link (rd != 0)
    cpuState.ProgramCounter = 40;

    // J -24, link to x2
    const imm4: i32 = -24;
    const j4: DecodedInstruction = .{ .JType = .{ .opcode = 0b1101111, .rd = 2, .imm = imm4 } };

    try execute(j4, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should jump backward to 16
    try std.testing.expectEqual(44, cpuState.Registers[2]); // x2 should hold the return address (40 + 4)
}

test "Execute SLT" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // Case 1: rs1 < rs2 (positive values)
    cpuState.Registers[1] = 1; // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt1: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: rs1 == rs2
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5; // rs1
    cpuState.Registers[2] = 5; // rs2

    // SLT x3, x1, x2
    const slt2: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: rs1 > rs2 (positive values)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10; // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt3: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: rs1 < rs2 (negative values)
    cpuState.ProgramCounter = 0x00000000;
    const v0: i32 = -3; // Is there not a way to do this inline?
    cpuState.Registers[1] = @bitCast(v0); // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt4: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: rs1 > rs2 (negative and positive values)
    cpuState.ProgramCounter = 0x00000000;
    const v1: i32 = -10;
    cpuState.Registers[1] = 5; // rs1
    cpuState.Registers[2] = @bitCast(v1); // rs2

    // SLT x3, x1, x2
    const slt5: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: rs1 == rs2 (negative values)
    cpuState.ProgramCounter = 0x00000000;
    const v2: i32 = -7;
    cpuState.Registers[1] = @bitCast(v2); // rs1
    cpuState.Registers[2] = @bitCast(v2); // rs2

    // SLT x3, x1, x2
    const slt6: DecodedInstruction = .{ .RType = .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt6, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute ANDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple AND operation
    cpuState.Registers[1] = 0b11011011; // x1 = 219
    const imm1: i32 = 0b11110000;

    // ANDI x5, x1, 0b11110000
    const andi1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm1 },
    };

    try execute(andi1, &cpuState, &memory);

    try std.testing.expectEqual(0b11010000, cpuState.Registers[5]); // x5 = 208
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: AND with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b11011011; // x1 = 219
    const imm2: i32 = 0;

    // ANDI x5, x1, 0
    const andi2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm2 },
    };

    try execute(andi2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: AND with all bits set in immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xDEADBEEF; // x1 = 0xDEADBEEF
    const imm3: i32 = -1; // 0xFFF in 12-bit two's complement is -1 (all bits set)

    // ANDI x5, x1, -1
    const andi3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm3 },
    };

    try execute(andi3, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.Registers[5]); // x5 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Negative immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b10101010; // x1 = 170
    const imm4: i32 = -16; // 0xFFF0 in 12-bit two's complement is -16

    // ANDI x5, x1, -16
    const andi4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm4 },
    };

    try execute(andi4, &cpuState, &memory);

    try std.testing.expectEqual(0b10100000, cpuState.Registers[5]); // x5 = 160
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Immediate overflow (mask effect)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    const imm5: i32 = 0x7FF; // Maximum positive 12-bit value

    // ANDI x5, x1, 0x7FF
    const andi5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm5 },
    };

    try execute(andi5, &cpuState, &memory);

    try std.testing.expectEqual(0x678, cpuState.Registers[5]); // x5 = 0x678
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute OR" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple OR operation
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // OR x5, x1, x2
    const or1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(or1, &cpuState, &memory);

    try std.testing.expectEqual(0b11101110, cpuState.Registers[5]); // x5 = 238
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: OR with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x0; // x1 = 0
    cpuState.Registers[2] = 0xCAFEBABE; // x2 = 0xCAFEBABE

    // OR x5, x1, x2
    const or2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(or2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.Registers[5]); // x5 = 0xCAFEBABE
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: OR with all bits set
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF; // x1 = all bits set
    cpuState.Registers[2] = 0x12345678; // x2 = 0x12345678

    // OR x5, x1, x2
    const or3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(or3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFF, cpuState.Registers[5]); // x5 = all bits set
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Mixed values
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b10010001; // x1 = 145
    cpuState.Registers[2] = 0b01110110; // x2 = 118

    // OR x5, x1, x2
    const or4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(or4, &cpuState, &memory);

    try std.testing.expectEqual(0b11110111, cpuState.Registers[5]); // x5 = 247
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: OR with itself
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x55555555; // x1 = alternating bits
    cpuState.Registers[2] = 0x55555555; // x2 = same value

    // OR x5, x1, x2
    const or5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(or5, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.Registers[5]); // x5 = 0x55555555
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SLL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple left shift
    cpuState.Registers[1] = 0b00001111; // x1 = 15
    cpuState.Registers[2] = 2; // x2 = shift amount = 2

    // SLL x5, x1, x2
    const sll1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sll1, &cpuState, &memory);

    try std.testing.expectEqual(0b00111100, cpuState.Registers[5]); // x5 = 60
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Left shift by 0 (no change)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    cpuState.Registers[2] = 0; // x2 = shift amount = 0

    // SLL x5, x1, x2
    const sll2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sll2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Shift larger than 32 bits (uses lower 5 bits of rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x1; // x1 = 1
    cpuState.Registers[2] = 35; // x2 = shift amount = 35 (35 & 0b11111 = 3)

    // SLL x5, x1, x2
    const sll3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sll3, &cpuState, &memory);

    try std.testing.expectEqual(0b1000, cpuState.Registers[5]); // x5 = 8
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Shift a negative number (interpreted as unsigned shift)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF; // x1 = -1
    cpuState.Registers[2] = 1; // x2 = shift amount = 1

    // SLL x5, x1, x2
    const sll5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sll5, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFE, cpuState.Registers[5]); // x5 = -2 (0xFFFFFFFE)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute XOR" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple XOR
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // XOR x5, x1, x2
    const xor1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(xor1, &cpuState, &memory);

    try std.testing.expectEqual(0b01100110, cpuState.Registers[5]); // x5 = 102
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: XOR with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.Registers[2] = 0x0; // x2 = 0

    // XOR x5, x1, x2
    const xor2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(xor2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: XOR with all bits set
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    cpuState.Registers[2] = 0xFFFFFFFF; // x2 = all bits set

    // XOR x5, x1, x2
    const xor3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(xor3, &cpuState, &memory);

    try std.testing.expectEqual(0xEDCBA987, cpuState.Registers[5]); // x5 = inverted bits
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: XOR with itself
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x55555555; // x1 = alternating bits
    cpuState.Registers[2] = 0x55555555; // x2 = same value

    // XOR x5, x1, x2
    const xor4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(xor4, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Mixed values
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b11110000; // x1 = 240
    cpuState.Registers[2] = 0b00001111; // x2 = 15

    // XOR x5, x1, x2
    const xor5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(xor5, &cpuState, &memory);

    try std.testing.expectEqual(0b11111111, cpuState.Registers[5]); // x5 = 255
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SLTU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: rs1 < rs2 (unsigned)
    cpuState.Registers[1] = 10; // x1 = 10
    cpuState.Registers[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sltu1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: rs1 == rs2
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    cpuState.Registers[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sltu2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: rs1 > rs2 (unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 30; // x1 = 30
    cpuState.Registers[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sltu3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Comparison with signed values treated as unsigned
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // x1 = 1
    cpuState.Registers[2] = 0xFFFFFFFF; // (-1 as unsigned)

    // SLTU x5, x1, x2
    const sltu4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sltu4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (1 < 0xFFFFFFFF)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: rs1 == 0 and rs2 == large unsigned value
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0; // x1 = 0
    cpuState.Registers[2] = 0x80000000; // x2 = 2^31 (large unsigned value)

    // SLTU x5, x1, x2
    const sltu5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sltu5, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SRL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple right shift
    cpuState.Registers[1] = 0b11110000; // x1 = 240
    cpuState.Registers[2] = 4; // x2 = shift amount = 4

    // SRL x5, x1, x2
    const srl1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(srl1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.Registers[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Right shift by 0 (no change)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    cpuState.Registers[2] = 0; // x2 = shift amount = 0

    // SRL x5, x1, x2
    const srl2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(srl2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Shift larger than 32 bits (uses lower 5 bits of rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x80000000; // x1 = 0x80000000
    cpuState.Registers[2] = 35; // x2 = shift amount = 35 (35 & 0b11111 = 3)

    // SRL x5, x1, x2
    const srl3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(srl3, &cpuState, &memory);

    try std.testing.expectEqual(0x10000000, cpuState.Registers[5]); // x5 = 0x10000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Shift a negative number (treated as unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF;
    cpuState.Registers[2] = 1; // x2 = shift amount = 1

    // SRL x5, x1, x2
    const srl5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(srl5, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFFFFFF, cpuState.Registers[5]); // x5 = 0x7FFFFFFF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SRA" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple arithmetic right shift (positive number)
    cpuState.Registers[1] = 0b01111000; // x1 = 120
    cpuState.Registers[2] = 3; // x2 = shift amount = 3

    // SRA x5, x1, x2
    const sra1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sra1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.Registers[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Simple arithmetic right shift (negative number)
    const negValue: i32 = -120; // 0b11111000 (two's complement)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(negValue); // x1 = -120
    cpuState.Registers[2] = 3; // x2 = shift amount = 3

    // SRA x5, x1, x2
    const sra2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sra2, &cpuState, &memory);

    const expected2: i32 = -15; // Result: 0b11111111 11111111 11111111 11110001
    const actual2: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(expected2, actual2); // x5 = -15
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Arithmetic shift by 0 (no change)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.Registers[2] = 0; // x2 = shift amount = 0

    // SRA x5, x1, x2
    const sra3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sra3, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Shift larger than 32 bits (uses lower 5 bits of rs2)
    const negValue4: i32 = -1; // x1 = 0xFFFFFFFF
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(negValue4); // x1 = -1
    cpuState.Registers[2] = 33; // x2 = shift amount = 33 (33 & 0b11111 = 1)

    // SRA x5, x1, x2
    const sra4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sra4, &cpuState, &memory);

    const expected4: i32 = -1; // Result stays -1 due to sign extension
    const actual4: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(expected4, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: All bits shifted out (positive value)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x7FFFFFFF; // x1 = largest positive value
    cpuState.Registers[2] = 31; // x2 = shift amount = 31

    // SRA x5, x1, x2
    const sra5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(sra5, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute AND" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple AND operation
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // AND x5, x1, x2
    const and1: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and1, &cpuState, &memory);

    try std.testing.expectEqual(0b10001000, cpuState.Registers[5]); // x5 = 136
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: AND with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    cpuState.Registers[2] = 0x0; // x2 = 0

    // AND x5, x1, x2
    const and2: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and2, &cpuState, &memory);

    try std.testing.expectEqual(0x0, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: AND with all bits set
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    cpuState.Registers[2] = 0xFFFFFFFF; // x2 = all bits set

    // AND x5, x1, x2
    const and3: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and3, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[5]); // x5 = 0x12345678
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: AND with itself
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x55555555; // x1 = alternating bits
    cpuState.Registers[2] = 0x55555555; // x2 = same value

    // AND x5, x1, x2
    const and4: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and4, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.Registers[5]); // x5 = 0x55555555
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Mixed values
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b11110000; // x1 = 240
    cpuState.Registers[2] = 0b00001111; // x2 = 15

    // AND x5, x1, x2
    const and5: DecodedInstruction = .{
        .RType = .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and5, &cpuState, &memory);

    try std.testing.expectEqual(0b00000000, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SLLI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple left shift
    cpuState.Registers[1] = 0b00001111; // x1 = 15

    // SLLI x5, x1, 2
    const slli1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 2 },
    };

    try execute(slli1, &cpuState, &memory);

    try std.testing.expectEqual(0b00111100, cpuState.Registers[5]); // x5 = 60
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Shift by 0 (no change)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678

    // SLLI x5, x1, 0
    const slli2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(slli2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Shift by 31 (maximum allowed by shamt)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // x1 = 1

    // SLLI x5, x1, 31
    const slli3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 31 },
    };

    try execute(slli3, &cpuState, &memory);

    try std.testing.expectEqual(0x80000000, cpuState.Registers[5]); // x5 = 2^31
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Shift left by -1 (interpreted as 31 due to bit truncation)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // x1 = 1
    const immNegative: i32 = -1;

    // SLLI x5, x1, -1
    const slli5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = @truncate(immNegative) },
    };

    try execute(slli5, &cpuState, &memory);

    try std.testing.expectEqual(0x80000000, cpuState.Registers[5]); // x5 = 2^31
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SLTI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: rs1 < imm (positive comparison)
    cpuState.Registers[1] = 10; // x1 = 10
    const imm1: i32 = 20;

    // SLTI x5, x1, 20
    const slti1: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = imm1,
        },
    };

    try execute(slti1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: rs1 == imm
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    const imm2: i32 = 20;

    // SLTI x5, x1, 20
    const slti2: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = imm2,
        },
    };

    try execute(slti2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: rs1 > imm
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 30; // x1 = 30
    const imm3: i32 = 20;

    // SLTI x5, x1, 20
    const slti3: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = imm3,
        },
    };

    try execute(slti3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: rs1 is negative, imm is positive
    cpuState.ProgramCounter = 0x00000000;
    const negRs1: i32 = -10;
    cpuState.Registers[1] = @bitCast(negRs1); // x1 = -10
    const imm4: i32 = 5;

    // SLTI x5, x1, 5
    const slti4: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = imm4,
        },
    };

    try execute(slti4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: rs1 is positive, imm is negative
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10; // x1 = 10
    const imm5: i32 = -20;

    // SLTI x5, x1, -20
    const slti5: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = imm5,
        },
    };

    try execute(slti5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: rs1 and imm are negative
    cpuState.ProgramCounter = 0x00000000;
    const negImm6: i32 = -5;
    const negRs16: i32 = -10;
    cpuState.Registers[1] = @bitCast(negRs16); // x1 = -10

    // SLTI x5, x1, -5
    const slti6: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b010,
            .rd = 5,
            .rs1 = 1,
            .imm = negImm6,
        },
    };

    try execute(slti6, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SLTIU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: rs1 < imm (unsigned)
    cpuState.Registers[1] = 10; // x1 = 10
    const imm1: i32 = 20; // unsigned immediate

    // SLTIU x5, x1, 20
    const sltiu1: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b011,
            .rd = 5,
            .rs1 = 1,
            .imm = imm1,
        },
    };

    try execute(sltiu1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: rs1 == imm
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    const imm2: i32 = 20; // unsigned immediate

    // SLTIU x5, x1, 20
    const sltiu2: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b011,
            .rd = 5,
            .rs1 = 1,
            .imm = imm2,
        },
    };

    try execute(sltiu2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: rs1 > imm (unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 30; // x1 = 30
    const imm3: i32 = 20; // unsigned immediate

    // SLTIU x5, x1, 20
    const sltiu3: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b011,
            .rd = 5,
            .rs1 = 1,
            .imm = imm3,
        },
    };

    try execute(sltiu3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[5]); // x5 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Signed negative value treated as unsigned
    const negImm: i32 = -1; // 0xFFFFFFFF in unsigned
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // x1 = 1

    // SLTIU x5, x1, -1
    const sltiu4: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b011,
            .rd = 5,
            .rs1 = 1,
            .imm = negImm,
        },
    };

    try execute(sltiu4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (1 < 0xFFFFFFFF)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: rs1 = 0, imm = large unsigned value (within i32 range)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0; // x1 = 0
    const largeImm: i32 = 0x7FFFFFFF; // Largest signed value

    // SLTIU x5, x1, 0x7FFFFFFF
    const sltiu5: DecodedInstruction = .{
        .IType = .{
            .opcode = 0b0010011,
            .funct3 = 0b011,
            .rd = 5,
            .rs1 = 1,
            .imm = largeImm,
        },
    };

    try execute(sltiu5, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[5]); // x5 = 1 (0 < 0x7FFFFFFF)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute XORI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple XORI operation
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    const imm1: i32 = 0b10101010;

    // XORI x5, x1, 0b10101010
    const xori1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = imm1 },
    };

    try execute(xori1, &cpuState, &memory);

    try std.testing.expectEqual(0b01100110, cpuState.Registers[5]); // x5 = 102
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: XORI with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    const imm2: i32 = 0;

    // XORI x5, x1, 0
    const xori2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = imm2 },
    };

    try execute(xori2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: XORI with all bits set
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    const imm3: i32 = -1; // 0xFFF in 12-bit two's complement is -1 (all bits set)

    // XORI x5, x1, -1
    const xori3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = imm3 },
    };

    try execute(xori3, &cpuState, &memory);

    try std.testing.expectEqual(0xEDCBA987, cpuState.Registers[5]); // x5 = inverted bits
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: XORI with zero register (x1 = 0)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x0; // x1 = 0
    const imm5: i32 = 0x3F; // Positive immediate

    // XORI x5, x1, 0x3F
    const xori5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = imm5 },
    };

    try execute(xori5, &cpuState, &memory);

    try std.testing.expectEqual(0x3F, cpuState.Registers[5]); // x5 = 0x3F
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SRLI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple right shift
    cpuState.Registers[1] = 0b11110000; // x1 = 240

    // SRLI x5, x1, 4
    const srli1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 4 },
    };

    try execute(srli1, &cpuState, &memory);

    try std.testing.expectEqual(0b00001111, cpuState.Registers[5]); // x5 = 15
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Shift by 0 (no change)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678

    // SRLI x5, x1, 0
    const srli2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(srli2, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Shift larger than 32 bits (only lower 5 bits of imm used)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x80000000; // x1 = 0x80000000

    // SRLI x5, x1, 35 (35 & 0b11111 = 3)
    const srli3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 35 },
    };

    try execute(srli3, &cpuState, &memory);

    try std.testing.expectEqual(0x10000000, cpuState.Registers[5]); // x5 = 0x10000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Shift all bits out
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF; // x1 = all bits set

    // SRLI x5, x1, 32 (32 & 0b11111 = 0)
    const srli4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 32 },
    };

    try execute(srli4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFF, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Edge case: Input with alternating bits
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xAAAAAAAA; // x1 = alternating bits

    // SRLI x5, x1, 1
    const srli5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 1 },
    };

    try execute(srli5, &cpuState, &memory);

    try std.testing.expectEqual(0x55555555, cpuState.Registers[5]); // x5 = shifted right
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute ORI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple ORI
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    const imm1: i32 = 0b10101010;

    // ORI x5, x1, 0b10101010
    const ori1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b110, .rd = 5, .rs1 = 1, .imm = imm1 },
    };

    try execute(ori1, &cpuState, &memory);

    try std.testing.expectEqual(0b11101110, cpuState.Registers[5]); // x5 = 238
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: ORI with zero
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xCAFEBABE; // x1 = 0xCAFEBABE
    const imm2: i32 = 0;

    // ORI x5, x1, 0
    const ori2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b110, .rd = 5, .rs1 = 1, .imm = imm2 },
    };

    try execute(ori2, &cpuState, &memory);

    try std.testing.expectEqual(0xCAFEBABE, cpuState.Registers[5]); // x5 = unchanged
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: ORI with all bits set in immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x12345678; // x1 = 0x12345678
    const imm3: i32 = -1; // Immediate = 0xFFFFFFFF

    // ORI x5, x1, -1
    const ori3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b110, .rd = 5, .rs1 = 1, .imm = imm3 },
    };

    try execute(ori3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFFF, cpuState.Registers[5]); // x5 = all bits set
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: ORI with a negative immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0b11110000; // x1 = 240
    const imm4: i32 = -16; // Immediate = 0xFFFFFFF0

    // ORI x5, x1, -16
    const ori4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b110, .rd = 5, .rs1 = 1, .imm = imm4 },
    };

    try execute(ori4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFFFF0, cpuState.Registers[5]); // x5 = OR with immediate
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: ORI with a positive immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x0; // x1 = 0
    const imm5: i32 = 0x7FF; // Immediate = maximum positive 12-bit

    // ORI x5, x1, 0x7FF
    const ori5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0010011, .funct3 = 0b110, .rd = 5, .rs1 = 1, .imm = imm5 },
    };

    try execute(ori5, &cpuState, &memory);

    try std.testing.expectEqual(0x7FF, cpuState.Registers[5]); // x5 = 0x7FF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
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

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Load a positive signed byte
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LB x5, 0(x1)
    const lb1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lb1, &cpuState, &memory);

    try std.testing.expectEqual(0x7F, cpuState.Registers[5]); // x5 = 127
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load a negative signed byte
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // Base address in x1

    // LB x5, 0(x1)
    const lb2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lb2, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-128, actual2); // x5 = -128
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load with non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LB x5, 2(x1)
    const lb3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 2 },
    };

    try execute(lb3, &cpuState, &memory);

    try std.testing.expectEqual(0x01, cpuState.Registers[5]); // x5 = 1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load from address with negative immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000004; // Base address in x1
    const imm4: i32 = -1;

    // LB x5, -1(x1)
    const lb4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm4 },
    };

    try execute(lb4, &cpuState, &memory);

    const actual4: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-1, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // TODO: Test misalign error
    // Case 5: Load with out-of-bound memory (should panic or error)
    // cpuState.ProgramCounter = 0x00000000;
    // cpuState.Registers[1] = 0x00000010; // Address beyond allocated memory

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

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Load a positive signed halfword
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LH x5, 0(x1)
    const lh1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lh1, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFF, cpuState.Registers[5]); // x5 = 32767
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load a negative signed halfword
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000002; // Base address in x1

    // LH x5, 0(x1)
    const lh2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lh2, &cpuState, &memory);

    const actual2: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-32768, actual2); // x5 = -32768
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load with a non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LH x5, 4(x1)
    const lh3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 4 },
    };

    try execute(lh3, &cpuState, &memory);

    try std.testing.expectEqual(0x1234, cpuState.Registers[5]); // x5 = 4660
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load a negative halfword and check sign-extension
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000006; // Base address in x1

    // LH x5, 0(x1)
    const lh4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b001, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lh4, &cpuState, &memory);

    const actual4: i32 = @bitCast(cpuState.Registers[5]);
    try std.testing.expectEqual(-1, actual4); // x5 = -1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Misaligned address (should panic or error)
    // cpuState.ProgramCounter = 0x00000000;
    // cpuState.Registers[1] = 0x00000001; // Misaligned address in x1

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

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Load an unsigned byte
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LBU x5, 0(x1)
    const lbu1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lbu1, &cpuState, &memory);

    try std.testing.expectEqual(0x00000080, cpuState.Registers[5]); // x5 = 128
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load a small unsigned byte
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // Base address in x1

    // LBU x5, 0(x1)
    const lbu2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lbu2, &cpuState, &memory);

    try std.testing.expectEqual(0x0000007F, cpuState.Registers[5]); // x5 = 127
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load a maximum unsigned byte
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000002; // Base address in x1

    // LBU x5, 0(x1)
    const lbu3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lbu3, &cpuState, &memory);

    try std.testing.expectEqual(0x000000FF, cpuState.Registers[5]); // x5 = 255
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load a zero byte
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000003; // Base address in x1

    // LBU x5, 0(x1)
    const lbu4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lbu4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Load with a non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // Base address in x1

    // LBU x5, 1(x1)
    const lbu5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b100, .rd = 5, .rs1 = 1, .imm = 1 },
    };

    try execute(lbu5, &cpuState, &memory);

    try std.testing.expectEqual(0x000000FF, cpuState.Registers[5]); // x5 = 255 (address 2)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute LHU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    // Initialize memory for tests
    try memory.write16(0, 0x7FFF); // Address 0: 32767 (positive unsigned halfword)
    try memory.write16(2, 0x8000); // Address 2: 32768 (unsigned)
    try memory.write16(4, 0xFFFF); // Address 4: 65535 (all bits set)

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Load a positive unsigned halfword
    cpuState.Registers[1] = 0x00000000; // Base address in x1

    // LHU x5, 0(x1)
    const lhu1: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lhu1, &cpuState, &memory);

    try std.testing.expectEqual(0x7FFF, cpuState.Registers[5]); // x5 = 32767
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load an unsigned halfword with high bit set
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000002; // Base address in x1

    // LHU x5, 0(x1)
    const lhu2: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lhu2, &cpuState, &memory);

    try std.testing.expectEqual(0x8000, cpuState.Registers[5]); // x5 = 32768
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load all bits set (maximum unsigned halfword)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000004; // Base address in x1

    // LHU x5, 0(x1)
    const lhu3: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    try execute(lhu3, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFF, cpuState.Registers[5]); // x5 = 65535
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load with non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000001; // Base address in x1

    // LHU x5, 3(x1) -> Address = 1 + 3 = 4
    const lhu4: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 3 },
    };

    try execute(lhu4, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFF, cpuState.Registers[5]); // x5 = 65535
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Load from unaligned address (should work for `LHU`)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000003; // Base address in x1

    // LHU x5, 0(x1) -> Address = 3
    const lhu5: DecodedInstruction = .{
        .IType = .{ .opcode = 0b0000011, .funct3 = 0b101, .rd = 5, .rs1 = 1, .imm = 0 },
    };

    const err = execute(lhu5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
    // TODO: Should PC increment if misaligned memory access error occurs?
    //try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SB" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Store a positive byte
    cpuState.Registers[1] = 0x00000000; // Base address in x1
    cpuState.Registers[2] = 0x0000007F; // Value to store in x2 (127)

    // SB x2, 0(x1)
    const sb1: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(sb1, &cpuState, &memory);

    const storedByte1 = try memory.read8(0x00000000);
    try std.testing.expectEqual(0x7F, storedByte1); // Expect 127 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Store a negative byte
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000004; // Base address in x1
    const neg128: i32 = -128;
    cpuState.Registers[2] = @bitCast(neg128); // Value to store in x2 (-128)

    // SB x2, 0(x1)
    const sb2: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(sb2, &cpuState, &memory);

    const storedByte2 = try memory.read8(0x00000004);
    try std.testing.expectEqual(0x80, storedByte2); // Expect 0x80 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Store with a non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000000; // Base address in x1
    cpuState.Registers[2] = 0x00000001; // Value to store in x2 (1)

    // SB x2, 2(x1)
    const sb3: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 2 },
    };

    try execute(sb3, &cpuState, &memory);

    const storedByte3 = try memory.read8(0x00000002);
    try std.testing.expectEqual(0x01, storedByte3); // Expect 1 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Store with a negative offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000008; // Base address in x1
    cpuState.Registers[2] = 0x000000FF; // Value to store in x2 (255)

    // SB x2, -4(x1)
    const sb4: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = -4 },
    };

    try execute(sb4, &cpuState, &memory);

    const storedByte4 = try memory.read8(0x00000004);
    try std.testing.expectEqual(0xFF, storedByte4); // Expect 255 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Out-of-bound memory access (should panic or error)
    // cpuState.ProgramCounter = 0x00000000;
    // cpuState.Registers[1] = 0x00000010; // Address beyond allocated memory
    // cpuState.Registers[2] = 0x12345678; // Value to store in x2

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

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Store a positive halfword
    cpuState.Registers[1] = 0x00000000; // Base address in x1
    cpuState.Registers[2] = 0x00007FFF; // Value to store in x2 (32767)

    // SH x2, 0(x1)
    const sh1: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(sh1, &cpuState, &memory);

    const storedHalf1 = try memory.read16(0x00000000);
    try std.testing.expectEqual(0x7FFF, storedHalf1); // Expect 32767 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Store a negative halfword
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000004; // Base address in x1
    cpuState.Registers[2] = 0xFFFFFFFF; // Value to store in x2 (-1, 0xFFFF)

    // SH x2, 0(x1)
    const sh2: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(sh2, &cpuState, &memory);

    const storedHalf2 = try memory.read16(0x00000004);
    try std.testing.expectEqual(0xFFFF, storedHalf2); // Expect 0xFFFF in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Store with a non-zero offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000000; // Base address in x1
    cpuState.Registers[2] = 0x00001234; // Value to store in x2 (4660)

    // SH x2, 6(x1)
    const sh3: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 6 },
    };

    try execute(sh3, &cpuState, &memory);

    const storedHalf3 = try memory.read16(0x00000006);
    try std.testing.expectEqual(0x1234, storedHalf3); // Expect 4660 in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Store with a negative offset
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x00000008; // Base address in x1
    cpuState.Registers[2] = 0xABCD; // Value to store in x2

    // SH x2, -2(x1)
    const sh4: DecodedInstruction = .{
        .SType = .{ .opcode = 0b0100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = -2 },
    };

    try execute(sh4, &cpuState, &memory);

    const storedHalf4 = try memory.read16(0x00000006);
    try std.testing.expectEqual(0xABCD, storedHalf4); // Expect 0xABCD in memory
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Out-of-bound memory access (should panic or error)
    // cpuState.ProgramCounter = 0x00000000;
    // cpuState.Registers[1] = 0x00000010; // Address beyond allocated memory
    // cpuState.Registers[2] = 0x5678;     // Value to store in x2

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

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Branch taken (values not equal)
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // BNE x1, x2, 12
    const bne1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(bne1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 2: Branch not taken (values equal)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 15; // x1 = 15
    cpuState.Registers[2] = 15; // x2 = 15

    // BNE x1, x2, 8
    const bne2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 8 },
    };

    try execute(bne2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 3: Negative immediate offset
    cpuState.ProgramCounter = 0x00000010;
    cpuState.Registers[1] = 25; // x1 = 25
    cpuState.Registers[2] = 35; // x2 = 35
    const imm3: i32 = -8;

    // BNE x1, x2, -8
    const bne3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = imm3 },
    };

    try execute(bne3, &cpuState, &memory);

    try std.testing.expectEqual(0x00000008, cpuState.ProgramCounter); // PC should branch to 8

    // Case 4: Zero branch offset (should not branch)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // x1 = 1
    cpuState.Registers[2] = 2; // x2 = 2

    // BNE x1, x2, 0
    const bne4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 0 },
    };

    try execute(bne4, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 5: Large positive immediate
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 100; // x1 = 100
    cpuState.Registers[2] = 50; // x2 = 50

    // BNE x1, x2, 2048
    const bne5: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b001, .rs1 = 1, .rs2 = 2, .imm = 2048 },
    };

    try execute(bne5, &cpuState, &memory);

    try std.testing.expectEqual(2048, cpuState.ProgramCounter); // PC should branch to 2048
}

test "Execute BLT" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Branch taken (rs1 < rs2)
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // BLT x1, x2, 12
    const blt1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b100, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(blt1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 2: Branch not taken (rs1 == rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 15; // x1 = 15
    cpuState.Registers[2] = 15; // x2 = 15

    // BLT x1, x2, 8
    const blt2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b100, .rs1 = 1, .rs2 = 2, .imm = 8 },
    };

    try execute(blt2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 3: Branch not taken (rs1 > rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    cpuState.Registers[2] = 10; // x2 = 10

    // BLT x1, x2, 16
    const blt3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b100, .rs1 = 1, .rs2 = 2, .imm = 16 },
    };

    try execute(blt3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 4: Branch taken (negative rs1 < positive rs2)
    cpuState.ProgramCounter = 0x00000000;
    const neg5: i32 = -5;
    cpuState.Registers[1] = @bitCast(neg5); // x1 = -5
    cpuState.Registers[2] = 5; // x2 = 5

    // BLT x1, x2, 20
    const blt4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b100, .rs1 = 1, .rs2 = 2, .imm = 20 },
    };

    try execute(blt4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.ProgramCounter); // PC should branch to 20

    // Case 5: Branch not taken (negative rs1 > negative rs2)
    cpuState.ProgramCounter = 0x00000000;
    const neg10: i32 = -10;
    cpuState.Registers[1] = @bitCast(neg5); // x1 = -5
    cpuState.Registers[2] = @bitCast(neg10); // x2 = -10

    // BLT x1, x2, -8
    const blt5: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b100, .rs1 = 1, .rs2 = 2, .imm = -8 },
    };

    try execute(blt5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction
}

test "Execute BGE" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Branch taken (rs1 > rs2)
    cpuState.Registers[1] = 10; // x1 = 10
    cpuState.Registers[2] = 5; // x2 = 5

    // BGE x1, x2, 16
    const bge1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b101, .rs1 = 1, .rs2 = 2, .imm = 16 },
    };

    try execute(bge1, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should branch to 16

    // Case 2: Branch taken (rs1 == rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 15; // x1 = 15
    cpuState.Registers[2] = 15; // x2 = 15

    // BGE x1, x2, 12
    const bge2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b101, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(bge2, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 3: Branch not taken (rs1 < rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // BGE x1, x2, 8
    const bge3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b101, .rs1 = 1, .rs2 = 2, .imm = 8 },
    };

    try execute(bge3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 4: Branch taken (negative rs1 >= negative rs2)
    cpuState.ProgramCounter = 0x00000000;
    const neg5: i32 = -5;
    const neg10: i32 = -10;
    cpuState.Registers[1] = @bitCast(neg5); // x1 = -5
    cpuState.Registers[2] = @bitCast(neg10); // x2 = -10

    // BGE x1, x2, 20
    const bge4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b101, .rs1 = 1, .rs2 = 2, .imm = 20 },
    };

    try execute(bge4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.ProgramCounter); // PC should branch to 20

    // Case 5: Branch not taken (negative rs1 < positive rs2)
    cpuState.ProgramCounter = 0x00000000;
    const neg15: i32 = -15;
    cpuState.Registers[1] = @bitCast(neg15); // x1 = -15
    cpuState.Registers[2] = 10; // x2 = 10

    // BGE x1, x2, -12
    const bge5: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b101, .rs1 = 1, .rs2 = 2, .imm = -12 },
    };

    try execute(bge5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction
}

test "Execute BLTU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Branch taken (rs1 < rs2, unsigned)
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // BLTU x1, x2, 12
    const bltu1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b110, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(bltu1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 2: Branch not taken (rs1 == rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 15; // x1 = 15
    cpuState.Registers[2] = 15; // x2 = 15

    // BLTU x1, x2, 8
    const bltu2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b110, .rs1 = 1, .rs2 = 2, .imm = 8 },
    };

    try execute(bltu2, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 3: Branch not taken (rs1 > rs2, unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 20; // x1 = 20
    cpuState.Registers[2] = 10; // x2 = 10

    // BLTU x1, x2, 16
    const bltu3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b110, .rs1 = 1, .rs2 = 2, .imm = 16 },
    };

    try execute(bltu3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 4: Branch taken (rs1 < rs2, unsigned with wraparound)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // x1 = 1
    cpuState.Registers[2] = 0xFFFFFFFF; // x2 = max unsigned (4294967295)

    // BLTU x1, x2, 20
    const bltu4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b110, .rs1 = 1, .rs2 = 2, .imm = 20 },
    };

    try execute(bltu4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.ProgramCounter); // PC should branch to 20

    // Case 5: Branch not taken (large unsigned rs1 >= small unsigned rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x80000000; // x1 = 2147483648 (unsigned)
    cpuState.Registers[2] = 100; // x2 = 100 (unsigned)

    // BLTU x1, x2, -8
    const bltu5: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b110, .rs1 = 1, .rs2 = 2, .imm = -8 },
    };

    try execute(bltu5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction
}

test "Execute BGEU" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Branch taken (rs1 > rs2, unsigned)
    cpuState.Registers[1] = 20; // x1 = 20
    cpuState.Registers[2] = 10; // x2 = 10

    // BGEU x1, x2, 16
    const bgeu1: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b111, .rs1 = 1, .rs2 = 2, .imm = 16 },
    };

    try execute(bgeu1, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should branch to 16

    // Case 2: Branch taken (rs1 == rs2, unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 15; // x1 = 15
    cpuState.Registers[2] = 15; // x2 = 15

    // BGEU x1, x2, 12
    const bgeu2: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b111, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(bgeu2, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 3: Branch not taken (rs1 < rs2, unsigned)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5; // x1 = 5
    cpuState.Registers[2] = 10; // x2 = 10

    // BGEU x1, x2, 8
    const bgeu3: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b111, .rs1 = 1, .rs2 = 2, .imm = 8 },
    };

    try execute(bgeu3, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction

    // Case 4: Branch taken (large unsigned rs1 >= small unsigned rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x80000000; // x1 = 2147483648 (unsigned)
    cpuState.Registers[2] = 100; // x2 = 100 (unsigned)

    // BGEU x1, x2, 20
    const bgeu4: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b111, .rs1 = 1, .rs2 = 2, .imm = 20 },
    };

    try execute(bgeu4, &cpuState, &memory);

    try std.testing.expectEqual(20, cpuState.ProgramCounter); // PC should branch to 20

    // Case 5: Branch not taken (small unsigned rs1 < large unsigned rs2)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // x1 = 1
    cpuState.Registers[2] = 0xFFFFFFFF; // x2 = 4294967295 (unsigned)

    // BGEU x1, x2, -8
    const bgeu5: DecodedInstruction = .{
        .BType = .{ .opcode = 0b1100011, .funct3 = 0b111, .rs1 = 1, .rs2 = 2, .imm = -8 },
    };

    try execute(bgeu5, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter); // PC should move to next instruction
}

test "Execute LUI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Load a positive immediate value
    // LUI x5, 0x12345
    const lui1: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0110111, .rd = 5, .imm = 0x12345 },
    };

    try execute(lui1, &cpuState, &memory);

    try std.testing.expectEqual(0x12345000, cpuState.Registers[5]); // x5 = 0x12345000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load a negative immediate value
    cpuState.ProgramCounter = 0;

    // LUI x6, -1 (0xFFFFF)
    const lui2: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0110111, .rd = 6, .imm = 0xFFFFF },
    };

    try execute(lui2, &cpuState, &memory);

    try std.testing.expectEqual(0xFFFFF000, cpuState.Registers[6]); // x6 = 0xFFFFF000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load with imm = 0
    cpuState.ProgramCounter = 0;

    // LUI x7, 0x0
    const lui3: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0110111, .rd = 7, .imm = 0x0 },
    };

    try execute(lui3, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[7]); // x7 = 0x00000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Write to x0 (should remain 0)
    cpuState.ProgramCounter = 0;

    // LUI x0, 0x12345
    const lui4: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0110111, .rd = 0, .imm = 0x12345 },
    };

    try execute(lui4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[0]); // x0 = 0x00000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute AUIPC" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00001000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Add a positive immediate value
    // AUIPC x5, 0x12345
    const auipc1: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0010111, .rd = 5, .imm = 0x12345 },
    };

    try execute(auipc1, &cpuState, &memory);

    try std.testing.expectEqual(0x12346000, cpuState.Registers[5]); // x5 = PC + 0x12345000 = 0x12346000
    try std.testing.expectEqual(0x1004, cpuState.ProgramCounter);

    // Case 2: Add a negative immediate value
    // AUIPC x6, -1 (0xFFFFF)
    cpuState.ProgramCounter = 0x00002000;
    const auipc2: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0010111, .rd = 6, .imm = 0xFFFFF },
    };

    try execute(auipc2, &cpuState, &memory);

    try std.testing.expectEqual(0x00001000, cpuState.Registers[6]); // x6 = PC + 0xFFFFF000 = 0x00001000
    try std.testing.expectEqual(0x00002004, cpuState.ProgramCounter);

    // Case 3: Add with imm = 0
    // AUIPC x7, 0x0
    cpuState.ProgramCounter = 0x00003000;
    const auipc3: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0010111, .rd = 7, .imm = 0x0 },
    };

    try execute(auipc3, &cpuState, &memory);

    try std.testing.expectEqual(0x00003000, cpuState.Registers[7]); // x7 = PC + 0x00000000 = 0x00003000
    try std.testing.expectEqual(0x00003004, cpuState.ProgramCounter);

    // Case 4: Write to x0 (should remain 0)
    // AUIPC x0, 0x12345
    cpuState.ProgramCounter = 0x00004000;
    const auipc4: DecodedInstruction = .{
        .UType = .{ .opcode = 0b0010111, .rd = 0, .imm = 0x12345 },
    };

    try execute(auipc4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[0]); // x0 = 0 (unchanged)
    try std.testing.expectEqual(0x00004004, cpuState.ProgramCounter);
}
