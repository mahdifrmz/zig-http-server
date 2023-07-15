const std = @import("std");
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
    const queue = try WorkQueue(u64).new(glb_allocator, 1024);
    _ = queue;
    const args = try getArgs();
    const port: u16 = if (args.items.len < 2)
        8080
    else
        std.fmt.parseInt(u16, args.items[1], 10) catch {
            eprint("Error: Invalid port number", .{});
            std.process.exit(1);
        };
    var server = std.net.StreamServer.init(.{});
    try server.listen(std.net.Address.initIp4(try comptime parseIP("0.0.0.0"), port));
    print("Zerver listening on port {d}", .{port});

    while (true) {
        const client = try server.accept();
        _ = client;
    }
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

fn WorkQueue(comptime ty: type) type {
    return struct {
        buffer: []ty,
        size: usize,
        sem_prod: std.Thread.Semaphore,
        sem_cons: std.Thread.Semaphore,
        lock: std.Thread.Mutex,
        ptr_prod: usize,
        ptr_cons: usize,

        fn new(allocator: Allocator, buffer_size: usize) !@This() {
            var queue: @This() = .{
                .buffer = try allocator.alloc(ty, buffer_size),
                .size = buffer_size,
                .sem_prod = std.Thread.Semaphore{ .permits = buffer_size },
                .sem_cons = std.Thread.Semaphore{},
                .lock = std.Thread.Mutex{},
            };
            queue.sem_prod.post();
        }

        fn push(self: *@This(), value: ty) void {
            self.sem_prod.wait();
            self.lock.lock();
            self.buffer[self.ptr_prod] = value;
            self.ptr_prod = (self.ptr_prod + 1) % self.buffer.len;
            self.self.lock.unlock();
            self.sem_cons.post();
        }

        fn pop(self: *@This(), value: ty) void {
            self.sem_cons.wait();
            self.lock.lock();
            self.buffer[self.ptr_cons] = value;
            self.ptr_cons = (self.ptr_cons + 1) % self.buffer.len;
            self.self.lock.unlock();
            self.sem_prod.post();
        }
    };
}
