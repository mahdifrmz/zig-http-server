const std = @import("std");
const allocator = std.heap.page_allocator;

pub fn main() !void {
    var argIter = try std.process.argsWithAllocator(allocator);
    while (true) {
        const arg = argIter.next() orelse break;
        std.debug.print("-> {s}\n", .{arg});
    }
    argIter.deinit();
}
