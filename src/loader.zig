const std = @import("std");

const vm = @import("vm.zig");
const assembler = @import("assembler.zig");

pub fn load(state: *vm.State, name: []const u8) !void {
    const f = try std.fs.cwd().openFile(name, .{});
    while (true) {
        const buf = try state.allocator.create([0x1000]u8);
        @memset(buf, 0);
        const a: u20 = @truncate(try f.getPos() >> 12);
        const n = try f.read(buf);
        try state.mem.put(a, buf);
        if (n < 0x1000) break;
    }
}

pub fn load_asm(state: *vm.State, name: []const u8) !void {
    const insts = try assembler.assemble_file(name, state.allocator);
    defer state.allocator.free(insts);
    var i: u32 = 0;
    while (i < insts.len) {
        const buf = try state.allocator.create([0x1000]u8);
        try state.mem.put(@truncate(i * 4 >> 12), buf);
        try state.perms.put(@truncate(i * 4 >> 12), 0b111);
        for (i..i + 0x1000 / 4) |j| {
            if (j >= insts.len) {
                try state.write_word(@intCast(j * 4), 0);
            } else {
                try state.write_word(@intCast(j * 4), insts[j].encode());
            }
        }
        i += 0x1000 / 4;
    }
}
