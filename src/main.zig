const std = @import("std");

const Inst = @import("inst.zig").Inst;
const loader = @import("loader.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = std.os.argv;

    if (argv.len < 2) {
        std.debug.print("Usage: {s} <.s file>\n", .{argv[0]});
        return;
    }

    var s = try vm.State.init(allocator);
    try loader.load_asm(&s, std.mem.span(argv[1]));
    while (true) {
        s.step() catch |err| {
            if (err == vm.Error.Exit) break;
            return err;
        };
    }
    std.debug.print("exited.\n", .{});
}
