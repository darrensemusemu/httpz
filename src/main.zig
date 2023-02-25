const std = @import("std");
const mem = std.mem;
const net = std.net;
const stderr = std.io.getStdErr();

const http_request = @import("http_request.zig");
const HttpRequest = http_request.HttpRequest;

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
    const config = try Config.init(args);
    const addr = try net.Address.parseIp(config.addr, config.port);
    var server = net.StreamServer.init(.{ .reuse_address = true });
    defer server.close();

    try server.listen(addr);

    while (true) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var allocator = arena.allocator();

        var conn = server.accept() catch |err| {
            std.log.err("Failed to accect connection: {any}", .{err});
            continue;
        };

        handleRequest(allocator, &conn) catch |err| {
            std.log.err("Failed to handle request {any}", .{err});
            continue;
        };
    }
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

fn handleRequest(allocator: mem.Allocator, conn: *net.StreamServer.Connection) !void {
    defer conn.stream.close();

    var req = try HttpRequest.init(allocator, conn);
    if (req.body) |b| {
        std.debug.print("receviend bpdy: '{s}'\n", .{b.items});
    }
}

test "_" {
    _ = http_request;
}
