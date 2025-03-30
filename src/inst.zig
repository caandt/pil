const std = @import("std");

pub const Inst = union(enum) {
    Add: packed struct { op: u7 = 1 << 1, rd: u3, rs1: u3, rs2: u3, _pad: u16 = 0 },
    Sub: packed struct { op: u7 = 2 << 1, rd: u3, rs1: u3, rs2: u3, _pad: u16 = 0 },
    Addi: packed struct { op: u7 = 3 << 1, rd: u3, rs1: u3, i: u19 = 0 },
    Subi: packed struct { op: u7 = 4 << 1, rd: u3, rs1: u3, i: u19 = 0 },
    Li: packed struct { op: u1 = 1, rd: u3, i: u28 },

    And: packed struct { op: u7 = 5 << 1, rd: u3, rs1: u3, rs2: u3, _pad: u16 = 0 },
    Or: packed struct { op: u7 = 6 << 1, rd: u3, rs1: u3, rs2: u3, _pad: u16 = 0 },
    Xor: packed struct { op: u7 = 7 << 1, rd: u3, rs1: u3, rs2: u3, _pad: u16 = 0 },
    Not: packed struct { op: u7 = 8 << 1, rd: u3, rs1: u3, _pad: u19 = 0 },

    Beq: packed struct { op: u7 = 9 << 1, rs1: u3, rs2: u3, si: i19 },
    Blt: packed struct { op: u7 = 10 << 1, rs1: u3, rs2: u3, si: i19 },
    Bne: packed struct { op: u7 = 11 << 1, rs1: u3, rs2: u3, si: i19 },
    Bl: packed struct { op: u7 = 12 << 1, si: i25 },
    Jl: packed struct { op: u7 = 13 << 1, i: u25 },
    Jmp: packed struct { op: u7 = 14 << 1, i: u25 },
    Jmpr: packed struct { op: u7 = 15 << 1, rs1: u3, _pad: u22 = 0 },

    Ld: packed struct { op: u7 = 16 << 1, rd: u3, rs: u3, i: u19 },
    St: packed struct { op: u7 = 17 << 1, rs: u3, rd: u3, i: u19 },
};

pub fn decode(n: u32) ?Inst {
    if (n & 1 == 1) return .{ .Li = @bitCast(n) };
    return switch ((n >> 1) % (1 << 5)) {
        inline 1...std.meta.fields(Inst).len - 1 => |op| {
            inline for (std.meta.fields(Inst)) |f| {
                if (@typeInfo(f.type).@"struct".fields[0].defaultValue().? == op << 1) {
                    return @unionInit(Inst, f.name, @bitCast(n));
                }
            }
        },
        else => null,
    };
}
pub fn encode(i: Inst) u32 {
    return switch (i) {
        inline else => |n| @bitCast(n),
    };
}
