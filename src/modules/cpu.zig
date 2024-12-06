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
                0b001 => {
                    std.debug.print("SLL\n", .{});
                },
                0b010 => { // SLT
                    // rd = (rs1 < rs2) ? 1 : 0
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
                0b011 => {
                    std.debug.print("SLTU\n", .{});
                },
                0b100 => {
                    std.debug.print("XOR\n", .{});
                },
                0b101 => {
                    std.debug.print("SLR/SLA\n", .{});
                },
                0b110 => {
                    std.debug.print("OR\n", .{});
                },
                0b111 => {
                    std.debug.print("AND\n", .{});
                },
            }

            cpuState.ProgramCounter += 4;
        },
        .IType => |inst| {
            switch (inst.funct3) {
                0b000 => { // ADDI
                    if (inst.rd != 0) {
                        const rs1Value: i32 = @bitCast(cpuState.Registers[inst.rs1]);
                        const sdf = @addWithOverflow(rs1Value, inst.imm);
                        cpuState.Registers[inst.rd] = @bitCast(sdf[0]);
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
                0b111 => {},
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

                    if (rs1Value == rs2Value) {
                        cpuState.ProgramCounter += @intCast(inst.imm);
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

test "Execute BEQ - Operands Equal" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // BEQ x1, x2, 12
    const beq: DecodedInstruction = .{ .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 } };

    try execute(beq, &cpuState, &memory);

    try std.testing.expectEqual(12, cpuState.ProgramCounter);
}

test "Execute BEQ - Operands Not Equal" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[1] = 1;
    cpuState.Registers[2] = 2;

    // BEQ x1, x2, 12
    const beq: DecodedInstruction = .{ .BType = .{ .funct3 = 0b000, .rs1 = 1, .rs2 = 2, .imm = 12 } };

    try execute(beq, &cpuState, &memory);

    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute J" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 12, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // J 12
    const beq: DecodedInstruction = .{ .JType = .{ .rd = 0, .imm = 12 } };

    try execute(beq, &cpuState, &memory);

    try std.testing.expectEqual(24, cpuState.ProgramCounter);
    try std.testing.expectEqual(0, cpuState.Registers[0]);
}

test "Execute JAL" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 16);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 12, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // JAL x1, 12
    const beq: DecodedInstruction = .{ .JType = .{ .rd = 1, .imm = 12 } };

    try execute(beq, &cpuState, &memory);

    try std.testing.expectEqual(24, cpuState.ProgramCounter);
    try std.testing.expectEqual(16, cpuState.Registers[1]);
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
