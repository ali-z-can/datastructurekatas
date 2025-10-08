const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

const StackError = error {
    MaxSizeReached,
};
pub fn stack_alloc(comptime T: type, comptime max_size: u32) type {
    return struct {
        const Node = struct {
            data: T, 
            next: ?*Node,
        };
        const Self = @This();
        arena: std.heap.ArenaAllocator,
        max_size : u32 = max_size, 
        curr_size : u32 = 0,
        head: ?*Node = null,
        pub fn init(allocator : std.mem.Allocator) Self {
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            return .{
                .arena = arena,
            };
        }

        pub fn deinit(this: Self) void {
            this.arena.deinit();
        }
        /// pop and return top element 
        pub fn pop(this: *Self) ?T {
            if (this.head == null) return null;
            const tmp = this.head;
            defer this.arena.allocator().destroy(tmp.?);
            this.head = this.head.?.next orelse null;
            this.curr_size -= 1;
            return tmp.?.data;
        }
        /// return if stack is empty
        pub fn empty(this: Self) bool{
            return (this.curr_size == 0);
        }
        /// return top element.
        pub fn peek(this: Self) ?T {
            if (this.head == null) return null;
            return this.head.?.data;
        }
        pub fn push(this: *Self, in: T) !void {
            if (this.curr_size == this.max_size) return StackError.MaxSizeReached;
            this.curr_size += 1;
            var new_node = try this.arena.allocator().create(Node);
            new_node.next = this.head;
            new_node.data = in;
            this.head = new_node;
        }
        pub fn gmx(this: Self) u32 {
            return this.max_size;
        }
    };
}

pub fn stack_static(comptime T: type, comptime max_size: u32) type {

    return struct {
        const Self = @This();
        arr : [max_size]T = undefined,
        max_size : u32 = max_size, 
        curr_size : u32 = 0,

        pub fn init() Self {
            return .{};
        }

        /// pop and return top element 
        pub fn pop(this: *Self) ?T {
            if (this.curr_size == 0) return null;
            defer this.arr[this.curr_size] = undefined;
            this.curr_size-= 1;
            return this.arr[this.curr_size];
        }
        /// return if stack is empty
        pub fn empty(this: Self) bool{
            return (this.curr_size == 0);
        }
        /// return top element.
        pub fn peek(this: Self) ?T {
            if (this.curr_size == 0) return null;
            return this.arr[this.curr_size - 1];
        }
        pub fn push(this: *Self, in: T) !void {
            if (this.curr_size == this.max_size) return StackError.MaxSizeReached;
            defer this.curr_size += 1;
            this.arr[this.curr_size] = in;
        }
        pub fn gmx(this: Self) u32 {
            return this.max_size;
        }
    };
}
test "alloc stack" {
    const allocator = testing.allocator;
    var stack = stack_alloc(u32, 1024).init(allocator);
    defer stack.deinit();
    assert (stack.gmx() == 1024);
    try stack.push(1);
    assert (stack.peek() == 1);
    try stack.push(2);
    assert (stack.peek() == 2);
    assert (stack.pop() == 2);
    assert (stack.peek() == 1);
    assert (stack.pop() == 1);
    for (0..1024) |i| {
        try stack.push(@intCast(i));
    }

    assert (stack.push(0) == StackError.MaxSizeReached);
    for (0..1024) |i| {
        const pr: u32 = stack.pop() orelse 0;
        assert (pr == ( @as(u32,1023) - @as(u32, @intCast(i))) );
    }
}

test "static stack" {
    var stack = stack_static(u32, 1024).init();
    assert (stack.gmx() == 1024);
    try stack.push(1);
    assert (stack.peek() == 1);
    try stack.push(2);
    assert (stack.peek() == 2);
    assert (stack.pop() == 2);
    assert (stack.peek() == 1);
    assert (stack.pop() == 1);
    for (0..1024) |i| {
        try stack.push(@intCast(i));
    }

    assert (stack.push(0) == StackError.MaxSizeReached);
    for (0..1024) |i| {
        const pr: u32 = stack.pop() orelse 0;
        assert (pr == ( @as(u32,1023) - @as(u32, @intCast(i))) );
    }
}
