const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const DataError = @import("errors.zig").DataError;
const assert = std.debug.assert;

pub const BST_config = struct {
    max_size: u32 = 1024,
};

pub fn AVL(
    comptime T : type,
    compare_fn : *const fn (rhs: T , lhs: T) bool,
    eq_fn : *const fn (rhs: T , lhs: T) bool,
    qc: BST_config
) type {

    return struct {
        const Node = struct {
            data: T, 
            right: ?*Node,
            left: ?*Node,
            pub fn has_left_child(node: *Node) bool{
                if (node.left == null) return false;
                return true;
            }
        };
        const Self = @This();
        max_size : u32 = qc.max_size, 
        curr_size : u32 = 0,
        root : ?*Node = null,
        arena: std.heap.ArenaAllocator,
        compare_fn : *const fn (lhs: T , rhs: T) bool = compare_fn,
        eq_fn : *const fn (lhs: T , rhs: T) bool = eq_fn,

        pub fn init(allocator : std.mem.Allocator) Self {
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            return .{.arena = arena};
        }
        pub fn deinit(this: Self) void {
            this.arena.deinit();
        }

        pub fn empty(this: Self) bool{
            return (this.curr_size == 0);
        }
        fn rotate_left(node: *Node) *Node {
            var cur_right: *Node = node.right.?;
            const cur_left: ?*Node = cur_right.left;
            cur_right.left = node;
            node.right = cur_left;
            return cur_right;
        }
        fn rotate_right(node: *Node) *Node {
            var cur_left: *Node = node.left.?;
            const cur_right: ?*Node = cur_left.right;

            cur_left.right = node;
            node.left = cur_right;
            return cur_left;
        }
        fn height(node: ?*Node) i32{
            if (node == null) return -1;
            return @max(height(node.?.right),height(node.?.left)) + 1;
        }
        pub fn insert(this: *Self, in: T) error{MaxSizeReached,OutOfMemory,DuplicateValue}!void {
            if (this.curr_size == this.max_size) return DataError.MaxSizeReached;
            var new_node = try this.arena.allocator().create(Node);
            new_node.data = in;
            new_node.right = null;
            new_node.left = null;
            this.root = try this.insert_helper(this.root, new_node);
            this.curr_size += 1;
        }
        pub fn insert_helper (this: *Self, root: ?*Node, key: *Node) error{MaxSizeReached,DuplicateValue}!?*Node{
            if (root == null) {
                return key;
            }
            if (this.eq_fn(root.?.data, key.data)) return DataError.DuplicateValue;
            if (this.compare_fn(root.?.data, key.data)) {
                root.?.right = try this.insert_helper(root.?.right, key);
            } else {
                root.?.left = try this.insert_helper(root.?.left, key);
            }
            const balance = get_balance(root.?);
            if (balance > 1 and  compare_fn(key.data, root.?.left.?.data)) {
                // left left
                return rotate_right(root.?);
            }
            if (balance < -1 and  compare_fn(root.?.right.?.data, key.data)) {
                // right right 
                return rotate_left(root.?);
            }
            if (balance > 1 and  compare_fn(root.?.left.?.data, key.data)) {
                // left right 
                root.?.left = rotate_left(root.?.left.?);
                return rotate_right(root.?);
            }
            if (balance < -1 and  compare_fn(key.data, root.?.right.?.data)) {
                // right left 
                root.?.right = rotate_right(root.?.right.?);
                return rotate_left(root.?);
            }
            return root;
        }

        fn get_balance(node: ?*Node) i32 {
            if (node == null) return 0;
            return height(node.?.left) - height(node.?.right);
        }

        pub fn inorder_travers(this: *Self) void {
            inorder_travers_helper(this.root);
        }

        fn inorder_travers_helper(root: ?*Node) void {
            if (root) |rot| {
                inorder_travers_helper(rot.left);
                std.debug.print("{} \n", .{rot.data});
                inorder_travers_helper(rot.right);
            }
        }
        pub fn remove(this: *Self, in: T) error{Empty,NotFound}!void {
            if (this.curr_size == 0) return DataError.Empty;
            if (!this.contains(in)) return DataError.NotFound;
            defer this.curr_size -= 1;
            this.root = try this.remove_helper(this.root, in);
        }
        fn child_count(node: *Node) u4 {
            var to_ret: u4 = 0;
            if (node.left != null) to_ret += 1;
            if (node.right != null) to_ret += 1;
            return to_ret;
        }
        fn remove_helper (this: *Self,node: ?*Node, in: T) !?*Node{
            if (node == null) return null;
            var lnode = node;
            if (this.eq_fn(in, lnode.?.data)) {
                switch (child_count(lnode.?)) {

                    0 => {
                        this.arena.allocator().destroy(lnode.?);
                        lnode = null;
                    },
                    1 => {
                        const tmp : *Node = lnode.?.left orelse lnode.?.right.?;

                        this.arena.allocator().destroy(lnode.?);
                        lnode = tmp;
                    },
                    2 => {
                        const tmp : *Node = smallest_child(lnode.?.right.?);
                        lnode.?.data = tmp.data;
                        lnode.?.right = try this.remove_helper(lnode.?.right,tmp.data);

                    },
                    else => std.debug.print("big error ?",.{}),
                }
            }
            else if (this.compare_fn(in,lnode.?.data)) {

                lnode.?.left = try this.remove_helper(lnode.?.left, in);
            } else {
                lnode.?.right = try this.remove_helper(lnode.?.right, in);
            }


            const balance = get_balance(lnode);

            if (lnode != null) {
            }

            if (balance > 1 and get_balance(lnode.?.left.?) >= 0) {
                // left left
                return rotate_right(lnode.?);
            }
            if (balance < -1 and  get_balance(lnode.?.right.?) <= 0) {
                // right right 
                return rotate_left(lnode.?);
            }
            if (balance > 1 and  get_balance(lnode.?.left.?) < 0) {
                // left right 
                lnode.?.left = rotate_left(lnode.?.left.?);
                return rotate_right(lnode.?);
            }
            if (balance < -1 and  get_balance(lnode.?.right.?) > 0) {
                // right left 
                lnode.?.right = rotate_right(lnode.?.right.?);
                return rotate_left(lnode.?);
            }

            return lnode;
        }

        fn smallest_child (node: *Node) *Node {
            var cur_node: *Node = node;
            while (Node.has_left_child(cur_node)) {
                cur_node = cur_node.*.left.?;
            }
            return cur_node;
        }
        pub fn contains(this: *Self,in: T) bool {
            return this.search(in,this.root);
        }
        fn search (this: *Self, in : T, node: ?*Node) bool {
            if (node == null) return false; 
            if (this.eq_fn(in, node.?.data)) return true;
            if (this.compare_fn(in, node.?.data)) { 
                return this.search(in, node.?.left);
            }
            else{
                return this.search(in, node.?.right); 
            }
        }
        pub fn inorder_slice(this: *Self) []T {
            var to_ret : [qc.max_size]T = undefined;
            var idx: usize = 0; 
            inorder_slice_helper(this.root, &to_ret, &idx);
            return to_ret[0..this.curr_size];
        }
        fn inorder_slice_helper(root: ?*Node,to_ret: []T, idx: *usize) void {
            if (root) |rot| {
                inorder_slice_helper(rot.left,to_ret,idx);
                to_ret[idx.*] = rot.data;
                idx.* += 1;
                inorder_slice_helper(rot.right,to_ret,idx);
            }
        }
    };
}

