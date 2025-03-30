const std = @import("std");

const vm = @import("vm.zig");

pub fn load(state: *vm.State, file: []const u8) !void {
    const f = try std.fs.cwd().openFile(file, .{});
    while (true) {
        const buf = try state.allocator.create([0x1000]u8);
        @memset(buf, 0);
        const a: u20 = @truncate(try f.getPos() >> 12);
        const n = try f.read(buf);
        try state.mem.put(a, buf);
        if (n < 0x1000) break;
    }
}
