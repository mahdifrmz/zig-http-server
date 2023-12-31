const std = @import("std");
const Pool = @import("./pool.zig").Pool;
const controller = @import("./controller.zig");
const state = @import("./state.zig");
const handleClientRoutine = controller.handleClientRoutine;
const getFlag = state.getFlag;
const initFlag = state.initFlag;
const ZerverConnection = controller.ZerverConnection;

const Address = std.net.Address;
const glb_allocator = std.heap.page_allocator;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArgList = ArrayList([]const u8);

fn getArgs() !ArgList {
    var arglist = ArgList.init(glb_allocator);
    var argIter = try std.process.argsWithAllocator(glb_allocator);
    while (true) {
        const arg = argIter.next() orelse break;
        try arglist.append(arg);
    }
    argIter.deinit();
    return arglist;
}

fn print(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdOut().writer();
    std.fmt.format(writer, fmt, args) catch {};
}
fn eprint(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    std.fmt.format(writer, fmt, args) catch {};
}

pub fn main() !void {
    const args = try getArgs();
    const port: u16 = if (args.items.len < 2)
        8080
    else
        std.fmt.parseInt(u16, args.items[1], 10) catch {
            eprint("Error: Invalid port number\n", .{});
            std.process.exit(1);
        };
    const address = std.net.Address.initIp4(try comptime parseIP("0.0.0.0"), port);
    var server = std.net.StreamServer.init(.{});
    try server.listen(address);
    print("Zerver listening on port {d}\n", .{port});
    initFlag();
    var pool = try Pool(ZerverConnection).init(glb_allocator, 4);
    while (!getFlag()) {
        const client = try server.accept();

        pool.spawn(handleClientRoutine, .{
            .client = client,
            .allocator = glb_allocator,
            .address = address,
        });
    }
    pool.terminate();
}

fn parseIP(ipv4: []const u8) ![4]u8 {
    const IPv4 = struct {
        fields: [4]u8,
    };

    const IPv4ConverterState = struct {
        ip: []const u8,
        next: usize,

        fn isEnd(self: *const @This()) bool {
            return self.next >= self.ip.len or self.ip[self.next] == '.';
        }

        fn new(ip: []const u8) @This() {
            return .{
                .ip = ip,
                .next = 0,
            };
        }
        fn advance(self: *@This()) void {
            self.next += 1;
        }
        fn calc(self: *@This()) !IPv4 {
            var fields = [4]u8{ 0, 0, 0, 0 };
            for (0..4) |i| {
                const cur = self.next;
                while (!self.isEnd()) {
                    self.advance();
                }
                const num = self.ip[cur..self.next];
                fields[i] = try std.fmt.parseInt(u8, num, 10);
                self.advance();
            }
            return .{ .fields = fields };
        }
    };

    var converter = IPv4ConverterState.new(ipv4);
    const addr = try converter.calc();
    return addr.fields;
}
