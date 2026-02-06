const std = @import("std");
const wasm = @import("wasm");

pub fn stringEscape(bytes: []const u8, w: *std.Io.Writer) std.Io.Writer.Error!void {
    for (bytes) |byte| switch (byte) {
        '\n' => try w.writeAll("\\n"),
        '\t' => try w.writeAll("\\t"),
        '\\' => try w.writeAll("\\\\"),
        '"' => try w.writeAll("\\\""),
        ' ', '!', '#'...'\'', '('...'[', ']'...'~' => try w.writeByte(byte),
        else => {
            try w.writeAll("\\");
            try w.printInt(byte, 16, .upper, .{ .width = 2, .fill = '0' });
        },
    };
}

pub fn fmtString(bytes: []const u8) std.fmt.Formatter([]const u8, stringEscape) {
    return .{ .data = bytes };
}

const Dumper = struct {
    out: *std.Io.Writer,
    allocator: std.mem.Allocator,
    functions: u32 = 0,
    tables: u32 = 0,
    elements: u32 = 0,
    memories: u32 = 0,
    globals: u32 = 0,
    datas: u32 = 0,
    func_section: ?@FieldType(wasm.Section, "func") = null,
    types: []wasm.FuncType = &.{},

    fn dumpTable(self: *Dumper, table: wasm.Table) !void {
        try self.out.print("(table (;{};) {}", .{ self.tables, table.limits.min });
        if (table.limits.max) |max| try self.out.print(" {}", .{max});
        try self.out.print(" {t})", .{table.type});
        self.tables += 1;
    }

    fn dumpMemory(self: *Dumper, limits: wasm.Limits) !void {
        try self.out.print("(memory (;{};) {}", .{ self.memories, limits.min });
        if (limits.max) |max| try self.out.print(" {}", .{max});
        try self.out.writeAll(")");
        self.memories += 1;
    }

    fn dumpInsts(self: *Dumper, reader: *wasm.Reader, multiline: bool) !bool {
        var count: usize = 0;
        var scopes: usize = 1;
        while (true) : (count += 1) {
            const inst = try reader.inst();

            if (inst == .end) {
                scopes -= 1;
                if (scopes == 0) {
                    break;
                }
            }

            if (multiline) {
                try self.out.writeByte('\n');
                try self.out.splatByteAll(' ', 2 * scopes + 2);
            } else {
                if (count > 0) {
                    try self.out.writeByte(' ');
                }
            }

            switch (inst) {
                .block, .loop, .@"if" => scopes += 1,
                else => {},
            }

            try self.out.writeAll(wasm.op.name(inst));
            try inst.format(self.out);
        }
        return count != 0;
    }

    fn dumpFuncType(self: *Dumper, typ: wasm.FuncType) !void {
        if (typ.params.len != 0) {
            try self.out.writeAll(" (param");
            for (typ.params) |ty| {
                try self.out.print(" {t}", .{ty});
            }
            try self.out.writeAll(")");
        }
        if (typ.results.len != 0) {
            try self.out.writeAll(" (result");
            for (typ.results) |ty| {
                try self.out.print(" {t}", .{ty});
            }
            try self.out.writeAll(")");
        }
    }

    fn dumpSection(self: *Dumper, section_value: wasm.Section) !void {
        switch (section_value) {
            .type => {
                var section = section_value.type;
                if (self.types.len != 0) return error.ParseError;
                self.types = try self.allocator.alloc(wasm.FuncType, section.count);
                var index: usize = 0;
                while (try section.next()) |func_type| : (index += 1) {
                    self.types[index] = func_type;

                    try self.out.print("  (type (;{};) (func", .{index});
                    try self.dumpFuncType(func_type);
                    try self.out.writeAll("))\n");
                }
            },
            .import => {
                var section = section_value.import;
                while (try section.next()) |im| {
                    try self.out.print(
                        "  (import \"{f}\" \"{f}\" ",
                        .{ fmtString(im.lib), fmtString(im.name) },
                    );
                    switch (im.kind) {
                        .memory => |limits| try self.dumpMemory(limits),
                        .function => |type_id| {
                            try self.out.print(
                                "(func (;{};) (type {}))",
                                .{ self.functions, type_id },
                            );
                            self.functions += 1;
                        },
                        .table => |table| {
                            try self.dumpTable(table);
                        },
                        .global => |ty| {
                            try self.out.print("(global (;{};) ", .{self.globals});
                            if (ty.mut == .mutable) {
                                try self.out.print("(mut {t})", .{ty.type});
                            } else {
                                try self.out.print("{t}", .{ty.type});
                            }
                            try self.out.writeAll(")");
                            self.globals += 1;
                        },
                    }
                    try self.out.writeAll(")\n");
                }
            },
            .func => self.func_section = section_value.func,
            .table => {
                var section = section_value.table;
                while (try section.next()) |table| {
                    try self.out.writeAll("  ");
                    try self.dumpTable(table);
                    try self.out.writeAll("\n");
                }
            },
            .memory => {
                var section = section_value.memory;
                while (try section.next()) |limits| {
                    try self.out.writeAll("  ");
                    try self.dumpMemory(limits);
                    try self.out.writeAll("\n");
                }
            },
            .global => {
                var section = section_value.global;
                while (try section.next()) |value| {
                    const ty, const insts = value;

                    try self.out.print("  (global (;{};) ", .{self.globals});
                    if (ty.mut == .mutable) {
                        try self.out.print("(mut {t}) ", .{ty.type});
                    } else {
                        try self.out.print("{t} ", .{ty.type});
                    }

                    _ = try self.dumpInsts(insts, false);
                    try self.out.writeAll(")\n");
                    self.globals += 1;
                }
            },
            .@"export" => {
                var section = section_value.@"export";
                while (try section.next()) |ex| {
                    try self.out.print("  (export \"{f}\"", .{fmtString(ex.name)});
                    switch (ex.kind) {
                        .function => try self.out.print(" (func {})", .{ex.index}),
                        .table => try self.out.print(" (table {})", .{ex.index}),
                        .memory => try self.out.print(" (memory {})", .{ex.index}),
                        .global => try self.out.print(" (global {})", .{ex.index}),
                    }
                    try self.out.writeAll(")\n");
                }
            },
            .start => |id| try self.out.print("  (start {})\n", .{id}),
            .element => {
                var section = section_value.element;
                while (try section.insts()) |insts| {
                    try self.out.print("  (elem (;{};) (", .{self.elements});
                    _ = try self.dumpInsts(insts, false);
                    try self.out.writeAll(") func");

                    var funcs = try section.funcs();
                    while (try funcs.next()) |id| {
                        try self.out.print(" {}", .{id});
                    }

                    try self.out.writeAll(")\n");

                    self.elements += 1;
                }
            },
            .code => {
                const types = if (self.func_section) |*section| section else {
                    return error.ParseError;
                };
                var section = section_value.code;
                while (try section.next()) |code_reader| {
                    var code = code_reader;

                    const type_id = try types.next() orelse {
                        return error.ParseError;
                    };

                    try self.out.print(
                        "  (func (;{};) (type {})",
                        .{ self.functions, type_id },
                    );

                    if (type_id >= self.types.len) {
                        return error.ParseError;
                    }

                    try self.dumpFuncType(self.types[type_id]);

                    const has_locals = code.local_count > 0;
                    while (try code.local()) |value| {
                        try self.out.writeAll("\n    (local");
                        const repeat, const ty = value;
                        for (0..repeat) |_| {
                            try self.out.print(" {t}", .{ty});
                        }
                        try self.out.writeAll(")");
                    }

                    const has_body = try self.dumpInsts(&code.reader, true);
                    try self.out.writeAll(if (has_locals or has_body) "\n  )\n" else ")\n");

                    self.functions += 1;
                }
            },
            .data => {
                var section = section_value.data;
                while (try section.memoryIndex()) |memory| {
                    _ = memory;
                    try self.out.print("  (data (;{};) (", .{self.datas});
                    _ = try self.dumpInsts(&section.reader, false);
                    const data = try section.data();
                    try self.out.print(") \"{f}\")\n", .{fmtString(data)});
                }
            },
            else => {},
        }
    }

    fn dumpModule(self: *Dumper, source: []const u8) !void {
        var parser = try wasm.Parser.init(source);
        try self.out.writeAll("(module\n");
        while (try parser.next()) |section| {
            try self.dumpSection(section);
        }
        try self.out.writeAll(")\n");
    }
};

fn dumpWasm(allocator: std.mem.Allocator, out: *std.Io.Writer, source: []const u8) !void {
    var dumper = Dumper{ .out = out, .allocator = allocator };
    defer if (dumper.types.len != 0) allocator.free(dumper.types);
    return try dumper.dumpModule(source);
}

pub fn main() !void {
    var args = std.process.args();
    const exe = args.next() orelse @panic("expected executable name");
    const file_path = args.next() orelse {
        std.debug.print("Usage: {s} <file.wasm>\n", .{exe});
        return;
    };

    const allocator = std.heap.page_allocator;

    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        file_path,
        std.math.maxInt(usize),
    );
    defer allocator.free(source);

    const out_file = std.fs.File.stdout();
    var out_writer = out_file.writer(&.{});
    try dumpWasm(allocator, &out_writer.interface, source);
}
