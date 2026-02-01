const std = @import("std");
const wasm = @import("root.zig");
const Reader = wasm.Reader;

pub const BlockType = wasm.BlockType;

pub const BrTable = struct {
    reader: *Reader,

    pub fn format(self: *const BrTable, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var iter = self.branches() catch return error.WriteFailed;
        while (iter.next() catch return error.WriteFailed) |idx| {
            try writer.print(" {}", .{idx});
        }
        try writer.print(" {}", .{self.default() catch return error.WriteFailed});
    }

    pub fn read(reader: *Reader) Reader.Error!BrTable {
        return BrTable{ .reader = reader };
    }

    pub fn branches(self: BrTable) Reader.Error!wasm.IdReader {
        return .{
            .count = try self.reader.readLeb(u32),
            .reader = self.reader,
        };
    }

    pub fn default(self: BrTable) Reader.Error!u32 {
        return try self.reader.readLeb(u32);
    }
};

pub const TableOp = struct {
    a: u32,
    b: u32,

    pub fn format(self: *const TableOp, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print(" {} {}", .{ self.a, self.b });
    }

    pub fn read(reader: *Reader) Reader.Error!TableOp {
        return TableOp{
            .a = try reader.readLeb(u32),
            .b = try reader.readLeb(u32),
        };
    }
};

pub const SelectT = struct {
    types: []const wasm.ValueType,

    pub fn format(self: *const SelectT, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("(result", .{});
        for (self.types) |ty| {
            try writer.print(" {s}", .{@tagName(ty)});
        }
        try writer.print(")", .{});
    }

    pub fn read(reader: *Reader) Reader.Error!SelectT {
        return SelectT{ .types = try reader.readValTypeList() };
    }
};

pub const MemOp = struct {
    alignment: u32,
    offset: u32,

    pub fn format(self: *const MemOp, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print(" align={} offset={}", .{ self.alignment, self.offset });
    }

    pub fn read(reader: *Reader) Reader.Error!MemOp {
        return MemOp{
            .alignment = try reader.readLeb(u32),
            .offset = try reader.readLeb(u32),
        };
    }
};

pub const VecShuffle = struct {
    indices: [16]u8,

    pub fn format(self: *const VecShuffle, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        for (self.indices) |index| {
            try writer.print(" {}", .{index});
        }
    }

    pub fn read(reader: *Reader) Reader.Error!VecShuffle {
        return VecShuffle{ .indices = try reader.readArr(16) };
    }
};

pub const LaneOp = struct {
    lane: u8,

    pub fn format(
        self: *const LaneOp,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print(" lane={}", .{self.lane});
    }

    pub fn read(reader: *Reader) Reader.Error!LaneOp {
        return LaneOp{ .lane = try reader.read(u8) };
    }
};

pub const MemLaneOp = struct {
    memop: MemOp,
    lane: u8,

    pub fn format(self: *const MemLaneOp, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{f} lane={}", .{ self.memop, self.lane });
    }

    pub fn read(reader: *Reader) Reader.Error!MemLaneOp {
        return MemLaneOp{
            .memop = try MemOp.read(reader),
            .lane = try reader.read(u8),
        };
    }
};

pub const @"unreachable" = void;
pub const nop = void;
pub const block = wasm.BlockType;
pub const loop = wasm.BlockType;
pub const @"if" = wasm.BlockType;
pub const @"else" = void;

// pub const try = void;
// pub const catch = void;
// pub const throw = void;
// pub const rethrow = void;
// pub const throw_ref = void;

pub const end = void;
pub const br = u32;
pub const br_if = u32;
pub const br_table = BrTable;
pub const @"return" = void;

pub const call = u32;
pub const call_indirect = TableOp;
pub const return_call = u32;
pub const return_call_indirect = TableOp;

// pub const call_ref = void;
// pub const return_call_ref = void;
// pub const delegate = void;
// pub const catch_all = void;

pub const drop = void;
pub const select = void;
pub const select_t = SelectT;

// pub const try_table = void;

