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

    try memory.write32(0, 0x00000013); // NOP
    try memory.write32(4, 0x00000013); // NOP
    try memory.write32(8, 0x00000013); // NOP
    try memory.write32(12, 0x00000013); // NOP
    try memory.write32(16, 0x00000013); // NOP
    try memory.write32(20, 0x00000013); // NOP
    try memory.write32(24, 0x00000013); // NOP
    try memory.write32(28, 0x00000013); // NOP
    try memory.write32(32, 0xfe1ff06f); // J -32

    var cpuState: cpu.CPUState = .{ .ProgramCounter = 0x0000, .StackPointer = 0x0000, .Registers = [_]u32{0} ** 32 };

    while (true) {
        try tick(&cpuState, &memory);
        std.debug.print("{any}\n", .{cpuState});
    }
}
