const std = @import("std");
const encode = @import("./encoder.zig");

pub const RawInstruction = struct {
    value: u32,

    // Bits [0:6]
    pub inline fn opcode(self: RawInstruction) u7 {
        return @truncate(self.value & 0b1111111);
    }

    // Bits [7:11]
    pub inline fn rd(self: RawInstruction) u5 {
        return @truncate((self.value >> 7) & 0b11111);
    }

    // Bits [12:14]
    pub inline fn funct3(self: RawInstruction) u3 {
        return @truncate((self.value >> 12) & 0b111);
    }

    // Bits [15:19]
    pub inline fn rs1(self: RawInstruction) u5 {
        return @truncate((self.value >> 15) & 0b11111);
    }

    // Bits [20:24]
    pub inline fn rs2(self: RawInstruction) u5 {
        return @truncate((self.value >> 20) & 0b11111);
    }

    // Bits [25:31]
    pub inline fn funct7(self: RawInstruction) u7 {
        return @truncate((self.value >> 25) & 0b1111111);
    }

    // Bits [20:31]
    pub inline fn funct12(self: RawInstruction) u12 {
        return @truncate((self.value >> 20) & 0xFFF);
    }

    pub inline fn immIType(self: RawInstruction) i32 {
        return signExtend((self.value >> 20) & 0xFFF, 12);
    }

    pub inline fn immSType(self: RawInstruction) i32 {
        const imm0 = (self.value >> 7) & 0b11111;
        const imm1 = (self.value >> 25) & 0b1111111;
        return signExtend((imm1 << 5) | imm0, 12);
    }

    pub inline fn immBType(self: RawInstruction) i32 {
        const imm0: u32 = (self.value >> 8) & 0b1111; // imm[4:1]
        const imm1: u32 = (self.value & 0b10000000) >> 7; // imm[11]
        const imm2: u32 = (self.value >> 25) & 0b111111; // imm[10:5]
        const imm3: u32 = (self.value >> 31) & 0b1; // imm[12]
        const imm: u32 = (imm3 << 12) | (imm1 << 11) | (imm2 << 5) | (imm0 << 1);
        return signExtend(imm, 13);
    }

    pub inline fn immUType(self: RawInstruction) i32 {
        const imm: i32 = @bitCast(self.value & 0xFFFFF000);
        return imm >> 12;
    }

    pub inline fn immJType(self: RawInstruction) i32 {
        const imm0 = (self.value >> 12) & 0b11111111; // imm[19:12]
        const imm1 = (self.value >> 20) & 0b1; // imm[11]
        const imm2 = (self.value >> 21) & 0b1111111111; // imm[10:1]
        const imm3 = (self.value >> 31) & 0b1; // imm[20]
        return signExtend((imm3 << 20) | (imm0 << 12) | (imm1 << 11) | (imm2 << 1), 21);
    }

    pub inline fn csr(self: RawInstruction) u12 {
        return @truncate((self.value >> 20) & 0b111111111111);
    }

    pub inline fn pred(self: RawInstruction) u4 {
        return @truncate((self.value >> 24) & 0b1111); // Bits [27:24]
    }

    pub inline fn succ(self: RawInstruction) u4 {
        return @truncate((self.value >> 20) & 0b1111); // Bits [23:20]
    }
};

inline fn signExtend(value: u32, comptime bits: u5) i32 {
    const signMask = @as(u32, 1) << (bits - 1);

    if ((value & signMask) != 0) {
        const signExtension: u32 = ~@as(u32, 0) << bits;
        return @bitCast(signExtension | value);
    }

    return @bitCast(value);
}

test "opcode extraction" {
    const inst = RawInstruction{ .value = encode.ADD(1, 2, 3) }; // ADD x1, x2, x3
    try std.testing.expectEqual(0b0110011, inst.opcode());
}

test "rd extraction" {
    const inst = RawInstruction{ .value = encode.ADD(10, 2, 3) }; // ADD x10, x2, x3
    try std.testing.expectEqual(10, inst.rd()); // rd = x10
}

test "funct3 extraction" {
    const inst = RawInstruction{ .value = encode.ADD(1, 2, 3) }; // ADD x1, x2, x3
    try std.testing.expectEqual(0b000, inst.funct3());
}

test "rs1 extraction" {
    const inst = RawInstruction{ .value = encode.ADD(1, 11, 3) }; // ADD x1, x11, x3
    try std.testing.expectEqual(11, inst.rs1()); // rs1 = x11
}

test "rs2 extraction" {
    const inst = RawInstruction{ .value = encode.ADD(1, 2, 12) }; // ADD x1, x2, x12
    try std.testing.expectEqual(12, inst.rs2()); // rs2 = x12
}

test "funct7 extraction" {
    const inst = RawInstruction{ .value = encode.SUB(1, 2, 3) }; // SUB x1, x2, x3
    try std.testing.expectEqual(0b0100000, inst.funct7());
}

test "I-type immediate extraction" {
    const inst = RawInstruction{ .value = encode.ADDI(5, 3, 4) }; // ADDI x5, x3, 4
    try std.testing.expectEqual(4, inst.immIType());
}

test "S-type immediate extraction" {
    const inst = RawInstruction{ .value = encode.SW(3, 20, 4) }; // SW x3, 20(x4)
    try std.testing.expectEqual(20, inst.immSType());
}

test "B-type immediate extraction" {
    const inst = RawInstruction{ .value = encode.BEQ(2, 3, -8) }; // BEQ x2, x3, -8
    try std.testing.expectEqual(-8, inst.immBType());
}

test "U-type immediate extraction" {
    const inst = RawInstruction{ .value = encode.LUI(7, 0x12345) }; // LUI x7, 0x12345
    try std.testing.expectEqual(0x12345, inst.immUType());
}

test "J-type immediate extraction" {
    const inst = RawInstruction{ .value = encode.JAL(8, 0x1000) }; // JAL x8, 0x1000
    try std.testing.expectEqual(0x1000, inst.immJType());
}

test "System immediate extraction" {
    const inst = RawInstruction{ .value = encode.CSRRC(4, 5, 0x300) }; // CSRRC x4, x5, CSR 0x300
    try std.testing.expectEqual(0x300, inst.immSystem());
}

// TODO: Write encoders for FENCE and FENCE.I
// test "pred extraction" {
//     const inst = Instruction{ .value = encode.FENCE(0b1111, 0b0000) }; // FENCE pred=1111, succ=0000
//     try std.testing.expectEqual(0b1111, inst.pred());
// }

// test "succ extraction" {
//     const inst = Instruction{ .value = encode.FENCE(0b0000, 0b1111) }; // FENCE pred=0000, succ=1111
//     try std.testing.expectEqual(0b1111, inst.succ());
// }