pub const local_get = u32;
pub const local_set = u32;
pub const local_tee = u32;
pub const global_get = u32;
pub const global_set = u32;
pub const i32_load = MemOp;
pub const i64_load = MemOp;
pub const f32_load = MemOp;
pub const f64_load = MemOp;
pub const i32_load8_s = MemOp;
pub const i32_load8_u = MemOp;
pub const i32_load16_s = MemOp;
pub const i32_load16_u = MemOp;
pub const i64_load8_s = MemOp;
pub const i64_load8_u = MemOp;
pub const i64_load16_s = MemOp;
pub const i64_load16_u = MemOp;
pub const i64_load32_s = MemOp;
pub const i64_load32_u = MemOp;
pub const i32_store = MemOp;
pub const i64_store = MemOp;
pub const f32_store = MemOp;
pub const f64_store = MemOp;
pub const i32_store8 = MemOp;
pub const i32_store16 = MemOp;
pub const i64_store8 = MemOp;
pub const i64_store16 = MemOp;
pub const i64_store32 = MemOp;
pub const memory_size = u32;
pub const memory_grow = u32;
pub const i32_const = i32;
pub const i64_const = i64;
pub const f32_const = f32;
pub const f64_const = f64;

pub const i32_eqz = void;
pub const i32_eq = void;
pub const i32_ne = void;
pub const i32_lt_s = void;
pub const i32_lt_u = void;
pub const i32_gt_s = void;
pub const i32_gt_u = void;
pub const i32_le_s = void;
pub const i32_le_u = void;
pub const i32_ge_s = void;
pub const i32_ge_u = void;
pub const i64_eqz = void;
pub const i64_eq = void;
pub const i64_ne = void;
pub const i64_lt_s = void;
pub const i64_lt_u = void;
pub const i64_gt_s = void;
pub const i64_gt_u = void;
pub const i64_le_s = void;
pub const i64_le_u = void;
pub const i64_ge_s = void;
pub const i64_ge_u = void;
pub const f32_eq = void;
pub const f32_ne = void;
pub const f32_lt = void;
pub const f32_gt = void;
pub const f32_le = void;
pub const f32_ge = void;
pub const f64_eq = void;
pub const f64_ne = void;
pub const f64_lt = void;
pub const f64_gt = void;
pub const f64_le = void;
pub const f64_ge = void;
pub const i32_clz = void;
pub const i32_ctz = void;
pub const i32_popcnt = void;
pub const i32_add = void;
pub const i32_sub = void;
pub const i32_mul = void;
pub const i32_div_s = void;
pub const i32_div_u = void;
pub const i32_rem_s = void;
pub const i32_rem_u = void;
pub const i32_and = void;
pub const i32_or = void;
pub const i32_xor = void;
pub const i32_shl = void;
pub const i32_shr_s = void;
pub const i32_shr_u = void;
pub const i32_rotl = void;
pub const i32_rotr = void;
pub const i64_clz = void;
pub const i64_ctz = void;
pub const i64_popcnt = void;
pub const i64_add = void;
pub const i64_sub = void;
pub const i64_mul = void;
pub const i64_div_s = void;
pub const i64_div_u = void;
pub const i64_rem_s = void;
pub const i64_rem_u = void;
pub const i64_and = void;
pub const i64_or = void;
pub const i64_xor = void;
pub const i64_shl = void;
pub const i64_shr_s = void;
pub const i64_shr_u = void;
pub const i64_rotl = void;
pub const i64_rotr = void;
pub const f32_abs = void;
pub const f32_neg = void;
pub const f32_ceil = void;
pub const f32_floor = void;
pub const f32_trunc = void;
pub const f32_nearest = void;
pub const f32_sqrt = void;
pub const f32_add = void;
pub const f32_sub = void;
pub const f32_mul = void;
pub const f32_div = void;
pub const f32_min = void;
pub const f32_max = void;
pub const f32_copysign = void;
pub const f64_abs = void;
pub const f64_neg = void;
pub const f64_ceil = void;
pub const f64_floor = void;
pub const f64_trunc = void;
pub const f64_nearest = void;
pub const f64_sqrt = void;
pub const f64_add = void;
pub const f64_sub = void;
pub const f64_mul = void;
pub const f64_div = void;
pub const f64_min = void;
pub const f64_max = void;
pub const f64_copysign = void;
pub const i32_wrap_i64 = void;
pub const i32_trunc_f32_s = void;
pub const i32_trunc_f32_u = void;
pub const i32_trunc_f64_s = void;
pub const i32_trunc_f64_u = void;
pub const i64_extend_i32_s = void;
pub const i64_extend_i32_u = void;
pub const i64_trunc_f32_s = void;
pub const i64_trunc_f32_u = void;
pub const i64_trunc_f64_s = void;
pub const i64_trunc_f64_u = void;
pub const f32_convert_i32_s = void;
pub const f32_convert_i32_u = void;
pub const f32_convert_i64_s = void;
pub const f32_convert_i64_u = void;
pub const f32_demote_f64 = void;
pub const f64_convert_i32_s = void;
pub const f64_convert_i32_u = void;
pub const f64_convert_i64_s = void;
pub const f64_convert_i64_u = void;
pub const f64_promote_f32 = void;
pub const i32_reinterpret_f32 = void;
pub const i64_reinterpret_f64 = void;
pub const f32_reinterpret_i32 = void;
pub const f64_reinterpret_i64 = void;

