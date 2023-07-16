const std = @import("std");
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Semaphore = Thread.Semaphore;
const Allocator = std.mem.Allocator;

fn WorkQueue(comptime ty: type) type {
    return struct {
        buffer: []ty,
        size: usize,
        sem_prod: Semaphore,
        sem_cons: Semaphore,
        lock: Mutex,
        ptr_prod: usize,
        ptr_cons: usize,
        allocator: Allocator,

        fn init(allocator: Allocator, buffer_size: usize) !@This() {
            return .{
                .buffer = try allocator.alloc(ty, buffer_size),
                .size = buffer_size,
                .sem_prod = Semaphore{ .permits = buffer_size },
                .sem_cons = Semaphore{},
                .lock = Mutex{},
                .ptr_prod = 0,
                .ptr_cons = 0,
                .allocator = allocator,
            };
        }

        fn push(self: *@This(), value: ty) void {
            self.sem_prod.wait();
            self.lock.lock();
            self.buffer[self.ptr_prod] = value;
            self.ptr_prod = (self.ptr_prod + 1) % self.buffer.len;
            self.lock.unlock();
            self.sem_cons.post();
        }

        fn pop(self: *@This()) ty {
            self.sem_cons.wait();
            self.lock.lock();
            const value = self.buffer[self.ptr_cons];
            self.ptr_cons = (self.ptr_cons + 1) % self.buffer.len;
            self.lock.unlock();
            self.sem_prod.post();
            return value;
        }

        fn deinit(self: *@This()) void {
            self.allocator.free(self.buffer);
        }
    };
}

fn TTask(comptime Arg: type) type {
    return union(enum) {
        End: void,
        Next: struct {
            routine: *const fn (Arg) void,
            arg: Arg,
        },

        fn task(routine: *const fn (Arg) void, arg: Arg) @This() {
            return .{ .Next = .{
                .routine = routine,
                .arg = arg,
            } };
        }
        fn none() @This() {
            return .{
                .End = {},
            };
        }
    };
}

pub fn Pool(comptime Arg: type) type {
    const Task = TTask(Arg);
    const Queue = WorkQueue(Task);

    return struct {
        work_queue: *Queue,
        handles: []Thread,
        allocator: Allocator,

        fn worker(work_queue: *Queue) void {
            while (true) {
                const task = work_queue.pop();
                switch (task) {
                    Task.End => {
                        break;
                    },
                    Task.Next => {
                        task.Next.routine(task.Next.arg);
                    },
                }
            }
        }

        pub fn init(allocator: Allocator, thread_count: usize) !@This() {
            var self = @This(){
                .handles = try allocator.alloc(Thread, thread_count),
                .work_queue = try allocator.create(Queue),
                .allocator = allocator,
            };
            self.work_queue.* = try Queue.init(allocator, 1024);
            for (0..thread_count) |i| {
                self.handles[i] = try Thread.spawn(.{}, worker, .{self.work_queue});
            }
            return self;
        }
        pub fn spawn(self: *@This(), routine: *const fn (Arg) void, arg: Arg) void {
            self.work_queue.push(Task.task(routine, arg));
        }
        pub fn terminate(self: *@This()) void {
            for (0..self.handles.len) |_| {
                self.work_queue.push(Task.none());
            }
            for (0..self.handles.len) |i| {
                self.handles[i].join();
            }
            self.work_queue.deinit();
            self.allocator.destroy(self.work_queue);
            self.allocator.free(self.handles);
        }
    };
}
