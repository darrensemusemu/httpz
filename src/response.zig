const std = @import("std");
const http = std.http;
const mem = std.mem;
const testing = std.testing;

pub const HttpResponse = struct {
    status: http.Status = .ok,
    body: Body,
    headers: HeaderMap,

    const Self = @This();

    pub const Body = std.ArrayList(u8);

    pub const HeaderMap = std.StringHashMap([]const u8);

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .body = Body.init(allocator),
            .headers = HeaderMap.init(allocator),
        };
    }

    pub fn setHeader(self: *Self, key: []const u8, value: []const u8) !void {
        try self.headers.put(key, value);
    }

    pub fn contentLength(self: *Self) usize {
        return self.body.items.len;
    }

    pub fn removeHeader(self: *Self, key: []const u8) bool {
        return self.headers.remove(key);
    }
};

test "http response" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    var res = HttpResponse.init(allocator);

    try res.setHeader("Content-Type", "text/html");
    try res.setHeader("Authorization", "Basic 0123456789");
    try testing.expectEqual(res.headers.count(), 2);

    try testing.expect(res.removeHeader("Authorization"));
    try testing.expectEqual(res.headers.count(), 1);
}
