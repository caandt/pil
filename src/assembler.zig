const std = @import("std");
const Inst = @import("inst.zig").Inst;
const Error = error{ TooManyOperands, TooFewOperands, InvalidRegister, InvalidInstruction };

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

fn assemble_line(line: []const u8) !?Inst {
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
    inline for (std.meta.fields(Inst)) |inst| {
        if (std.ascii.eqlIgnoreCase(toks[0], inst.name)) {
            var val: inst.type = undefined;
            var i: u8 = 1;
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
                } else {
                    @field(val, f.name) = try std.fmt.parseInt(f.type, toks[i], 0);
                }
                i += 1;
            }
            if (i != len) return Error.TooManyOperands;
            return @unionInit(Inst, inst.name, val);
        }
    }
    return Error.InvalidInstruction;
}
pub fn assemble(src: []const u8, allocator: std.mem.Allocator) ![]Inst {
    var it = std.mem.splitScalar(u8, src, '\n');
    var insts = std.ArrayList(Inst).init(allocator);
    errdefer insts.deinit();
    while (it.next()) |l| {
        const next = try assemble_line(l);
        if (next) |inst| try insts.append(inst);
    }
    return insts.toOwnedSlice();
}
pub fn assemble_file(name: []const u8, allocator: std.mem.Allocator) ![]Inst {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();
    const src = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(src);

    return assemble(src, allocator);
}
