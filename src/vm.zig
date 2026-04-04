const std = @import("std");

pub const Instr = union(enum) {
    Add: void,
    Sub: void,
    Mul: void,
    Print: void,
    Dup: void,
    Pop: void,
    Push: i32,
    Jmp: usize, // jump to instruction index
    JmpIfZ: usize, // jump to instruction index if top of stack is zero
};

pub const VM = struct {
    stack: [128]i32 = undefined,
    sp: usize = 0,

    pub fn push(self: *VM, val: i32) void {
        if (self.sp >= self.stack.len) @panic("Stack overflow");
        self.stack[self.sp] = val;
        self.sp += 1;
    }

    pub fn pop(self: *VM) i32 {
        if (self.sp == 0) @panic("Stack underflow");
        self.sp -= 1;
        return self.stack[self.sp];
    }

    pub fn peek(self: *VM) i32 {
        if (self.sp == 0) @panic("Stack underflow");
        return self.stack[self.sp - 1];
    }

    pub fn run(self: *VM, program: []const Instr) void {
        var ip: usize = 0;
        while (ip < program.len) {
            const instr = program[ip];
            switch (instr) {
                .Push => |v| self.push(v),
                .Add => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(a + b);
                },
                .Sub => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(a - b);
                },
                .Mul => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(a * b);
                },
                .Print => {
                    const val = self.pop();
                    std.debug.print("{}\n", .{val});
                },
                .Dup => {
                    const val = self.peek();
                    self.push(val);
                },
                .Pop => _ = self.pop(),
                .Jmp => |target| ip = target - 1, // -1 because loop increments ip
                .JmpIfZ => |target| {
                    const val = self.pop();
                    if (val == 0) ip = target - 1;
                },
            }
            ip += 1;
        }
    }
};