// Sign-extension opcodes (--enable-sign-extension)
pub const i32_extend8_s = void;
pub const i32_extend16_s = void;
pub const i64_extend8_s = void;
pub const i64_extend16_s = void;
pub const i64_extend32_s = void;

// Interpreter-only opcodes
// pub const alloca = void;
// pub const br_unless = void;
// pub const call_import = void;
// pub const data = void;
// pub const drop_keep = void;
// pub const catch_drop = void;
// pub const adjust_frame_for_return_call = void;
// pub const global_get_ref = void;
// pub const local_get_ref = void;
// pub const mark_ref = void;

// Saturating float-to-int opcodes (--enable-saturating-float-to-int)
pub const i32_trunc_sat_f32_s = void;
pub const i32_trunc_sat_f32_u = void;
pub const i32_trunc_sat_f64_s = void;
pub const i32_trunc_sat_f64_u = void;
pub const i64_trunc_sat_f32_s = void;
pub const i64_trunc_sat_f32_u = void;
pub const i64_trunc_sat_f64_s = void;
pub const i64_trunc_sat_f64_u = void;

// Bulk-memory
pub const memory_init = u32;
pub const data_drop = u32;
pub const memory_copy = void;
pub const memory_fill = void;
pub const table_init = TableOp;
pub const elem_drop = u32;
pub const table_copy = TableOp;

// Reference types
pub const table_get = u32;
pub const table_set = u32;
pub const table_grow = u32;
pub const table_size = u32;
pub const table_fill = u32;
// pub const ref_null = void;
// pub const ref_is_null = void;
// pub const ref_func = void;
// pub const ref_as_non_null = void;
// pub const br_on_null = void;
// pub const br_on_non_null = void;

