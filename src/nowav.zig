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
        try writer.print("|    sample rate: {d}          |\n",.{self.sample_rate});
        try writer.print("|    bits per sample: {d}         |\n", .{self.bits_per_sample});
    }
};

const WavSpecEx = struct {
    spec: WavSpec,
    bytes_per_sample: u16,
    
    pub fn format(
        self: WavSpecEx,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}",.{self.spec});
        try writer.print("|    bytes per sample: {d}         |\n",.{self.bytes_per_sample});
    }
    
};

const WavFile = struct {
    file_name: []const u8,
    file_size: u32,
    spec_ex: WavSpecEx,

    pub fn format(
        self: WavFile, 
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions, 
        writer: anytype
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("============{s}==============\n", .{self.file_name});
        try writer.print("|    file size: {d}               |\n", .{self.file_size});
        try writer.print("{s}",.{self.spec_ex});
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
        _ = try file.reader().skipBytes(6,.{});
    
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

    pub fn decode(filename: []const u8, file: fs.File) !nowav{
        
        return nowav{
            .file = file,
            .header = try Self.decode_header(filename,file),
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
    _ = try file.reader().skipBytes(6,.{});
    
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

test "read header file" {
    const file = try fs.cwd().openFile("samples/sine.wav", .{
        .read = true,
    });
    defer file.close();

    const nowavey = try nowav.decode("sine.wav",file);

    const wav_str = try std.fmt.allocPrint(
        testing.allocator,
        "{s}",
        .{nowavey.header},
    );
    defer testing.allocator.free(wav_str);
    
    
    const teststr = 
       \\============sine.wav==============
       \\|    file size: 88244               |
       \\|    channels: 1                 |
       \\|    sample rate: 44100          |
       \\|    bits per sample: 16         |
       \\|    bytes per sample: 2         |
       \\
    ;    
    
    try testing.expect(std.mem.eql(u8, wav_str,teststr));
}

test "decode struct" {
    
    const file = try fs.cwd().openFile("samples/sine.wav", .{
        .read = true,
    });
    defer file.close();    
    
    const nowavey = try nowav.decode("sine.wav",file);
    
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
    try testing.expect(std.mem.eql(u8,str,teststr));
}


test "read pcm wave format" {
    let mut wav_reader = WavReader::open("testsamples/pcmwaveformat-16bit-44100Hz-mono.wav")
        .unwrap();

    assert_eq!(wav_reader.spec().channels, 1);
    assert_eq!(wav_reader.spec().sample_rate, 44100);
    assert_eq!(wav_reader.spec().bits_per_sample, 16);
    assert_eq!(wav_reader.spec().sample_format, SampleFormat::Int);

    let samples: Vec<i16> = wav_reader.samples()
        .map(|r| r.unwrap())
        .collect();

    // The test file has been prepared with these exact four samples.
    assert_eq!(&samples[..], &[2, -3, 5, -7]);
}

test "read skips unknown chunks" {
    
}

test "read 0 valid bits fallback" {
    
}

test "length and size hints are incorrect" {
    
}

test "Size hint is correct" {
    
}

test "Samples == Samples" {
    
}

test "read wave format ex pcm" {
    
}

test "read wave format ex ieee float" {
    
}

test "read wave stereo" {
    
}