const std = @import("std");

const inst = @import("inst.zig").Inst;

pub const Error = error{ SegFault, InvalidInst, Exit, OutOfMemory, UnknownSyscall };
pub const State = struct {
    r0: u32 = 0,
    r1: u32 = 0,
    r2: u32 = 0,
    r3: u32 = 0,
    r4: u32 = 0,
    r5: u32 = 0,
    sp: u32 = 0,
    lr: u32 = 0,
    pc: u32 = 0,
    mem: std.AutoHashMap(u20, *[0x1000]u8),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Error!State {
        const mem = std.AutoHashMap(u20, *[0x1000]u8).init(allocator);
        return State{ .mem = mem, .allocator = allocator };
    }
    fn get_page(self: *State, n: u20) Error!*[0x1000]u8 {
        return self.mem.get(n) orelse {
            const new = try self.allocator.create([0x1000]u8);
            @memset(new, 0);
            try self.mem.put(n, new);
            return new;
        };
    }
    pub fn read_byte(self: *State, addr: u32) Error!u8 {
        const page = try self.get_page(@intCast(addr >> 12));
        return page[addr % (1 << 12)];
    }
    pub fn read_word(self: *State, addr: u32) Error!u32 {
        const b0: u32 = try self.read_byte(addr);
        const b1: u32 = try self.read_byte(addr + 1);
        const b2: u32 = try self.read_byte(addr + 2);
        const b3: u32 = try self.read_byte(addr + 3);
        return (b3 << 24) | (b2 << 16) | (b1 << 8) | (b0 << 0);
    }
    pub fn write_byte(self: *State, addr: u32, byte: u8) Error!void {
        const page = try self.get_page(@intCast(addr >> 12));
        page[addr % (1 << 12)] = byte;
    }
    pub fn write_word(self: *State, addr: u32, word: u32) Error!void {
        try self.write_byte(addr + 0, @truncate(word >> 0));
        try self.write_byte(addr + 1, @truncate(word >> 8));
        try self.write_byte(addr + 2, @truncate(word >> 16));
        try self.write_byte(addr + 3, @truncate(word >> 24));
    }
    fn get_reg(self: *State, reg: u3) u32 {
        return switch (reg) {
            0 => self.r0,
            1 => self.r1,
            2 => self.r2,
            3 => self.r3,
            4 => self.r4,
            5 => self.r5,
            6 => self.sp,
            7 => self.lr,
        };
    }
    fn set_reg(self: *State, reg: u3, val: u32) void {
        switch (reg) {
            0 => self.r0 = val,
            1 => self.r1 = val,
            2 => self.r2 = val,
            3 => self.r3 = val,
            4 => self.r4 = val,
            5 => self.r5 = val,
            6 => self.sp = val,
            7 => self.lr = val,
        }
    }
    pub fn step(self: *State) Error!void {
        const inst_bytes = try self.read_word(self.pc);
        const curr_inst = inst.decode(inst_bytes) orelse return Error.InvalidInst;
        std.debug.print("{}\n", .{curr_inst});
        switch (curr_inst) {
            .Add => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                self.set_reg(i.rd, a +% b);
            },
            .Sub => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                self.set_reg(i.rd, a -% b);
            },
            .Addi => |i| {
                const a = self.get_reg(i.rs1);
                const b = i.i;
                self.set_reg(i.rd, a +% b);
            },
            .Subi => |i| {
                const a = self.get_reg(i.rs1);
                const b = i.i;
                self.set_reg(i.rd, a -% b);
            },
            .Li => |i| {
                self.set_reg(i.rd, i.i);
            },
            .And => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                self.set_reg(i.rd, a & b);
            },
            .Or => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                self.set_reg(i.rd, a | b);
            },
            .Xor => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                self.set_reg(i.rd, a ^ b);
            },
            .Not => |i| {
                const a = self.get_reg(i.rs1);
                self.set_reg(i.rd, ~a);
            },
            .Beq => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                if (a == b) {
                    self.pc +%= @as(u32, @bitCast(@as(i32, i.si)));
                    return;
                }
            },
            .Blt => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                if (a < b) {
                    self.pc +%= @as(u32, @bitCast(@as(i32, i.si)));
                    return;
                }
            },
            .Bne => |i| {
                const a = self.get_reg(i.rs1);
                const b = self.get_reg(i.rs2);
                if (a != b) {
                    self.pc +%= @as(u32, @bitCast(@as(i32, i.si)));
                    return;
                }
            },
            .Bl => |i| {
                self.lr = self.pc + 4;
                self.pc +%= @as(u32, @bitCast(@as(i32, i.si)));
                return;
            },
            .Jl => |i| {
                self.lr = self.pc + 4;
                self.pc = i.i;
                return;
            },
            .Jmp => |i| {
                self.pc = i.i;
                return;
            },
            .Jmpr => |i| {
                self.pc = self.get_reg(i.rs1);
                return;
            },
            .Ld => |i| {
                const a = try self.read_word(self.get_reg(i.rs) + i.i);
                self.set_reg(i.rd, a);
            },
            .St => |i| {
                const a = self.get_reg(i.rs);
                try self.write_word(self.get_reg(i.rd) + i.i, a);
            },
            .Sys => |i| {
                switch (i.i) {
                    0 => return Error.Exit,
                    1 => {
                        inline for (std.meta.fields(State)) |f| {
                            if (f.type != u32) continue;
                            std.debug.print("{s}: {}\n", .{ f.name, @field(self, f.name) });
                        }
                    },
                    2 => {
                        var j = self.r0;
                        while (true) {
                            const b = try self.read_byte(j);
                            if (b == 0) break;
                            std.debug.print("{c}", .{b});
                            j += 1;
                        }
                    },
                    3 => {
                        const buf = try self.allocator.alloc(u8, self.r1);
                        defer self.allocator.free(buf);
                        const j = std.io.getStdIn().readAll(buf) catch 0;
                        for (0..j) |k| {
                            try self.write_byte(@truncate(self.r0 + k), buf[k]);
                        }
                    },
                    else => return Error.UnknownSyscall,
                }
            },
        }
        self.pc +%= 4;
    }
};
