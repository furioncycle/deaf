const std = @import("std");

const testing = std.testing;

const fs = std.fs;

const FileType = enum {
    Wave,
    Unknown,
};

const Fmt = enum {
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

const WavSpec = struct {
    channels: u16,
    bits_per_sample: u16,
    sample_rate: u32,

    pub fn format(
        self: WavSpec,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        _ = self;
        try writer.print("|    channels: {d}                 |\n", .{self.channels});
        try writer.print("|    sample rate: {d}          |\n", .{self.sample_rate});
        try writer.print("|    bits per sample: {d}         |\n", .{self.bits_per_sample});
    }
};

const WavSpecEx = struct {
    spec: WavSpec,
    bytes_per_sample: u16,

    pub fn format(self: WavSpecEx, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{self.spec});
        try writer.print("|    bytes per sample: {d}         |\n", .{self.bytes_per_sample});
    }
};

const WavFile = struct {
    file_name: []const u8,
    file_size: u32,
    spec_ex: WavSpecEx,

    pub fn format(self: WavFile, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("============{s}==============\n", .{self.file_name});
        try writer.print("|    file size: {d}               |\n", .{self.file_size});
        try writer.print("{s}", .{self.spec_ex});
    }
};

const alloc = std.heap.page_allocator;

pub const nowav = struct {
    file: fs.File = undefined,
    header: WavFile,
    const Self = @This();
    pub fn decode_header(filename: []const u8, file: fs.File) !WavFile {
        try file.seekTo(0);

        var buffer: [4]u8 = undefined;

        _ = try file.read(&buffer);

        if (!std.mem.eql(u8, &buffer, "RIFF")) {
            return error.InvalidWaveFile;
        }

        const file_size = try file.reader().readIntLittle(u32);

        _ = try file.read(&buffer);
        if (!std.mem.eql(u8, &buffer, "WAVE")) {
            return error.InvalidWaveFile;
        }

        const format_type = FileType.Wave;
        _ = format_type;

        _ = try file.reader().skipBytes(10, .{}); //fmt id skipped

        //    const fmt_block_size = try file.reader().readIntLittle(u32);
        //    _ = fmt_block_size;

        //  const coding_fmt = Fmt.get(try file.reader().readIntLittle(u16));
        //  _ = coding_fmt;

        const num_channels = try file.reader().readIntLittle(u16);

        const sample_rate = try file.reader().readIntLittle(u32);

        //const data_transmission_rate = try file.reader().readIntLittle(u32);
        //_ = data_transmission_rate;
        _ = try file.reader().skipBytes(6, .{});

        //const block_alignment = try file.reader().readIntLittle(u16);
        //_ = block_alignment;

        const bits_per_sample = try file.reader().readIntLittle(u16);

        //TODO extended block format if not PCM

        return WavFile{
            .file_name = filename,
            .file_size = file_size + 8,
            .spec_ex = .{
                .spec = .{
                    .bits_per_sample = bits_per_sample,
                    .sample_rate = sample_rate,
                    .channels = num_channels,
                },
                .bytes_per_sample = 2,
            },
        };
    }

    pub fn decode(filename: []const u8, file: fs.File) !nowav {
        return nowav{
            .file = file,
            .header = try Self.decode_header(filename, file),
        };
    }

    pub fn printHeader(self: Self) ![]const u8 {
        const wav_str = try std.fmt.allocPrint(
            alloc,
            "{s}",
            .{self.header},
        );

        return wav_str;
    }
};

