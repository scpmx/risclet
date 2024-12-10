export fn _start() void {
    for (0..20) |i| {
        const val = fib(i);
        print_int(val);
    }
    exit(0);
}

pub fn print_char(addr: *const u8) void {
    const char: u32 = @intCast(addr.*);
    asm volatile ("ecall"
        :
        : [char_value] "{a0}" (char), // Dereference addr to get the value
          [syscall_number] "{a7}" (2), // System call number for "print character"
        : "memory"
    );
}

pub fn print_int(value: u32) void {
    asm volatile ("ecall"
        :
        : [int_value] "{a0}" (value), // Number
          [syscall_number] "{a7}" (1), // System call number for "print integer"
        : "memory"
    );
}

pub fn exit(exit_code: u8) void {
    asm volatile ("ecall"
        :
        : [exit_code_value] "{a0}" (exit_code),
          [syscall_number] "{a7}" (3),
        : "memory"
    );
}

// Lets test out the stack
pub fn fib(n: u32) u32 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    return fib(n - 1) + fib(n - 2);
}
