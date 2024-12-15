// R-Type Instructions
pub fn ADD(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b000, 0b0000000, 0b0110011);
}

pub fn SUB(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b000, 0b0100000, 0b0110011);
}

pub fn SLL(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b001, 0b0000000, 0b0110011);
}

pub fn SLT(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b010, 0b0000000, 0b0110011);
}

pub fn SLTU(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b011, 0b0000000, 0b0110011);
}

pub fn XOR(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b100, 0b0000000, 0b0110011);
}

pub fn SRL(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b101, 0b0000000, 0b0110011);
}

pub fn SRA(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b101, 0b0100000, 0b0110011);
}

pub fn OR(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b110, 0b0000000, 0b0110011);
}

pub fn AND(rd: u5, rs1: u5, rs2: u5) u32 {
    return RType(rd, rs1, rs2, 0b111, 0b0000000, 0b0110011);
}

// I-Type instruction encoders
pub fn ADDI(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b000, 0b0010011);
}

pub fn SLTI(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b010, 0b0010011);
}

pub fn SLTIU(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b011, 0b0010011);
}

pub fn XORI(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b100, 0b0010011);
}

pub fn ORI(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b110, 0b0010011);
}

pub fn ANDI(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b111, 0b0010011);
}

pub fn JALR(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b000, 0b1100111);
}

pub fn LB(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b000, 0b0000011);
}

pub fn LH(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b001, 0b0000011);
}

pub fn LW(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b010, 0b0000011);
}

pub fn LBU(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b100, 0b0000011);
}

pub fn LHU(rd: u5, rs1: u5, imm: i12) u32 {
    return IType(rd, rs1, imm, 0b101, 0b0000011);
}

pub fn SLLI(rd: u5, rs1: u5, shamt: u5) u32 {
    return IType(rd, rs1, @intCast(shamt), 0b001, 0b0010011);
}

pub fn SRLI(rd: u5, rs1: u5, shamt: u5) u32 {
    const shamt_as_i5: i5 = @bitCast(shamt);
    const imm = @as(i12, shamt_as_i5);
    return IType(rd, rs1, imm, 0b101, 0b0010011);
}

pub fn SRAI(rd: u5, rs1: u5, shamt: u5) u32 {
    const shamt_as_i5: i5 = @bitCast(shamt);
    const imm = @as(i12, shamt_as_i5);
    return IType(rd, rs1, imm | (0b0100000 << 5), 0b101, 0b0010011);
}

// S-Type instruction encoders
pub fn SB(rs2: u5, imm: i12, rs1: u5) u32 {
    return SType(rs1, rs2, imm, 0b000, 0b0100011); // funct3 = 0b000, opcode = 0b0100011
}

pub fn SH(rs2: u5, imm: i12, rs1: u5) u32 {
    return SType(rs1, rs2, imm, 0b001, 0b0100011); // funct3 = 0b001, opcode = 0b0100011
}

pub fn SW(rs2: u5, imm: i12, rs1: u5) u32 {
    return SType(rs1, rs2, imm, 0b010, 0b0100011); // funct3 = 0b010, opcode = 0b0100011
}

// B-Type instruction encoders
pub fn BEQ(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b000, 0b1100011);
}

pub fn BNE(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b001, 0b1100011);
}

pub fn BLT(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b100, 0b1100011);
}

pub fn BGE(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b101, 0b1100011);
}

pub fn BLTU(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b110, 0b1100011);
}

pub fn BGEU(rs1: u5, rs2: u5, imm: i13) u32 {
    return BType(rs1, rs2, imm, 0b111, 0b1100011);
}

// U-Type instruction encoders
pub fn LUI(rd: u5, imm: i20) u32 {
    return UType(rd, imm, 0b0110111);
}

pub fn AUIPC(rd: u5, imm: i20) u32 {
    return UType(rd, imm, 0b0010111);
}

// J-Type instruction encoders
pub fn JAL(rd: u5, imm: i21) u32 {
    return JType(rd, imm, 0b1101111);
}

// System instruction encoders
pub fn ECALL() u32 {
    return 0x00000073;
}

pub fn EBREAK() u32 {
    return 0x00100073;
}

pub fn SRET() u32 {
    return 0x10200073;
}

pub fn WFI() u32 {
    return 0x10500073;
}

