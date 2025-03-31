const std = @import("std");

const Inst = @import("inst.zig").Inst;
const loader = @import("loader.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    var s = try vm.State.init(std.heap.page_allocator);
    try loader.load(&s, "a");
    while (true)
        try s.step();
}
