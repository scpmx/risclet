const std = @import("std");

const RawInstruction = u32;

const InstructionType = enum { RType, IType, SType, BType, UType, JType };

const RTypeInstruction = packed struct { opcode: u7, rd: u5, funct3: u3, rs1: u5, rs2: u5, funct7: u7 };

pub fn opcode(rawInstruction: RawInstruction) InstructionType {
    const opcodeBits = rawInstruction & 0b1111111;
    switch (opcodeBits) {
        0b0110011 => {
            //std.debug.print("R-Type Instruction\n", .{});
            return InstructionType.RType;
        },
        0b0010011, 0b0000011 => {
            //std.debug.print("I-Type Instruction\n", .{});
            return InstructionType.IType;
        },
        0b0100011 => {
            //std.debug.print("S-Type Instruction\n", .{});
            return InstructionType.SType;
        },
        0b1100011 => {
            //std.debug.print("B-Type Instruction\n", .{});
            return InstructionType.BType;
        },
        0b0110111, 0b0010111 => {
            //std.debug.print("U-Type Instruction\n", .{});
            return InstructionType.UType;
        },
        0b1101111 => {
            //std.debug.print("J-Type Instruction\n", .{});
            return InstructionType.JType;
        },
        // TODO: How should we handle decoding invalid opcodes?
        else => @panic("Invalid Opcode!!!"),
    }
}

fn decodeRType(inst: RawInstruction) RTypeInstruction {
    return RTypeInstruction{
        .funct7 = @truncate((inst >> 25) & 0b1111111), // Extract bits [25:31]
        .rs2 = @truncate((inst >> 20) & 0b11111), // Extract bits [20:24]
        .rs1 = @truncate((inst >> 15) & 0b11111), // Extract bits [15:19]
        .funct3 = @truncate((inst >> 12) & 0b111), // Extract bits [12:14]
        .rd = @truncate((inst >> 7) & 0b11111), // Extract bits [7:11]
        .opcode = @truncate(inst & 0b1111111), // Extract bits [0:6]
    };
}

test "decode r-type instruction" {
    const inst: RawInstruction = 0b00000000001000010000000110110011; // ADD x3, x1, x2

    const instructionType = opcode(inst);
    try std.testing.expectEqual(instructionType, InstructionType.RType);

    const rtypeinstruction: RTypeInstruction = decodeRType(inst);
    try std.testing.expectEqual(0b0110011, rtypeinstruction.opcode);
    try std.testing.expectEqual(0b00011, rtypeinstruction.rd);
    try std.testing.expectEqual(0b000, rtypeinstruction.funct3);
    try std.testing.expectEqual(0b00010, rtypeinstruction.rs1);
    try std.testing.expectEqual(0b00010, rtypeinstruction.rs2);
    try std.testing.expectEqual(0b0000000, rtypeinstruction.funct7);
}

test "decode i-type instruction" {
    const inst: RawInstruction = 0b00000000010000001000001010010011; // ADDI x5, x1, 4

    const instructionType = opcode(inst);

    try std.testing.expectEqual(instructionType, InstructionType.IType);
}

test "decode s-type instruction" {
    const inst: RawInstruction = 0b00000000010100001000001000100011; // SW x5, 8(x1)

    const instructionType = opcode(inst);

    try std.testing.expectEqual(instructionType, InstructionType.SType);
}

test "decode b-type instruction" {
    const inst: RawInstruction = 0b00000000001000001000000101100011; // BEQ x1, x2, 16

    const instructionType = opcode(inst);

    try std.testing.expectEqual(instructionType, InstructionType.BType);
}

test "decode u-type instruction" {
    const inst: RawInstruction = 0b00000000000000000011000010110111; // LUI x1, 0x30000

    const instructionType = opcode(inst);

    try std.testing.expectEqual(instructionType, InstructionType.UType);
}

test "decode j-type instruction" {
    const inst: RawInstruction = 0b00000000000000000000100011101111; // JAL x1, 32

    const instructionType = opcode(inst);

    try std.testing.expectEqual(instructionType, InstructionType.JType);
}

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
    const instruction: RawInstruction = try memory.read32(state.ProgramCounter);

    // Decode
    const itype = opcode(instruction);
    switch (itype) {
        InstructionType.RType => {
            const rTypeInstruction = decodeRType(instruction);
            std.log.debug("{any}", .{rTypeInstruction});
        },
        else => @panic("WTF"),
    }

    // Execute

    // Write Back
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var memory = try Memory.init(allocator, 1024);
    defer memory.deinit(allocator);

    try memory.write32(0x0000, 0b00000000001000010000000110110011);

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
