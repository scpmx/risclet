const std = @import("std");
const encode = @import("./encoder.zig");

pub const RawInstruction = u32;

pub const DecodedInstruction = union(enum) {
    RType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., arithmetic/logical).
        rd: u5, // Bits [7:11]: Destination register.
        funct3: u3, // Bits [12:14]: Broadly classifies the operation (e.g., addition/subtraction, AND/OR).
        rs1: u5, // Bits [15:19]: First source register.
        rs2: u5, // Bits [20:24]: Second source register.
        funct7: u7, // Bits [25:31]: Provides additional specificity for the operation (e.g., ADD vs. SUB).
    },
    IType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., immediate arithmetic, loads).
        rd: u5, // Bits [7:11]: Destination register.
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., ADDI, ORI).
        rs1: u5, // Bits [15:19]: Source register.
        imm: i32, // Calculated immediate value (sign-extended).
    },
    SType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., stores).
        rs1: u5, // Bits [15:19]: Base register for memory address.
        rs2: u5, // Bits [20:24]: Source register (data to store).
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., SW for word store).
        imm: i32, // Calculated immediate value (sign-extended).
    },
    BType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., branches).
        rs1: u5, // Bits [15:19]: First source register for comparison.
        rs2: u5, // Bits [20:24]: Second source register for comparison.
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., BEQ, BNE).
        imm: i32, // Calculated immediate value (sign-extended).
    },
    UType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., LUI, AUIPC).
        rd: u5, // Bits [7:11]: Destination register.
        imm: i32, // Upper immediate value (stored in the high 20 bits of the result, left-shifted by 12).
    },
    JType: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (e.g., jumps).
        rd: u5, // Bits [7:11]: Destination register (holds the return address).
        imm: i32, // Calculated immediate value (sign-extended).
    },
    System: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (`1110011` for system instructions).
        imm: u5, // Bits [24:20]: Immediate.
        funct3: u3, // Bits [12:14]: Sub-operation identifier (e.g., ECALL, EBREAK).
    },
    Fence: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (`0001111` for FENCE).
        pred: u4, // Bits [27:24]: Preceding memory operations mask.
        succ: u4, // Bits [23:20]: Succeeding memory operations mask.
        funct3: u3, // Bits [12:14]: Always `0b000`.
    },
    FenceI: struct {
        opcode: u7, // Bits [0:6]: Specifies the operation group (`0001111` for FENCE.I).
        funct3: u3, // Bits [12:14]: Always `0b001` for FENCE.I.
    },
};

pub fn decode(rawInstruction: RawInstruction) !DecodedInstruction {
    const opcodeBits = rawInstruction & 0b1111111;

    switch (opcodeBits) {
        0b0110011 => { // R-Type
            return DecodedInstruction{
                .RType = .{
                    .opcode = @truncate(rawInstruction & 0b1111111),
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
                    .opcode = @truncate(rawInstruction & 0b1111111),
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
                    .opcode = @truncate(rawInstruction & 0b1111111),
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .imm = signExtend((imm1 << 5) | imm0, 12),
                },
            };
        },
        0b1100011 => { // B-Type
            const imm0: u32 = (rawInstruction >> 8) & 0b1111; // imm[4:1]
            const imm1: u32 = (rawInstruction & 0b10000000) >> 7; // imm[11]
            const imm2: u32 = (rawInstruction >> 25) & 0b111111; // imm[10:5]
            const imm3: u32 = (rawInstruction >> 31) & 0b1; // imm[12]

            const imm: u32 = (imm3 << 12) | (imm1 << 11) | (imm2 << 5) | (imm0 << 1);

            return DecodedInstruction{
                .BType = .{
                    .opcode = @truncate(rawInstruction & 0b1111111),
                    .rs1 = @truncate((rawInstruction >> 15) & 0b11111),
                    .rs2 = @truncate((rawInstruction >> 20) & 0b11111),
                    .funct3 = @truncate((rawInstruction >> 12) & 0b111),
                    .imm = signExtend(imm, 13),
                },
            };
        },
        0b0110111, 0b0010111 => { // U-Type
            const imm: i32 = @bitCast(rawInstruction & 0xFFFFF000);
            return DecodedInstruction{
                .UType = .{
                    .opcode = @truncate(rawInstruction & 0b1111111),
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .imm = imm >> 12,
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
                    .opcode = @truncate(rawInstruction & 0b1111111),
                    .rd = @truncate((rawInstruction >> 7) & 0b11111),
                    .imm = signExtend((imm3 << 20) | (imm0 << 12) | (imm1 << 11) | (imm2 << 1), 21),
                },
            };
        },
        0b1110011 => { // SYSTEM
            const imm: u5 = @truncate((rawInstruction >> 20) & 0b11111); // Bits [24:20]: Immediate
            const funct3: u3 = @truncate((rawInstruction >> 12) & 0b111); // Bits [14:12]
            return DecodedInstruction{
                .System = .{
                    .opcode = @truncate(rawInstruction & 0b1111111),
                    .imm = imm,
                    .funct3 = funct3,
                },
            };
        },
        0b0001111 => { // FENCE / FENCE.I
            const funct3: u3 = @truncate((rawInstruction >> 12) & 0b111); // Bits [14:12]: Always `0b000` for FENCE.
            switch (funct3) {
                0b000 => {
                    const pred: u4 = @truncate((rawInstruction >> 24) & 0b1111); // Bits [27:24]
                    const succ: u4 = @truncate((rawInstruction >> 20) & 0b1111); // Bits [23:20]
                    return DecodedInstruction{
                        .Fence = .{ .opcode = @truncate(rawInstruction & 0b1111111), .pred = pred, .succ = succ, .funct3 = funct3 },
                    };
                },
                0b001 => {
                    return DecodedInstruction{
                        .FenceI = .{ .opcode = @truncate(rawInstruction & 0b1111111), .funct3 = funct3 },
                    };
                },
                else => return error.UnknownFunc3,
            }
        },
        else => return error.UnknownOpcode,
    }
}

