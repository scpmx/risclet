// Put these ecalls here even though we're going to rewrite them all soon enough
pub inline fn print_char(addr: *const u8) void {
    const char: u32 = @intCast(addr.*);
    asm volatile ("ecall"
        :
        : [char_value] "{a0}" (char), // Dereference addr to get the value
          [syscall_number] "{a7}" (2), // System call number for "print character"
        : "memory"
    );
}

pub inline fn print_int(value: u32) void {
    asm volatile ("ecall"
        :
        : [int_value] "{a0}" (value), // Number
          [syscall_number] "{a7}" (1), // System call number for "print integer"
        : "memory"
    );
}

pub inline fn exit(exit_code: u8) void {
    asm volatile ("ecall"
        :
        : [exit_code_value] "{a0}" (exit_code),
          [syscall_number] "{a7}" (3),
        : "memory"
    );
}
