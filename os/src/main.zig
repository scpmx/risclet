const ecall = @import("./ecall.zig");

export fn _start() noreturn {
    while (true) {}
}

export fn _trap_handler() void {
    ecall.print_int(42); // example to ensure this function doesn't get optimized out
}
