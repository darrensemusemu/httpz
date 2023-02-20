const std = @import("std");
const http = std.http;
const meta = std.meta;
const mem = std.mem;
const net = std.net;
const testing = std.testing;

pub const HttpRequest = struct {
    allocator: mem.Allocator,
    conn: *net.StreamServer.Connection,
    method: http.Method,
    url: []const u8,
    version: http.Version,
    headers: HeaderMap,

    const Self = @This();

    pub const HeaderMap = std.StringHashMap([]const u8);

    const max_usize = std.math.maxInt(usize);

    fn parseMethod(allocator: mem.Allocator, reader: anytype) !http.Method {
        var req_method = try reader.readUntilDelimiterAlloc(allocator, ' ', max_usize);
        return meta.stringToEnum(http.Method, req_method) orelse return error.UnknownRequestMethod;
    }

    fn parseUrl(allocator: mem.Allocator, reader: anytype) ![]const u8 {
        return try reader.readUntilDelimiterAlloc(allocator, ' ', max_usize);
    }

    fn parseHttpVersion(allocator: mem.Allocator, reader: anytype) !http.Version {
        var req_version = try reader.readUntilDelimiterAlloc(allocator, '\r', max_usize);
        return meta.stringToEnum(http.Version, req_version) orelse return error.UnknownHttpVersion;
    }

    fn parseEndofLine(allocator: mem.Allocator, reader: anytype) !void {
        _ = try reader.readUntilDelimiterAlloc(allocator, '\n', max_usize);
    }

    pub fn init(allocator: mem.Allocator, conn: *net.StreamServer.Connection) !HttpRequest {
        var reader = conn.stream.reader();

        var method = try parseMethod(allocator, reader);
        var url = try parseUrl(allocator, reader);
        var version = try parseHttpVersion(allocator, reader);
        try parseEndofLine(allocator, reader);

        var headers = try parseHeaders(allocator, reader);

        return HttpRequest{
            .allocator = allocator,
            .conn = conn,
            .method = method,
            .url = url,
            .version = version,
            .headers = headers,
        };
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

            if (line.len == 0) {
                break;
            }

            var split_iter = mem.split(u8, line, ":");
            var key = split_iter.next() orelse return error.HeaderKeyNotFound;
            var value = split_iter.next() orelse return error.HeaderValueNotFound;
            try headers.put(key, mem.trim(u8, value, " "));
        }
        return headers;
    }
};

const TestStringReader = struct {
    content: []const u8,
    pos: u64 = 0,

    const Self = @This();

    fn initFromString(str: []const u8) TestStringReader {
        return Self{ .content = str[0..] };
    }

    fn readFn(self: *Self, buf: []u8) ReadError!usize {
        if (self.content.len == 0 or self.pos >= self.content.len - 1) return 0;

        var remaining_len: usize = self.content.len - (self.pos + 1);
        if (remaining_len == 0) return 0;

        var n_read = if (buf.len <= self.content.len) buf.len else remaining_len;
        mem.copy(u8, buf, self.content[self.pos .. self.pos + n_read]);
        self.pos += n_read;
        return n_read;
    }

    pub const ReadError = error{ReadError};

    pub const Reader = std.io.Reader(*Self, ReadError, readFn);

    pub fn reader(self: *Self) Reader {
        return Reader{ .context = self };
    }
};

test "HttpRequest parse request line" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    var t = TestStringReader.initFromString("GET /images/logo.png HTTP/1.1\r\n");
    const method = try HttpRequest.parseMethod(allocator, t.reader());
    try testing.expectEqual(method, http.Method.GET);

    const url = try HttpRequest.parseUrl(allocator, t.reader());
    try testing.expectEqualStrings(url, "/images/logo.png");

    const version = try HttpRequest.parseHttpVersion(allocator, t.reader());
    try testing.expectEqual(version, http.Version.@"HTTP/1.1");
}

test "HttpRequest.parseHeaders()" {
    var area = std.heap.ArenaAllocator.init(testing.allocator);
    defer area.deinit();
    var allocator = area.allocator();

    var t = TestStringReader.initFromString("");
    var headers = try HttpRequest.parseHeaders(allocator, t.reader());
    try testing.expectEqual(headers.count(), 0);

    t = TestStringReader.initFromString("Host: www.example.com\r\nContent-type: application/json\r\n\r\n");
    headers = try HttpRequest.parseHeaders(allocator, t.reader());
    try testing.expectEqual(headers.count(), 2);
    try testing.expectEqualStrings(headers.get("Host") orelse "", "www.example.com");
    try testing.expectEqualStrings(headers.get("Content-type") orelse "", "application/json");
}
