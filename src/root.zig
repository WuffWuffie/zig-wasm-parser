const std = @import("std");
const Allocator = std.mem.Allocator;

pub const op = @import("inst.zig");

pub const element_type: u8 = 0x70;
pub const function_type: u8 = 0x60;
pub const result_type: u8 = 0x40;

pub const SectionKind = enum(u8) {
    custom,
    type,
    import,
    func,
    table,
    memory,
    global,
    @"export",
    start,
    element,
    code,
    data,
    data_count,
    _,
};

pub const ValueType = enum(u8) {
    i32 = 0x7F,
    i64 = 0x7E,
    f32 = 0x7D,
    f64 = 0x7C,
    v128 = 0x7B,
};

pub const BlockType = enum(i32) {
    i32 = -1,
    i64 = -2,
    f32 = -3,
    f64 = -4,
    v128 = -5,
    empty = -64,
    _,

    pub fn read(reader: *Reader) Reader.Error!BlockType {
        return reader.readEnum(BlockType);
    }
};

pub const RefType = enum(i7) {
    funcref = -16,
    externref = -17,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{t}", .{self});
    }
};

pub const ExternalKind = enum(u8) {
    function,
    table,
    memory,
    global,
};

pub const CustomData = struct {
    name: []const u8,
    data: []const u8,
};

pub const Limits = struct {
    min: u32,
    max: ?u32,

    pub fn read(reader: *Reader) Reader.Error!Limits {
        const flags = try reader.read(u8);
        var limits: Limits = undefined;
        limits.min = try reader.readLeb(u32);
        if (flags & 1 != 0) {
            limits.max = try reader.readLeb(u32);
        } else {
            limits.max = null;
        }
        return limits;
    }
};

pub const Table = struct {
    type: RefType,
    limits: Limits,

    pub fn read(reader: *Reader) Reader.Error!Table {
        return Table{
            .type = try reader.readEnum(RefType),
            .limits = try Limits.read(reader),
        };
    }
};

pub const Mutability = enum(u8) {
    immutable,
    mutable,
};

pub const GlobalType = struct {
    type: ValueType,
    mut: Mutability,

    pub fn read(reader: *Reader) Reader.Error!GlobalType {
        return GlobalType{
            .type = try reader.readEnum(ValueType),
            .mut = try reader.readEnum(Mutability),
        };
    }
};

pub const ImportKind = union(enum) {
    function: u32,
    table: Table,
    memory: Limits,
    global: GlobalType,
};

pub const Import = struct {
    lib: []const u8,
    name: []const u8,
    kind: ImportKind,
};

pub const Export = struct {
    name: []const u8,
    index: u32,
    kind: ExternalKind,
};

pub const FuncType = struct {
    params: []const ValueType,
    results: []const ValueType,
};

pub const IdReader = struct {
    reader: *Reader,
    count: u32,

    pub fn next(self: *IdReader) Reader.Error!?u32 {
        if (self.count == 0) return null;
        self.count -= 1;
        return try self.reader.readLeb(u32);
    }
};

pub const CodeReader = struct {
    reader: Reader,
    local_count: u32,

    pub fn local(self: *CodeReader) Reader.Error!?struct { u32, ValueType } {
        if (self.local_count == 0) return null;
        self.local_count -= 1;
        return .{
            try self.reader.readLeb(u32),
            try self.reader.readEnum(ValueType),
        };
    }
};

