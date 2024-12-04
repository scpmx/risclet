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

pub fn tick(cpuState: *CPUState, memory: *Memory) !void {

    // Fetch Instruction
    const raw: RawInstruction = try memory.read32(cpuState.ProgramCounter);

    // Decode
    const decodedInstruction = try instruction.decode(raw);

    // Execute
    try execute(decodedInstruction, cpuState, memory);

    // Write Back
}

fn execute(decodedInstruction: DecodedInstruction, cpuState: *CPUState, memory: *Memory) !void {
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
                0b000 => { // JALR
                    const regValue = cpuState.Registers[inst.rs1];
                    cpuState.ProgramCounter = (regValue + inst.imm) & ~@as(u32, 1);
                },
                0b001 => {},
                0b010 => { // LW
                    // TODO: Handle LW edge cases:
                    // - Misaligned memory addresses (address not divisible by 4)
                    // - Out-of-bounds memory access
                    // - Accessing uninitialized or restricted memory regions
                    // - Immediate overflow or incorrect sign extension
                    if (inst.rd != 0) {
                        const baseAddress = cpuState.Registers[inst.rs1];
                        const address = baseAddress + inst.imm;

                        if (address & 0b11 != 0) {
                            return error.MisalignedAddress;
                        }

                        cpuState.Registers[inst.rd] = try memory.read32(address);
                    }
                },
                0b011 => {},
                0b100 => {},
                0b101 => {},
                0b110 => {},
                0b111 => {},
            }

            if (inst.funct3 != 0b000) {
                cpuState.ProgramCounter += 4;
            }
        },
        .SType => |inst| {
            switch (inst.funct3) {
                0b000 => {},
                0b001 => {},
                0b010 => { // SW
                    const baseAddress = cpuState.Registers[inst.rs1];
                    _ = baseAddress;
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
            std.debug.print("BType: {any}\n", .{inst});
        },
        .UType => |inst| {
            std.debug.print("UType: {any}\n", .{inst});
            cpuState.ProgramCounter += 4;
        },
        .JType => |inst| {
            std.debug.print("JType: {any}\n", .{inst});
        },
    }
}

test "Decode and execute ADD" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 4);
    defer memory.deinit(alloc);

    try memory.write32(0x00000000, 0x002081b3); // ADD x3, x1, x2

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[1] = 1;
    cpuState.Registers[2] = 2;

    try tick(&cpuState, &memory);

    try std.testing.expectEqual(3, cpuState.Registers[3]);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}

test "Decode and execute LW" {
    const alloc = std.testing.allocator;

    var memory = try Memory.init(alloc, 8);
    defer memory.deinit(alloc);

    try memory.write32(0x00000000, 0x0040a103); // LW x2, 4(x1)
    try memory.write32(0x00000004, 0x12345678);

    var cpuState: CPUState = .{ .ProgramCounter = 0x00000000, .StackPointer = 0x00000000, .Registers = [_]u32{0} ** 32 };

    try tick(&cpuState, &memory);

    try std.testing.expectEqual(0x12345678, cpuState.Registers[2]);
    try std.testing.expectEqual(4, cpuState.ProgramCounter);
}
