const std = @import("std");
const mem = std.mem;
const net = std.net;
const stderr = std.io.getStdErr();

const httpz = @import("httpz");

pub fn main() !void {
    run() catch |err| {
        try stderr.writer().print("Failed with err: {any}\n", .{err});
        std.process.exit(1);
    };
}

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const addr = try net.Address.parseIp("0.0.0.0", 8080);
    var http_server = httpz.Server.init(allocator, addr);
    defer http_server.close();

    const t = struct {
        fn handleHtml(res: *httpz.Response, _: *httpz.Request) !void {
            res.status = .ok;
            try res.setHeader("Content-Type", "text/html");
            try res.body.appendSlice(
                \\<!DOCTYPE html>
                \\<html>
                \\  <head>
                \\      <title>Homt</Title>
                \\  </head>
                \\  <body>
                \\      <h3 style="text-align: center">Hello World!</h3>
                \\  </body>
                \\</html>
            );
        }
    };

    var mux = httpz.Mux.init(allocator);
    try mux.handle("/home", t.handleHtml);

    std.log.info("running on port: 8080", .{});
    try http_server.listenAndServe(&mux);
}
