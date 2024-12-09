const std = @import("std");
const mem = @import("./modules/memory.zig");
const cpu = @import("./modules/cpu.zig");
const ins = @import("./modules/instruction.zig");
const deb = @import("./modules/debug.zig");

fn tick(cpuState: *cpu.CPUState, memory: *mem.Memory) !void {
    const raw: ins.RawInstruction = try memory.read32(cpuState.ProgramCounter);
    const decodedInstruction = try ins.decode(raw);
    try cpu.execute(decodedInstruction, cpuState, memory);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var memory = try mem.Memory.init(allocator, 1024 * 1024);
    defer memory.deinit(allocator);

    // Open the file for reading
    const file = try std.fs.cwd().openFile("./hello.bin", .{});
    defer file.close();

    // Get the file size
    const stat = try file.stat();

    // Allocate a buffer to hold the file contents
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);

    // Read the file contents into the buffer
    const bytes_read = try file.readAll(buffer);
    if (bytes_read != stat.size) {
        return error.UnexpectedEOF;
    }

    // Access the raw bytes
    var idx = @as(u32, 0);
    for (buffer) |byte| {
        // std.debug.print("Load byte {d}: {x}\n", .{ idx, byte });
        try memory.write8(idx, byte);
        idx += 1;
    }

    var cpuState: cpu.CPUState = .{ .ProgramCounter = 0x0000, .Registers = [_]u32{0} ** 32 };

    while (true) {
        try tick(&cpuState, &memory);
    }
}