pub fn decode_header(filename: []const u8, file: fs.File) !WavFile {
    try file.seekTo(0);

    var buffer: [4]u8 = undefined;

    _ = try file.read(&buffer);

    if (!std.mem.eql(u8, &buffer, "RIFF")) {
        return error.InvalidWaveFile;
    }

    const file_size = try file.reader().readIntLittle(u32);

    _ = try file.read(&buffer);
    if (!std.mem.eql(u8, &buffer, "WAVE")) {
        return error.InvalidWaveFile;
    }

    const format_type = FileType.Wave;
    _ = format_type;

    _ = try file.reader().skipBytes(10, .{}); //fmt id skipped

    //    const fmt_block_size = try file.reader().readIntLittle(u32);
    //    _ = fmt_block_size;

    //  const coding_fmt = Fmt.get(try file.reader().readIntLittle(u16));
    //  _ = coding_fmt;

    const num_channels = try file.reader().readIntLittle(u16);

    const sample_rate = try file.reader().readIntLittle(u32);

    //const data_transmission_rate = try file.reader().readIntLittle(u32);
    //_ = data_transmission_rate;
    _ = try file.reader().skipBytes(6, .{});

    //const block_alignment = try file.reader().readIntLittle(u16);
    //_ = block_alignment;

    const bits_per_sample = try file.reader().readIntLittle(u16);

    //TODO extended block format if not PCM

    return WavFile{
        .file_name = filename,
        .file_size = file_size + 8,
        .spec_ex = .{
            .spec = .{
                .bits_per_sample = bits_per_sample,
                .sample_rate = sample_rate,
                .channels = num_channels,
            },
            .bytes_per_sample = 2,
        },
    };
}

comptime {
    _ = Tests;
}

pub const runAllTests = Tests.runAll;

