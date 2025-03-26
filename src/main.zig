const std = @import("std");
const builtin = @import("builtin");
const ArgConfig = @import("arg_config.zig");

pub const chars: []const u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 []{};':\",.`<>/?-_=+!@#$%^&*()";

const native_os = builtin.target.os.tag;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };
    var page_alloc = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    const config = try ArgConfig.ArgConfig.init(&args, &gpa);
    const half = config.arg_byte_count.? >> 1;
    var ptr = try page_alloc.alloc(u8, config.arg_byte_count.?);
    defer page_alloc.free(ptr);

    @memset(ptr[0..config.arg_byte_count.?], 0);

    var file = try std.fs.cwd().createFile("large_output.txt", .{ .truncate = true });
    var buffered_writer = std.io.bufferedWriter(file.writer());
    var writer = buffered_writer.writer();

    var prng = std.Random.DefaultPrng.init(0);
    prng.seed(config.arg_seed.?);
    const rng = prng.random();
    var meep: [1]u8 = undefined;

    for (0..half) |i| {
        meep = .{chars[rng.uintAtMost(u8, 92)]};
        ptr[i] = meep[0];
        _ = try writer.write(&meep);
    }

    if (config.arg_byte_count.? & 1 != 0) {
        meep = .{chars[rng.uintAtMost(u8, 92)]};
        _ = try writer.write(&meep);
    }

    var i = half - 1;

    while (i > 0) : (i -= 1) {
        const tmp: [1]u8 = .{ptr[i]};
        _ = try writer.write(&tmp);
    }

    var last: [1]u8 = .{ptr[0]};
    _ = try writer.write(&last);

    try buffered_writer.flush();
}
