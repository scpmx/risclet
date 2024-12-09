const std = @import("std");

pub const Memory = struct {
    buffer: []u8,

    size: usize,

    pub fn init(allocator: std.mem.Allocator, size: usize) !Memory {
        return Memory{ .buffer = try allocator.alloc(u8, size), .size = size };
    }

    pub fn deinit(self: *Memory, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn read8(self: *const Memory, address: usize) !u8 {
        if (address >= self.size) {
            return error.OutOfBounds;
        }
        return self.buffer[address];
    }

    pub fn write8(self: *Memory, address: usize, value: u8) !void {
        if (address >= self.size) {
            return error.OutOfBounds;
        }
        self.buffer[address] = value;
    }

    pub fn read16(self: *const Memory, address: usize) !u16 {
        if (address + 1 >= self.size) {
            return error.OutOfBounds;
        }

        const b0 = self.buffer[address + 0];
        const b1 = self.buffer[address + 1];

        return @as(u16, b1) << 8 | @as(u16, b0); // Little-endian order
    }

    pub fn write16(self: *Memory, address: usize, value: u16) !void {
        if (address + 1 >= self.size) {
            return error.OutOfBounds;
        }

        self.buffer[address + 0] = @truncate(value); // LSB
        self.buffer[address + 1] = @truncate(value >> 8); // MSB
    }

    pub fn read32(self: *const Memory, address: usize) !u32 {
        if (address + 3 >= self.size) {
            return error.OutOfBounds;
        }

        const b0 = self.buffer[address + 0];
        const b1 = self.buffer[address + 1];
        const b2 = self.buffer[address + 2];
        const b3 = self.buffer[address + 3];

        return @as(u32, b3) << 24 | @as(u32, b2) << 16 | @as(u32, b1) << 8 | @as(u32, b0); // Little-endian order
    }

    pub fn write32(self: *Memory, address: usize, value: u32) !void {
        if (address + 3 >= self.size) {
            return error.OutOfBounds;
        }

        self.buffer[address + 0] = @truncate(value); // LSB
        self.buffer[address + 1] = @truncate(value >> 8);
        self.buffer[address + 2] = @truncate(value >> 16);
        self.buffer[address + 3] = @truncate(value >> 24); // MSB
    }
};

test "write then read 8" {
    const allocator = std.testing.allocator;

    var memory = try Memory.init(allocator, 256);
    defer memory.deinit(allocator);

    const address = 0x10;
    const expected = 42;

    try memory.write8(address, expected);
    const actual = try memory.read8(address);

    try std.testing.expectEqual(expected, actual);
}

test "write then read 16" {
    const allocator = std.testing.allocator;

    var memory = try Memory.init(allocator, 256);
    defer memory.deinit(allocator);

    const address = 0x10;
    const expected = 0x1234;

    try memory.write16(address, expected);
    const actual = try memory.read16(address);

    try std.testing.expectEqual(expected, actual);
}

test "write then read 32" {
    const allocator = std.testing.allocator;

    var memory = try Memory.init(allocator, 256);
    defer memory.deinit(allocator);

    const address = 0x10;
    const expected = 0xDEADBEEF;

    try memory.write32(address, expected);
    const actual = try memory.read32(address);

    try std.testing.expectEqual(expected, actual);
}
