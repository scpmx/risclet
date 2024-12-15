const RawInstruction = @import("./instruction.zig").RawInstruction;
const encode = @import("/encoder.zig");

const RType = struct { rd: u5, rs1: u5, rs2: u5 };

const IType = struct { rd: u5, rs1: u5, imm: i32 };

const SType = struct { rs1: u5, rs2: u5, imm: i32 };

const BType = struct { rs1: u5, rs2: u5, imm: i32 };

const UType = struct { rd: u5, imm: i32 };

const JType = struct { rd: u5, imm: i32 };

const SysType = struct { rd: u5, rs1: u5, csr: u12 };

const SysImmType = struct { rd: u5, rs1: u5, csr: u12, imm: u4 };

pub const DecodedInstruction = union(enum) {
    // R-Type Instructions
    ADD: RType,
    SUB: RType,
    SLL: RType,
    SLT: RType,
    SLTU: RType,
    XOR: RType,
    SRL: RType,
    SRA: RType,
    OR: RType,
    AND: RType,

    // I-Type
    ADDI: IType,
    SLLI: IType,
    SLTI: IType,
    SLTIU: IType,
    XORI: IType,
    SRLI: IType,
    ORI: IType,
    ANDI: IType,
    LB: IType,
    LH: IType,
    LW: IType,
    LBU: IType,
    LHU: IType,
    JALR: IType,

    // S-Type
    SB: SType,
    SH: SType,
    SW: SType,

    // B-Type
    BEQ: BType,
    BNE: BType,
    BLT: BType,
    BGE: BType,
    BLTU: BType,
    BGEU: BType,

    // U-Type
    LUI: UType,
    AUIPC: UType,

    // J-Type
    JAL: JType,

    // System
    WFI: void,
    SRET: void,
    ECALL: void,
    EBREAK: void,

    CSRRW: SysType,
    CSRRS: SysType,
    CSRRC: SysType,
    CSRRWI: SysImmType,
    CSRRSI: SysImmType,
    CSRRCI: SysImmType,

    // Fence
    FENCE: void,
    FENCEI: void,
};

