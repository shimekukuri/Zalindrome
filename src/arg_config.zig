const std = @import("std");
const ArgIterator = std.process.ArgIterator;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const ArgConfig = struct {
    allocator: *const Allocator,
    arg_byte_count: ?u64 = 1024,
    arg_path: ?[]const u8,
    arg_seed: ?u64 = 0,

    pub fn init(args: *ArgIterator, allocator: *const Allocator) !ArgConfig {
        var config: ArgConfig = ArgConfig.default(allocator);
        config.arg_path = args.next();

        var value = args.next();
        flagSw: switch (switchingFn(value)) {
            .n => {
                value = args.next();
                config.arg_byte_count = try std.fmt.parseInt(u64, value.?, 10);
                value = args.next();
                continue :flagSw switchingFn(value);
            },
            .s => {
                value = args.next();
                config.arg_seed = try std.fmt.parseInt(u64, value.?, 10);
                value = args.next();
                continue :flagSw switchingFn(value);
            },
            .EXITSWITCH => {
                break :flagSw;
            },
        }
        return config;
    }

    pub fn default(allocator: *const Allocator) ArgConfig {
        return ArgConfig{
            .allocator = allocator,
            .arg_byte_count = 1024,
            .arg_path = "~/",
            .arg_seed = 0,
        };
    }

    fn switchingFn(value: ?[:0]const u8) ArgParams {
        if (value) |v| {
            return std.meta.stringToEnum(ArgParams, std.mem.span(v.ptr)[1..]) orelse ArgParams.EXITSWITCH;
        } else {
            return ArgParams.EXITSWITCH;
        }
    }
};

pub const ArgParams = enum { n, s, EXITSWITCH };
