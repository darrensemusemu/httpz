const std = @import("std");
const http = std.http;
const meta = std.meta;
const mem = std.mem;
const net = std.net;
const io = std.io;
const testing = std.testing;

const utils = @import("utils.zig");

pub const Request = struct {
    allocator: mem.Allocator,
    method: http.Method,
    url: []const u8,
    version: http.Version,
    headers: HeaderMap,
    body: ?Body,

    const Self = @This();

    pub const Body = std.ArrayList(u8);

    pub const HeaderMap = std.StringHashMap([]const u8);

    const max_usize = std.math.maxInt(usize);

    pub fn init(allocator: mem.Allocator, reader: net.Stream.Reader) !Self {
        var method = try parseMethod(allocator, reader);
        var url = try parseUrl(allocator, reader);
        var version = try parseHttpVersion(allocator, reader);
        var headers = try parseHeaders(allocator, reader);
        var body: ?Body = null;

        if (method.requestHasBody()) {
            body = try parseBody(allocator, reader, &headers);
        }

        return Self{
            .allocator = allocator,
            .method = method,
            .url = url,
            .version = version,
            .headers = headers,
            .body = body,
        };
    }

    fn parseBody(allocator: mem.Allocator, reader: anytype, headers: *HeaderMap) !?Body {
        var content_length_str = headers.get("Content-Length") orelse return null;
        var len = std.fmt.parseUnsigned(u32, content_length_str, 0) catch return error.BadRequest;
        var body = try Body.initCapacity(allocator, len);
        try body.appendNTimes(0, len); // fill body
        _ = try reader.readNoEof(body.items);
        return body;
    }

    fn parseMethod(allocator: mem.Allocator, reader: anytype) !http.Method {
        var req_method = try reader.readUntilDelimiterAlloc(allocator, ' ', max_usize);
        return meta.stringToEnum(http.Method, req_method) orelse return error.UnknownRequestMethod;
    }

    fn parseUrl(allocator: mem.Allocator, reader: anytype) ![]const u8 {
        return try reader.readUntilDelimiterAlloc(allocator, ' ', max_usize);
    }

    fn parseHttpVersion(allocator: mem.Allocator, reader: anytype) !http.Version {
        var req_version = try reader.readUntilDelimiterAlloc(allocator, '\r', max_usize);
        const version = meta.stringToEnum(http.Version, req_version) orelse return error.UnknownHttpVersion;
        reader.skipBytes(1, .{}) catch |err| {
            switch (err) {
                error.EndOfStream => {},
                else => return err,
            }
        };
        return version;
    }

    fn parseHeaders(allocator: mem.Allocator, reader: anytype) !HeaderMap {
        var headers = HeaderMap.init(allocator);

        while (true) {
            var line = reader.readUntilDelimiterAlloc(allocator, '\r', max_usize) catch |err| {
                return switch (err) {
                    error.EndOfStream => headers,
                    else => return err,
                };
            };

            reader.skipBytes(1, .{}) catch |err| {
                return switch (err) {
                    error.EndOfStream => headers,
                    else => return err,
                };
            };

            if (line.len == 0) return headers;
            var split_iter = mem.split(u8, line, ":");
            var key = split_iter.next() orelse return error.HeaderKeyNotFound; // TODO: handle case insetivity
            var value = split_iter.next() orelse return error.HeaderValueNotFound;
            try headers.put(key, mem.trim(u8, value, " "));
        }

        return headers;
    }
};

test "Request parse request line" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    var t = utils.TestStringReader.initFromString("GET /images/logo.png HTTP/1.1\r\n");
    const method = try Request.parseMethod(allocator, t.reader());
    try testing.expectEqual(method, http.Method.GET);

    const url = try Request.parseUrl(allocator, t.reader());
    try testing.expectEqualStrings(url, "/images/logo.png");

    const version = try Request.parseHttpVersion(allocator, t.reader());
    try testing.expectEqual(version, http.Version.@"HTTP/1.1");
}

test "Request.parseHeaders()" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    var t = utils.TestStringReader.initFromString("");
    var headers = try Request.parseHeaders(allocator, t.reader());
    try testing.expectEqual(headers.count(), 0);

    t = utils.TestStringReader.initFromString("Host: www.example.com\r\nContent-type: application/json\r\n\r\n");
    headers = try Request.parseHeaders(allocator, t.reader());
    try testing.expectEqual(headers.count(), 2);
    try testing.expectEqualStrings(headers.get("Host") orelse "", "www.example.com");
    try testing.expectEqualStrings(headers.get("Content-type") orelse "", "application/json");
}
