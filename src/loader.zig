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
    state.mem = try assembler.assemble_file(name, state.allocator);
}

const Error = error{InvalidELF};
pub fn load_elf(state: *vm.State, name: []const u8) !void {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();
    const f = try std.fs.cwd().openFile(name, .{});
    defer f.close();
    const header = try std.elf.Header.read(file);
    var it = header.program_header_iterator(file);
    while (try it.next()) |h| {
        try f.seekTo(h.p_offset);
        if (h.p_type == std.elf.PT_LOAD) {
            var i: usize = 0;
            while (i < h.p_filesz) {
                const buf = try state.allocator.create([0x1000]u8);
                try state.mem.mem.put(@intCast((h.p_vaddr + i) >> 12), buf);
                try state.mem.perms.put(@intCast((h.p_vaddr + i) >> 12), @truncate(h.p_flags));
                i += try f.read(buf);
            }
        }
    }
    state.pc = @truncate(header.entry);
}
