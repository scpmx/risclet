const SStatus = packed struct {
    SIE: u1 = 0, // Supervisor Interrupt Enable
    reserved0: u3 = 0, // Reserved (bits 2-4)
    SPIE: u1 = 0, // Supervisor Previous Interrupt Enable
    reserved1: u2 = 0, // Reserved (bits 6-7)
    SPP: u1 = 0, // Supervisor Previous Privilege
    reserved2: u9 = 0, // Reserved (bits 9-17)
    UBE: u1 = 0, // User-mode Endianness
    SUM: u1 = 0, // Supervisor Memory Access
    MXR: u1 = 0, // Make Executable Readable
    reserved3: u4 = 0, // Reserved (bits 20-23)
    FS: u2 = 0, // Floating-Point Status
    XS: u2 = 0, // Extension Status
    reserved4: u6 = 0, // Reserved (bits 26-31)
};

pub const Csrs = struct {

    // 0x100
    // Supervisor Status Register
    sstatus: u32 = 0,

    // 0x104
    // Supervisor Interrupt Enable Register
    sie: u32 = 0,

    // 0x105
    // Supervisor Trap-Vector Base Address
    stvec: u32 = 0,

    // 0x106
    // Counter Enable register for Supervisor mode
    scounteren: u32 = 0,

    // 0x140
    // Supervisor Scratch Register
    sscratch: u32 = 0,

    // 0x141
    // Supervisor Exception Program Counter
    sepc: u32 = 0,

    // 0x142
    // Supervisor Cause Register
    scause: u32 = 0,

    // 0x143
    // Supervisor Trap Value Register
    stval: u32 = 0,

    // 0x144
    // Supervisor Interrupt Pending Register
    sip: u32 = 0,

    // 0x180
    // Supervisor Address Translation and Protection
    satp: u32 = 0,

    fn getPtr(self: Csrs, addr: u12) !*u32 {
        return switch (addr) {
            0x100 => &self.sstatus,
            0x104 => &self.sie,
            0x105 => &self.stvec,
            0x106 => &self.scounteren,
            0x140 => &self.sscratch,
            0x141 => &self.sepc,
            0x142 => &self.scause,
            0x143 => &self.stval,
            0x144 => &self.sip,
            0x180 => &self.satp,
            else => error.UnknownCSR,
        };
    }

    pub fn readWrite(self: Csrs, addr: u12, val: u32) !u32 {
        const ptr = try self.getPtr(addr);
        const oldValue = ptr.*;
        ptr.* = val;
        return oldValue;
    }

    pub fn readSet(self: Csrs, addr: u12, val: u32) !u32 {
        const ptr = try self.getPtr(addr);
        const oldValue = ptr.*;
        ptr.* |= val;
        return oldValue;
    }

    pub fn readClear(self: Csrs, addr: u12, val: u32) !u32 {
        const ptr = try self.getPtr(addr);
        const oldValue = ptr.*;
        ptr.* &= ~val;
        return oldValue;
    }
};
