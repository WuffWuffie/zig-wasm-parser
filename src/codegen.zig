//! Generate the instruction parsing code from opcode.def defined in WABT library.
//! Run with `zig build gen_opcodes`
//! Outputs to `src/inst.zig`

const std = @import("std");

const inst_data = @import("inst_data.zig");

const TypeKind = union(enum) {
    void,
    u32,
    i32,
    i64,
    f32,
    f64,
    u128,
    other: []const u8,
};

const InstCodeTuple = struct { []const u8, u32, TypeKind };

fn codeLessThan(_: void, a: InstCodeTuple, b: InstCodeTuple) bool {
    return a.@"1" < b.@"1";
}

const types = b: {
    @setEvalBranchQuota(1_000_000);
    var res: []const struct { []const u8, TypeKind } = &.{};
    for (@typeInfo(inst_data).@"struct".decls) |decl| {
        const kind: TypeKind = switch (@field(inst_data, decl.name)) {
            void => .void,
            u32 => .u32,
            i32 => .i32,
            i64 => .i64,
            f32 => .f32,
            f64 => .f64,
            u128 => .u128,
            else => |Type| k: {
                const idx = std.mem.lastIndexOfScalar(u8, @typeName(Type), '.');
                break :k .{ .other = @typeName(Type)[(idx orelse unreachable) + 1 ..] };
            },
        };
        res = res ++ .{.{ decl.name, kind }};
    }
    break :b res;
};

