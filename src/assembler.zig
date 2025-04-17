const std = @import("std");
const Inst = @import("inst.zig").Inst;
const Mem = @import("vm.zig").Mem;
const Error = error{ TooManyOperands, TooFewOperands, InvalidRegister, InvalidInstruction, UnknownDirective, MissingLabel };

const regs = std.StaticStringMapWithEql(u3, std.ascii.eqlIgnoreCase).initComptime(.{
    .{ "r0", 0 },
    .{ "r1", 1 },
    .{ "r2", 2 },
    .{ "r3", 3 },
    .{ "r4", 4 },
    .{ "r5", 5 },
    .{ "r6", 6 },
    .{ "r7", 7 },
    .{ "sp", 6 },
    .{ "lr", 7 },
});
const Line = union(enum) {
    inst: Inst,
    labeled: struct { inst: Inst, label: []const u8 },
    label: []const u8,
    directive: struct { name: []const u8, arg: []const u8 },
};
fn assemble_line(line: []const u8) !?Line {
    var trim = std.mem.trim(u8, line, " \t\r");
    if (std.mem.indexOfScalar(u8, trim, ';')) |i| {
        trim = trim[0..i];
    }
    var it = std.mem.splitScalar(u8, trim, ' ');
    var toks = [4][]const u8{ "", "", "", "" };
    var len: u8 = 0;
    while (it.next()) |tok| {
        if (tok.len > 0) {
            if (len >= toks.len) {
                return Error.TooManyOperands;
            }
            toks[len] = tok;
            len += 1;
        }
    }
    if (len == 0) return null;
    if (toks[0][0] == '.') {
        if (len > 1) {
            return .{ .directive = .{ .name = toks[0], .arg = toks[1] } };
        }
        return .{ .directive = .{ .name = toks[0], .arg = "" } };
    }
    if (len == 1 and toks[0][toks[0].len - 1] == ':') {
        return .{ .label = toks[0][0 .. toks[0].len - 1] };
    }
    inline for (std.meta.fields(Inst)) |inst| {
        if (std.ascii.eqlIgnoreCase(toks[0], inst.name)) {
            var val: inst.type = undefined;
            var i: u8 = 1;
            var label: ?[]const u8 = null;
            inline for (std.meta.fields(inst.type)) |f| {
                if (f.defaultValue()) |d| {
                    @field(val, f.name) = d;
                    continue;
                }
                if (i >= len) {
                    return Error.TooFewOperands;
                }
                if (f.type == u3) {
                    @field(val, f.name) = regs.get(toks[i]) orelse return Error.InvalidRegister;
                } else if (toks[i][0] == '$') {
                    label = toks[i][1..];
                } else {
                    @field(val, f.name) = try std.fmt.parseInt(f.type, toks[i], 0);
                }
                i += 1;
            }
            if (i != len) return Error.TooManyOperands;
            if (label) |l| {
                return .{ .labeled = .{ .inst = @unionInit(Inst, inst.name, val), .label = l } };
            }
            return .{ .inst = @unionInit(Inst, inst.name, val) };
        }
    }
    return Error.InvalidInstruction;
}
pub fn assemble(src: []const u8, allocator: std.mem.Allocator) !Mem {
    var it = std.mem.splitScalar(u8, src, '\n');
    var labels = std.StringHashMap(u32).init(allocator);
    defer labels.deinit();
    var mem = Mem.init(allocator);
    mem.write_unchecked = true;
    var queued = std.ArrayList(struct { Inst, []const u8, u32 }).init(allocator);
    defer queued.deinit();
    var a: u32 = 0;
    while (it.next()) |l| {
        const next = try assemble_line(l);
        if (next) |line| {
            switch (line) {
                .inst => |inst| {
                    try mem.write_word(a, inst.encode());
                    a += 4;
                },
                .label => |label| {
                    try labels.put(label, a);
                },
                .directive => |directive| {
                    if (std.mem.eql(u8, directive.name, ".addr")) {
                        a = try std.fmt.parseInt(u32, directive.arg, 0);
                    } else if (std.mem.eql(u8, directive.name, ".perm")) {
                        mem.default_perm = try std.fmt.parseInt(u3, directive.arg, 0);
                    } else if (std.mem.eql(u8, directive.name, ".word")) {
                        try mem.write_word(a, try std.fmt.parseInt(u32, directive.arg, 0));
                        a += 4;
                    } else {
                        return Error.UnknownDirective;
                    }
                },
                .labeled => |labeled| {
                    try queued.append(.{ labeled.inst, labeled.label, a });
                    a += 4;
                },
            }
        }
    }
    for (queued.items) |q| {
        if (labels.get(q.@"1")) |label| {
            switch (q.@"0") {
                inline .Beq, .Bne, .Blt, .Bl => |*b| {
                    @constCast(b).si = @truncate(@as(i64, @intCast(label)) - @as(i64, @intCast(q.@"2")));
                },
                inline .Jmp, .Jl => |*j| {
                    @constCast(j).i = @truncate(label);
                },
                else => return Error.InvalidInstruction,
            }
            try mem.write_word(q.@"2", q.@"0".encode());
        } else {
            return Error.MissingLabel;
        }
    }
    return mem;
}
pub fn assemble_file(name: []const u8, allocator: std.mem.Allocator) !Mem {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();
    const src = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(src);

    return assemble(src, allocator);
}
