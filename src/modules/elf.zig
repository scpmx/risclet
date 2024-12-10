const std = @import("std");
const Memory = @import("./memory.zig").Memory;

pub const Elf32Header = struct {
    e_ident: [16]u8,
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u32,
    e_phoff: u32,
    e_shoff: u32,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,

    pub fn fromBytes(buffer: []const u8) !Elf32Header {
        if (buffer.len < 52) {
            return error.InvalidELF;
        }

        var e_ident: [16]u8 = undefined;
        for (0..16) |i| {
            e_ident[i] = buffer[i];
        }

        return Elf32Header{
            .e_ident = e_ident,
            .e_type = readU16(buffer, 16),
            .e_machine = readU16(buffer, 18),
            .e_version = readU32(buffer, 20),
            .e_entry = readU32(buffer, 24),
            .e_phoff = readU32(buffer, 28),
            .e_shoff = readU32(buffer, 32),
            .e_flags = readU32(buffer, 36),
            .e_ehsize = readU16(buffer, 40),
            .e_phentsize = readU16(buffer, 42),
            .e_phnum = readU16(buffer, 44),
            .e_shentsize = readU16(buffer, 46),
            .e_shnum = readU16(buffer, 48),
            .e_shstrndx = readU16(buffer, 50),
        };
    }
};

fn readU16(buffer: []const u8, offset: usize) u16 {
    return @as(u16, buffer[offset]) | (@as(u16, buffer[offset + 1]) << 8);
}

fn readU32(buffer: []const u8, offset: usize) u32 {
    return @as(u32, buffer[offset]) |
        (@as(u32, buffer[offset + 1]) << 8) |
        (@as(u32, buffer[offset + 2]) << 16) |
        (@as(u32, buffer[offset + 3]) << 24);
}

pub const Elf32_Phdr = struct {
    p_type: u32,
    p_offset: u32,
    p_vaddr: u32,
    p_paddr: u32,
    p_filesz: u32,
    p_memsz: u32,
    p_flags: u32,
    p_align: u32,

    pub fn fromBytes(buffer: []const u8, offset: usize) !Elf32_Phdr {
        if (buffer.len < offset + 32) {
            return error.InvalidELF;
        }

        return Elf32_Phdr{
            .p_type = readU32(buffer, offset + 0),
            .p_offset = readU32(buffer, offset + 4),
            .p_vaddr = readU32(buffer, offset + 8),
            .p_paddr = readU32(buffer, offset + 12),
            .p_filesz = readU32(buffer, offset + 16),
            .p_memsz = readU32(buffer, offset + 20),
            .p_flags = readU32(buffer, offset + 24),
            .p_align = readU32(buffer, offset + 28),
        };
    }
};

pub fn load_elf(memory: *Memory, buffer: []const u8) !u32 {
    const elf_header = try Elf32Header.fromBytes(buffer);

    const magic = [4]u8{ 0x7F, 'E', 'L', 'F' };
    if (!std.mem.eql(u8, elf_header.e_ident[0..4], &magic)) {
        return error.InvalidELF;
    }

    for (0..elf_header.e_phnum) |i| {
        const offset = elf_header.e_phoff + (i * elf_header.e_phentsize);
        const phdr = try Elf32_Phdr.fromBytes(buffer, offset);
        if (phdr.p_type == 1) { // PT_LOAD
            const segment_data = buffer[phdr.p_offset .. phdr.p_offset + phdr.p_filesz];

            for (0..segment_data.len) |idx| {
                try memory.write8(phdr.p_vaddr + idx, segment_data[idx]);
            }

            for (phdr.p_filesz..phdr.p_memsz) |idx| {
                try memory.write8(phdr.p_vaddr + idx, 0);
            }
        }
    }

    return elf_header.e_entry;
}
