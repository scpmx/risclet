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

pub fn tick(cpu: *CPUState, memory: *Memory) !void {

    // Fetch Instruction
    const raw: RawInstruction = try memory.read32(cpu.ProgramCounter);

    // Decode
    const decodedInstruction = try instruction.decode(raw);

    // Execute
    try execute(decodedInstruction, cpu, memory);

    // Write Back
}

fn execute(decodedInstruction: DecodedInstruction, cpu: *CPUState, _: *Memory) !void {
    switch (decodedInstruction) {
        .RType => |inst| {
            switch (inst.funct3) {
                0b000 => {
                    switch (inst.funct7) {
                        0b0000000 => {
                            std.debug.print("ADD", .{});
                            if (inst.rd != 0) {
                                cpu.Registers[inst.rd] = cpu.Registers[inst.rs1] + cpu.Registers[inst.rs2];
                            }
                        },
                        0b0100000 => {
                            std.debug.print("SUB", .{});
                            if (inst.rd != 0) {
                                cpu.Registers[inst.rd] = cpu.Registers[inst.rs1] - cpu.Registers[inst.rs2];
                            }
                        },
                        else => return error.UnknownFunct7,
                    }
                },
                0b001 => {
                    std.debug.print("SLL", .{});
                },
                0b010 => {
                    std.debug.print("SLT", .{});
                },
                0b011 => {
                    std.debug.print("SLTU", .{});
                },
                0b100 => {
                    std.debug.print("XOR", .{});
                },
                0b101 => {
                    std.debug.print("SLR/SLA", .{});
                },
                0b110 => {
                    std.debug.print("OR", .{});
                },
                0b111 => {
                    std.debug.print("AND", .{});
                },
            }
        },
        .IType => |inst| {
            std.debug.print("IType: {any}", .{inst});
        },
        .SType => |inst| {
            std.debug.print("SType: {any}", .{inst});
        },
        .BType => |inst| {
            std.debug.print("BType: {any}", .{inst});
        },
        .UType => |inst| {
            std.debug.print("UType: {any}", .{inst});
        },
        .JType => |inst| {
            std.debug.print("JType: {any}", .{inst});
        },
    }
}