// Simd opcodes
pub const v128_load = MemOp;
pub const v128_load8x8_s = MemOp;
pub const v128_load8x8_u = MemOp;
pub const v128_load16x4_s = MemOp;
pub const v128_load16x4_u = MemOp;
pub const v128_load32x2_s = MemOp;
pub const v128_load32x2_u = MemOp;
pub const v128_load8_splat = MemOp;
pub const v128_load16_splat = MemOp;
pub const v128_load32_splat = MemOp;
pub const v128_load64_splat = MemOp;
pub const v128_store = MemOp;
pub const v128_const = u128;
pub const i8x16_shuffle = VecShuffle;
pub const i8x16_swizzle = void;
pub const i8x16_splat = void;
pub const i16x8_splat = void;
pub const i32x4_splat = void;
pub const i64x2_splat = void;
pub const f32x4_splat = void;
pub const f64x2_splat = void;
pub const i8x16_extract_lane_s = LaneOp;
pub const i8x16_extract_lane_u = LaneOp;
pub const i8x16_replace_lane = LaneOp;
pub const i16x8_extract_lane_s = LaneOp;
pub const i16x8_extract_lane_u = LaneOp;
pub const i16x8_replace_lane = LaneOp;
pub const i32x4_extract_lane = LaneOp;
pub const i32x4_replace_lane = LaneOp;
pub const i64x2_extract_lane = LaneOp;
pub const i64x2_replace_lane = LaneOp;
pub const f32x4_extract_lane = LaneOp;
pub const f32x4_replace_lane = LaneOp;
pub const f64x2_extract_lane = LaneOp;
pub const f64x2_replace_lane = LaneOp;
pub const i8x16_eq = void;
pub const i8x16_ne = void;
pub const i8x16_lt_s = void;
pub const i8x16_lt_u = void;
pub const i8x16_gt_s = void;
pub const i8x16_gt_u = void;
pub const i8x16_le_s = void;
pub const i8x16_le_u = void;
pub const i8x16_ge_s = void;
pub const i8x16_ge_u = void;
pub const i16x8_eq = void;
pub const i16x8_ne = void;
pub const i16x8_lt_s = void;
pub const i16x8_lt_u = void;
pub const i16x8_gt_s = void;
pub const i16x8_gt_u = void;
pub const i16x8_le_s = void;
pub const i16x8_le_u = void;
pub const i16x8_ge_s = void;
pub const i16x8_ge_u = void;
pub const i32x4_eq = void;
pub const i32x4_ne = void;
pub const i32x4_lt_s = void;
pub const i32x4_lt_u = void;
pub const i32x4_gt_s = void;
pub const i32x4_gt_u = void;
pub const i32x4_le_s = void;
pub const i32x4_le_u = void;
pub const i32x4_ge_s = void;
pub const i32x4_ge_u = void;
pub const f32x4_eq = void;
pub const f32x4_ne = void;
pub const f32x4_lt = void;
pub const f32x4_gt = void;
pub const f32x4_le = void;
pub const f32x4_ge = void;
pub const f64x2_eq = void;
pub const f64x2_ne = void;
pub const f64x2_lt = void;
pub const f64x2_gt = void;
pub const f64x2_le = void;
pub const f64x2_ge = void;
pub const v128_not = void;
pub const v128_and = void;
pub const v128_andnot = void;
pub const v128_or = void;
pub const v128_xor = void;
pub const v128_bitselect = void;
pub const v128_any_true = void;
pub const v128_load8_lane = MemLaneOp;
pub const v128_load16_lane = MemLaneOp;
pub const v128_load32_lane = MemLaneOp;
pub const v128_load64_lane = MemLaneOp;
pub const v128_store8_lane = MemLaneOp;
pub const v128_store16_lane = MemLaneOp;
pub const v128_store32_lane = MemLaneOp;
pub const v128_store64_lane = MemLaneOp;
pub const v128_load32_zero = MemOp;
pub const v128_load64_zero = MemOp;
pub const f32x4_demote_f64x2_zero = void;
pub const f64x2_promote_low_f32x4 = void;
pub const i8x16_abs = void;
pub const i8x16_neg = void;
pub const i8x16_popcnt = void;
pub const i8x16_all_true = void;
pub const i8x16_bitmask = void;
pub const i8x16_narrow_i16x8_s = void;
pub const i8x16_narrow_i16x8_u = void;
pub const i8x16_shl = void;
pub const i8x16_shr_s = void;
pub const i8x16_shr_u = void;
pub const i8x16_add = void;
pub const i8x16_add_sat_s = void;
pub const i8x16_add_sat_u = void;
pub const i8x16_sub = void;
pub const i8x16_sub_sat_s = void;
pub const i8x16_sub_sat_u = void;
pub const i8x16_min_s = void;
pub const i8x16_min_u = void;
pub const i8x16_max_s = void;
pub const i8x16_max_u = void;
pub const i8x16_avgr_u = void;
pub const i16x8_extadd_pairwise_i8x16_s = void;
pub const i16x8_extadd_pairwise_i8x16_u = void;
pub const i32x4_extadd_pairwise_i16x8_s = void;
pub const i32x4_extadd_pairwise_i16x8_u = void;
pub const i16x8_abs = void;
pub const i16x8_neg = void;
pub const i16x8_q15mulr_sat_s = void;
pub const i16x8_all_true = void;
pub const i16x8_bitmask = void;
pub const i16x8_narrow_i32x4_s = void;
pub const i16x8_narrow_i32x4_u = void;
pub const i16x8_extend_low_i8x16_s = void;
pub const i16x8_extend_high_i8x16_s = void;
pub const i16x8_extend_low_i8x16_u = void;
pub const i16x8_extend_high_i8x16_u = void;
pub const i16x8_shl = void;
pub const i16x8_shr_s = void;
pub const i16x8_shr_u = void;
pub const i16x8_add = void;
pub const i16x8_add_sat_s = void;
pub const i16x8_add_sat_u = void;
pub const i16x8_sub = void;
pub const i16x8_sub_sat_s = void;
pub const i16x8_sub_sat_u = void;
pub const i16x8_mul = void;
pub const i16x8_min_s = void;
pub const i16x8_min_u = void;
pub const i16x8_max_s = void;
pub const i16x8_max_u = void;
pub const i16x8_avgr_u = void;
pub const i16x8_extmul_low_i8x16_s = void;
pub const i16x8_extmul_high_i8x16_s = void;
pub const i16x8_extmul_low_i8x16_u = void;
pub const i16x8_extmul_high_i8x16_u = void;
pub const i32x4_abs = void;
pub const i32x4_neg = void;
pub const i32x4_all_true = void;
pub const i32x4_bitmask = void;
pub const i32x4_extend_low_i16x8_s = void;
pub const i32x4_extend_high_i16x8_s = void;
pub const i32x4_extend_low_i16x8_u = void;
pub const i32x4_extend_high_i16x8_u = void;
pub const i32x4_shl = void;
pub const i32x4_shr_s = void;
pub const i32x4_shr_u = void;
pub const i32x4_add = void;
pub const i32x4_sub = void;
pub const i32x4_mul = void;
pub const i32x4_min_s = void;
pub const i32x4_min_u = void;
pub const i32x4_max_s = void;
pub const i32x4_max_u = void;
pub const i32x4_dot_i16x8_s = void;
pub const i32x4_extmul_low_i16x8_s = void;
pub const i32x4_extmul_high_i16x8_s = void;
pub const i32x4_extmul_low_i16x8_u = void;
pub const i32x4_extmul_high_i16x8_u = void;
pub const i64x2_abs = void;
pub const i64x2_neg = void;
pub const i64x2_all_true = void;
pub const i64x2_bitmask = void;
pub const i64x2_extend_low_i32x4_s = void;
pub const i64x2_extend_high_i32x4_s = void;
pub const i64x2_extend_low_i32x4_u = void;
pub const i64x2_extend_high_i32x4_u = void;
pub const i64x2_shl = void;
pub const i64x2_shr_s = void;
pub const i64x2_shr_u = void;
pub const i64x2_add = void;
pub const i64x2_sub = void;
pub const i64x2_mul = void;
pub const i64x2_eq = void;
pub const i64x2_ne = void;
pub const i64x2_lt_s = void;
pub const i64x2_gt_s = void;
pub const i64x2_le_s = void;
pub const i64x2_ge_s = void;
pub const i64x2_extmul_low_i32x4_s = void;
pub const i64x2_extmul_high_i32x4_s = void;
pub const i64x2_extmul_low_i32x4_u = void;
pub const i64x2_extmul_high_i32x4_u = void;
pub const f32x4_ceil = void;
pub const f32x4_floor = void;
pub const f32x4_trunc = void;
pub const f32x4_nearest = void;
pub const f64x2_ceil = void;
pub const f64x2_floor = void;
pub const f64x2_trunc = void;
pub const f64x2_nearest = void;
pub const f32x4_abs = void;
pub const f32x4_neg = void;
pub const f32x4_sqrt = void;
pub const f32x4_add = void;
pub const f32x4_sub = void;
pub const f32x4_mul = void;
pub const f32x4_div = void;
pub const f32x4_min = void;
pub const f32x4_max = void;
pub const f32x4_pmin = void;
pub const f32x4_pmax = void;
pub const f64x2_abs = void;
pub const f64x2_neg = void;
pub const f64x2_sqrt = void;
pub const f64x2_add = void;
pub const f64x2_sub = void;
pub const f64x2_mul = void;
pub const f64x2_div = void;
pub const f64x2_min = void;
pub const f64x2_max = void;
pub const f64x2_pmin = void;
pub const f64x2_pmax = void;
pub const i32x4_trunc_sat_f32x4_s = void;
pub const i32x4_trunc_sat_f32x4_u = void;
pub const f32x4_convert_i32x4_s = void;
pub const f32x4_convert_i32x4_u = void;
pub const i32x4_trunc_sat_f64x2_s_zero = void;
pub const i32x4_trunc_sat_f64x2_u_zero = void;
pub const f64x2_convert_low_i32x4_s = void;
pub const f64x2_convert_low_i32x4_u = void;

