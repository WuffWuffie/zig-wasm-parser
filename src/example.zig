const std = @import("std");
const wasm = @import("wasm");

fn outputInsts(reader: *wasm.Reader) !void {
    var scopes: usize = 1;
    while (true) {
        const inst = try reader.inst();

        if (inst == .end) {
            scopes -= 1;
            if (scopes == 0) {
                break;
            }
        }

        switch (inst) {
            .block, .loop, .@"if" => scopes += 1,
            else => {},
        }

        std.debug.print("{any}\n", .{inst});
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "balls.wasm",
        std.math.maxInt(usize),
    );

    var parser = try wasm.Parser.init(source);

    while (try parser.next()) |section_value| {
        std.debug.print("section: {t}\n", .{section_value});
        defer std.debug.print("\n", .{});

        switch (section_value) {
            .type => {
                var section = section_value.type;
                while (try section.next()) |func_type| {
                    std.debug.print(
                        "params: {any} results: {any}\n",
                        .{ func_type.params, func_type.results },
                    );
                }
            },
            .import => {
                var section = section_value.import;
                while (try section.next()) |im| {
                    std.debug.print(
                        "import {s}.{s}: {any}\n",
                        .{ im.lib, im.name, im.kind },
                    );
                }
            },
            .func => {
                var section = section_value.func;
                while (try section.next()) |type_id| {
                    std.debug.print("func type: {}\n", .{type_id});
                }
            },
            .table => {
                var section = section_value.table;
                while (try section.next()) |table| {
                    std.debug.print("table: {any}\n", .{table});
                }
            },
            .memory => {
                var section = section_value.memory;
                while (try section.next()) |limits| {
                    std.debug.print("memory limits: {any}\n", .{limits});
                }
            },
            .global => {
                var section = section_value.global;
                while (try section.next()) |value| {
                    const ty, const insts = value;
                    std.debug.print("global type: {}\n", .{ty});
                    std.debug.print("init:\n", .{});
                    try outputInsts(insts);
                }
            },
            .@"export" => {
                var section = section_value.@"export";
                while (try section.next()) |ex| {
                    std.debug.print(
                        "export name: {s} index: {} kind: {t}\n",
                        .{ ex.name, ex.index, ex.kind },
                    );
                }
            },
            .start => |id| {
                std.debug.print("start: {}\n", .{id});
            },
            .element => {
                var section = section_value.element;
                while (try section.insts()) |insts| {
                    std.debug.print("init:\n", .{});
                    try outputInsts(insts);

                    std.debug.print("funcs:\n", .{});
                    var funcs = try section.funcs();
                    while (try funcs.next()) |id| {
                        std.debug.print("{}\n", .{id});
                    }
                }
            },
            .code => {
                var section = section_value.code;
                while (try section.next()) |code_reader| {
                    var code = code_reader;

                    std.debug.print("locals:\n", .{});
                    while (try code.local()) |value| {
                        const repeat, const ty = value;
                        std.debug.print("{} * {t}\n", .{ repeat, ty });
                    }

                    std.debug.print("body:\n", .{});
                    try outputInsts(&code.reader);
                }
            },
            .data => {
                var section = section_value.data;
                while (try section.memoryIndex()) |memory| {
                    std.debug.print("memory: {}\n", .{memory});
                    std.debug.print("init:\n", .{});
                    try outputInsts(&section.reader);
                    std.debug.print("data: \"{f}\"\n", .{std.zig.fmtString(try section.data())});
                }
            },
            .data_count => |count| {
                std.debug.print("data count: {}\n", .{count});
            },
            .other => {
                // custom and other sections can be read manually
                // otherwise they are just skipped
                var section = section_value.other;
                if (section.kind == .custom) {
                    const name, const data = try section.custom();
                    std.debug.print("custom data:\n", .{});
                    std.debug.print("name: \"{f}\"\n", .{std.zig.fmtString(name)});
                    std.debug.print("data: \"{f}\"\n", .{std.zig.fmtString(data)});
                }
            },
        }
    }
}
