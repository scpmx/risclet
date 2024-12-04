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
        imm: i32, // Calculated immediate value (sign-extended).
    },
    SType: struct {
        rs1: u5, // Bits [15:19]: Base register for memory address.
        rs2: u5, // Bits [20:24]: Source register (data to store).
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., SW for word store).
        imm: i32, // Calculated immediate value (sign-extended).
    },
    BType: struct {
        rs1: u5, // Bits [15:19]: First source register for comparison.
        rs2: u5, // Bits [20:24]: Second source register for comparison.
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., BEQ, BNE).
        imm: i32, // Calculated immediate value (sign-extended).
    },
    UType: struct {
        rd: u5, // Bits [7:11]: Destination register.
        imm: i32, // Upper immediate value (stored in the high 20 bits of the result, left-shifted by 12).
    },
    JType: struct {
        rd: u5, // Bits [7:11]: Destination register (holds the return address).
        imm: i32, // Calculated immediate value (sign-extended).
    },
};

pub fn decode(rawInstruction: RawInstruction) !DecodedInstruction {
    const opcodeBits = rawInstruction & 0b1111111;

    switch (opcodeBits) {
        0b0110011 => { // R-Type
            return DecodedInstruction{
                .RType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111),
                    .funct7 = @truncate((rawInstruction >> 25) & 0b1111111),
                },
            };
        },
        0b0010011, 0b0000011 => { // I-Type
            return DecodedInstruction{
                .IType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .imm = signExtend((rawInstruction >> 20) & 0xFFF, 12),
                },
            };
        },
        0b0100011 => { // S-Type
            const imm0 = (rawInstruction >> 7) & 0b11111;
            const imm1 = (rawInstruction >> 25) & 0b1111111;
            return DecodedInstruction{
                .SType = .{
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .imm = signExtend((imm1 << 5) | imm0, 12),
                },
            };
        },
        0b1100011 => { // B-Type
            const imm0 = (rawInstruction >> 7) & 0b1111; // imm[4:1]
            const imm1 = (rawInstruction >> 11) & 0b1; // imm[11]
            const imm2 = (rawInstruction >> 25) & 0b111111; // imm[10:5]
            const imm3 = (rawInstruction >> 31) & 0b1; // imm[12]
            return DecodedInstruction{
                .BType = .{
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .imm = signExtend((imm3 << 12) | (imm2 << 5) | (imm1 << 11) | (imm0 << 1), 13),
                },
            };
        },
        0b0110111, 0b0010111 => { // U-Type
            const imm: i32 = @bitCast(rawInstruction & 0xFFFFF000);
            return DecodedInstruction{
                .UType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .imm = imm >> 8,
                },
            };
        },
        0b1101111 => { // J-Type
            const imm0 = (rawInstruction >> 12) & 0b11111111; // imm[19:12]
            const imm1 = (rawInstruction >> 20) & 0b1; // imm[11]
            const imm2 = (rawInstruction >> 21) & 0b1111111111; // imm[10:1]
            const imm3 = (rawInstruction >> 31) & 0b1; // imm[20]
            return DecodedInstruction{
                .JType = .{
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .imm = signExtend((imm3 << 20) | (imm0 << 12) | (imm1 << 11) | (imm2 << 1), 21),
                },
            };
        },
        else => return error.UnknownOpcode,
    }
}

fn signExtend(value: u32, bits: u8) i32 {
    const shift: u5 = @truncate(32 - bits);
    const val: i32 = @bitCast(value);
    return (val << shift) >> shift;
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
            try std.testing.expectEqual(4, i.imm); // Single calculated imm
        },
        else => try std.testing.expect(false),
    }
}

test "decode s-type instruction" {
    const inst: RawInstruction = 0x0050a423; // SW x5, 8(x1)
    const instructionType = try decode(inst);

    switch (instructionType) {
        .SType => |s| {
            try std.testing.expectEqual(1, s.rs1);
            try std.testing.expectEqual(5, s.rs2);
            try std.testing.expectEqual(2, s.funct3);
            try std.testing.expectEqual(8, s.imm); // Single calculated imm
        },
        else => try std.testing.expect(false),
    }
}

test "decode b-type instruction" {
    const inst: RawInstruction = 0x00209463; // BEQ x1, x2, 16
    const instructionType = try decode(inst);

    switch (instructionType) {
        .BType => |b| {
            try std.testing.expectEqual(1, b.rs1);
            try std.testing.expectEqual(2, b.rs2);
            try std.testing.expectEqual(1, b.funct3);
            try std.testing.expectEqual(16, b.imm);
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
            try std.testing.expectEqual(0x300000, u.imm);
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
            try std.testing.expectEqual(8, j.imm);
        },
        else => try std.testing.expect(false),
    }
}