fn signExtend(value: u32, comptime bits: u5) i32 {
    const signMask = @as(u32, 1) << (bits - 1);

    if ((value & signMask) != 0) {
        const signExtension: u32 = ~@as(u32, 0) << bits;
        return @bitCast(signExtension | value);
    }

    return @bitCast(value);
}

test "signExtend function" {
    // Positive values (no sign extension required)
    try std.testing.expectEqual(5, signExtend(0b00000101, 6)); // 5
    try std.testing.expectEqual(15, signExtend(0b001111, 6)); // 15

    // Negative values (sign extension required)
    try std.testing.expectEqual(-1, signExtend(0b111111, 6)); // -1
    try std.testing.expectEqual(-32, signExtend(0b100000, 6)); // -32
    try std.testing.expectEqual(-128, signExtend(0b10000000, 8)); // -128

    // Edge cases
    try std.testing.expectEqual(0, signExtend(0b0, 6)); // 0 (zero case)
    try std.testing.expectEqual(-16, signExtend(0b1110000, 7)); // -16
    try std.testing.expectEqual(127, signExtend(0b01111111, 8)); // 127 (maximum positive for 8 bits)
    try std.testing.expectEqual(-32768, signExtend(0b1000000000000000, 16)); // -32768
    try std.testing.expectEqual(32767, signExtend(0b0111111111111111, 16)); // 32767
}

test "decode r-type instruction" {
    const inst: RawInstruction = 0x002081b3; // ADD x3, x1, x2
    const instructionType = try decode(inst);

    switch (instructionType) {
        .RType => |x| {
            try std.testing.expectEqual(0b110011, x.opcode);
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
            try std.testing.expectEqual(0b0010011, i.opcode);
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
            try std.testing.expectEqual(0b0100011, s.opcode);
            try std.testing.expectEqual(1, s.rs1);
            try std.testing.expectEqual(5, s.rs2);
            try std.testing.expectEqual(2, s.funct3);
            try std.testing.expectEqual(8, s.imm); // Single calculated imm
        },
        else => try std.testing.expect(false),
    }
}

test "decode b-type instruction" {
    const inst: RawInstruction = 0x00209463; // BEQ x1, x2, 8
    const instructionType = try decode(inst);

    switch (instructionType) {
        .BType => |b| {
            try std.testing.expectEqual(0b1100011, b.opcode);
            try std.testing.expectEqual(1, b.rs1);
            try std.testing.expectEqual(2, b.rs2);
            try std.testing.expectEqual(1, b.funct3);
            try std.testing.expectEqual(8, b.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode b-type instruction 2" {
    const inst: RawInstruction = encode.BLT(1, 2, -8);
    const instructionType = try decode(inst);

    switch (instructionType) {
        .BType => |b| {
            try std.testing.expectEqual(0b1100011, b.opcode);
            try std.testing.expectEqual(1, b.rs1);
            try std.testing.expectEqual(2, b.rs2);
            try std.testing.expectEqual(4, b.funct3);
            try std.testing.expectEqual(-8, b.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode u-type instruction" {
    const inst: RawInstruction = 0x300000b7; // LUI x1, 0x30000
    const instructionType = try decode(inst);

    switch (instructionType) {
        .UType => |u| {
            try std.testing.expectEqual(0b0110111, u.opcode);
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
            try std.testing.expectEqual(0b1101111, j.opcode);
            try std.testing.expectEqual(1, j.rd);
            try std.testing.expectEqual(8, j.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode system instruction - ECALL" {
    const inst: RawInstruction = 0x00000073; // ECALL
    const instructionType = try decode(inst);

    switch (instructionType) {
        .System => |sys| {
            try std.testing.expectEqual(0b1110011, sys.opcode);
            try std.testing.expectEqual(0b000, sys.funct3);
            try std.testing.expectEqual(0b00000, sys.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode system instruction - EBREAK" {
    const inst: RawInstruction = 0x00100073; // EBREAK
    const instructionType = try decode(inst);

    switch (instructionType) {
        .System => |sys| {
            try std.testing.expectEqual(0b1110011, sys.opcode);
            try std.testing.expectEqual(0b000, sys.funct3);
            try std.testing.expectEqual(0b00001, sys.imm);
        },
        else => try std.testing.expect(false),
    }
}

test "decode fence instruction" {
    const inst: RawInstruction = 0x0FF0000F; // FENCE rw, rw
    const instructionType = try decode(inst);

    switch (instructionType) {
        .Fence => |f| {
            try std.testing.expectEqual(0b0001111, f.opcode);
            try std.testing.expectEqual(0b1111, f.pred); // Preceding operations (rw, io)
            try std.testing.expectEqual(0b1111, f.succ); // Succeeding operations (rw, io)
            try std.testing.expectEqual(0b000, f.funct3); // Always 0 for FENCE
        },
        else => try std.testing.expect(false),
    }
}

test "decode fence.i instruction" {
    const inst: RawInstruction = 0x0000100F; // FENCE.I
    const instructionType = try decode(inst);

    switch (instructionType) {
        .FenceI => |fi| {
            try std.testing.expectEqual(0b0001111, fi.opcode);
            try std.testing.expectEqual(0b001, fi.funct3); // Always 0b001 for FENCE.I
        },
        else => try std.testing.expect(false),
    }
}
