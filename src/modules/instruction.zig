const std = @import("std");

pub const RawInstruction = u32;

pub const DecodedInstruction = union(enum) {
    RType: struct {
        rd: u5, // Bits [7:11]: Destination register.
        funct3: u3, // Bits [12:14]: Broadly classifies the operation (e.g., addition/subtraction, AND/OR).
        rs1: u5, // Bits [15:19]: First source register.
        rs2: u5, // Bits [20:24]: Second source register.
        funct7: u7, // Bits [25:31]: Provides additional specificity for the operation (e.g., ADD vs. SUB).
    },
    IType: struct {
        rd: u5, // Bits [7:11]: Destination register.
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., ADDI, ORI).
        rs1: u5, // Bits [15:19]: Source register.
        imm: u12, // Bits [20:31]: Immediate value (sign-extended).
    },
    SType: struct {
        imm0: u5, // Bits [7:11]: Lower 5 bits of the immediate value (imm[4:0]).
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., SW for word store).
        rs1: u5, // Bits [15:19]: Base register for memory address.
        rs2: u5, // Bits [20:24]: Source register (data to store).
        imm1: u7, // Bits [25:31]: Upper 7 bits of the immediate value (imm[11:5]).
    },
    BType: struct {
        imm0: u4, // Bits [7:10]: Immediate bits [4:1] (used for offset calculation).
        imm1: u1, // Bit [11]: Immediate bit [11].
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., BEQ, BNE).
        rs1: u5, // Bits [15:19]: First source register for comparison.
        rs2: u5, // Bits [20:24]: Second source register for comparison.
        imm2: u6, // Bits [25:30]: Immediate bits [10:5] (used for offset calculation).
        imm3: u1, // Bit [31]: Immediate bit [12] (most significant bit for offset).
    },
    UType: struct {
        rd: u5, // Bits [7:11]: Destination register.
        imm: u20, // Bits [12:31]: Upper immediate value (stored in the high 20 bits of the result).
    },
    JType: struct {
        rd: u5, // Bits [7:11]: Destination register (holds the return address).
        imm0: u8, // Bits [12:19]: Immediate bits [19:12] (offset for jump target).
        imm1: u1, // Bit [20]: Immediate bit [11].
        imm2: u10, // Bits [21:30]: Immediate bits [10:1] (offset for jump target).
        imm3: u1, // Bit [31]: Immediate bit [20] (most significant bit for offset).
    },
};

pub fn decode(rawInstruction: RawInstruction) !DecodedInstruction {
    const opcodeBits = rawInstruction & 0b1111111;
    switch (opcodeBits) {
        0b0110011 => {
            return DecodedInstruction{
                .RType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111), // Extract bits [7:11]
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111), // Extract bits [12:14]
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111), // Extract bits [15:19]
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111), // Extract bits [20:24]
                    .funct7 = @truncate((rawInstruction >> 25) & 0b1111111), // Extract bits [25:31]
                },
            };
        },
        0b0010011, 0b0000011 => {
            return DecodedInstruction{
                .IType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111), // Extract bits [7:11]
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111), // Extract bits [12:14]
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111), // Extract bits [15:19]
                    .imm = @truncate((rawInstruction >> 20) & 0b111111111111), // Extract bits [20:31]
                },
            };
        },
        0b0100011 => {
            return DecodedInstruction{
                .SType = .{
                    .imm0 = @truncate((rawInstruction >> 7) & 0b11111), // Extract bits [7:11]
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111), // Extract bits [12:14]
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111), // Extract bits [15:19]
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111), // Extract bits [20:24]
                    .imm1 = @truncate((rawInstruction >> 25) & 0b1111111), // Extract bits [25:31]
                },
            };
        },
        0b1100011 => {
            return DecodedInstruction{
                .BType = .{
                    .imm0 = @truncate((rawInstruction >> 7) & 0b1111), // Extract imm[4:1] from bits [7:10]
                    .imm1 = @truncate((rawInstruction >> 11) & 0b1), // Extract imm[11] from bit [11]
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111), // Extract funct3 from bits [12:14]
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111), // Extract rs1 from bits [15:19]
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111), // Extract rs2 from bits [20:24]
                    .imm2 = @truncate((rawInstruction >> 25) & 0b111111), // Extract imm[10:5] from bits [25:30]
                    .imm3 = @truncate((rawInstruction >> 31) & 0b1), // Extract imm[12] from bit [31]
                },
            };
        },
        0b0110111, 0b0010111 => {
            return DecodedInstruction{
                .UType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111), // Extract rd from bits [7:11]
                    .imm = @truncate((rawInstruction >> 12) & 0xFFFFF), // Extract imm[31:12] from bits [12:31]
                },
            };
        },
        0b1101111 => {
            return DecodedInstruction{
                .JType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111), // Extract rd from bits [7:11]
                    .imm0 = @truncate((rawInstruction >> 12) & 0b11111111), // Extract imm[19:12] from bits [12:19]
                    .imm1 = @truncate((rawInstruction >> 20) & 0b1), // Extract imm[11] from bit [20]
                    .imm2 = @truncate((rawInstruction >> 21) & 0b1111111111), // Extract imm[10:1] from bits [21:30]
                    .imm3 = @truncate((rawInstruction >> 31) & 0b1), // Extract imm[20] from bit [31]
                },
            };
        },
        else => return error.UnknownOpcode,
    }
}

