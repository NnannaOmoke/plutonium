const std = @import("std");

const ArrayList = std.ArrayList;
const mem = std.mem;
const Mutex = Thread.Mutex;
const Thread = std.Thread;
const time = std.time;
const testing = std.testing;

const Task = enum {
    SayHi,
    SayName,
    GiveTime,
    Kill,
};

const WorkerThread = struct {
    const Self = @This();
    inner: Thread, //do we even need this?,it doesn't do anything, but I'll keep it for now

    //this function exists to run permanently until it returns, at which point the thread running it will die.
    fn executor(device: *GlobalPoolThread) void {
        while (true) {
            if (device.work_queue.try_lock()) {
                defer device.work_queue.unlock();
                const task: ?Task = device.work_queue.pop_task();
                if (task) |t| {
                    switch (t) {
                        .SayHi => {},
                        .SayName => {},
                        .GiveTime => {},
                        .Kill => {
                            break; //break the loop, and that's it
                        },
                    }
                } else {
                    time.sleep(device.sleep_time * time.ns_per_ms);
                    continue;
                }
            } else {
                time.sleep(device.sleep_time * time.ns_per_ms);
                continue;
            }
        }
    }
};

const GlobalTaskList = struct {
    const Self = @This();
    mutex: Mutex,
    tasks: ArrayList(Task),

    pub fn init(allocator: mem.Allocator) Self {
        return .{ .mutex = .{}, .tasks = ArrayList(Task).init(allocator) };
    }
    //should be done at the end of the program
    pub fn deinit(self: *Self) void {
        self.tasks.deinit();
    }

    pub fn try_lock(self: *Self) bool {
        return self.mutex.tryLock();
    }

    pub fn lock(self: *Self) void {
        return self.mutex.lock();
    }

    pub fn unlock(self: *Self) void {
        return self.mutex.unlock();
    }

    pub fn pop_task(self: *Self) ?Task {
        if (self.tasks.items.len == 0) {
            return null;
        } else {
            return self.tasks.orderedRemove(0); //this language has no queues, just stacks, this op is O(n)
        }
    }

    pub fn add_task(self: *Self, slice: []Task) void {
        //caller will lock, and then add tasks
        self.tasks.appendSlice(slice); //coerces to one task? interesting
    }
};

const GlobalPoolThread = struct {
    const Self = @This();
    work_queue: GlobalTaskList,
    sleep_time: usize,
    threads: ArrayList(WorkerThread),

    pub fn init(allocator: mem.Allocator, sleep_time: ?usize) Self {
        return .{
            .work_queue = GlobalTaskList.init(allocator),
            .threads = ArrayList(WorkerThread).init(allocator),
            .sleep_time = if (sleep_time) |st| st else 85, //default sleep time for non-busy threads is 85
        };
    }

    pub fn start(self: *Self, nthreads: ?usize) !void {
        const num = if (nthreads) |num| num else try Thread.getCpuCount();
        for (0..num) |_| {
            const handle = try Thread.spawn(.{}, WorkerThread.executor, .{ .device = self });
            handle.detach();
            const wt = WorkerThread{ .inner = handle };
            try self.threads.append(wt);
        }
    }

    pub fn deinit(self: Self) void {
        self.work_queue.deinit();
        self.threads.deinit();
    }

    pub fn add_task(self: *Self, task: Task) void {
        self.work_queue.lock();
        defer self.work_queue.unlock();
        self.work_queue.add_task(task);
    }
};
