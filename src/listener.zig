const std = @import("std");
const print = std.debug.print;
const Task = @import("root.zig").Task;
const net = std.net;
const http = std.http;

fn start_server(server: *net.Server) void {
    while (true) {
        var connection = server.accept() catch |err| {
            print("connection to client interrupted: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        var read_buffer: [1024]u8 = undefined;
        var http_server = http.Server.init(connection, &read_buffer);

        var request = http_server.receiveHead() catch |err| {
            print("could not read head: {}\n", .{err});
            continue;
        };
        handle_request(&request) catch |err| {
            print("could not handle request: {}", .{err});
            continue;
        };
    }
}

fn handle_request(request: *http.Server.Request) !void {
    print("handling request for {s}\n", .{request.head.target});
    try request.respond("hello http!\n", .{});
}

pub fn main() !void {
    const addr = net.Address.parseIp4("127.0.0.1", 8080) catch |err| {
        print("an error occurred while resolving the ip address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});

    start_server(&server);
}