pub const Reader = struct {
    pub const Error = error{ OutOfMemory, ParseError };

    ptr: [*]const u8,
    end: [*]const u8,

    inline fn ensureBytes(self: *Reader, n: usize) Error!void {
        if (n > @intFromPtr(self.end) - @intFromPtr(self.ptr)) {
            return error.ParseError;
        }
    }

    fn readRaw(self: *Reader, len: usize) Error![*]const u8 {
        try self.ensureBytes(len);
        const ptr = self.ptr;
        self.ptr += len;
        return ptr;
    }

    pub inline fn readArrRef(self: *Reader, comptime len: usize) Error!*const [len]u8 {
        const ptr = try self.readRaw(len);
        return ptr[0..len];
    }

    pub inline fn readSlice(self: *Reader, len: usize) Error![]const u8 {
        const ptr = try self.readRaw(len);
        return ptr[0..len];
    }

    pub inline fn readArr(self: *Reader, comptime len: usize) Error![len]u8 {
        const ptr = try self.readArrRef(len);
        return ptr.*;
    }

    pub fn remaining(self: *Reader) []const u8 {
        const len = @intFromPtr(self.end) - @intFromPtr(self.ptr);
        return self.ptr[0..len];
    }

    pub fn read(self: *Reader, comptime Int: type) Error!Int {
        const bytes = try self.readArr(@sizeOf(Int));
        return std.mem.littleToNative(Int, @bitCast(bytes));
    }

    pub fn readLeb(self: *Reader, comptime Int: type) Error!Int {
        const UInt = std.meta.Int(.unsigned, @typeInfo(Int).int.bits);
        const ShiftUInt = std.math.Log2Int(UInt);
        if (@typeInfo(Int).int.signedness == .unsigned) {
            var result: Int = 0;
            var shift: ShiftUInt = 0;
            while (true) {
                const byte = try self.read(u8);
                result |= @as(Int, byte & 0x7F) << shift;
                if ((byte & 0x80) == 0) return result;
                shift += 7;
                if (shift >= @bitSizeOf(Int)) return error.ParseError;
            }
        } else {
            var result: UInt = 0;
            var shift: ShiftUInt = 0;
            while (true) {
                const byte = try self.read(u8);
                result |= @as(UInt, byte & 0x7F) << shift;
                if ((byte & 0x80) == 0) {
                    if (shift < @bitSizeOf(UInt) and (byte & 0x40) != 0) {
                        result |= ~@as(UInt, 0) << shift;
                    }
                    return @bitCast(result);
                }
                shift += 7;
                if (shift >= @bitSizeOf(UInt)) return error.ParseError;
            }
        }
    }

    pub fn readSliceDyn(self: *Reader) Error![]const u8 {
        const length = try self.readLeb(u32);
        return try self.readSlice(length);
    }

    pub fn subReader(self: *Reader) Error!Reader {
        const len = try self.readLeb(u32);
        try self.ensureBytes(len);
        const start = self.ptr;
        const end = self.ptr + len;
        self.ptr = end;
        return Reader{ .ptr = start, .end = end };
    }

    pub fn readEnum(self: *Reader, comptime T: type) Error!T {
        const UInt = std.meta.Int(.unsigned, @bitSizeOf(T));
        const AlignedInt = std.meta.Int(.unsigned, (@bitSizeOf(T) + 7) / 8 * 8);
        const val = try self.read(AlignedInt);
        const tag: @typeInfo(T).@"enum".tag_type = @bitCast(@as(UInt, @truncate(val)));
        return std.enums.fromInt(T, tag) orelse return error.ParseError;
    }

    pub fn readValTypeList(self: *Reader) Error![]const ValueType {
        return @ptrCast(try self.readSliceDyn());
    }

    pub const inst = op.parse;
};

pub const TypeSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *TypeSection) Reader.Error!?FuncType {
        if (self.count == 0) return null;
        self.count -= 1;
        const ty = try self.reader.read(u8);
        if (ty != function_type) return error.ParseError;
        return FuncType{
            .params = try self.reader.readValTypeList(),
            .results = try self.reader.readValTypeList(),
        };
    }
};

pub const ImportSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *ImportSection) Reader.Error!?Import {
        if (self.count == 0) return null;
        self.count -= 1;

        const lib = try self.reader.readSliceDyn();
        const name = try self.reader.readSliceDyn();

        const ext_kind = try self.reader.readEnum(ExternalKind);
        const kind: ImportKind = switch (ext_kind) {
            .function => .{ .function = try self.reader.readLeb(u32) },
            .table => .{ .table = try Table.read(&self.reader) },
            .memory => .{ .memory = try Limits.read(&self.reader) },
            .global => .{ .global = try GlobalType.read(&self.reader) },
        };

        return Import{
            .lib = lib,
            .name = name,
            .kind = kind,
        };
    }
};

pub const FuncSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *FuncSection) Reader.Error!?u32 {
        if (self.count == 0) return null;
        self.count -= 1;
        return try self.reader.readLeb(u32);
    }
};

