const std = @import("std");
const mem = std.mem;
const net = std.net;
const stderr = std.io.getStdErr();

const request = @import("request.zig");
const response = @import("response.zig");
const server = @import("server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    run(&args) catch |err| {
        try stderr.writer().print("Failed with err: {any}\n", .{err});
        std.process.exit(1);
    };
}

fn run(args: *std.process.ArgIterator) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    const config = try Config.init(args);
    const addr = try net.Address.parseIp(config.addr, config.port);

    var http_server = server.HttpServer.init(allocator, addr);
    defer http_server.close();

    try http_server.listenAndServe();
}

const Config = struct {
    addr: []const u8 = "0.0.0.0",
    port: u16 = 8080,
    file_path: []const u8,

    const Self = @This();

    fn init(args: *std.process.ArgIterator) !Config {
        //const exe_name = args.next().?;
        const file_path = args.next() orelse {
            // try usage(exe_name); TODO : require config filename
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

test "_" {
    _ = request;
    _ = response;
    _ = server;
}
