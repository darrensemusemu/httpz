# httpz

A simple Go like http server implementation. Note: WIP.


## Example

### Init Server

```zig
// ....
const addr = try net.Address.parseIp(config.addr, config.port);

var http_server = server.HttpServer.init(allocator, addr);
defer http_server.close();
//...
```


### Create handlers

A simple handler

```zig
const t = struct {
    fn handleHome(res: *response.HttpResponse, _: *request.HttpRequest) !void {
        res.status = .ok;
        try res.setHeader("Content-Type", "text/plain");
        try res.body.appendSlice("Hello World");
    }
};
```

Handle different http methods

```zig
const t = struct {
    fn handleJson(res: *response.HttpResponse, req: *request.HttpRequest) !void {
        res.status = .ok;
        switch (req.method) {
            .GET => {
                try res.setHeader("Content-Type", "application/json");
                try res.body.appendSlice("{\"status\": \"ok\"}");
            },
            else => res.status = std.http.Status.method_not_allowed,
        }
    }
};
```

Handle HTML content 

```zig
const t = struct {
    fn handle404(res: *response.HttpResponse, _: *request.HttpRequest) !void {
        res.status = .not_found;
        try res.setHeader("Content-Type", "text/html");
        try res.body.appendSlice(
            \\<html>
            \\  <head>
            \\      <title>404</Title>
            \\  </head>
            \\  <body>
            \\      <h3 style="text-align: center">404</h3>
            \\  </body>
            \\</html>
        );
    }
};
```


### Listen & Serve

```zig
// Creates a Mux
var mux = server.Mux.init(allocator);

// Register handlers
try mux.handle("/", t.handleHome);
try mux.handle("/status.json", t.handleJson);
try mux.handle("/404", t.handle404);

// Listen & serve requests
try http_server.listenAndServe(&mux);
```
