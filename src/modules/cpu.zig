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
                                cpuState.Registers[inst.rd] = cpuState.Registers[inst.rs1] + cpuState.Registers[inst.rs2];
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
                0b010 => {
                    std.debug.print("SLT\n", .{});
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
                        const rs1Value: i32 = @intCast(cpuState.Registers[inst.rs1]);
                        cpuState.Registers[inst.rd] = @intCast(rs1Value + inst.imm);
                    }
                },
                0b001 => {},
                0b010 => { // LW
                    // TODO: Handle LW edge cases:
                    // - Misaligned memory addresses (address not divisible by 4)
                    // - Out-of-bounds memory access
                    // - Accessing uninitialized or restricted memory regions
                    // - Immediate overflow or incorrect sign extension
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
                    const rs2Value = cpuState.Registers[inst.rs2];
                    try memory.write32(@intCast(rs1Value + inst.imm), rs2Value);
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
            cpuState.ProgramCounter += @intCast(inst.imm);
        },
    }
}

test "Execute ADD" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[1] = 1;
    cpuState.Registers[2] = 2;

    // ADD x3, x1, x2
    const add: DecodedInstruction = .{ .RType = .{ .funct3 = 0x000, .funct7 = 0x0000000, .rd = 3, .rs1 = 1, .rs2 = 2 } };

    try execute(add, &cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.Registers[3]);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute ADDI" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[1] = 1;
    cpuState.Registers[5] = 2;

    // ADDI x5, x1, 10
    const addi: DecodedInstruction = .{ .IType = .{ .funct3 = 0b000, .rd = 5, .rs1 = 1, .imm = 10 } };

    try execute(addi, &cpuState, &memory);

    try std.testing.expectEqual(11, cpuState.Registers[5]);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute LW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 8);
    defer memory.deinit(alloc);

    try memory.write32(4, 0x12345678);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    // LW x2, 4(x1)
    const lw: DecodedInstruction = .{ .IType = .{ .funct3 = 0b010, .imm = 4, .rd = 2, .rs1 = 1 } };

    try execute(lw, &cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[2]);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Execute SW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 8);
    defer memory.deinit(alloc);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[2] = 0xDEADBEEF;

    // SW x5, 4(x1)
    const sw: DecodedInstruction = .{ .SType = .{
        .funct3 = 0b010,
        .rs1 = 1,
        .imm = 4,
        .rs2 = 2,
    } };

    try execute(sw, &cpuState, &memory);

    const storedWord = try memory.read32(4);

    try std.testing.expectEqual(0xDEADBEEF, storedWord);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
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
