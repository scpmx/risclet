const std = @import("std");
const Memory = @import("./memory.zig").Memory;

pub const Elf32Header = struct {
    magic: [16]u8,
    file_type: u16,
    machine_type: u16,
    version: u32,
    entry_point: u32,
    program_header_offset: u32,
    section_header_offset: u32,
    flags: u32,
    header_size: u16,
    program_header_entry_size: u16,
    program_header_entry_count: u16,
    section_header_entry_size: u16,
    section_header_entry_count: u16,
    section_header_string_index: u16,

    pub fn fromBytes(buffer: []const u8) !Elf32Header {
        if (buffer.len < 52) {
            return error.InvalidELF;
        }

        var magic: [16]u8 = undefined;
        for (0..16) |i| {
            magic[i] = buffer[i];
        }

        return Elf32Header{
            .magic = magic,
            .file_type = readU16(buffer, 16),
            .machine_type = readU16(buffer, 18),
            .version = readU32(buffer, 20),
            .entry_point = readU32(buffer, 24),
            .program_header_offset = readU32(buffer, 28),
            .section_header_offset = readU32(buffer, 32),
            .flags = readU32(buffer, 36),
            .header_size = readU16(buffer, 40),
            .program_header_entry_size = readU16(buffer, 42),
            .program_header_entry_count = readU16(buffer, 44),
            .section_header_entry_size = readU16(buffer, 46),
            .section_header_entry_count = readU16(buffer, 48),
            .section_header_string_index = readU16(buffer, 50),
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

pub const Elf32ProgramHeader = struct {
    segment_type: u32,
    file_offset: u32,
    virtual_address: u32,
    physical_address: u32,
    file_size: u32,
    memory_size: u32,
    flags: u32,
    alignment: u32,

    pub fn fromBytes(buffer: []const u8, offset: usize) !Elf32ProgramHeader {
        if (buffer.len < offset + 32) {
            return error.InvalidELF;
        }

        return Elf32ProgramHeader{
            .segment_type = readU32(buffer, offset + 0),
            .file_offset = readU32(buffer, offset + 4),
            .virtual_address = readU32(buffer, offset + 8),
            .physical_address = readU32(buffer, offset + 12),
            .file_size = readU32(buffer, offset + 16),
            .memory_size = readU32(buffer, offset + 20),
            .flags = readU32(buffer, offset + 24),
            .alignment = readU32(buffer, offset + 28),
        };
    }
};

pub fn load_elf(memory: *Memory, buffer: []const u8) !u32 {
    const elf_header = try Elf32Header.fromBytes(buffer);

    const magic = [4]u8{ 0x7F, 'E', 'L', 'F' };
    if (!std.mem.eql(u8, elf_header.magic[0..4], &magic)) {
        return error.InvalidELF;
    }

    for (0..elf_header.program_header_entry_count) |i| {
        const offset = elf_header.program_header_offset + (i * elf_header.program_header_entry_size);
        const phdr = try Elf32ProgramHeader.fromBytes(buffer, offset);
        if (phdr.segment_type == 1) { // PT_LOAD
            const segment_data = buffer[phdr.file_offset .. phdr.file_offset + phdr.file_size];

            for (0..segment_data.len) |idx| {
                try memory.write8(phdr.virtual_address + idx, segment_data[idx]);
            }

            for (phdr.file_size..phdr.memory_size) |idx| {
                try memory.write8(phdr.virtual_address + idx, 0);
            }
        }
    }

    return elf_header.entry_point;
}
