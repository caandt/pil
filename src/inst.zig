const std = @import("std");

pub const Inst = union(enum) {
    Add: packed struct { op: u7, rd: u3, rs1: u3, rs2: u3, _pad: u16 },
    Sub: packed struct { op: u7, rd: u3, rs1: u3, rs2: u3, _pad: u16 },
    Addi: packed struct { op: u7, rd: u3, rs1: u3, i: u19 },
    Subi: packed struct { op: u7, rd: u3, rs1: u3, i: u19 },
    Li: packed struct { op: u1, rd: u3, i: u28 },

    And: packed struct { op: u7, rd: u3, rs1: u3, rs2: u3, _pad: u16 },
    Or: packed struct { op: u7, rd: u3, rs1: u3, rs2: u3, _pad: u16 },
    Xor: packed struct { op: u7, rd: u3, rs1: u3, rs2: u3, _pad: u16 },
    Not: packed struct { op: u7, rd: u3, rs1: u3, _pad: u19 },

    Beq: packed struct { op: u7, rs1: u3, rs2: u3, si: i19 },
    Blt: packed struct { op: u7, rs1: u3, rs2: u3, si: i19 },
    Bne: packed struct { op: u7, rs1: u3, rs2: u3, si: i19 },
    Bl: packed struct { op: u7, si: i25 },
    Jl: packed struct { op: u7, i: u25 },
    Jmp: packed struct { op: u7, i: u25 },
    Jmpr: packed struct { op: u7, rs1: u3, _pad: u22 },

    Ld: packed struct { op: u7, rd: u3, rs: u3, i: u19 },
    St: packed struct { op: u7, rs: u3, rd: u3, i: u19 },
};

pub fn decode(n: u32) ?Inst {
    if (n & 1 == 1) return .{ .Li = @bitCast(n) };
    const opcode = .{ null, .Add, .Sub, .Addi, .Subi, .And, .Or, .Xor, .Not, .Beq, .Blt, .Bne, .Bl, .Jl, .Jmp, .Jmpr, .Ld, .St };
    return switch ((n >> 1) % (1 << 5)) {
        inline 1...opcode.len - 1 => |op| @unionInit(Inst, @tagName(opcode[op]), @bitCast(n)),
        else => null,
    };
}
pub fn encode(i: Inst) u32 {
    return switch (i) {
        inline else => |n| @bitCast(n),
    };
}
