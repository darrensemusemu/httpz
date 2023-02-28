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
        fn handleJson(res: *httpz.Response, req: *httpz.Request) !void {
            res.status = .ok;
            switch (req.method) {
                .GET => {
                    try res.setHeader("Content-Type", "application/json");
                    try res.body.appendSlice("{\"status\": \"ok\"}");
                },
                .POST => {
                    //...
                    try res.body.appendSlice("{\"id\": \"99\"}");
                },
                else => res.status = .method_not_allowed,
            }
        }
    };

    var mux = httpz.Mux.init(allocator);
    try mux.handle("/status", t.handleJson);

    std.log.info("running on port: 8080", .{});
    try http_server.listenAndServe(&mux);
}
