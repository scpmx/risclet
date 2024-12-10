const std = @import("std");
const mem = @import("./modules/memory.zig");
const cpu = @import("./modules/cpu.zig");
const ins = @import("./modules/instruction.zig");
const deb = @import("./modules/debug.zig");
const elf = @import("./modules/elf.zig");

fn tick(cpuState: *cpu.CPUState, memory: *mem.Memory) !void {
    const raw: ins.RawInstruction = try memory.read32(cpuState.ProgramCounter);
    const decodedInstruction = try ins.decode(raw);
    try cpu.execute(decodedInstruction, cpuState, memory);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const size = 1024 * 1024 * 256;
    var memory = try mem.Memory.init(allocator, size);
    defer memory.deinit(allocator);

    // Open the file for reading
    const file = try std.fs.cwd().openFile("os.elf", .{});
    defer file.close();

    // Get the file size
    const stat = try file.stat();

    // Allocate a buffer to hold the file contents
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);

    // // Read the file contents into the buffer
    const bytes_read = try file.readAll(buffer);
    if (bytes_read != stat.size) {
        return error.UnexpectedEOF;
    }

    const entry = try elf.load_elf(&memory, buffer);

    var cpuState: cpu.CPUState = .{ .ProgramCounter = entry, .Registers = [_]u32{0} ** 32 };

    while (true) {
        try tick(&cpuState, &memory);
    }
}
