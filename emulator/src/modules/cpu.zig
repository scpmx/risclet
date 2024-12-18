const std = @import("std");
const DecodedInstruction = @import("./decode.zig").DecodedInstruction;
const Memory = @import("./memory.zig").Memory;
const encode = @import("./encoder.zig");
const Csrs = @import("./csrs.zig").Csrs;
const RawInstruction = @import("./instruction.zig").RawInstruction;

const Privilege = enum { Supervisor, User };

const Trap = struct {
    cause: u32,
    fault_addr: u32,
    pc: u32,
};

pub const CPUState = struct {
    // Current Privilege Level
    privilege: Privilege = .Supervisor,

    // General Purpose Registers
    gprs: [32]u32 = [_]u32{0} ** 32,

    // Program Counter
    pc: u32 = 0,

    // Control and Status Registers
    csrs: Csrs = Csrs{},

    pub fn default(entry_pointer: u32, stack_pointer: u32) CPUState {
        var state = CPUState{};
        state.pc = entry_pointer;
        state.gprs[2] = stack_pointer;
        return state;
    }
};

pub fn fetch(cpu: *CPUState, mem: *Memory) !RawInstruction {
    const value = try mem.read32(cpu.pc);
    return RawInstruction{ .value = value };
}

pub fn execute(instruction: DecodedInstruction, cpu: *CPUState, mem: *Memory) ?Trap {
    switch (instruction) {
        .ADD => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = @addWithOverflow(cpu.gprs[x.rs1], cpu.gprs[x.rs2])[0];
            }
            cpu.pc += 4;
        },
        .SUB => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = @subWithOverflow(cpu.gprs[x.rs1], cpu.gprs[x.rs2])[0];
            }
            cpu.pc += 4;
        },
        .SLL => |x| {
            if (x.rd != 0) {
                const shiftAmount: u5 = @truncate(cpu.gprs[x.rs2]);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] << shiftAmount;
            }
            cpu.pc += 4;
        },
        .SLT => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const rs2Signed: i32 = @bitCast(cpu.gprs[x.rs2]);
                if (rs1Signed < rs2Signed) {
                    cpu.gprs[x.rd] = 1;
                } else {
                    cpu.gprs[x.rd] = 0;
                }
            }
            cpu.pc += 4;
        },
        .SLTU => |x| {
            if (x.rd != 0) {
                if (cpu.gprs[x.rs1] < cpu.gprs[x.rs2]) {
                    cpu.gprs[x.rd] = 1;
                } else {
                    cpu.gprs[x.rd] = 0;
                }
            }
            cpu.pc += 4;
        },
        .XOR => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] ^ cpu.gprs[x.rs2];
            }
            cpu.pc += 4;
        },
        .SRL => |x| {
            if (x.rd != 0) {
                const shiftAmount: u5 = @truncate(cpu.gprs[x.rs2]);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] >> shiftAmount;
            }
            cpu.pc += 4;
        },
        .SRA => |x| {
            if (x.rd != 0) {
                const shiftAmount: u5 = @truncate(cpu.gprs[x.rs2]);
                const signedRs1Value: i32 = @bitCast(cpu.gprs[x.rs1]);
                const result: i32 = signedRs1Value >> shiftAmount;
                cpu.gprs[x.rd] = @bitCast(result);
            }
            cpu.pc += 4;
        },
        .OR => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] | cpu.gprs[x.rs2];
            }
            cpu.pc += 4;
        },
        .AND => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] & cpu.gprs[x.rs2];
            }
            cpu.pc += 4;
        },
        .ADDI => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const newValue = @addWithOverflow(rs1Signed, x.imm);
                cpu.gprs[x.rd] = @bitCast(newValue[0]);
            }
            cpu.pc += 4;
        },
        .SLLI => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                const shiftAmount: u5 = @truncate(immUnsigned);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] << shiftAmount;
            }
            cpu.pc += 4;
        },
        .SLTI => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                if (rs1Signed < x.imm) {
                    cpu.gprs[x.rd] = 1;
                } else {
                    cpu.gprs[x.rd] = 0;
                }
            }
            cpu.pc += 4;
        },
        .SLTIU => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                if (cpu.gprs[x.rs1] < immUnsigned) {
                    cpu.gprs[x.rd] = 1;
                } else {
                    cpu.gprs[x.rd] = 0;
                }
            }
            cpu.pc += 4;
        },
        .XORI => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] ^ immUnsigned;
            }
            cpu.pc += 4;
        },
        .SRLI => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                const shiftAmount: u5 = @truncate(immUnsigned);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] >> shiftAmount;
            }
            cpu.pc += 4;
        },
        .ORI => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] | immUnsigned;
            }
            cpu.pc += 4;
        },
        .ANDI => |x| {
            if (x.rd != 0) {
                const immUnsigned: u32 = @bitCast(x.imm);
                cpu.gprs[x.rd] = cpu.gprs[x.rs1] & immUnsigned;
            }
            cpu.pc += 4;
        },
        .LB => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const address: u32 = @bitCast(rs1Signed + x.imm);

                const loadedByte = mem.read8(address) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };

                const byteAsWord = @as(u32, loadedByte);

                if (loadedByte & 0x80 != 0) {
                    const signedValue = 0xFFFFFF00 | byteAsWord;
                    cpu.gprs[x.rd] = signedValue;
                } else {
                    cpu.gprs[x.rd] = byteAsWord;
                }
            }
            cpu.pc += 4;
        },
        .LH => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const address: u32 = @bitCast(rs1Signed + x.imm);

                if (address & 0b1 != 0) {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                }

                const loadedU16 = mem.read16(address) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };

                const u16AsWord = @as(u32, loadedU16);

                if (u16AsWord & 0x8000 != 0) {
                    const signedValue = 0xFFFF0000 | u16AsWord;
                    cpu.gprs[x.rd] = signedValue;
                } else {
                    cpu.gprs[x.rd] = u16AsWord;
                }
            }
            cpu.pc += 4;
        },
        .LW => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const address: u32 = @bitCast(rs1Signed + x.imm);

                if (address & 0b11 != 0) {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                }

                cpu.gprs[x.rd] = mem.read32(address) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };
            }
            cpu.pc += 4;
        },
        .LBU => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const address: u32 = @bitCast(rs1Signed + x.imm);

                const loadedByte = mem.read8(address) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };

                const byteAsWord = @as(u32, loadedByte);

                cpu.gprs[x.rd] = byteAsWord;
            }
            cpu.pc += 4;
        },
        .LHU => |x| {
            if (x.rd != 0) {
                const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
                const address: u32 = @bitCast(rs1Signed + x.imm);

                if (address & 0b1 != 0) {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                }

                const loadedU16 = mem.read16(address) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };

                const u16AsWord = @as(u32, loadedU16);

                cpu.gprs[x.rd] = u16AsWord;
            }
            cpu.pc += 4;
        },
        .JALR => |x| {
            const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
            const target: u32 = @bitCast(rs1Signed + x.imm);
            // TODO: Ensure this is the actual behavior of JALR
            const aligned = target & 0xFFFFFFFE; // Clear LSB to ensure alignment
            if (x.rd != 0) {
                cpu.gprs[x.rd] = cpu.pc + 4; // Save return address
            }
            cpu.pc = aligned;
        },
        .SB => |x| {
            const rs1Value: i32 = @bitCast(cpu.gprs[x.rs1]);
            const address: u32 = @bitCast(rs1Value + x.imm);
            mem.write8(address, @truncate(cpu.gprs[x.rs2])) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            cpu.pc += 4;
        },
        .SH => |x| {
            const rs1Value: i32 = @bitCast(cpu.gprs[x.rs1]);
            const address: u32 = @bitCast(rs1Value + x.imm);

            if (address & 0b1 != 0) {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            } else {
                mem.write16(address, @truncate(cpu.gprs[x.rs2])) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };
            }
            cpu.pc += 4;
        },
        .SW => |x| {
            const rs1Value: i32 = @bitCast(cpu.gprs[x.rs1]);
            const address: u32 = @bitCast(rs1Value + x.imm);

            if (address & 0b11 != 0) {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            } else {
                mem.write32(address, cpu.gprs[x.rs2]) catch {
                    return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
                };
            }
            cpu.pc += 4;
        },
        .BEQ => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const rs2Value = cpu.gprs[x.rs2];
            if (rs1Value == rs2Value and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .BNE => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const rs2Value = cpu.gprs[x.rs2];
            if (rs1Value != rs2Value and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .BLT => |x| {
            const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
            const rs2Signed: i32 = @bitCast(cpu.gprs[x.rs2]);
            if (rs1Signed < rs2Signed and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .BGE => |x| {
            const rs1Signed: i32 = @bitCast(cpu.gprs[x.rs1]);
            const rs2Signed: i32 = @bitCast(cpu.gprs[x.rs2]);
            if (rs1Signed >= rs2Signed and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .BLTU => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const rs2Value = cpu.gprs[x.rs2];
            if (rs1Value < rs2Value and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .BGEU => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const rs2Value = cpu.gprs[x.rs2];
            if (rs1Value >= rs2Value and x.imm != 0) {
                const pcAsI32: i32 = @bitCast(cpu.pc);
                const nextPcValue = pcAsI32 + x.imm;
                cpu.pc = @bitCast(nextPcValue);
            } else {
                cpu.pc += 4;
            }
        },
        .LUI => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = @bitCast(x.imm << 12);
            }
            cpu.pc += 4;
        },
        .AUIPC => |x| {
            if (x.rd != 0) {
                const immShifted: u32 = @bitCast(x.imm << 12);
                cpu.gprs[x.rd] = @addWithOverflow(cpu.pc, immShifted)[0];
            }
            cpu.pc += 4;
        },
        .JAL => |x| {
            if (x.rd != 0) {
                cpu.gprs[x.rd] = cpu.pc + 4;
            }
            const pcAsSigned: i32 = @bitCast(cpu.pc);
            cpu.pc = @bitCast(pcAsSigned + x.imm);
        },
        .WFI => {
            std.debug.print("WFI", .{});
            cpu.pc += 4;
        },
        .SRET => {
            std.debug.print("SRET", .{});
            cpu.pc += 4;
        },
        .ECALL => {
            std.debug.print("ECALL", .{});
            cpu.pc += 4;
        },
        .EBREAK => {
            std.debug.print("EBREAK", .{});
            cpu.pc += 4;
        },
        .CSRRW => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const oldValue = cpu.csrs.readWrite(x.csr, rs1Value) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .CSRRS => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const oldValue = cpu.csrs.readSet(x.csr, rs1Value) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .CSRRC => |x| {
            const rs1Value = cpu.gprs[x.rs1];
            const oldValue = cpu.csrs.readClear(x.csr, rs1Value) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .CSRRWI => |x| {
            const immAsU32: u32 = @as(u32, x.imm);
            const oldValue = cpu.csrs.readWrite(x.csr, immAsU32) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .CSRRSI => |x| {
            const immAsU32: u32 = @as(u32, x.imm);
            const oldValue = cpu.csrs.readSet(x.csr, immAsU32) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .CSRRCI => |x| {
            const immAsU32: u32 = @as(u32, x.imm);
            const oldValue = cpu.csrs.readClear(x.csr, immAsU32) catch {
                return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
            };
            if (x.rd != 0) {
                cpu.gprs[x.rd] = oldValue;
            }
            cpu.pc += 4;
        },
        .FENCE => {
            std.debug.print("FENCE", .{});
            cpu.pc += 4;
        },
        .FENCEI => {
            std.debug.print("FENCE.I", .{});
            cpu.pc += 4;
        },
        .Unknown => |_| {
            return Trap{ .cause = 0, .fault_addr = 0, .pc = cpu.pc };
        },
    }
    return null;
}

test "csrrw test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize registers and CSR
    cpu.gprs[2] = 0xAAAAAAAA;
    cpu.csrs.sstatus = 0x55555555;

    // CSRRW: Write CSR and read old value to rd
    const di = DecodedInstruction{ .CSRRW = .{ .rd = 1, .rs1 = 2, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[1], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0xAAAAAAAA);
}

test "csrrs test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize registers and CSR
    cpu.gprs[3] = 0x0F0F0F0F;
    cpu.csrs.sstatus = 0x55555555;

    // CSRRS: Read CSR and set bits using rs1
    const di = DecodedInstruction{ .CSRRS = .{ .rd = 2, .rs1 = 3, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[2], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0x5F5F5F5F);
}

test "csrrc test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize registers and CSR
    cpu.gprs[4] = 0x0F0F0F0F;
    cpu.csrs.sstatus = 0x55555555;

    // CSRRC: Read CSR and clear bits using rs1
    const di = DecodedInstruction{ .CSRRC = .{ .rd = 3, .rs1 = 4, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[3], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0x50505050);
}

test "csrrwi test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize CSR
    cpu.csrs.sstatus = 0x55555555;

    // CSRRWI: Write immediate to CSR and read old value to rd
    const di = DecodedInstruction{ .CSRRWI = .{ .rd = 4, .imm = 0xA, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[4], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0xA);
}

test "csrrsi test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize CSR
    cpu.csrs.sstatus = 0x55555555;

    // CSRRSI: Read CSR and set bits using immediate
    const di = DecodedInstruction{ .CSRRSI = .{ .rd = 5, .imm = 0xF, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[5], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0x5555555F);
}

test "csrrci test" {
    var mem = try Memory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    var cpu = CPUState.default(0, 0);

    // Initialize CSR
    cpu.csrs.sstatus = 0x55555555;

    // CSRRCI: Read CSR and clear bits using immediate
    const di = DecodedInstruction{ .CSRRCI = .{ .rd = 6, .imm = 0xF, .csr = 0x100 } };
    try execute(di, &cpu, &mem);

    try std.testing.expectEqual(cpu.gprs[6], 0x55555555);
    try std.testing.expectEqual(cpu.csrs.sstatus, 0x55555550);
}
