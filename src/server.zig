const std = @import("std");
const http = std.http;
const mem = std.mem;
const net = std.net;

const request = @import("request.zig");
const HttpRequest = request.HttpRequest;
const response = @import("response.zig");
const HttpResponse = response.HttpResponse;

fn defaultHandler(res: *HttpResponse, _: *HttpRequest) !void {
    res.status = .not_found;
    try res.body.appendSlice(
        \\<!DOCTYPE html>
        \\<html>
        \\  <head>
        \\      <title>httpdir</title>
        \\  </head>
        \\  <body>
        \\      <h1>httpdir</h1>
        \\  </body>
        \\</html>
    );
}

pub const HttpServer = struct {
    allocator: mem.Allocator,
    addr: net.Address,
    http_version: http.Version = http.Version.@"HTTP/1.1",

    streamServer: net.StreamServer = net.StreamServer.init(.{ .reuse_address = true }),

    const Self = @This();

    pub const HttpHandler = fn (res: *HttpResponse, req: *HttpRequest) anyerror!void;

    pub fn init(allocator: mem.Allocator, addr: net.Address) Self {
        return Self{
            .allocator = allocator,
            .addr = addr,
            //.handler = defaultHandler,
        };
    }

    pub fn listenAndServe(self: *Self) !void {
        try self.listen();
        try self.serve();
    }

    fn listen(self: *Self) !void {
        try self.streamServer.listen(self.addr);
    }

    fn serve(self: *Self) !void {
        while (true) {
            var conn = self.streamServer.accept() catch |err| {
                std.log.err("Failed to accect connection: {any}", .{err});
                continue;
            };

            self.handleRequest(conn) catch |err| {
                std.log.err("Failed to handle request {any}", .{err}); // FIXME: habdle server error
                continue;
            };
        }
    }

    fn handleRequest(self: *Self, conn: net.StreamServer.Connection) !void {
        defer conn.stream.close();
        var reader = conn.stream.reader();

        var req = try HttpRequest.init(self.allocator, reader);
        var res = HttpResponse.init(self.allocator);
        try defaultHandler(&res, &req);

        var writer = conn.stream.writer();
        var buffered_writer = std.io.bufferedWriter(writer);
        defer buffered_writer.flush() catch |err| {
            std.log.err("Failed to flush buffered writer: {any}", .{err});
        };

        try std.fmt.format(writer, "{s} {d} {s}\r\nContent-Length: {d}", .{
            @tagName(self.http_version),
            @enumToInt(res.status),
            res.status.phrase() orelse "",
            res.body.items.len,
        });

        if (res.body.items.len > 0) {
            _ = try buffered_writer.write("\r\n\r\n");
            _ = try buffered_writer.write(res.body.items);
        }
    }

    pub fn close(self: *Self) void {
        self.streamServer.close();
    }
};
