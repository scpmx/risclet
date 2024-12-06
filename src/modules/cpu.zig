const std = @import("std");
const instruction = @import("./instruction.zig");
const DecodedInstruction = instruction.DecodedInstruction;
const RawInstruction = instruction.RawInstruction;
const Memory = @import("./memory.zig").Memory;

pub const CPUState = struct {
    ProgramCounter: u32,
    StackPointer: u32,
    Registers: [32]u32,
};

pub fn execute(decodedInstruction: DecodedInstruction, cpuState: *CPUState, memory: *Memory) !void {
    switch (decodedInstruction) {
        .RType => |inst| {
            switch (inst.funct3) {
                0b000 => {
                    switch (inst.funct7) {
                        0b0000000 => { // ADD
                            if (inst.rd != 0) {
                                const rs1Value = cpuState.Registers[inst.rs1];
                                const rs2Value = cpuState.Registers[inst.rs2];
                                const value = @addWithOverflow(rs1Value, rs2Value);
                                cpuState.Registers[inst.rd] = value[0];
                            }
                        },
                        0b0100000 => { // SUB
                            if (inst.rd != 0) {
                                cpuState.Registers[inst.rd] = cpuState.Registers[inst.rs1] - cpuState.Registers[inst.rs2];
                            }
                        },
                        else => return error.UnknownFunct7,
                    }
                },
                0b001 => { // SLL
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const shiftAmount: u5 = @truncate(cpuState.Registers[inst.rs2]);
                        cpuState.Registers[inst.rd] = rs1Value << shiftAmount;
                    }
                },
                0b010 => { // SLT
                    if (inst.rd != 0) {
                        const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                        const rs2Value: i32 = @bitCast(cpuState.Registers[inst.rs2]);
                        if (rs1Value < rs2Value) {
                            cpuState.Registers[inst.rd] = 1;
                        } else {
                            cpuState.Registers[inst.rd] = 0;
                        }
                    }
                },
                0b011 => { // SLTU
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const rs2Value = cpuState.Registers[inst.rs2];
                        if (rs1Value < rs2Value) {
                            cpuState.Registers[inst.rd] = 1;
                        } else {
                            cpuState.Registers[inst.rd] = 0;
                        }
                    }
                },
                0b100 => { // XOR
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const rs2Value = cpuState.Registers[inst.rs2];
                        cpuState.Registers[inst.rd] = rs1Value ^ rs2Value;
                    }
                },
                0b101 => {
                    switch (inst.funct7) {
                        0b0000000 => { // SRL
                            if (inst.rd != 0) {
                                const rs1Value = cpuState.Registers[inst.rs1];
                                const shiftAmount: u5 = @truncate(cpuState.Registers[inst.rs2]);
                                cpuState.Registers[inst.rd] = rs1Value >> shiftAmount;
                            }
                        },
                        0b0100000 => { // SRA
                            if (inst.rd != 0) {
                                const rs1Value = cpuState.Registers[inst.rs1];
                                const shiftAmount: u5 = @truncate(cpuState.Registers[inst.rs2]);

                                // Cast `rs1Value` to a signed type for arithmetic shift
                                const signedRs1Value: i32 = @bitCast(rs1Value);

                                // Perform arithmetic right shift
                                const result: i32 = signedRs1Value >> shiftAmount;

                                // Store result back as unsigned in the destination register
                                cpuState.Registers[inst.rd] = @bitCast(result);
                            }
                        },
                        else => return error.UnknownFunct7,
                    }
                },
                0b110 => { // OR
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const rs2Value = cpuState.Registers[inst.rs2];
                        cpuState.Registers[inst.rd] = rs1Value | rs2Value;
                    }
                },
                0b111 => {
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const rs2Value = cpuState.Registers[inst.rs2];
                        cpuState.Registers[inst.rd] = rs1Value & rs2Value;
                    }
                },
            }

            cpuState.ProgramCounter += 4;
        },
        .IType => |inst| {
            switch (inst.funct3) {
                0b000 => { // ADDI
                    if (inst.rd != 0) {
                        const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                        const newValue = @addWithOverflow(rs1Value, inst.imm);
                        cpuState.Registers[inst.rd] = @bitCast(newValue[0]);
                    }
                },
                0b001 => {},
                0b010 => { // LW
                    if (inst.rd != 0) {
                        const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                        const address = rs1Value + inst.imm;

                        if (address & 0b11 != 0) {
                            return error.MisalignedAddress;
                        }

                        cpuState.Registers[inst.rd] = try memory.read32(@intCast(address));
                    }
                },
                0b011 => {},
                0b100 => {},
                0b101 => {},
                0b110 => {},
                0b111 => { // ANDI
                    if (inst.rd != 0) {
                        const rs1Value = cpuState.Registers[inst.rs1];
                        const immUnsigned: u32 = @bitCast(inst.imm);
                        cpuState.Registers[inst.rd] = rs1Value & immUnsigned;
                    }
                },
            }
            cpuState.ProgramCounter += 4;
        },
        .SType => |inst| {
            switch (inst.funct3) {
                0b000 => {},
                0b001 => {},
                0b010 => { // SW
                    const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                    const address: u32 = @intCast(rs1Value + inst.imm);

                    if (address & 0b11 != 0) {
                        return error.MisalignedAddress;
                    } else {
                        try memory.write32(address, cpuState.Registers[inst.rs2]);
                    }
                },
                0b011 => {},
                0b100 => {},
                0b101 => {},
                0b110 => {},
                0b111 => {},
            }
            cpuState.ProgramCounter += 4;
        },
        .BType => |inst| {
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
                0b001 => {},
                0b010 => {},
                0b011 => {},
                0b100 => {},
                0b101 => {},
                0b110 => {},
                0b111 => {},
            }
        },
        .UType => |inst| {
            std.debug.print("UType: {any}\n", .{inst});
            cpuState.ProgramCounter += 4;
        },
        .JType => |inst| {
            // If rd = 0, the instruction is J. Otherwise, it's JAL
            if (inst.rd != 0) {
                cpuState.Registers[inst.rd] = cpuState.ProgramCounter + 4;
            }
            const pcAsSigned: i32 = @bitCast(cpuState.ProgramCounter);
            cpuState.ProgramCounter = @bitCast(pcAsSigned + inst.imm);
        },
        .System => |inst| {
            switch (inst.imm) {
                0b00000 => { // ECALL
                    const syscallNumber = cpuState.Registers[17]; // a7 is 17 in RISC-V ABI
                    const arg0 = cpuState.Registers[10]; // a0 is x10 in RISC-V ABI

                    switch (syscallNumber) {
                        1 => { // Print integer
                            try std.debug.print("ECALL: Print Integer - {d}\n", .{arg0});
                        },
                        2 => { // Exit emulator
                            try std.debug.print("ECALL: Exit with code {d}\n", .{arg0});
                            std.os.exit(@intCast(arg0));
                        },
                        else => {
                            try std.debug.print("ECALL: Unsupported system call {d}\n", .{syscallNumber});
                        },
                    }
                },
                0b00001 => { // EBREAK
                },
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

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // Case 1: Simple addition (1 + 2 = 3)
    cpuState.Registers[1] = 1;
    cpuState.Registers[2] = 2;

    // ADD x3, x1, x2
    const add1: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add1, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.Registers[3]); // Expect x3 = 3
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Addition with zero (5 + 0 = 5)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;
    cpuState.Registers[2] = 0;

    // ADD x3, x1, x2
    const add2: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add2, &cpuState, &memory);

    try std.testing.expectEqual(5, cpuState.Registers[3]); // Expect x3 = 5
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Negative number addition (-7 + 10 = 3)
    const v1: i32 = -7;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = @bitCast(v1);
    cpuState.Registers[2] = 10;

    // ADD x3, x1, x2
    const add3: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

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
    const add4: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add4, &cpuState, &memory);

    const actual0: i32 = @bitCast(cpuState.Registers[3]);
    try std.testing.expectEqual(-17, actual0); // Expect x3 = -17
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: Addition causing unsigned overflow (0xFFFFFFFF + 1 = 0)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0xFFFFFFFF;
    cpuState.Registers[2] = 1;

    // ADD x3, x1, x2
    const add5: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (unsigned overflow)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: Large positive and negative numbers (0x7FFFFFFF + 0x80000000 = -1)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0x7FFFFFFF; // Largest positive 32-bit number
    cpuState.Registers[2] = 0x80000000; // Largest negative 32-bit number (in two's complement)

    // ADD x3, x1, x2
    const add6: DecodedInstruction = .{ .RType = .{ .funct3 = 0b000, .funct7 = 0b0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add6, &cpuState, &memory);

    const actual1: i32 = @bitCast(cpuState.Registers[3]);
    try std.testing.expectEqual(-1, actual1); // Expect x3 = -1
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute ADDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple addition (1 + 10 = 11)
    cpuState.Registers[1] = 1;

    // ADDI x5, x1, 10
    const addi1: DecodedInstruction = .{
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 10 },
    };

    try execute(addi1, &cpuState, &memory);

    try std.testing.expectEqual(11, cpuState.Registers[5]); // Expect x5 = 11
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Addition with zero immediate (5 + 0 = 5)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;

    // ADDI x5, x1, 0
    const addi2: DecodedInstruction = .{
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 0 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm3 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm4 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm5 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm6 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm7 },
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
        .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = imm8 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Basic load (x2 = MEM[x1 + 4])
    cpuState.Registers[1] = 0; // Base address in x1

    // LW x2, 4(x1)
    const lw1: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = 4, .rd = 2, .rs1 = 1 } };

    try execute(lw1, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[2]); // Expect x2 = 0x12345678
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: Load with positive offset (x2 = MEM[x1 + 8])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0;

    // LW x2, 8(x1)
    const lw2: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = 8, .rd = 2, .rs1 = 1 } };

    try execute(lw2, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.Registers[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: Load with negative offset (x2 = MEM[x1 - 4])
    const baseAddress: u32 = 12;
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = baseAddress;
    const imm3: i32 = -4;

    // LW x2, -4(x1)
    const lw3: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = imm3, .rd = 2, .rs1 = 1 } };

    try execute(lw3, &cpuState, &memory);

    try std.testing.expectEqual(0xDEADBEEF, cpuState.Registers[2]); // Expect x2 = 0xDEADBEEF
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: Load from zeroed memory (x2 = MEM[x1 + 12])
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 0;

    // LW x2, 12(x1)
    const lw4: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = 12, .rd = 2, .rs1 = 1 } };

    try execute(lw4, &cpuState, &memory);

    try std.testing.expectEqual(0x00000000, cpuState.Registers[2]); // Expect x2 = 0x00000000
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // TODO: How to assert panic?
    // Case 5: Unaligned memory address (should panic or handle error)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 1; // Base address in x1 (unaligned address)

    // LW x2, 2(x1)
    const lw5: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = 2, .rd = 2, .rs1 = 1 } };
    const err = execute(lw5, &cpuState, &memory);

    try std.testing.expectError(error.MisalignedAddress, err);
}

