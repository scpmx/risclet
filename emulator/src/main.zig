const std = @import("std");
const mem = @import("./modules/memory.zig");
const cpu = @import("./modules/cpu.zig");
const ins = @import("./modules/instruction.zig");
const deb = @import("./modules/debug.zig");
const elf = @import("./modules/elf.zig");
const d = @import("./modules/decode.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const size = 1024 * 1024 * 1024;
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

    const cpuState = cpu.CPUState.default(entry, 0x000FFFFC);

    _ = cpuState;
}
