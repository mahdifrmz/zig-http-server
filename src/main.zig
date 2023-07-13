const std = @import("std");
const allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArgList = ArrayList([]const u8);

fn getArgs() !ArgList {
    var arglist = ArgList.init(allocator);
    var argIter = try std.process.argsWithAllocator(allocator);
    while (true) {
        const arg = argIter.next() orelse break;
        try arglist.append(arg);
    }
    argIter.deinit();
    return arglist;
}

pub fn main() !void {
    const args = try getArgs();
    const port: u16 = if (args.items.len < 2)
        8080
    else
        try std.fmt.parseInt(u16, args.items[1], 10);
    var server = std.net.StreamServer.init(.{});
    try server.listen(try std.net.Address.resolveIp("0.0.0.0", port));
    while (true) {
        const client = try server.accept();
        _ = client;
    }
}
