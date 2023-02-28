# httpz

A simple Go like http server implementation. Note: WIP.

## Example

### Simple Server

```zig
// ....
const addr = try net.Address.parseIp("0.0.0.0", 8080);
var http_server = httpz.Server.init(allocator, addr);
defer http_server.close();

const t = struct {
    fn handleHome(res: *httpz.Response, _: *httpz.Request) anyerror!void {
        res.status = .ok;
        try res.setHeader("Content-Type", "text/plain");
        try res.body.appendSlice("Hello World");
    }
};

var mux = httpz.Mux.init(allocator);
try mux.handle("/", t.handleHome);

std.log.info("running on port: 8080", .{});
try http_server.listenAndServe(&mux);
```
