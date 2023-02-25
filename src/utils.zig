const std = @import("std");
const mem = std.mem;

pub const TestStringReader = struct {
    content: []const u8,
    pos: u64 = 0,

    const Self = @This();

    pub fn initFromString(str: []const u8) TestStringReader {
        return Self{ .content = str[0..] };
    }

    pub fn readFn(self: *Self, buf: []u8) ReadError!usize {
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