const Tests = struct {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const print = std.debug.print;
    fn runAll() !void {
        const tests = .{
            "read_header_file",
            "decode_struct",
            "read_pcm_wave_format",
            "sample_format_mismatch_should_signal_error",
            "read_should_signal_error",
            "read_nonstandard_01",
            "read_waveformat_extensible_ieee_float",
            "read_wav_32bit",
            "read_waveformat_extensible_pcm_24bit_4byte",
            "read_waveformatex_8bit",
            "read_waveformatex_pcm_24bit",
            "read_pcm_wave_format_24bit_4byte",
            "read_pcm_wave_format_8bit",
            "read_wave_stereo",
            "read_wave_format_ex_ieee_float",
            "read_wave_format_ex_pcm",
            "Samples_eq_Samples",
            "size_hint_is_correct",
            "length_and_size_hints_are_incorrect",
            "read_0_valid_bits_fallback",
            "read_skips_unknown_chunks",
            "read_pcm_wave_format",
        };

        print("Running tests...\n", .{});
        inline for (tests) |fn_name| {
            print("{s}...\n", .{fn_name});
            try @field(@This(), "test_" ++ fn_name)();
        }
        print("All {d} tests passed. \n", .{tests.len});
    }

    test "read_header_file" {
        test_read_header_file();
    }
    fn test_read_header_file() !void {
        const file = try fs.cwd().openFile("samples/sine.wav", .{
            .read = true,
        });
        defer file.close();

        const nowavey = try nowav.decode("sine.wav", file);

        const wav_str = try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{nowavey.header},
        );
        defer allocator.free(wav_str);

        const teststr =
            \\============sine.wav==============
            \\|    file size: 88244               |
            \\|    channels: 1                 |
            \\|    sample rate: 44100          |
            \\|    bits per sample: 16         |
            \\|    bytes per sample: 2         |
            \\
        ;

        try expect(std.mem.eql(u8, wav_str, teststr));
    }

    test "decode_struct" {
        test_decode_struct();
    }
    fn test_decode_struct() !void {
        const file = try fs.cwd().openFile("samples/sine.wav", .{
            .read = true,
        });
        defer file.close();

        const nowavey = try nowav.decode("sine.wav", file);

        const teststr =
            \\============sine.wav==============
            \\|    file size: 88244               |
            \\|    channels: 1                 |
            \\|    sample rate: 44100          |
            \\|    bits per sample: 16         |
            \\|    bytes per sample: 2         |
            \\
        ;
        const str = try nowavey.printHeader();
        try expect(std.mem.eql(u8, str, teststr));
    }

    test "read_pcm_wave_format" {
        test_read_pcm_wave_format();
    }
    fn test_read_pcm_wave_format() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-16bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();

        //let mut wav_reader = WavReader::open("testsamples/pcmwaveformat-16bit-44100Hz-mono.wav")
        //    .unwrap();

        const nowavey = try nowav.decode("pcmwaveformat-16bit-44100Hz-mono.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
        // try testing.expect(nowavey.header.spec_ex.spec.sample_format, SampleFormat.Int);

        //    let samples: Vec<i16> = wav_reader.samples()
        //       .map(|r| r.unwrap())
        //       .collect();

        // The test file has been prepared with these exact four samples.
        //  assert_eq!(&samples[..], &[2, -3, 5, -7]);
    }

    test "read_skips_unknown_chunks" {
        test_read_skips_unknown_chunks();
    }
    fn test_read_skips_unknown_chunks() !void {
        // The test samples are the same as without the -extra suffix, but ffmpeg
        // has kindly added some useless chunks in between the fmt and data chunk.
        const files = &[_][]const u8{ "samples/pcmwaveformat-16bit-44100Hz-mono-extra.wav", "samples/waveformatex-16bit-44100Hz-mono-extra.wav" };
        for (files) |file| {
            const dataFile = try fs.cwd().openFile(file, .{
                .read = true,
            });
            defer dataFile.close();
            const nowavey = try nowav.decode(file[8..], dataFile);

            try expect(nowavey.header.spec_ex.spec.channels == 1);
            try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
            try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
        }

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);

        //            let sample = wav_reader.samples::<i16>().next().unwrap().unwrap();
        //            assert_eq!(sample, 2);

    }

    test "read_0_valid_bits_fallback" {
        test_read_0_valid_bits_fallback();
    }
    fn test_read_0_valid_bits_fallback() !void {
        const dataFile = try fs.cwd().openFile("samples/nonstandard-02.wav", .{
            .read = true,
        });
        defer dataFile.close();

        const nowavey = try nowav.decode("nonstandard-02.wav", dataFile);

        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i32> = wav_reader.sample()
        //    .map(|r| r.unwrap)
        //    .collect()

        //assert_eq!(&samples[..], &[19, -229373, 33587161, -2147483497]);
    }

    test "length_and_size_hints_are_incorrect" {
        test_length_and_size_hints_are_incorrect();
    }
    fn test_length_and_size_hints_are_incorrect() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-16bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();

        //assert_eq!(wav.len(),4);

        //{
        // let mut samples = wav.samples""<i16>();

        // assert_eq!(samples.size_hint(), (4, Some(4)));
        // samples.next();
        // assert_eq!(samples.size_hint(), (3, Some(3)));
        //}

        //assert_eq!(wav.len(),4);

        //{
        // let mut samples = wav.samples::<i16>();
        // assert_eq!(samples.size_hint(), (3, Some(3)));
        // samples.next();
        // assert_eq!(samples.size_hint(), (2, SOme(2)));
        //}

    }

    test "size_hint_is_correct" {
        test_size_hint_is_correct();
    }
    fn test_size_hint_is_correct() !void {
        const files = &[_][]const u8{ "samples/pcmwaveformat-16bit-44100Hz-mono.wav", "samples/waveformatex-16bit-44100Hz-stereo.wav", "samples/waveformatextensible-32bit-48kHz-stereo.wav" };

        for (files) |file| {
            const d = try fs.cwd().openFile(file, .{
                .read = true,
            });
            defer d.close();
            _ = d;
            //let len reader.len()
            //let mut iter = reader.samples::<i32>();
            //for i in 0..len {
            //  let remaining = (len - i) as usize;
            //  assert_eq!(iter.size_hint(), (remaining, Some(remaining)));
            //  asert!(iter.next().is_some());
            //}
            //assert!(iter.next().is_none());
        }
    }

    test "Samples_eq_Samples" {
        test_Samples_eq_Samples();
    }
    fn test_Samples_eq_Samples() !void {
        const val = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer val.close();

        const ref = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer ref.close();

        //let samples_val: Vec<i16> = val.into_samples()
        //                                .map(|r| r.unwrap())
        //                                .collect()

        //let samples_ref: Vec<i16> = ref.samples()
        //                               .map(|r| r.unwrap())
        //                               .collect()

        //assert_eq!(samples_val,samples_ref);
    }

    test "read_wave_format_ex_pcm" {
        test_read_wave_format_ex_pcm();
    }
    fn test_read_wave_format_ex_pcm() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-16bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();

        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[2, -3, 5, -7])
    }

    test "read_wave_format_ex_ieee_float" {
        test_read_wave_format_ex_ieee_float();
    }
    fn test_read_wave_format_ex_ieee_float() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-ieeefloat-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Float);
        //let samples: Vec<f32> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[2.0, 3.0, -16411.0, 1019.0])}
    }

    test "read_wave_stereo" {
        test_read_wave_stereo();
    }
    fn test_read_wave_stereo() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-16bit-44100Hz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[2, -3, 5, -7, 11, -13, 17, -19])
    }

    test "read_pcm_wave_format_8bit" {
        test_read_pcm_wave_format_8bit();
    }
    fn test_read_pcm_wave_format_8bit() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 8);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[19, -53, 89, -127])

    }

    test "read_pcm_wave_format_24bit_4byte" {
        test_read_pcm_wave_format_24bit_4byte();
    }
    fn test_read_pcm_wave_format_24bit_4byte() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-24bit-4byte-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();

        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[-96, 23053,8388607,-8360672])

    }

    test "read_waveformatex_pcm_24bit" {
        test_read_waveformatex_pcm_24bit();
    }
    fn test_read_waveformatex_pcm_24bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-24bit-192kHz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 192_000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[-17, 4_194_319, -6_291_437, 8_355_817])
    }

    test "read_waveformatex_8bit" {
        test_read_waveformatex_8bit();
    }
    fn test_read_waveformatex_8bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-8bit-11025Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 11025);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 8);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[-128, -128, -128, -128])
    }

    test "read_waveformat_extensible_pcm_24bit_4byte" {
        test_read_waveformat_extensible_pcm_24bit_4byte();
    }
    fn test_read_waveformat_extensible_pcm_24bit_4byte() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-24bit-4byte-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24); //failed

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[-96, 23_052, 8_388_607, -8_360_672])
    }

    test "read_wav_32bit" {
        test_read_wav_32bit();
    }
    fn test_read_wav_32bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-32bit-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[19, -229_373, 33_587_161, -2_147,483_497])

    }

    test "read_waveformat_extensible_ieee_float" {
        test_read_waveformat_extensible_ieee_float();
    }
    fn test_read_waveformat_extensible_ieee_float() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-ieeefloat-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::float);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[2.0, 3.0, -16411.0, 1019.0])

    }

    test "read_nonstandard_01" {
        test_read_nonstandard_01();
    }
    fn test_read_nonstandard_01() !void {
        const file = try fs.cwd().openFile("samples/nonstandard-01.wav", .{
            .read = true,
        });
        defer file.close();
        const nowavey = try nowav.decode("test.wav", file);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24); //failed

        //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
        //let samples: Vec<i16> = wav.samples()
        //                           .map(|r| r.unwrap())
        //                           .collect()
        //assert_eq!(&samples[..], &[0,0])

    }

    test "read_should_signal_error" {
        test_read_should_signal_error();
    }
    fn test_read_should_signal_error() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-24bit-192kHz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        _ = file;
        //assert_eq!(file.samples::<i8>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i16>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i32>().next().unwrap().is_ok())
        //assert_eq!(file.samples::<f32>().next().unwrap().is_ok())

        const file2 = try fs.cwd().openFile("samples/waveformatextensible-32bit-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file2.close();
        _ = file2;
        //assert_eq!(file.samples::<i8>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i16>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i32>().next().unwrap().is_ok())
        //assert_eq!(file.samples::<f32>().next().unwrap().is_err())     //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);
    }

    test "sample_format_mismatch_should_signal_error" {
        test_sample_format_mismatch_should_signal_error();
    }
    fn test_sample_format_mismatch_should_signal_error() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-ieeefloat-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        _ = file;
        //assert_eq!(file.samples::<i8>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i16>().next().unwrap().is_err())
        //assert_eq!(file.samples::<i32>().next().unwrap().is_err())
        //assert_eq!(file.samples::<f32>().next().unwrap().is_ok())

        const file2 = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file2.close();
        _ = file2;
        //assert_eq!(file.samples::<i8>().next().unwrap().is_ok())
        //assert_eq!(file.samples::<i16>().next().unwrap().is_ok())
        //assert_eq!(file.samples::<i32>().next().unwrap().is_ok())
        //assert_eq!(file.samples::<f32>().next().unwrap().is_ok())     //            assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);                     }
    }
};
