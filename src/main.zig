const std = @import("std");

const Memory = struct {
    buffer: []u8,

    size: usize,

    pub fn init(allocator: std.mem.Allocator, size: usize) !Memory {
        return Memory{ .buffer = try allocator.alloc(u8, size), .size = size };
    }

    pub fn deinit(self: *Memory, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn read8(self: *const Memory, address: usize) !u8 {
        if (address > self.size) {
            return error.OutOfBounds;
        }
        return self.buffer[address];
    }

    pub fn write8(self: *Memory, address: usize, value: u8) !void {
        if (address > self.size) {
            return error.OutOfBounds;
        }
        self.buffer[address] = value;
    }

    pub fn read32(self: *const Memory, address: usize) !u32 {
        if (address + 3 > self.size) {
            return error.OutOfBounds;
        }

        const b0 = self.buffer[address + 0];
        const b1 = self.buffer[address + 1];
        const b2 = self.buffer[address + 2];
        const b3 = self.buffer[address + 3];

        return @as(u32, b0) << 24 | @as(u32, b1) << 16 | @as(u32, b2) << 8 | @as(u32, b3);
    }

    pub fn write32(self: *Memory, address: usize, value: u32) !void {
        if (address + 3 > self.size) {
            return error.OutOfBounds;
        }

        self.buffer[address + 0] = @truncate(value >> 24);
        self.buffer[address + 1] = @truncate(value >> 16);
        self.buffer[address + 2] = @truncate(value >> 8);
        self.buffer[address + 3] = @truncate(value);
    }
};

const CPUState = struct {
    ProgramCounter: u32,
    StackPointer: u32,
    Registers: [32]u32,
};

pub fn tick(state: *CPUState, memory: *Memory) !void {

    // Fetch Instruction
    const instruction = try memory.read32(state.ProgramCounter);

    _ = instruction;

    // Decode

    // Execute

    // Write Back
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var memory = try Memory.init(allocator, 1024);
    defer memory.deinit(allocator);

    var cpuState: CPUState = .{ .ProgramCounter = 0x0000, .StackPointer = 0x0000, .Registers = [_]u32{0} ** 32 };

    try tick(&cpuState, &memory);

    std.debug.print("PC: {}\n", .{cpuState.ProgramCounter});
}

test "write then read u8" {
    const allocator = std.testing.allocator;

    var memory = try Memory.init(allocator, 256);
    defer memory.deinit(allocator);

    const address = 0x10;
    const expected = 42;

    try memory.write8(address, expected);
    const actual = try memory.read8(address);

    try std.testing.expectEqual(expected, actual);
}

test "write then read u32" {
    const allocator = std.testing.allocator;

    var memory = try Memory.init(allocator, 256);
    defer memory.deinit(allocator);

    const address = 0x10;
    const expected = 0xDEADBEEF;

    try memory.write32(address, expected);
    const actual = try memory.read32(address);

    try std.testing.expectEqual(expected, actual);
}
