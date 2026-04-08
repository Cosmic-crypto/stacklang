const std = @import("std");

pub const Instr = union(enum) {
    Add: void,
    Sub: void,
    Mul: void,
    Div: void,
    Pow: void,
    Print: void,
    PrintIdx: usize,
    PrintAll: void,
    Dup: void,
    Pop: void,
    PopIdx: usize,
    Push: i32,
    Jmp: usize,
    JmpIfZ: usize,
    EnabDefPop: void,
};

pub const VM = struct {
    stack: std.ArrayList(i32),
    sp: usize = 0,
    def_pop: bool = true,
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) VM {
        return .{
            .stack = std.ArrayList(i32).initCapacity(gpa, 0) catch @panic("OOM"),
            .gpa = gpa,
        };
    }

    pub fn enab_def_pop(self: *VM) void {
        self.def_pop = if (self.def_pop) false else true;
    }

    pub fn push(self: *VM, val: i32) void {
        if (self.sp >= self.stack.items.len) {
            self.stack.append(self.gpa, val) catch @panic("Stack overflow");
        } else {
            self.stack.items[self.sp] = val;
        }
        self.sp += 1;
    }

    pub fn pop(self: *VM) i32 {
        if (self.sp == 0) @panic("Stack underflow");
        self.sp -= 1;
        return self.stack.items[self.sp];
    }

    pub fn peek(self: *VM) i32 {
        if (self.sp == 0) @panic("Stack underflow");
        return self.stack.items[self.sp - 1];
    }

    pub fn run(self: *VM, program: []const Instr) void {
        var ip: usize = 0;
        while (ip < program.len) {
            const instr = program[ip];
            switch (instr) {
                .Push => |v| self.push(v),
                .Add => {
                    const b: i32 = if (self.def_pop) self.pop() else self.peek();
                    const a: i32 = if (self.def_pop) self.pop() else self.peek();
                    self.push(a + b);
                },
                .Sub => {
                    const b: i32 = if (self.def_pop) self.pop() else self.peek();
                    const a: i32 = if (self.def_pop) self.pop() else self.peek();
                    self.push(a - b);
                },
                .Mul => {
                    const b: i32 = if (self.def_pop) self.pop() else self.peek();
                    const a: i32 = if (self.def_pop) self.pop() else self.peek();
                    self.push(a * b);
                },
                .Div => {
                    const b: i32 = if (self.def_pop) self.pop() else self.peek();
                    const a: i32 = if (self.def_pop) self.pop() else self.peek();
                    self.push(@divExact(a, b));
                },
                .Pow => {
                    const b: i32 = if (self.def_pop) self.pop() else self.peek();
                    const a: i32 = if (self.def_pop) self.pop() else self.peek();
                    self.push(std.math.pow(i32, a, b));
                },
                .Print => {
                    const val: i32 = if (self.def_pop) self.pop() else self.peek();
                    std.debug.print("{}\n", .{val});
                },
                .PrintIdx => |v| {
                    const val: i32 = self.stack.items[v];
                    std.debug.print("{}", .{val});
                },
                .PrintAll => {
                    for (self.stack.items) |val| {
                        std.debug.print("{}\n", .{val});
                        if (self.def_pop) _ = self.pop();
                    }
                },
                .Dup => {
                    const val: i32 = self.peek();
                    self.push(val);
                },
                .Pop => _ = self.pop(),
                .PopIdx => |idx| _ = self.stack.orderedRemove(idx),
                .Jmp => |target| ip = target - 1,
                .JmpIfZ => |target| {
                    const val: i32 = self.pop();
                    if (val == 0) ip = target - 1;
                },
                .EnabDefPop => self.enab_def_pop(),
            }
            ip += 1;
        }
    }
};
