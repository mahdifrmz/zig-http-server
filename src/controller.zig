const std = @import("std");
const state = @import("./state.zig");
const Connection = std.net.StreamServer.Connection;
const Allocator = std.mem.Allocator;
const Address = std.net.Address;
const setFlag = state.setFlag;

pub const ZerverConnection = struct {
    client: Connection,
    allocator: Allocator,
    address: Address,
};

fn fakeConnection(address: Address) !void {
    const stream = try std.net.tcpConnectToAddress(address);
    stream.close();
}
fn handleClient(con: ZerverConnection) !void {
    // get command
    var command_buf = [3]u8{ 0, 0, 0 };
    var read_count = try con.client.stream.reader().readAtLeast(&command_buf, 3);
    if (read_count < 3) {}
    // check termination
    else if (std.mem.eql(u8, &command_buf, "TRM")) {
        setFlag();
        try fakeConnection(con.address);
    } else {
        // load home page data
        const home_page = try std.fs.cwd().openFile("./public/index.html", .{});
        const content_length = try home_page.getEndPos();
        var buffer = try con.allocator.alloc(u8, content_length);
        _ = try home_page.readAll(buffer);
        // send HTTP header
        try std.fmt.format(con.client.stream.writer(), "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\n\r\n", .{content_length});
        // send HTTP body
        try con.client.stream.writeAll(buffer);
        // close connectrion
    }
    con.client.stream.close();
}
pub fn handleClientRoutine(connection: ZerverConnection) void {
    handleClient(connection) catch {};
}