// Relaxed-SIMD opcodes
pub const i8x16_relaxed_swizzle = void;
pub const i32x4_relaxed_trunc_f32x4_s = void;
pub const i32x4_relaxed_trunc_f32x4_u = void;
pub const i32x4_relaxed_trunc_f64x2_s_zero = void;
pub const i32x4_relaxed_trunc_f64x2_u_zero = void;
pub const f32x4_relaxed_madd = void;
pub const f32x4_relaxed_nmadd = void;
pub const f64x2_relaxed_madd = void;
pub const f64x2_relaxed_nmadd = void;
pub const i8x16_relaxed_laneselect = void;
pub const i16x8_relaxed_laneselect = void;
pub const i32x4_relaxed_laneselect = void;
pub const i64x2_relaxed_laneselect = void;
pub const f32x4_relaxed_min = void;
pub const f32x4_relaxed_max = void;
pub const f64x2_relaxed_min = void;
pub const f64x2_relaxed_max = void;
pub const i16x8_relaxed_q15mulr_s = void;
pub const i16x8_relaxed_dot_i8x16_i7x16_s = void;
pub const i32x4_relaxed_dot_i8x16_i7x16_add_s = void;

// Thread opcodes (--enable-threads)
// pub const memory_atomic_notify = void;
// pub const memory_atomic_wait32 = void;
// pub const memory_atomic_wait64 = void;
// pub const atomic_fence = void;
// pub const i32_atomic_load = void;
// pub const i64_atomic_load = void;
// pub const i32_atomic_load8_u = void;
// pub const i32_atomic_load16_u = void;
// pub const i64_atomic_load8_u = void;
// pub const i64_atomic_load16_u = void;
// pub const i64_atomic_load32_u = void;
// pub const i32_atomic_store = void;
// pub const i64_atomic_store = void;
// pub const i32_atomic_store8 = void;
// pub const i32_atomic_store16 = void;
// pub const i64_atomic_store8 = void;
// pub const i64_atomic_store16 = void;
// pub const i64_atomic_store32 = void;
// pub const i32_atomic_rmw_add = void;
// pub const i64_atomic_rmw_add = void;
// pub const i32_atomic_rmw8_add_u = void;
// pub const i32_atomic_rmw16_add_u = void;
// pub const i64_atomic_rmw8_add_u = void;
// pub const i64_atomic_rmw16_add_u = void;
// pub const i64_atomic_rmw32_add_u = void;
// pub const i32_atomic_rmw_sub = void;
// pub const i64_atomic_rmw_sub = void;
// pub const i32_atomic_rmw8_sub_u = void;
// pub const i32_atomic_rmw16_sub_u = void;
// pub const i64_atomic_rmw8_sub_u = void;
// pub const i64_atomic_rmw16_sub_u = void;
// pub const i64_atomic_rmw32_sub_u = void;
// pub const i32_atomic_rmw_and = void;
// pub const i64_atomic_rmw_and = void;
// pub const i32_atomic_rmw8_and_u = void;
// pub const i32_atomic_rmw16_and_u = void;
// pub const i64_atomic_rmw8_and_u = void;
// pub const i64_atomic_rmw16_and_u = void;
// pub const i64_atomic_rmw32_and_u = void;
// pub const i32_atomic_rmw_or = void;
// pub const i64_atomic_rmw_or = void;
// pub const i32_atomic_rmw8_or_u = void;
// pub const i32_atomic_rmw16_or_u = void;
// pub const i64_atomic_rmw8_or_u = void;
// pub const i64_atomic_rmw16_or_u = void;
// pub const i64_atomic_rmw32_or_u = void;
// pub const i32_atomic_rmw_xor = void;
// pub const i64_atomic_rmw_xor = void;
// pub const i32_atomic_rmw8_xor_u = void;
// pub const i32_atomic_rmw16_xor_u = void;
// pub const i64_atomic_rmw8_xor_u = void;
// pub const i64_atomic_rmw16_xor_u = void;
// pub const i64_atomic_rmw32_xor_u = void;
// pub const i32_atomic_rmw_xchg = void;
// pub const i64_atomic_rmw_xchg = void;
// pub const i32_atomic_rmw8_xchg_u = void;
// pub const i32_atomic_rmw16_xchg_u = void;
// pub const i64_atomic_rmw8_xchg_u = void;
// pub const i64_atomic_rmw16_xchg_u = void;
// pub const i64_atomic_rmw32_xchg_u = void;
// pub const i32_atomic_rmw_cmpxchg = void;
// pub const i64_atomic_rmw_cmpxchg = void;
// pub const i32_atomic_rmw8_cmpxchg_u = void;
// pub const i32_atomic_rmw16_cmpxchg_u = void;
// pub const i64_atomic_rmw8_cmpxchg_u = void;
// pub const i64_atomic_rmw16_cmpxchg_u = void;
// pub const i64_atomic_rmw32_cmpxchg_u = void;
