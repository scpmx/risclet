const std = @import("std");
const mem = @import("./modules/memory.zig");
const cpu = @import("./modules/cpu.zig");
const ins = @import("./modules/instruction.zig");

fn tick(cpuState: *cpu.CPUState, memory: *mem.Memory) !void {
    const raw: ins.RawInstruction = try memory.read32(cpuState.ProgramCounter);
    const decodedInstruction = try ins.decode(raw);
    try cpu.execute(decodedInstruction, cpuState, memory);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var memory = try mem.Memory.init(allocator, 1024);
    defer memory.deinit(allocator);

    try memory.write32(0x0000, 0b00000000001000010000000110110011);
    try memory.write32(0x0004, 0b00000000001000010000000110110011);

    var cpuState: cpu.CPUState = .{ .ProgramCounter = 0x0000, .StackPointer = 0x0000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[2] = 9;

    try cpu.tick(&cpuState, &memory);

    std.debug.print("x3: {}\n", .{cpuState.Registers[3]});
}