test "Execute SW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16); // Allocate 16 bytes of memory
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{
        .ProgramCounter = 0x00000000,
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Basic store (x2 -> MEM[x1 + 4])
    cpuState.Registers[1] = 0; // Base address in x1
    cpuState.Registers[2] = 0xDEADBEEF; // Value to store in x2

    // SW x2, 4(x1)
    const sw1: DecodedInstruction = .{
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = 4, .rs2 = 2 },
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
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
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
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = imm3, .rs2 = 2 },
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
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
    };

    try execute(sw4a, &cpuState, &memory);

    const storedWord4a = try memory.read32(4);

    try std.testing.expectEqual(0x11111111, storedWord4a); // Expect memory[4] = 0x11111111

    // Write a second value to the same address
    cpuState.Registers[2] = 0x22222222; // Second value to store in x2

    // SW x2, 0(x1)
    const sw4b: DecodedInstruction = .{
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
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
        .SType = .{ .funct3 = 0b010, .rs1 = 1, .imm = 0, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Operands are equal (should branch to PC + imm)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5;
    cpuState.Registers[2] = 5;

    // BEQ x1, x2, 12
    const beq1: DecodedInstruction = .{
        .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 },
    };

    try execute(beq1, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter); // PC should branch to 12

    // Case 2: Operands are not equal (should fall through)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10;
    cpuState.Registers[2] = 20;

    // BEQ x1, x2, 12
    const beq2: DecodedInstruction = .{
        .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 },
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
        .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = imm3 },
    };

    try execute(beq3, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should branch back to 16

    // Case 4: Zero immediate (should fall through)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 42;
    cpuState.Registers[2] = 42;

    // BEQ x1, x2, 0
    const beq4: DecodedInstruction = .{
        .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 0 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Forward jump without link (rd = 0)
    cpuState.ProgramCounter = 12;

    // J 12
    const j1: DecodedInstruction = .{ .JType = .{ .rd = 0, .imm = 12 } };

    try execute(j1, &cpuState, &memory);

    try std.testing.expectEqual(24, cpuState.ProgramCounter); // PC should jump forward by 12
    try std.testing.expectEqual(0, cpuState.Registers[0]); // Ensure x0 is always 0

    // Case 2: Backward jump without link (rd = 0)
    cpuState.ProgramCounter = 24;

    // J -16
    const imm2: i32 = -16;
    const j2: DecodedInstruction = .{ .JType = .{ .rd = 0, .imm = imm2 } };

    try execute(j2, &cpuState, &memory);

    try std.testing.expectEqual(8, cpuState.ProgramCounter); // PC should jump backward to 8
    try std.testing.expectEqual(0, cpuState.Registers[0]); // Ensure x0 is always 0

    // Case 3: Forward jump with link (rd != 0)
    cpuState.ProgramCounter = 16;

    // J 12, link to x1
    const j3: DecodedInstruction = .{ .JType = .{ .rd = 1, .imm = 12 } };

    try execute(j3, &cpuState, &memory);

    try std.testing.expectEqual(28, cpuState.ProgramCounter); // PC should jump forward to 28
    try std.testing.expectEqual(20, cpuState.Registers[1]); // x1 should hold the return address (16 + 4)

    // Case 4: Backward jump with link (rd != 0)
    cpuState.ProgramCounter = 40;

    // J -24, link to x2
    const imm4: i32 = -24;
    const j4: DecodedInstruction = .{ .JType = .{ .rd = 2, .imm = imm4 } };

    try execute(j4, &cpuState, &memory);

    try std.testing.expectEqual(16, cpuState.ProgramCounter); // PC should jump backward to 16
    try std.testing.expectEqual(44, cpuState.Registers[2]); // x2 should hold the return address (40 + 4)
}

test "Execute SLT" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // Case 1: rs1 < rs2 (positive values)
    cpuState.Registers[1] = 1; // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt1: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt1, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 2: rs1 == rs2
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 5; // rs1
    cpuState.Registers[2] = 5; // rs2

    // SLT x3, x1, x2
    const slt2: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt2, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 3: rs1 > rs2 (positive values)
    cpuState.ProgramCounter = 0x00000000;
    cpuState.Registers[1] = 10; // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt3: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt3, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 4: rs1 < rs2 (negative values)
    cpuState.ProgramCounter = 0x00000000;
    const v0: i32 = -3; // Is there not a way to do this inline?
    cpuState.Registers[1] = @bitCast(v0); // rs1
    cpuState.Registers[2] = 2; // rs2

    // SLT x3, x1, x2
    const slt4: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt4, &cpuState, &memory);

    try std.testing.expectEqual(1, cpuState.Registers[3]); // Expect x3 = 1 (true)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 5: rs1 > rs2 (negative and positive values)
    cpuState.ProgramCounter = 0x00000000;
    const v1: i32 = -10;
    cpuState.Registers[1] = 5; // rs1
    cpuState.Registers[2] = @bitCast(v1); // rs2

    // SLT x3, x1, x2
    const slt5: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(slt5, &cpuState, &memory);

    try std.testing.expectEqual(0, cpuState.Registers[3]); // Expect x3 = 0 (false)
    try std.testing.expectEqual(4, cpuState.ProgramCounter);

    // Case 6: rs1 == rs2 (negative values)
    cpuState.ProgramCounter = 0x00000000;
    const v2: i32 = -7;
    cpuState.Registers[1] = @bitCast(v2); // rs1
    cpuState.Registers[2] = @bitCast(v2); // rs2

    // SLT x3, x1, x2
    const slt6: DecodedInstruction = .{ .RType = .{ .funct3 = 0b010, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple AND operation
    cpuState.Registers[1] = 0b11011011; // x1 = 219
    const imm1: i32 = 0b11110000;

    // ANDI x5, x1, 0b11110000
    const andi1: DecodedInstruction = .{
        .IType = .{ .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm1 },
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
        .IType = .{ .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm2 },
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
        .IType = .{ .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm3 },
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
        .IType = .{ .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm4 },
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
        .IType = .{ .funct3 = 0b111, .rd = 5, .rs1 = 1, .imm = imm5 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple OR operation
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // OR x5, x1, x2
    const or1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b110, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple left shift
    cpuState.Registers[1] = 0b00001111; // x1 = 15
    cpuState.Registers[2] = 2; // x2 = shift amount = 2

    // SLL x5, x1, x2
    const sll1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b001, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple XOR
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // XOR x5, x1, x2
    const xor1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b100, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: rs1 < rs2 (unsigned)
    cpuState.Registers[1] = 10; // x1 = 10
    cpuState.Registers[2] = 20; // x2 = 20

    // SLTU x5, x1, x2
    const sltu1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b011, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple right shift
    cpuState.Registers[1] = 0b11110000; // x1 = 240
    cpuState.Registers[2] = 4; // x2 = shift amount = 4

    // SRL x5, x1, x2
    const srl1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple arithmetic right shift (positive number)
    cpuState.Registers[1] = 0b01111000; // x1 = 120
    cpuState.Registers[2] = 3; // x2 = shift amount = 3

    // SRA x5, x1, x2
    const sra1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b101, .funct7 = 0b0100000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .StackPointer = 0x00000000,
        .Registers = [_]u32{0} ** 32,
    };

    // Case 1: Simple AND operation
    cpuState.Registers[1] = 0b11001100; // x1 = 204
    cpuState.Registers[2] = 0b10101010; // x2 = 170

    // AND x5, x1, x2
    const and1: DecodedInstruction = .{
        .RType = .{ .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
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
        .RType = .{ .funct3 = 0b111, .funct7 = 0b0000000, .rd = 5, .rs1 = 1, .rs2 = 2 },
    };

    try execute(and5, &cpuState, &memory);

    try std.testing.expectEqual(0b00000000, cpuState.Registers[5]); // x5 = 0
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}