pub fn printInstParser(out: *std.Io.Writer, indent: []const u8, info: InstCodeTuple) !void {
    const field, const id, const kind = info;
    try out.print("{s}0x{X} => ", .{ indent, id });
    switch (kind) {
        .void => try out.print(".{f}", .{std.zig.fmtId(field)}),
        .u32 => try out.print(".{{ .{f} = try reader.readLeb(u32) }}", .{std.zig.fmtId(field)}),
        .i32 => try out.print(".{{ .{f} = try reader.readLeb(i32) }}", .{std.zig.fmtId(field)}),
        .i64 => try out.print(".{{ .{f} = try reader.readLeb(i64) }}", .{std.zig.fmtId(field)}),
        .f32 => try out.print(".{{ .{f} = try reader.read(f32) }}", .{std.zig.fmtId(field)}),
        .f64 => try out.print(".{{ .{f} = try reader.read(f64) }}", .{std.zig.fmtId(field)}),
        .u128 => try out.print(".{{ .{f} = try reader.read(u128) }}", .{std.zig.fmtId(field)}),
        .other => |type_name| try out.print(
            ".{{ .{f} = try data.{s}.read(reader) }}",
            .{ std.zig.fmtId(field), type_name },
        ),
    }
    try out.writeAll(",\n");
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const cwd = std.fs.cwd();

    const data = try cwd.readFileAlloc(
        allocator,
        "wabt/include/wabt/opcode.def",
        std.math.maxInt(usize),
    );

    var opcodes: std.ArrayList(struct { []const u8, []const u8, TypeKind }) = .empty;
    var opcodes_prefix: std.ArrayList(InstCodeTuple) = .empty;
    var opcodes_misc: std.ArrayList(InstCodeTuple) = .empty;
    var opcodes_simd: std.ArrayList(InstCodeTuple) = .empty;
    var opcodes_atomic: std.ArrayList(InstCodeTuple) = .empty;

    var lines = std.mem.splitAny(u8, data, "\r\n");
    while (lines.next()) |line_raw| {
        const start = "WABT_OPCODE(";
        const end = ")";
        if (std.mem.startsWith(u8, line_raw, start) and
            std.mem.endsWith(u8, line_raw, end))
        {
            const line = line_raw[start.len .. line_raw.len - end.len];

            var parts: [10][]const u8 = undefined;
            var parts_iter = std.mem.tokenizeAny(u8, line, " ,");
            for (&parts) |*dst| {
                dst.* = parts_iter.next() orelse @panic("");
            }

            const prefix = try std.fmt.parseInt(u8, parts[5], 0);
            const code = try std.fmt.parseInt(u32, parts[6], 0);
            const name = parts[7];
            const text = parts[8];

            var field = try std.json.parseFromSliceLeaky([]const u8, allocator, text, .{});
            if (std.mem.eql(u8, name, "SelectT")) field = "select.t";
            field = try std.mem.replaceOwned(u8, allocator, field, ".", "_");

            const kind: TypeKind = for (types) |typ_pair| {
                if (std.mem.eql(u8, typ_pair.@"0", field)) {
                    break typ_pair.@"1";
                }
            } else {
                std.debug.print("not found: {s}\n", .{field});
                continue;
            };

            std.debug.print("ok: {s}\n", .{field});

            try opcodes.append(allocator, .{ field, text, kind });
            switch (prefix) {
                0 => try opcodes_prefix.append(allocator, .{ field, code, kind }),
                0xFC => try opcodes_misc.append(allocator, .{ field, code, kind }),
                0xFD => try opcodes_simd.append(allocator, .{ field, code, kind }),
                0xFE => try opcodes_atomic.append(allocator, .{ field, code, kind }),
                else => @panic(""),
            }
        }
    }

    std.mem.sortUnstable(InstCodeTuple, opcodes_prefix.items, {}, codeLessThan);
    std.mem.sortUnstable(InstCodeTuple, opcodes_misc.items, {}, codeLessThan);
    std.mem.sortUnstable(InstCodeTuple, opcodes_simd.items, {}, codeLessThan);
    std.mem.sortUnstable(InstCodeTuple, opcodes_atomic.items, {}, codeLessThan);

    const out_file = try cwd.createFile("src/inst.zig", .{});
    defer out_file.close();
    var out_writer = out_file.writer(&.{});
    const out = &out_writer.interface;

    try out.writeAll(
        \\//! Do not edit manually!
        \\//!
        \\//! This file is generated by `codegen.zig`.
        \\
        \\const std = @import("std");
        \\const wasm = @import("root.zig");
        \\const data = @import("inst_data.zig");
        \\const Reader = wasm.Reader;
        \\
        \\pub const InstKind = @typeInfo(Inst).@"union".tag_type.?;
        \\
        \\pub const Inst = union(enum) {
        \\
    );

    for (opcodes.items) |value| {
        const field, _, const kind = value;
        try out.print("    {f}", .{std.zig.fmtId(field)});
        switch (kind) {
            .void => try out.print(",\n", .{}),
            .u32 => try out.print(": u32,\n", .{}),
            .i32 => try out.print(": i32,\n", .{}),
            .i64 => try out.print(": i64,\n", .{}),
            .f32 => try out.print(": f32,\n", .{}),
            .f64 => try out.print(": f64,\n", .{}),
            .u128 => try out.print(": u128,\n", .{}),
            .other => |name| try out.print(": data.{s},\n", .{name}),
        }
    }

    try out.writeAll(
        \\
        \\    pub fn format(
        \\        self: *const Inst,
        \\        writer: *std.Io.Writer,
        \\    ) std.Io.Writer.Error!void {
        \\        switch (self.*) {
        \\
    );
    for (opcodes.items) |value| {
        const field, _, const kind = value;
        switch (kind) {
            .void => {},
            .u32, .i32, .i64, .f32, .f64, .u128 => try out.print(
                "            .{f} => |val| try writer.print(\" {{}}\", .{{val}}),\n",
                .{std.zig.fmtId(field)},
            ),
            .other => try out.print(
                "            .{f} => |*val| try val.format(writer),\n",
                .{std.zig.fmtId(field)},
            ),
        }
    }
    try out.writeAll(
        \\            else => {},
        \\        }
        \\    }
        \\};
        \\
    );

    try out.writeAll(
        \\
        \\pub fn name(inst: InstKind) []const u8 {
        \\    return ([_][]const u8{
        \\
    );
    for (opcodes.items) |value| {
        try out.print("        {s},\n", .{value[1]});
    }
    try out.writeAll(
        \\    })[@intFromEnum(inst)];
        \\}
        \\
        \\pub fn parse(reader: *Reader) !Inst {
        \\    return switch (try reader.read(u8)) {
        \\
    );

    for (opcodes_prefix.items) |info| {
        try printInstParser(out, "        ", info);
    }

    if (opcodes_misc.items.len != 0) {
        try out.writeAll("        0xFC => switch (try reader.readLeb(u32)) {\n");
        for (opcodes_misc.items) |info| {
            try printInstParser(out, "            ", info);
        }
        try out.writeAll("            else => error.ParseError,\n");
        try out.writeAll("        },\n");
    }

    if (opcodes_simd.items.len != 0) {
        try out.writeAll("        0xFD => switch (try reader.readLeb(u32)) {\n");
        for (opcodes_simd.items) |info| {
            try printInstParser(out, "            ", info);
        }
        try out.writeAll("            else => error.ParseError,\n");
        try out.writeAll("        },\n");
    }

    if (opcodes_atomic.items.len != 0) {
        try out.writeAll("        0xFE => switch (try reader.readLeb(u32)) {\n");
        for (opcodes_atomic.items) |info| {
            try printInstParser(out, "            ", info);
        }
        try out.writeAll("            else => error.ParseError,\n");
        try out.writeAll("        },\n");
    }

    try out.writeAll(
        \\        else => error.ParseError,
        \\    };
        \\}
        \\
    );
}
