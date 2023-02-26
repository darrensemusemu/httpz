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

    const config = Config.init(args);
    const addr = try net.Address.parseIp(config.addr, config.port);

    var http_server = server.HttpServer.init(allocator, addr);
    defer http_server.close();

    const t = struct {
        fn handleHome(res: *response.HttpResponse, _: *request.HttpRequest) !void {
            res.status = .ok;
            try res.setHeader("Content-Type", "text/plain");
            try res.body.appendSlice("Hello World");
        }

        fn handleJson(res: *response.HttpResponse, _: *request.HttpRequest) !void {
            res.status = .ok;
            try res.setHeader("Content-Type", "application/json");
            try res.body.appendSlice(
                \\{"status": "ok"}
            );
        }

        fn handle404(res: *response.HttpResponse, _: *request.HttpRequest) !void {
            res.status = .not_found;
            try res.setHeader("Content-Type", "text/html");
            try res.body.appendSlice(
                \\<html>
                \\  <head>
                \\      <title>404</Title>
                \\  </head>
                \\  <body>
                \\      <h3 style="text-align: center">404</h3>
                \\  </body>
                \\</html>
            );
        }
    };

    var mux = server.Mux.init(allocator);
    try mux.handle("/", t.handleHome);
    try mux.handle("/status.json", t.handleJson);
    try mux.handle("/404", t.handle404);
    try http_server.listenAndServe(&mux);
}

const Config = struct {
    addr: []const u8 = "0.0.0.0",
    port: u16 = 8080,

    const Self = @This();

    fn init(_: *std.process.ArgIterator) Self {
        return Self{};
    }
};

test "_" {
    _ = request;
    _ = response;
    _ = server;
}
