const std = @import("std");
const http = std.http;
const mem = std.mem;
const net = std.net;
const testing = std.testing;

const request = @import("request.zig");
const HttpRequest = request.HttpRequest;
const response = @import("response.zig");
const HttpResponse = response.HttpResponse;

fn defaultHandler(res: *HttpResponse, _: *HttpRequest) !void {
    res.status = .not_found;
    try res.setHeader("Content-Type", "application/json");
    try res.body.appendSlice(
        \\{
        \\  "status": "404",
        \\  "type": "about:blank",
        \\  "title": "Not Found",
        \\  "detail": "Resource not found"
        \\}
    );
}

pub const HttpHandler = *const fn (res: *HttpResponse, req: *HttpRequest) anyerror!void;

const MuxError = error{
    HandlerExists,
};

pub const Mux = struct {
    handlers: HandlersMap,

    const Self = @This();

    const HandlersMap = std.StringHashMap(HttpHandler);

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .handlers = HandlersMap.init(allocator),
        };
    }

    pub fn handle(self: *Self, pattern: []const u8, handler: HttpHandler) !void {
        if (self.handlers.contains(pattern)) {
            return MuxError.HandlerExists;
        }
        try self.handlers.put(pattern, handler);
    }

    pub fn getHandler(self: *Self, pattern: []const u8) ?HttpHandler {
        // TODO: handle url params
        return self.handlers.get(pattern);
    }
};
pub const HttpServer = struct {
    allocator: mem.Allocator,
    addr: net.Address,
    http_version: http.Version = http.Version.@"HTTP/1.1",
    streamServer: net.StreamServer = net.StreamServer.init(.{ .reuse_address = true }),

    const Self = @This();

    pub fn init(allocator: mem.Allocator, addr: net.Address) Self {
        return Self{
            .allocator = allocator,
            .addr = addr,
        };
    }

    pub fn listenAndServe(self: *Self, mux: ?*Mux) !void {
        try self.listen();
        try self.serve(mux);
    }

    fn listen(self: *Self) !void {
        try self.streamServer.listen(self.addr);
    }

    fn serve(self: *Self, mux: ?*Mux) !void {
        while (true) {
            var conn = self.streamServer.accept() catch |err| {
                std.log.err("Failed to accect connection: {any}", .{err});
                continue;
            };

            self.handleRequest(conn, mux) catch |err| {
                std.log.err("Failed to handle request {any}", .{err}); // FIXME: habdle server error
                continue;
            };
        }
    }

    fn handleRequest(self: *Self, conn: net.StreamServer.Connection, mux: ?*Mux) !void {
        defer conn.stream.close();
        var reader = conn.stream.reader();

        var req = try HttpRequest.init(self.allocator, reader);
        var res = HttpResponse.init(self.allocator);

        if (mux) |m| {
            const handler = m.getHandler(req.url) orelse defaultHandler;
            try handler(&res, &req);
        } else try defaultHandler(&res, &req);

        var buffered_writer = std.io.bufferedWriter(conn.stream.writer());
        defer buffered_writer.flush() catch |err| {
            std.log.err("Failed to flush buffered writer: {any}", .{err});
        };

        var writer = buffered_writer.writer();

        // write response line
        try writer.print("{s} {d} {s}\r\n", .{
            @tagName(self.http_version),
            @enumToInt(res.status),
            res.status.phrase() orelse "",
        });

        // content length
        try writer.print("Content-Length: {d}\r\n", .{res.contentLength()});

        var header_iter = res.headers.iterator();
        while (header_iter.next()) |entry| {
            try writer.print("{s}: {s}\r\n", .{
                entry.key_ptr.*,
                entry.value_ptr.*,
            });
        }

        _ = try writer.write("\r\n");
        if (res.body.items.len > 0) {
            _ = try writer.write(res.body.items);
        }
    }

    pub fn close(self: *Self) void {
        self.streamServer.close();
    }
};

test "mux" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    const t = struct {
        fn handleHome(_: *HttpResponse, _: *HttpRequest) !void {}
    };

    var mux = Mux.init(allocator);
    try mux.handle("/", defaultHandler);
    try mux.handle("/home", t.handleHome);
    var res = mux.handle("/home", t.handleHome);
    try testing.expectError(MuxError.HandlerExists, res);
}
