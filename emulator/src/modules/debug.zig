const std = @import("std");
const instruction = @import("./instruction.zig");
const DecodedInstruction = instruction.DecodedInstruction;
const RawInstruction = instruction.RawInstruction;
const Memory = @import("./memory.zig").Memory;
const CPUState = @import("./cpu.zig").CPUState;

pub fn printInstruction(decodedInstruction: DecodedInstruction, address: usize) !void {
    switch (decodedInstruction) {
        .RType => |inst| {
            switch (inst.opcode) {
                0b0110011 => {
                    switch (inst.funct3) {
                        0b000 => {
                            switch (inst.funct7) {
                                0b0000000 => { // ADD
                                    std.debug.print("{X:0>8}: ADD x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                                },
                                0b0100000 => { // SUB
                                    std.debug.print("{X:0>8}: SUB x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                                },
                                else => {
                                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                                },
                            }
                        },
                        0b001 => { // SLL
                            std.debug.print("{X:0>8}: SLL x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b010 => { // SLT
                            std.debug.print("{X:0>8}: SLT x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b011 => { // SLTU
                            std.debug.print("{X:0>8}: SLTU x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b100 => { // XOR
                            std.debug.print("{X:0>8}: XOR x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b101 => {
                            switch (inst.funct7) {
                                0b0000000 => { // SRL
                                    std.debug.print("{X:0>8}: SRL x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                                },
                                0b0100000 => { // SRA
                                    std.debug.print("{X:0>8}: SRA x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                                },
                                else => {
                                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                                },
                            }
                        },
                        0b110 => { // OR
                            std.debug.print("{X:0>8}: OR x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b111 => { // AND
                            std.debug.print("{X:0>8}: AND x{d}, x{d}, x{d}\n", .{ address, inst.rd, inst.rs1, inst.rs2 });
                        },
                    }
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .IType => |inst| {
            switch (inst.opcode) {
                0b0010011 => {
                    // const rs1Value = cpuState.gprs[inst.rs1];
                    switch (inst.funct3) {
                        0b000 => { // ADDI
                            std.debug.print("{X:0>8}: ADDI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b001 => { // SLLI
                            std.debug.print("{X:0>8}: SLLI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b010 => { // SLTI
                            std.debug.print("{X:0>8}: SLTI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b011 => { // SLTIU
                            std.debug.print("{X:0>8}: SLTIU x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b100 => { // XORI
                            std.debug.print("{X:0>8}: XORI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b101 => { // SRLI
                            std.debug.print("{X:0>8}: SRLI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b110 => { // ORI
                            std.debug.print("{X:0>8}: ORI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                        0b111 => { // ANDI
                            std.debug.print("{X:0>8}: ANDI x{d}, x{d}, {d}\n", .{ address, inst.rd, inst.rs1, inst.imm });
                        },
                    }
                },
                0b0000011 => {
                    switch (inst.funct3) {
                        0b000 => { // LB
                            std.debug.print("{X:0>8}: LB x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        0b001 => { // LH
                            std.debug.print("{X:0>8}: LH x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        0b010 => { // LW
                            std.debug.print("{X:0>8}: LW x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        0b100 => { // LBU
                            std.debug.print("{X:0>8}: LBU x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        0b101 => { // LHU
                            std.debug.print("{X:0>8}: LHB x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        else => {
                            std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                        },
                    }
                },
                0b1100111 => {
                    switch (inst.funct3) {
                        0b000 => { // JALR
                            std.debug.print("{X:0>8}: JALR x{d}, {d}(x{d})\n", .{ address, inst.rd, inst.imm, inst.rs1 });
                        },
                        else => {
                            std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                        },
                    }
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .SType => |inst| {
            switch (inst.opcode) {
                0b0100011 => {
                    switch (inst.funct3) {
                        0b000 => { // SB
                            std.debug.print("{X:0>8}: SB x{d}, {d}(x{d})\n", .{ address, inst.rs2, inst.imm, inst.rs1 });
                        },
                        0b001 => { // SH
                            std.debug.print("{X:0>8}: SH x{d}, {d}(x{d})\n", .{ address, inst.rs2, inst.imm, inst.rs1 });
                        },
                        0b010 => { // SW
                            std.debug.print("{X:0>8}: SW x{d}, {d}(x{d})\n", .{ address, inst.rs2, inst.imm, inst.rs1 });
                        },
                        else => {
                            std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                        },
                    }
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .BType => |inst| {
            switch (inst.opcode) {
                0b1100011 => {
                    switch (inst.funct3) {
                        0b000 => { // BEQ
                            std.debug.print("{X:0>8}: BEQ x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        0b001 => { // BNE
                            std.debug.print("{X:0>8}: BNE x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        0b100 => { // BLT
                            std.debug.print("{X:0>8}: BLT x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        0b101 => { // BGE
                            std.debug.print("{X:0>8}: BGE x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        0b110 => { // BLTU
                            std.debug.print("{X:0>8}: BLTU x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        0b111 => { // BGEU
                            std.debug.print("{X:0>8}: BGEU x{d}, x{d}, {d}\n", .{ address, inst.rs1, inst.rs2, inst.imm });
                        },
                        else => {
                            std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                        },
                    }
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .UType => |inst| {
            switch (inst.opcode) {
                0b0110111 => { // LUI
                    std.debug.print("{X:0>8}: LUI x{d}, {d}\n", .{ address, inst.rd, inst.imm });
                },
                0b0010111 => { // AUIPC
                    std.debug.print("{X:0>8}: AUIPC x{d}, {d}\n", .{ address, inst.rd, inst.imm });
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .JType => |inst| {
            switch (inst.opcode) {
                0b1101111 => { // J/JAL
                    std.debug.print("{X:0>8}: JAL x{d}, {d}\n", .{ address, inst.rd, inst.imm });
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .System => |inst| {
            switch (inst.opcode) {
                0b1110011 => {
                    switch (inst.imm) {
                        // Not tested as this is a sample implementation
                        0b00000 => { // ECALL
                            std.debug.print("{X:0>8}: ECALL\n", .{address});
                        },
                        // Not tested
                        0b00001 => { // EBREAK
                            std.debug.print("{X:0>8}: EBREAK\n", .{address});
                        },
                        else => {
                            std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                        },
                    }
                },
                else => {
                    std.debug.print("{X:0>8}: Unknown Instruction: {any}\n", .{ address, decodedInstruction });
                },
            }
        },
        .Fence => |_| {
            std.debug.print("{X:0>8}: FENCE\n", .{address});
        },
        .FenceI => |_| {
            std.debug.print("{X:0>8}: FENCE.I\n", .{address});
        },
    }
}

pub fn printCPU(cpuState: *const CPUState) void {
    std.debug.print("PC: 0x{X}, gprs: {any}\n", .{ cpuState.pc, cpuState.gprs });
}
