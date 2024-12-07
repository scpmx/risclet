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

    try memory.write32(0, 0x06400093); // ADDI x1, x0, 100 # 100
    try memory.write32(4, 0x00100893); // ADDI a7, x0, 1 # Select Syscall 1
    try memory.write32(8, 0x00000513); // ADDI a0, x0, 0 # i
    try memory.write32(12, 0x00000073); // ECALL
    try memory.write32(16, 0x00150513); // ADDI a0, a0, 1
    try memory.write32(20, 0xfe154ce3); // BLT a0, x1, loop
    try memory.write32(24, 0x00200893); // ADDI a7, x0, 2 # Select EXIT syscall
    try memory.write32(28, 0x00000513); // ADDI a0, x0, 0 # Corresponds to exit code 0
    try memory.write32(32, 0x00000073); // ECALL

    var cpuState: cpu.CPUState = .{ .ProgramCounter = 0x0000, .StackPointer = 0x0000, .Registers = [_]u32{0} ** 32 };

    while (true) {
        const err = tick(&cpuState, &memory);

        if (err == error.UnknownOpcode) {
            @breakpoint();
        }
    }
}
