const ecall = @import("./ecall.zig");

export fn _start() noreturn {
    asm volatile ("csrw stvec, t0"
        :
        : [address] "{t0}" (_trap_handler),
        : "memory"
    );

    while (true) {}
}

export fn _trap_handler() void {
    asm volatile ("sret");
    unreachable;
}
