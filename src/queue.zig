const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const DataError = @import("errors.zig").DataError;
const assert = std.debug.assert;

pub const queue_config = struct {
    max_size: u32 = 1024,
};

pub fn static_queue(comptime T: type, qc: queue_config) type {
    return struct {
        const Self = @This();
        arr: [qc.max_size]T = undefined,
        max_size : u32 = qc.max_size, 
        curr_size : u32 = 0,
        head: u32 = 0,
        tail: u32 = 0,

        pub fn init() Self {
            return .{};
        }

        /// pop and return head element 
        pub fn pop(this: *Self) error{Empty}!T {
            if (this.curr_size == 0) return DataError.Empty;
            defer {
                if (this.tail == this.max_size - 1) {
                    this.tail = 0;
                }
                else {
                    this.tail = this.tail + 1;
                }
            }
            defer this.arr[this.tail] = undefined;
            this.curr_size -= 1;
            return this.arr[this.tail];
        }
        /// return if stack is empty
        pub fn empty(this: Self) bool{
            return (this.curr_size == 0);
        }
        /// return top element.
        pub fn peek(this: Self) error{Empty}!T {
            if (this.curr_size == 0) return DataError.Empty;
            return {
                if (this.head == 0) {
                    this.arr[this.max_size];
                } else {
                    this.arr[this.head - 1];
                }
            };
        }
        pub fn push(this: *Self, in: T) error{MaxSizeReached}!void {
            if (this.curr_size == this.max_size) return DataError.MaxSizeReached;
            this.curr_size += 1;
            defer {
                if (this.head == this.max_size - 1) {
                    this.head = 0;
                }
                else {
                    this.head = this.head + 1;
                }
            }
            this.arr[this.head] = in;
        }
    };
}

pub fn dynamic_queue(comptime T: type, qc: queue_config) type {
    return struct {
        const Node = struct {
            data: T, 
            next: ?*Node,
        };
        const Self = @This();
        arena: std.heap.ArenaAllocator,
        max_size : u32 = qc.max_size, 
        curr_size : u32 = 0,
        head: ?*Node = null,
        tail: ?*Node = null,

        pub fn init(allocator : std.mem.Allocator) Self {
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            return .{.arena = arena};
        }

        pub fn deinit(this: Self) void {
            this.arena.deinit();
        }

        /// pop and return next element 
        pub fn pop(this: *Self) error{Empty}!T {
            if (this.empty()) return DataError.Empty;
            assert(this.tail != null);
            assert(this.head != null);
            const tmp = this.tail;
            this.tail = this.tail.?.next orelse null;
            defer this.arena.allocator().destroy(tmp.?);
            this.curr_size -= 1;
            return tmp.?.data;
        }
        /// return if stack is empty
        pub fn empty(this: Self) bool{
            return (this.curr_size == 0);
        }
        /// return top element.
        pub fn peek(this: Self) error{Empty}!T {
            if (this.curr_size == 0) return DataError.Empty;
            assert(this.tail != null);
            assert(this.head != null);
            return this.tail.?.data;
        }
        pub fn push(this: *Self, in: T) error{MaxSizeReached,OutOfMemory}!void {
            if (this.curr_size == this.max_size) return DataError.MaxSizeReached;
            var new_node = try this.arena.allocator().create(Node);
            new_node.next = null;
            new_node.data = in;
            if (this.empty()) {
                this.tail = new_node;
            } else {
                this.head.?.next = new_node;
            }
            this.head = new_node;
            this.curr_size += 1;
        }
    };

}

test "static q" {
    var q = static_queue(u32, .{.max_size = 4}).init();
    var res : u32 = undefined;
    try q.push(1);
    try q.push(2);
    try q.push(3);
    try q.push(4);
    try expectError(DataError.MaxSizeReached,q.push(5));
    res = q.pop() catch unreachable;
    try expect(res == 1);
    res = q.pop() catch unreachable;
    try expect(res == 2);
    try q.push(1);
    try q.push(2);
    res = q.pop() catch unreachable;
    try expect(res == 3);
    res = q.pop() catch unreachable;
    try expect(res == 4);
    res = q.pop() catch unreachable;
    try expect(res == 1);
    res = q.pop() catch unreachable;
    try expect(res == 2);
}

test "dynamic q" {
    const allocator = testing.allocator;
    var q = dynamic_queue(u32, .{.max_size = 4}).init(allocator);
    defer q.deinit();
    var res : u32 = undefined;
    try q.push(1);
    try q.push(2);
    try q.push(3);
    try q.push(4);
    try expectError(DataError.MaxSizeReached,q.push(5));
    res = q.pop() catch unreachable;
    try expect(res == 1);
    res = q.pop() catch unreachable;
    try expect(res == 2);
    try q.push(1);
    try q.push(2);
    res = q.pop() catch unreachable;
    try expect(res == 3);
    res = q.pop() catch unreachable;
    try expect(res == 4);
    res = q.pop() catch unreachable;
    try expect(res == 1);
    res = q.pop() catch unreachable;
    try expect(res == 2);
}
