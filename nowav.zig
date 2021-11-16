
const std = @import("std");
const testing = std.testing;
const fs = std.fs;


const FileType = enum {
    Wave,
    Unknown,
};

const SampleFormat = enum {
    Float,
    Int,
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
        return switch(fmt){
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
        comptime fmt: [] const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        _ = self;
        try writer.print("{d}",.{self.channels});
    }
};

const WavSpecEx = struct {
    spec: WavSpec,
    bytes_per_sample: u16,
};

const wavFile = struct {
    file_name: []const u8,
    file_size: u32,
    spec_ex: WavSpec,
    
    pub fn format(self: wavFile, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void{
        _ = fmt;
        _ = options;
        _ = self;
        try writer.print("============{s}==============",.{self.file_name});
        try writer.print("|   file size: {d}          |",.{self.file_size});
    }
};

pub fn decode_header(filename: []const u8,file: fs.File) !WavFile {
    
    try file.seekTo(0);
    
    var buffer: [4]u8 = undefined;
    
    _ = try file.read(&buffer);
    
    if(!std.mem.eql(u8,&buffer,"RIFF")){
        return error.InvalidWaveFile;
    }
    
    const file_size = try file.reader().readIntLittle(u32);
    wav.file_size = file_size + 8;
    
    _ = try file.read(&buffer);
    if(!std.mem.eql(u8,&buffer,"WAVE")){
        return error.InvalidWaveFile;
    }
    
    const format_type = FileType.Wave;
    _ = format_type;

    _ = try file.reader().skipBytes(4,.{}); //fmt id skipped 
    
    const fmt_block_size = try file.reader().readIntLittle(u32);
    _ = fmt_block_size;

    const coding_fmt = Fmt.get(try file.reader().readIntLittle(u16));
    _ = coding_fmt;

    const num_channels = try file.reader().readIntLittle(u16);
    wav.spec.channels = num_channels;
    
    const sample_rate = try file.reader().readIntLittle(u32);
    wav.spec.sample_rate = sample_rate;
    
    const data_transmission_rate = try file.reader().readIntLittle(u32);
    _ = data_transmission_rate;

    const block_alignment = try file.reader().readIntLittle(u16);
    _ = block_alignment;
        
    const bits_per_sample = try file.reader().readIntLittle(u16);
    wav.spec.bits_per_sample  = bits_per_sample;
    

    //TODO extended block format if not PCM

    return .{
        .file_name = filename,
        .file_size = file_size,
        .spec_ex = .{
            .spec =.{
               .bits_per_sample = bits_per_sample,
               .sample_rate = sample_rate,
               .channels = num_channels,
            },
            .bytes_per_sample = 2,
        },    
    }; 

}

test "print formatter works" {
   const wav = WavSpec{
    .channels = 1,
    .bits_per_sample = 16,
    .sample_rate = 44100,
    .sample_format = SampleFormat.Int,
    };
    
    const wav_str = try std.fmt.allocPrint(
        testing.allocator,
        "{s}",
        .{wav},
    );
    defer testing.allocator.free(wav_str);

    try testing.expect(std.mem.eql(u8,wav_str,"1",));
}

test "read header file" {
   const file = try fs.cwd().openFile(
        "samples/sine.wav",
        .{.read = true,}
   );
   defer file.close();

   const header = try decode_header(file);
    
   const wav_str = try std.fmt.allocPrint(
        testing.allocator,
        "{s}",
        .{header.spec},
   );
    defer testing.allocator.free(wav_str);

    try testing.expect(std.mem.eql(u8,wav_str,"1"));    
}