test "decode r-type instruction" {
    const inst: RawInstruction = 0x002081b3; // ADD x3, x1, x2
    const instructionType = try decode(inst);

    switch (instructionType) {
        .RType => |x| {
            try std.testing.expectEqual(3, x.rd);
            try std.testing.expectEqual(0, x.funct3);
            try std.testing.expectEqual(1, x.rs1);
            try std.testing.expectEqual(2, x.rs2);
            try std.testing.expectEqual(0, x.funct7);
        },
        else => try std.testing.expect(false),
    }
}

test "decode i-type instruction" {
    const inst: RawInstruction = 0x00408293; // ADDI x5, x1, 4
    const instructionType = try decode(inst);

    switch (instructionType) {
        .IType => |i| {
            try std.testing.expectEqual(5, i.rd);
            try std.testing.expectEqual(0, i.funct3);
            try std.testing.expectEqual(1, i.rs1);
            try std.testing.expectEqual(4, i.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode s-type instruction" {
    const inst: RawInstruction = 0x0050a423; // SW x5, 8(x1)
    const instructionType = try decode(inst);

    switch (instructionType) {
        .SType => |s| {
            try std.testing.expectEqual(8, s.imm0);
            try std.testing.expectEqual(2, s.funct3);
            try std.testing.expectEqual(1, s.rs1);
            try std.testing.expectEqual(5, s.rs2);
            try std.testing.expectEqual(0, s.imm1);
        },
        else => try std.testing.expect(false),
    }
}

test "decode b-type instruction" {
    const inst: RawInstruction = 0x00209463; // BEQ x1, x2, 16
    const instructionType = try decode(inst);

    switch (instructionType) {
        .BType => |b| {
            try std.testing.expectEqual(8, b.imm0);
            try std.testing.expectEqual(0, b.imm1);
            try std.testing.expectEqual(1, b.funct3);
            try std.testing.expectEqual(1, b.rs1);
            try std.testing.expectEqual(2, b.rs2);
            try std.testing.expectEqual(0, b.imm2);
            try std.testing.expectEqual(0, b.imm3);
        },
        else => try std.testing.expect(false),
    }
}

test "decode u-type instruction" {
    const inst: RawInstruction = 0x300000b7; // LUI x1, 0x30000
    const instructionType = try decode(inst);

    switch (instructionType) {
        .UType => |u| {
            try std.testing.expectEqual(1, u.rd);
            try std.testing.expectEqual(0x30000, u.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode j-type instruction" {
    const inst: RawInstruction = 0x008000ef; // JAL x1, 8
    const instructionType = try decode(inst);

    switch (instructionType) {
        .JType => |j| {
            try std.testing.expectEqual(1, j.rd);
            try std.testing.expectEqual(0, j.imm0);
            try std.testing.expectEqual(0, j.imm1);
            try std.testing.expectEqual(4, j.imm2);
            try std.testing.expectEqual(0, j.imm3);
        },
        else => try std.testing.expect(false),
    }
}
