const std = @import("std");
const stderr = std.io.getStdErr();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();
    run(allocator) catch |err| {
        try stderr.writer().print("Failed with err: {any}\n", .{err});
        std.process.exit(1);
    };
}

fn run(allocator: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const config = try Config.init(&args);
    const addr = try std.net.Address.parseIp(config.addr, config.port);
    var server = std.net.StreamServer.init(.{ .reuse_address = true });
    defer server.close();

    try server.listen(addr);

    while (true) {
        var conn = try server.accept();
        defer conn.stream.close();

        _ = try conn.stream.write("Hello darkneses my old friend:");
        std.log.info("recieved conn ", .{});
    }
}

const Config = struct {
    addr: []const u8 = "0.0.0.0",
    port: u16 = 8080,
    file_path: []const u8,

    const Self = @This();

    fn init(args: *std.process.ArgIterator) !Config {
        const exe_name = args.next().?;
        const file_path = args.next() orelse {
            try usage(exe_name);
            return error.ConfigFileNotFound;
        };
        return Config{ .file_path = file_path };
    }

    fn usage(exe_name: []const u8) !void {
        try stderr.writer().print(
            \\ Usage:
            \\  {s} <config_file>
        , .{exe_name});
    }
};