fn u32eq(lhs: u32, rhs: u32) bool {
    if (lhs == rhs) {
        return true;
    }
    return false;
}
fn u32cmp(lhs: u32, rhs: u32) bool {
    if (lhs < rhs) {
        return true;
    }
    return false;
}


test "insert single element" {
    var avl = AVL(u32, u32cmp, u32eq, .{.max_size = 8}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(10);
    try testing.expect(avl.contains(10));
    try testing.expectEqualSlices(u32, &[_]u32{10}, avl.inorder_slice());
}

test "left rotation" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(1);
    try avl.insert(2);
    try avl.insert(3);
    try testing.expectEqualSlices(u32, &[_]u32{1,2,3}, avl.inorder_slice());
}

test "right rotation" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(3);
    try avl.insert(2);
    try avl.insert(1);

    try testing.expectEqualSlices(u32, &[_]u32{1,2,3}, avl.inorder_slice());
}

test "left-right rotation" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(3);
    try avl.insert(1);
    try avl.insert(2);

    try testing.expectEqualSlices(u32, &[_]u32{1,2,3}, avl.inorder_slice());
}

test "right-left rotation" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(1);
    try avl.insert(3);
    try avl.insert(2);

    try testing.expectEqualSlices(u32, &[_]u32{1,2,3}, avl.inorder_slice());
}

test "delete leaf node" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();
    try avl.insert(10);
    try avl.insert(20);
    try avl.insert(30);
    try avl.remove(30);
    try testing.expect(!avl.contains(30));
    try testing.expectEqualSlices(u32, &[_]u32{10,20}, avl.inorder_slice());
}

test "delete node with one child" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(10);
    try avl.insert(5);

    try avl.remove(10);
    try testing.expect(!avl.contains(10));
    try testing.expectEqualSlices(u32, &[_]u32{5}, avl.inorder_slice());
}

test "delete node with two children" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(20);
    try avl.insert(10);
    try avl.insert(30);
    try avl.insert(25);
    try avl.insert(40);

    try avl.remove(30);
    try testing.expect(!avl.contains(30));
    try testing.expectEqualSlices(u32, &[_]u32{10,20,25,40}, avl.inorder_slice());
}

test "deletion rebalancing" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(1);
    try avl.insert(2);
    try avl.insert(3);
    try avl.insert(4);
    try avl.insert(5);
    try avl.insert(6);
    try avl.remove(1);
    try testing.expect(!avl.contains(1));
    try testing.expectEqualSlices(u32, &[_]u32{2,3,4,5,6}, avl.inorder_slice());
}

test "search non-existing element" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(5);
    try testing.expect(!avl.contains(10));
}

test "insert until max_size" {
    var avl = AVL(u32, u32cmp, u32eq, .{.max_size = 4}).init(testing.allocator);
    defer avl.deinit();

    try avl.insert(1);
    try avl.insert(2);
    try avl.insert(3);
    try avl.insert(4);

    try testing.expectError(error.MaxSizeReached, avl.insert(5));
}

test "delete from empty tree" {
    var avl = AVL(u32, u32cmp, u32eq, .{}).init(testing.allocator);
    defer avl.deinit();

    try testing.expectError(error.Empty, avl.remove(10));
}