pub const TableSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *TableSection) Reader.Error!?Table {
        if (self.count == 0) return null;
        self.count -= 1;
        return try Table.read(&self.reader);
    }
};

pub const MemorySection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *MemorySection) Reader.Error!?Limits {
        if (self.count == 0) return null;
        self.count -= 1;
        return try Limits.read(&self.reader);
    }
};

pub const GlobalSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *GlobalSection) Reader.Error!?struct { GlobalType, *Reader } {
        if (self.count == 0) return null;
        self.count -= 1;
        const ty = try GlobalType.read(&self.reader);
        return .{ ty, &self.reader };
    }
};

pub const ExportSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *ExportSection) Reader.Error!?Export {
        if (self.count == 0) return null;
        self.count -= 1;
        return Export{
            .name = try self.reader.readSliceDyn(),
            .kind = try self.reader.readEnum(ExternalKind),
            .index = try self.reader.readLeb(u32),
        };
    }
};

pub const ElementSection = struct {
    reader: Reader,
    count: u32,

    pub fn insts(self: *ElementSection) Reader.Error!?*Reader {
        if (self.count == 0) return null;
        self.count -= 1;
        const flag = try self.reader.read(u8);
        if (flag != 0) return error.ParseError;
        return &self.reader;
    }

    pub fn funcs(self: *ElementSection) Reader.Error!IdReader {
        return IdReader{
            .count = try self.reader.readLeb(u32),
            .reader = &self.reader,
        };
    }
};

pub const CodeSection = struct {
    reader: Reader,
    count: u32,

    pub fn next(self: *CodeSection) Reader.Error!?CodeReader {
        if (self.count == 0) return null;
        self.count -= 1;
        var inner = try self.reader.subReader();
        return CodeReader{
            .local_count = try inner.readLeb(u32),
            .reader = inner,
        };
    }
};

pub const DataSection = struct {
    reader: Reader,
    count: u32,

    pub fn memoryIndex(self: *DataSection) Reader.Error!?u32 {
        if (self.count == 0) return null;
        self.count -= 1;
        return try self.reader.readLeb(u32);
    }

    pub fn data(self: *DataSection) Reader.Error![]const u8 {
        return try self.reader.readSliceDyn();
    }
};

pub const OtherSection = struct {
    kind: SectionKind,
    reader: Reader,

    pub fn custom(self: *OtherSection) Reader.Error!struct { []const u8, []const u8 } {
        return .{ try self.reader.readSliceDyn(), self.reader.remaining() };
    }
};

pub const Section = union(enum) {
    type: TypeSection,
    import: ImportSection,
    func: FuncSection,
    table: TableSection,
    memory: MemorySection,
    global: GlobalSection,
    @"export": ExportSection,
    start: u32,
    element: ElementSection,
    code: CodeSection,
    data: DataSection,
    data_count: u32,
    other: OtherSection,
};

pub const Parser = struct {
    reader: Reader,

    pub fn init(source: []const u8) Reader.Error!Parser {
        var self = Parser{ .reader = .{
            .ptr = source.ptr,
            .end = source.ptr + source.len,
        } };

        const magic = try self.reader.read(u32);
        if (magic != 0x6d736100) return error.ParseError;
        const version = try self.reader.read(u32);
        if (version > 2) return error.ParseError;

        return self;
    }

    pub fn next(self: *Parser) Reader.Error!?Section {
        if (self.reader.ptr == self.reader.end) return null;

        const kind = try self.reader.readEnum(SectionKind);
        var reader = try self.reader.subReader();
        return switch (kind) {
            .type => .{ .type = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .import => .{ .import = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .func => .{ .func = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .table => .{ .table = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .memory => .{ .memory = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .global => .{ .global = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .@"export" => .{ .@"export" = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .start => .{ .start = try reader.readLeb(u32) },
            .element => .{ .element = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .code => .{ .code = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .data => .{ .data = .{
                .count = try reader.readLeb(u32),
                .reader = reader,
            } },
            .data_count => .{ .data_count = try reader.readLeb(u32) },
            else => .{ .other = .{
                .kind = kind,
                .reader = reader,
            } },
        };
    }
};
