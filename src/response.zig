const std = @import("std");
const http = std.http;
const mem = std.mem;

pub const HttpResponse = struct {
    status: http.Status = .ok,
    body: Body,
    method: http.Method = .GET,

    const Self = @This();

    pub const Body = std.ArrayList(u8);
    pub const HeaderMap = std.StringHashMap([]const u8);

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .body = Body.init(allocator),
        };
    }
};