pub fn decode(instruction: RawInstruction) !DecodedInstruction {
    switch (instruction.opcode()) {
        0b0110011 => { // R-Type
            const rtype = RType{
                .rd = instruction.rd(),
                .rs1 = instruction.rs1(),
                .rs2 = instruction.rs2(),
            };
            switch (instruction.funct3()) {
                0b000 => {
                    switch (instruction.funct7()) {
                        0b0000000 => {
                            return DecodedInstruction{ .ADD = rtype };
                        },
                        0b0100000 => {
                            return DecodedInstruction{ .SUB = rtype };
                        },
                        else => return error.UnknownInstruction,
                    }
                },
                0b001 => {
                    return DecodedInstruction{ .SLL = rtype };
                },
                0b010 => {
                    return DecodedInstruction{ .SLT = rtype };
                },
                0b011 => {
                    return DecodedInstruction{ .SLTU = rtype };
                },
                0b100 => {
                    return DecodedInstruction{ .XOR = rtype };
                },
                0b101 => {
                    switch (instruction.funct7()) {
                        0b0000000 => {
                            return DecodedInstruction{ .SRL = rtype };
                        },
                        0b0100000 => {
                            return DecodedInstruction{ .SRA = rtype };
                        },
                        else => return error.UnknownInstruction,
                    }
                },
                0b110 => {
                    return DecodedInstruction{ .OR = rtype };
                },
                0b111 => {
                    return DecodedInstruction{ .AND = rtype };
                },
            }
        },
        0b0010011 => { // I-Type
            const iType = IType{
                .rd = instruction.rd(),
                .rs1 = instruction.rs1(),
                .imm = instruction.immIType(),
            };

            switch (instruction.funct3()) {
                0b000 => {
                    return DecodedInstruction{ .ADDI = iType };
                },
                0b001 => {
                    return DecodedInstruction{ .SLLI = iType };
                },
                0b010 => {
                    return DecodedInstruction{ .SLTI = iType };
                },
                0b011 => {
                    return DecodedInstruction{ .SLTIU = iType };
                },
                0b100 => {
                    return DecodedInstruction{ .XORI = iType };
                },
                0b101 => {
                    return DecodedInstruction{ .SRLI = iType };
                },
                0b110 => {
                    return DecodedInstruction{ .ORI = iType };
                },
                0b111 => {
                    return DecodedInstruction{ .ANDI = iType };
                },
            }
        },
        0b0000011 => { // I-Type
            const iType = IType{
                .rd = instruction.rd(),
                .rs1 = instruction.rs1(),
                .imm = instruction.immIType(),
            };

            switch (instruction.funct3()) {
                0b000 => { // LB
                    return DecodedInstruction{ .LB = iType };
                },
                0b001 => { // LH
                    return DecodedInstruction{ .LH = iType };
                },
                0b010 => { // LW
                    return DecodedInstruction{ .LW = iType };
                },
                0b100 => { // LBU
                    return DecodedInstruction{ .LBU = iType };
                },
                0b101 => { // LHU
                    return DecodedInstruction{ .LHU = iType };
                },
                else => return error.UnknownInstruction,
            }
        },
        0b1100111 => { // I-Type
            switch (instruction.funct3()) {
                0b000 => {
                    return DecodedInstruction{
                        .JALR = IType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .imm = instruction.immIType(),
                        },
                    };
                },
                else => return error.UnknownInstruction,
            }
        },
        0b0100011 => { // S-Type
            const sType = SType{
                .rs1 = instruction.rs1(),
                .rs2 = instruction.rs2(),
                .imm = instruction.immSType(),
            };
            switch (instruction.funct3()) {
                0b000 => { // SB
                    return DecodedInstruction{ .SB = sType };
                },
                0b001 => { // SH
                    return DecodedInstruction{ .SH = sType };
                },
                0b010 => { // SW
                    return DecodedInstruction{ .SW = sType };
                },
                else => return error.UnknownInstruction,
            }
        },
        0b1100011 => { // B-Type
            const bType = BType{
                .rs1 = instruction.rs1(),
                .rs2 = instruction.rs2(),
                .imm = instruction.immBType(),
            };
            switch (instruction.funct3()) {
                0b000 => { // BEQ
                    return DecodedInstruction{ .BEQ = bType };
                },
                0b001 => { // BNE
                    return DecodedInstruction{ .BNE = bType };
                },
                0b100 => { // BLT
                    return DecodedInstruction{ .BLT = bType };
                },
                0b101 => { // BGE
                    return DecodedInstruction{ .BGE = bType };
                },
                0b110 => { // BLTU
                    return DecodedInstruction{ .BLTU = bType };
                },
                0b111 => { // BGEU
                    return DecodedInstruction{ .BGEU = bType };
                },
                else => return error.UnknownInstruction,
            }
        },
        0b0110111 => { // U-Type
            return DecodedInstruction{
                .LUI = UType{
                    .rd = instruction.rd(),
                    .imm = instruction.immUType(),
                },
            };
        },
        0b0010111 => { // U-Type
            return DecodedInstruction{
                .AUIPC = UType{
                    .rd = instruction.rd(),
                    .imm = instruction.immUType(),
                },
            };
        },
        0b1101111 => { // J-Type
            return DecodedInstruction{
                .JAL = JType{
                    .rd = instruction.rd(),
                    .imm = instruction.immJType(),
                },
            };
        },
        0b1110011 => { // System
            switch (instruction.funct3()) {
                0 => {
                    switch (instruction.funct12()) {
                        0x000 => {
                            return DecodedInstruction{ .ECALL = {} };
                        },
                        0x001 => {
                            return DecodedInstruction{ .EBREAK = {} };
                        },
                        0x102 => {
                            return DecodedInstruction{ .SRET = {} };
                        },
                        0x105 => {
                            return DecodedInstruction{ .WFI = {} };
                        },
                        else => return error.UnknownInstruction,
                    }
                },
                1 => {
                    return DecodedInstruction{
                        .CSRRW = SysType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                        },
                    };
                },
                2 => {
                    return DecodedInstruction{
                        .CSRRS = SysType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                        },
                    };
                },
                3 => {
                    return DecodedInstruction{
                        .CSRRC = SysType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                        },
                    };
                },
                5 => {
                    return DecodedInstruction{
                        .CSRRWI = SysImmType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                            .imm = 0, // TODO
                        },
                    };
                },
                6 => {
                    return DecodedInstruction{
                        .CSRRSI = SysImmType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                            .imm = 0, // TODO
                        },
                    };
                },
                7 => {
                    return DecodedInstruction{
                        .CSRRCI = SysImmType{
                            .rd = instruction.rd(),
                            .rs1 = instruction.rs1(),
                            .csr = instruction.csr(),
                            .imm = 0, // TODO
                        },
                    };
                },
                else => return error.UnknownInstruction,
            }
        },
        0b0001111 => { // I-Type
            switch (instruction.funct3()) {
                0b000 => {
                    return DecodedInstruction{ .FENCE = {} };
                },
                0b001 => {
                    return DecodedInstruction{ .FENCEI = {} };
                },
                else => return error.UnknownInstruction,
            }
        },
        else => return error.UnknownInstruction,
    }
}