pub fn CSRRW(rd: u5, rs1: u5, csr: u12) u32 {
    const csr_as_u32 = @as(u32, csr);
    const rs1_as_u32 = @as(u32, rs1);
    const one_as_u32 = @as(u32, 1);
    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, 0b1110011);
    return (csr_as_u32 << 20) | (rs1_as_u32 << 15) | (one_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

pub fn CSRRS(rd: u5, rs1: u5, csr: u12) u32 {
    const rd_as_u32 = @as(u32, rd);
    const rs1_as_u32 = @as(u32, rs1);
    const two_as_u32 = @as(u32, 2);
    const csr_as_u32 = @as(u32, csr);
    const opcode_as_u32 = @as(u32, 0b1110011);
    return (csr_as_u32 << 20) | (rs1_as_u32 << 15) | (two_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

pub fn CSRRC(rd: u5, rs1: u5, csr: u12) u32 {
    const rd_as_u32 = @as(u32, rd);
    const rs1_as_u32 = @as(u32, rs1);
    const three_as_u32 = @as(u32, 3);
    const csr_as_u32 = @as(u32, csr);
    const opcode_as_u32 = @as(u32, 0b1110011);
    return (csr_as_u32 << 20) | (rs1_as_u32 << 15) | (three_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

pub fn CSRRWI(rd: u5, imm: u5, csr: u12) u32 {
    const csr_as_u32 = @as(u32, csr);
    const imm_as_u32 = @as(u32, imm);
    const funct3_as_u32 = @as(u32, 0b101); // funct3 for CSRRWI
    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, 0b1110011); // CSR opcode
    return (csr_as_u32 << 20) | (imm_as_u32 << 15) | (funct3_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

pub fn CSRRSI(rd: u5, imm: u5, csr: u12) u32 {
    const csr_as_u32 = @as(u32, csr);
    const imm_as_u32 = @as(u32, imm);
    const funct3_as_u32 = @as(u32, 0b110); // funct3 for CSRRSI
    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, 0b1110011); // CSR opcode
    return (csr_as_u32 << 20) | (imm_as_u32 << 15) | (funct3_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

pub fn CSRRCI(rd: u5, imm: u5, csr: u12) u32 {
    const csr_as_u32 = @as(u32, csr);
    const imm_as_u32 = @as(u32, imm);
    const funct3_as_u32 = @as(u32, 0b111); // funct3 for CSRRCI
    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, 0b1110011); // CSR opcode
    return (csr_as_u32 << 20) | (imm_as_u32 << 15) | (funct3_as_u32 << 12) | (rd_as_u32 << 7) | opcode_as_u32;
}

fn RType(rd: u5, rs1: u5, rs2: u5, funct3: u3, funct7: u7, opcode: u7) u32 {
    const rd_as_u32 = @as(u32, rd);
    const rs1_as_u32 = @as(u32, rs1);
    const rs2_as_u32 = @as(u32, rs2);
    const funct3_as_u32 = @as(u32, funct3);
    const funct7_as_u32 = @as(u32, funct7);
    const opcode_as_u32 = @as(u32, opcode);

    return (funct7_as_u32 << 25) |
        (rs2_as_u32 << 20) |
        (rs1_as_u32 << 15) |
        (funct3_as_u32 << 12) |
        (rd_as_u32 << 7) |
        opcode_as_u32;
}

fn IType(rd: u5, rs1: u5, imm: i12, funct3: u3, opcode: u7) u32 {
    const imm_as_i32 = @as(i32, imm);
    const imm_unsigned: u32 = @bitCast(imm_as_i32);
    const rd_as_u32 = @as(u32, rd);
    const rs1_as_u32 = @as(u32, rs1);
    const funct3_as_u32 = @as(u32, funct3);
    const opcode_as_u32 = @as(u32, opcode);

    return (imm_unsigned << 20) |
        (rs1_as_u32 << 15) |
        (funct3_as_u32 << 12) |
        (rd_as_u32 << 7) |
        opcode_as_u32;
}

fn SType(rs1: u5, rs2: u5, imm: i12, funct3: u3, opcode: u7) u32 {
    const imm_as_i32 = @as(i32, imm);
    const imm_unsigned: u32 = @bitCast(imm_as_i32);

    const imm_11_5 = (imm_unsigned >> 5) & 0b1111111;
    const imm_4_0 = imm_unsigned & 0b11111;

    const rs1_as_u32 = @as(u32, rs1);
    const rs2_as_u32 = @as(u32, rs2);
    const funct3_as_u32 = @as(u32, funct3);
    const opcode_as_u32 = @as(u32, opcode);

    return (imm_11_5 << 25) |
        (rs2_as_u32 << 20) |
        (rs1_as_u32 << 15) |
        (funct3_as_u32 << 12) |
        (imm_4_0 << 7) |
        opcode_as_u32;
}

fn BType(rs1: u5, rs2: u5, imm: i13, funct3: u3, opcode: u7) u32 {
    const imm_as_i32 = @as(i32, imm);
    const imm_unsigned: u32 = @bitCast(imm_as_i32);

    const imm_12 = (imm_unsigned >> 12) & 0b1;
    const imm_10_5 = (imm_unsigned >> 5) & 0b111111;
    const imm_4_1 = (imm_unsigned >> 1) & 0b1111;
    const imm_11 = (imm_unsigned >> 11) & 0b1;

    const rs1_as_u32 = @as(u32, rs1);
    const rs2_as_u32 = @as(u32, rs2);
    const funct3_as_u32 = @as(u32, funct3);
    const opcode_as_u32 = @as(u32, opcode);

    return (imm_12 << 31) |
        (imm_10_5 << 25) |
        (rs2_as_u32 << 20) |
        (rs1_as_u32 << 15) |
        (funct3_as_u32 << 12) |
        (imm_4_1 << 8) |
        (imm_11 << 7) |
        opcode_as_u32;
}

fn UType(rd: u5, imm: i20, opcode: u7) u32 {
    const imm_as_i32 = @as(i32, imm);
    const imm_unsigned: u32 = @bitCast(imm_as_i32);
    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, opcode);

    return (imm_unsigned << 12) |
        (rd_as_u32 << 7) |
        opcode_as_u32;
}

fn JType(rd: u5, imm: i21, opcode: u7) u32 {
    const imm_as_i32 = @as(i32, imm);
    const imm_unsigned: u32 = @bitCast(imm_as_i32);

    const imm_20 = (imm_unsigned >> 20) & 0b1;
    const imm_10_1 = (imm_unsigned >> 1) & 0b1111111111;
    const imm_11 = (imm_unsigned >> 11) & 0b1;
    const imm_19_12 = (imm_unsigned >> 12) & 0b11111111;

    const rd_as_u32 = @as(u32, rd);
    const opcode_as_u32 = @as(u32, opcode);

    return (imm_20 << 31) |
        (imm_19_12 << 12) |
        (imm_11 << 20) |
        (imm_10_1 << 21) |
        (rd_as_u32 << 7) |
        opcode_as_u32;
}
