const std = @import("std");
const atomic = std.atomic;
const Ordering = atomic.Ordering;

const Flag = atomic.Atomic(bool);
var end_flag: Flag = undefined;

pub fn getFlag() bool {
    return end_flag.load(Ordering.SeqCst);
}

pub fn setFlag() void {
    end_flag.store(true, Ordering.SeqCst);
}

pub fn initFlag() void {
    end_flag = Flag.init(false);
}
