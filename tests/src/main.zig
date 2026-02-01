extern fn syscall() void;

export const some_value: u32 = 123;
export const hello_world_string: [*:0]const u8 = "Hello, World!";

export fn add(a: i32, b: i32) i32 {
    return a +% b;
}

export fn tst() void {
    syscall();
}

fn mmm() callconv(.c) void {}
fn mmm2() callconv(.c) void {
    syscall();
}

export fn getFn() *const fn () callconv(.c) void {
    return mmm;
}
export fn getFn2() *const fn () callconv(.c) void {
    return mmm2;
}
