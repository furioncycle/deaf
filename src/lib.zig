const std = @import("std");

pub const FileType = enum {
    Wave,
    Unknown,
};

pub const SampleFormat = enum {
    Int,
    Float,
};

pub const Fmt = enum {
    Pcm,
    Microsoft_Adpcm,
    Ieee_float,
    A_law,
    Micro_law,
    Gsm,
    Adpcm,
    Extended,
    Unknown,

    pub fn get(fmt: u16) Fmt {
        return switch (fmt) {
            1 => Fmt.Pcm,
            2 => Fmt.Microsoft_Adpcm,
            3 => Fmt.Ieee_float,
            6 => Fmt.A_law,
            7 => Fmt.Micro_law,
            49 => Fmt.Gsm,
            64 => Fmt.Adpcm,
            65_534 => Fmt.Extended,
            else => Fmt.Unknown,
        };
    }
};

pub const WavSpec = struct {
    channels: u16,
    bits_per_sample: u16,
    sample_rate: u32,
    sample_format: SampleFormat,
    pub fn format(
        self: WavSpec,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        _ = self;
        try writer.print("channels: {d}\n", .{self.channels});
        try writer.print("sample rate: {d}\n", .{self.sample_rate});
        try writer.print("bits per sample: {d}\n", .{self.bits_per_sample});
        try writer.print("sample format: {s}\n", .{self.sample_format});
    }
};

pub const WavSpecEx = struct {
    spec: WavSpec,
    bytes_per_sample: u16,

    pub fn format(self: WavSpecEx, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{self.spec});
        try writer.print("bytes per sample: {d}\n", .{self.bytes_per_sample});
    }
};