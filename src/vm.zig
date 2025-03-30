const std = @import("std");

const inst = @import("inst.zig");

pub const Error = error{ SegFault, InvalidInst };
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
    pub fn init(allocator: std.mem.Allocator) !State {
        const mem = std.AutoHashMap(u20, *[0x1000]u8).init(allocator);
        return State{ .mem = mem, .allocator = allocator };
    }
    fn read_byte(self: *State, addr: u32) Error!u8 {
        const page = self.mem.get(@intCast(addr >> 12)) orelse return Error.SegFault;
        return page[addr % (1 << 12)];
    }
    fn read_word(self: *State, addr: u32) Error!u32 {
        if (addr % 4 != 0) return Error.SegFault;
        const page = self.mem.get(@intCast(addr >> 12)) orelse return Error.SegFault;
        const a = addr % (1 << 12);
        return @as(*u32, @ptrCast(@alignCast(&page[a]))).*;
    }
    fn write_byte(self: *State, addr: u32, byte: u8) Error!void {
        const page = self.mem.get(@intCast(addr >> 12)) orelse return Error.SegFault;
        page[addr % (1 << 12)] = byte;
    }
    fn write_word(self: *State, addr: u32, word: u32) Error!void {
        if (addr % 4 != 0) return Error.SegFault;
        const page = self.mem.get(@intCast(addr >> 12)) orelse return Error.SegFault;
        const a = addr % (1 << 12);
        page[a] = @truncate(word >> 24);
        page[a + 1] = @truncate(word >> 16);
        page[a + 2] = @truncate(word >> 8);
        page[a + 3] = @truncate(word);
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
        }
        self.pc +%= 4;
    }
};
