const std = @import("std");
const instruction = @import("./instruction.zig");
const DecodedInstruction = instruction.DecodedInstruction;
const RawInstruction = instruction.RawInstruction;
const Memory = @import("./memory.zig").Memory;
const CPUState = @import("./cpu.zig").CPUState;

pub fn printInstruction(decodedInstruction: DecodedInstruction) !void {
    switch (decodedInstruction) {
        .RType => |inst| {
            switch (inst.opcode) {
                0b0110011 => {
                    switch (inst.funct3) {
                        0b000 => {
                            switch (inst.funct7) {
                                0b0000000 => { // ADD
                                    std.debug.print("ADD x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                                },
                                0b0100000 => { // SUB
                                    std.debug.print("SUB x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                                },
                                else => {
                                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                                },
                            }
                        },
                        0b001 => { // SLL
                            std.debug.print("SLL x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b010 => { // SLT
                            std.debug.print("SLT x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b011 => { // SLTU
                            std.debug.print("SLTU x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b100 => { // XOR
                            std.debug.print("XOR x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b101 => {
                            switch (inst.funct7) {
                                0b0000000 => { // SRL
                                    std.debug.print("SRL x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                                },
                                0b0100000 => { // SRA
                                    std.debug.print("SRA x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                                },
                                else => {
                                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                                },
                            }
                        },
                        0b110 => { // OR
                            std.debug.print("OR x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                        0b111 => { // AND
                            std.debug.print("AND x{d}, x{d}, x{d}\n", .{ inst.rd, inst.rs1, inst.rs2 });
                        },
                    }
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .IType => |inst| {
            switch (inst.opcode) {
                0b0010011 => {
                    // const rs1Value = cpuState.Registers[inst.rs1];
                    switch (inst.funct3) {
                        0b000 => { // ADDI
                            std.debug.print("ADDI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b001 => { // SLLI
                            std.debug.print("SLLI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b010 => { // SLTI
                            std.debug.print("SLTI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b011 => { // SLTIU
                            std.debug.print("SLTIU x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b100 => { // XORI
                            std.debug.print("XORI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b101 => { // SRLI
                            std.debug.print("SRLI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b110 => { // ORI
                            std.debug.print("ORI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                        0b111 => { // ANDI
                            std.debug.print("ANDI x{d}, x{d}, {d}\n", .{ inst.rd, inst.rs1, inst.imm });
                        },
                    }
                },
                0b0000011 => {
                    switch (inst.funct3) {
                        0b000 => { // LB
                            std.debug.print("LB x{d}, {d}(x{d})\n", .{ inst.rd, inst.imm, inst.rs1 });
                        },
                        0b001 => { // LH
                            std.debug.print("LH x{d}, {d}(x{d})\n", .{ inst.rd, inst.imm, inst.rs1 });
                        },
                        0b010 => { // LW
                            std.debug.print("LW x{d}, {d}(x{d})\n", .{ inst.rd, inst.imm, inst.rs1 });
                        },
                        0b100 => { // LBU
                            std.debug.print("LBU x{d}, {d}(x{d})\n", .{ inst.rd, inst.imm, inst.rs1 });
                        },
                        0b101 => { // LHU
                            std.debug.print("LHB x{d}, {d}(x{d})\n", .{ inst.rd, inst.imm, inst.rs1 });
                        },
                        else => {
                            std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                        },
                    }
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .SType => |inst| {
            switch (inst.opcode) {
                0b0100011 => {
                    switch (inst.funct3) {
                        0b000 => { // SB
                            std.debug.print("SB x{d}, {d}(x{d})\n", .{ inst.rs2, inst.rs1, inst.imm });
                        },
                        0b001 => { // SH
                            std.debug.print("SH x{d}, {d}(x{d})\n", .{ inst.rs2, inst.rs1, inst.imm });
                        },
                        0b010 => { // SW
                            std.debug.print("SW x{d}, {d}(x{d})\n", .{ inst.rs2, inst.rs1, inst.imm });
                        },
                        else => {
                            std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                        },
                    }
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .BType => |inst| {
            switch (inst.opcode) {
                0b1100011 => {
                    switch (inst.funct3) {
                        0b000 => { // BEQ
                            std.debug.print("BEQ x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        0b001 => { // BNE
                            std.debug.print("BNE x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        0b100 => { // BLT
                            std.debug.print("BLT x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        0b101 => { // BGE
                            std.debug.print("BGE x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        0b110 => { // BLTU
                            std.debug.print("BLTU x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        0b111 => { // BGEU
                            std.debug.print("BGEU x{d}, x{d}, {d}\n", .{ inst.rs1, inst.rs2, inst.imm });
                        },
                        else => {
                            std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                        },
                    }
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .UType => |inst| {
            switch (inst.opcode) {
                0b0110111 => { // LUI
                    std.debug.print("LUI x{d}, {d}\n", .{ inst.rd, inst.imm });
                },
                0b0010111 => { // AUIPC
                    std.debug.print("AUIPC x{d}, {d}\n", .{ inst.rd, inst.imm });
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .JType => |inst| {
            switch (inst.opcode) {
                0b1101111 => { // J/JAL
                    std.debug.print("JAL x{d}, {d}\n", .{ inst.rd, inst.imm });
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .System => |inst| {
            switch (inst.opcode) {
                0b1110011 => {
                    switch (inst.imm) {
                        // Not tested as this is a sample implementation
                        0b00000 => { // ECALL
                            std.debug.print("ECALL\n", .{});
                        },
                        // Not tested
                        0b00001 => { // EBREAK
                            std.debug.print("EBREAK\n", .{});
                        },
                        else => {
                            std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                        },
                    }
                },
                else => {
                    std.debug.print("Unknown Instruction: {any}\n", .{decodedInstruction});
                },
            }
        },
        .Fence => |_| {
            std.debug.print("FENCE\n", .{});
        },
        .FenceI => |_| {
            std.debug.print("FENCE.I\n", .{});
        },
    }
}

pub fn printCPU(cpuState: *const CPUState) void {
    std.debug.print("PC: 0x{X}, Registers: {any}\n", .{ cpuState.ProgramCounter, cpuState.Registers });
}
