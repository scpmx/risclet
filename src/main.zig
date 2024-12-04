const std = @import("std");

const RawInstruction = u32;

const InstructionType = enum { RType, IType, SType, BType, UType, JType };

const RTypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the general operation class (e.g., arithmetic, logical).
    rd: u5, // Bits [7:11]: Destination register.
    funct3: u3, // Bits [12:14]: Broadly classifies the operation (e.g., addition/subtraction, AND/OR).
    rs1: u5, // Bits [15:19]: First source register.
    rs2: u5, // Bits [20:24]: Second source register.
    funct7: u7, // Bits [25:31]: Provides additional specificity for the operation (e.g., ADD vs. SUB).
};

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

const ITypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the operation class (e.g., immediate arithmetic, loads).
    rd: u5, // Bits [7:11]: Destination register.
    funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., ADDI, ORI).
    rs1: u5, // Bits [15:19]: Source register.
    imm: u12, // Bits [20:31]: Immediate value (sign-extended).
};

fn decodeIType(inst: RawInstruction) ITypeInstruction {
    return ITypeInstruction{
        .imm = @truncate((inst >> 20) & 0b111111111111), // Extract bits [20:31]
        .rs1 = @truncate((inst >> 15) & 0b11111), // Extract bits [15:19]
        .funct3 = @truncate((inst >> 12) & 0b111), // Extract bits [12:14]
        .rd = @truncate((inst >> 7) & 0b11111), // Extract bits [7:11]
        .opcode = @truncate(inst & 0b1111111), // Extract bits [0:6]
    };
}

const STypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the operation class (e.g., store operations).
    imm0: u5, // Bits [7:11]: Lower 5 bits of the immediate value (imm[4:0]).
    funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., SW for word store).
    rs1: u5, // Bits [15:19]: Base register for memory address.
    rs2: u5, // Bits [20:24]: Source register (data to store).
    imm1: u7, // Bits [25:31]: Upper 7 bits of the immediate value (imm[11:5]).
};

const BTypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the operation class (e.g., conditional branch).
    imm0: u4, // Bits [7:10]: Immediate bits [4:1] (used for offset calculation).
    imm1: u1, // Bit [11]: Immediate bit [11].
    funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., BEQ, BNE).
    rs1: u5, // Bits [15:19]: First source register for comparison.
    rs2: u5, // Bits [20:24]: Second source register for comparison.
    imm2: u6, // Bits [25:30]: Immediate bits [10:5] (used for offset calculation).
    imm3: u1, // Bit [31]: Immediate bit [12] (most significant bit for offset).
};

const UTypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the operation class (e.g., LUI, AUIPC).
    rd: u5, // Bits [7:11]: Destination register.
    imm: u20, // Bits [12:31]: Upper immediate value (stored in the high 20 bits of the result).
};

const JTypeInstruction = packed struct {
    opcode: u7, // Bits [0:6]: Specifies the operation class (e.g., JAL).
    rd: u5, // Bits [7:11]: Destination register (holds the return address).
    imm0: u8, // Bits [12:19]: Immediate bits [19:12] (offset for jump target).
    imm1: u1, // Bit [20]: Immediate bit [11].
    imm2: u10, // Bits [21:30]: Immediate bits [10:1] (offset for jump target).
    imm3: u1, // Bit [31]: Immediate bit [20] (most significant bit for offset).
};

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

    const itypeinstruction: ITypeInstruction = decodeIType(inst);
    try std.testing.expectEqual(0b0010011, itypeinstruction.opcode);
    try std.testing.expectEqual(0b00101, itypeinstruction.rd);
    try std.testing.expectEqual(0b000, itypeinstruction.funct3);
    try std.testing.expectEqual(0b00001, itypeinstruction.rs1);
    try std.testing.expectEqual(0b000000000100, itypeinstruction.imm);
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

            switch (rTypeInstruction.funct3) {
                0b000 => { // Add or subtract
                    switch (rTypeInstruction.funct7) {
                        0b0000000 => {
                            std.log.debug("Add", .{});
                            state.Registers[rTypeInstruction.rd] = state.Registers[rTypeInstruction.rs1] + state.Registers[rTypeInstruction.rs2];
                        },
                        0b0100000 => {
                            std.log.debug("Sub", .{});
                            state.Registers[rTypeInstruction.rd] = state.Registers[rTypeInstruction.rs1] - state.Registers[rTypeInstruction.rs2];
                        },
                        else => @panic("Not allowed!!!!!"),
                    }
                },
                0b001 => {
                    std.log.debug("SLL", .{});
                },
                0b010 => {
                    std.log.debug("SLT", .{});
                },
                0b011 => {
                    std.log.debug("SLTU", .{});
                },
                0b100 => {
                    std.log.debug("XOR", .{});
                },
                0b101 => {
                    std.log.debug("SLR/SLA", .{});
                },
                0b110 => {
                    std.log.debug("OR", .{});
                },
                0b111 => {
                    std.log.debug("AND", .{});
                },
            }

            state.Registers[0] = 0; // Ensure x0 stays 0. This is probably faster than using an if to check rd but idk
            state.ProgramCounter += 4;
            std.log.debug("Decoded RType", .{});
        },
        InstructionType.IType => {
            state.ProgramCounter += 4;
            std.log.debug("Decoded IType", .{});
        },
        InstructionType.SType => {
            state.ProgramCounter += 4;
            std.log.debug("Decoded SType", .{});
        },
        InstructionType.BType => {
            state.ProgramCounter += 4;
            std.log.debug("Decoded BType", .{});
        },
        InstructionType.UType => {
            state.ProgramCounter += 4;
            std.log.debug("Decoded UType", .{});
        },
        InstructionType.JType => {
            std.log.debug("Decoded JType", .{});
        },
    }

    // Execute

    // Write Back
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var memory = try Memory.init(allocator, 1024);
    defer memory.deinit(allocator);

    try memory.write32(0x0000, 0b00000000001000010000000110110011);
    try memory.write32(0x0004, 0b00000000001000010000000110110011);

    var cpuState: CPUState = .{ .ProgramCounter = 0x0000, .StackPointer = 0x0000, .Registers = [_]u32{0} ** 32 };

    cpuState.Registers[2] = 9;

    try tick(&cpuState, &memory);

    std.debug.print("x3: {}\n", .{cpuState.Registers[3]});
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
