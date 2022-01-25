const std = @import("std");

const testing = std.testing;

const fs = std.fs;

const KSDATAFORMAT_SUBTYPE_PCM = [16]u8{ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 };
const KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = [16]u8{ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 };

const FileType = enum {
    Wave,
    Unknown,
};

const SampleFormat = enum {
    Int,
    Float,
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

const WavSpecEx = struct {
    spec: WavSpec,
    bytes_per_sample: u16,

    pub fn format(self: WavSpecEx, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{self.spec});
        try writer.print("bytes per sample: {d}\n", .{self.bytes_per_sample});
    }
};

const Samples = struct {
    len: u64,
    remaining: u64,
    
    fn read_into(self: *@This(), file:fs.File,buf: []u8) !void {
        var n: usize = 0;
        _ = self;
        while(n < buf.len){
            
            //var max = std.math.min(buf[n..].len,self.len - n);
            //_ = max;
            var progress = try file.read(buf);
            if(progress > 0) {
                n += progress;
            }else {
                return error.FailedToRead;
            }
        }
    }
    
    fn read_le_i24_4(self: *@This(), file: fs.File) !i32 {
        const val = try self.read_le_u32(file);
        if((val & (1 << 23) == 0)){
            return  @bitCast(i32,val & 0x00_ff_ff_ff);
        }else{
            return @bitCast(i32, val | 0xff_00_00_00);
        }
    }
    fn read_le_i24(self: *@This(), file: fs.File) !i32{
        const val = try self.read_le_u24(file);
        if((val & (1 << 23) == 0)){
            return @bitCast(i32, val);
        }else{
            return @bitCast(i32,val | 0xff_00_00_00);
        }
    }    
    
    fn read_le_u24(self: *@This(), file: fs.File) !u32 {
        var buf: [3]u8 = undefined;
        try self.read_into(file, buf[0..]);
        var val = @intCast(u32,buf[2]) << 16 | @intCast(u32,buf[1]) << 8 | @intCast(u32,buf[0]);
        return val;
    }

    fn read_le_u32(self: *@This(),file: fs.File) !u32 {
        var buf: [4]u8 = undefined;
        try self.read_into(file,buf[0..]);
        var val = @intCast(u32,buf[3]) << 24 | @intCast(u32,buf[2])<<16 | 
                 @intCast(u32,buf[1]) << 8 | @intCast(u32,buf[0]); 
        return val;
    }
    
    fn read_le_f32(self: *@This(),file: fs.File) !f32 {
        const val = try self.read_le_u32(file);
        return @bitCast(f32,val);
    }
    
    fn read_le_i32(self: *@This(), file: fs.File) !i32 {
        const val = try self.read_le_u32(file);
        return @bitCast(i32,val);
    }
    
    fn read_le_u16(self: *@This(),file: fs.File) !u16 {
        var buf: [2]u8 = undefined;
        try self.read_into(file,buf[0..]);
        var val = @intCast(u16,buf[1]) << 8 | @intCast(u16,buf[0]);
        return val;
    }    
    
    fn read_le_i16(self: *@This(),file: fs.File) !i16 {
        const val = try self.read_le_u16(file);
        return @bitCast(i16,val);
    }
    
    fn read_u8(self: *@This(), file: fs.File) !u8{
        var buf: [1]u8 = undefined;
        try self.read_into(file,buf[0..]);
        return buf[0];
    }
    fn read_i8(self: *@This(), file: fs.File) !i8 {
        const val = try self.read_u8(file);
        return @bitCast(i8,val);
    }
    pub fn collect(self: *@This(),comptime format: type, file: fs.File, bytes: u16, bits: u16) ![]format {
        var list = std.ArrayList(format).init(alloc);
        var count:usize = 0;
        while(count < (self.len/bytes)): (count += 1){
        if(@typeInfo(format) == .Float){
           if(bytes == 4 and bits == 32){
              const val = try self.read_le_f32(file);
              try list.append(val);
           }else if(bytes == 3 and bits == 24) {
              const val = try self.read_le_i24(file);
              try list.append(@intToFloat(f32,val));        
           }else if(bytes == 2 and bits == 16){
              const val = try self.read_le_i16(file);                
              try list.append(@intToFloat(f32,val));
           }else if(bytes == 1 and bits == 8){
              const val = @intCast(i8,@intCast(i16,try self.read_u8(file))-128);
              try list.append(@intToFloat(f32,val));
           }else if(bytes > 4){
              return error.TooWide;
           }else {
              return error.Unsupported;
           }
        }else{
           if(format == i32 and bytes == 4 and bits == 32){
              const val = try self.read_le_i32(file);
              try list.append(val);   
           }else if(format == i16 and bytes == 2 and bits == 16 ){
              const val = try self.read_le_i16(file);
              try list.append(val);
           }else if(bytes == 1 and bits == 8){
              const val = @intCast(i8,@intCast(i16,try self.read_u8(file)) - 128); //conversion 
              try list.append(@intCast(i16,val));
           }else if(format == i32 and bytes == 2 and bits == 16){
              const val = @intCast(i32, try self.read_le_i16(file));
              try list.append(val);                     
           }else if(format == i32 and bytes == 3 and bits == 24){
              const val = try self.read_le_i24(file);
              try list.append(val);
           }else if(format == i32 and bytes == 4 and bits == 24){
               const val = try self.read_le_i24_4(file);
               try list.append(val);
           }else {
                return error.FailedToCatch;
            }
        }
        }
        return list.toOwnedSlice();
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
        try writer.print("file size: {d}\n", .{self.file_size});
        try writer.print("{s}", .{self.spec_ex});
    }
};

const alloc = std.heap.page_allocator;

pub fn nowav() type {
    return struct {
        file: fs.File,
        header: WavFile,
        samples: Samples,
    
        const Self = @This();
        
        pub fn init(file: fs.File) Self {
            return Self{
                .file = file,
                .header = undefined,
                .samples = undefined,
            };
        }
        
        fn next_tag(self: *Self,buffer: []u8) !u32 {
            _ = try self.file.read(buffer);
            return try self.file.reader().readIntLittle(u32);
        }
    
        fn decode_header(self: *Self,filename: []const u8) !WavFile {
            try self.file.seekTo(0);

            var buffer: [4]u8 = undefined;
            var got_fmt = false;
            var data_size: u64 = 0;
            var next_tag_ofs: i64 = -1;
            var data_ofs: i64 = -1;
            var wavSpec: WavSpecEx = undefined;
        
            _ = try self.file.read(&buffer);
        
            if (!std.mem.eql(u8, &buffer, "RIFF")) {
                return error.InvalidWaveFile;
            }//TODO add RIFX,RF64,BW64

            const chunk_size = try self.file.reader().readIntLittle(u32);

            _ = try self.file.read(&buffer);
            if (!std.mem.eql(u8, &buffer, "WAVE")) {
                return error.InvalidWaveFile;
            }
        
            //TODO for RF64|BW64 get data_size and samplecount based in ffmpeg
        
            //audio stream        
        
            while(true){
            
                const size = try self.next_tag(&buffer);
        
                if (std.mem.eql(u8, &buffer, "fmt ")) {
                    try self.read_format_chunk(size, &wavSpec);
                    got_fmt = true;
            } else if (std.mem.eql(u8, &buffer, "fact")) {
                //samples per channel
                  _ = try self.file.reader().readIntLittle(u32);
//                wavSpec.spec.samples_per_channel = try file.reader().readIntLittle(u32);
            } else if (std.mem.eql(u8, &buffer, "data")) {
               if(!got_fmt) return error.NoFmtTag;
                
               if(size != 0xFFFFFFFF){
                  data_size = size;
                  next_tag_ofs = if(size>0) next_tag_ofs else std.math.maxInt(i64);                
                  
               }else{
                  data_size = 0;
                  next_tag_ofs = std.math.maxInt(i64);//wav->data_end; 
               }
               //TODO assign data_ofs to seeking
               _ = data_ofs;
               if(data_size > (std.math.maxInt(i64) >> 3)){
                    data_size = 0;
                    return error.DataSizeToLarge;
               }
               
               //TODO - indirectly hidden changing state 
               self.samples = .{.len = data_size, .remaining = data_size};
                    
               return WavFile{
                   .file_name = filename,
                   .file_size = chunk_size + 8,
                   .spec_ex = wavSpec,
               };
            } else {
               //Ignore bytes for the time being of tags that dont matter
               _ = try self.file.reader().skipBytes(size,.{});
            }    
        }
    }

    fn read_wave_pcm_format(self: *Self,len: u32, spec: *WavSpecEx) !void {
        const is_wave_format_ex = switch(len){
            16 => false,
            18 => true,
            40 => true,
            else => return error.UnknownFormat,
        };
        
        if(is_wave_format_ex) {
            const cb_size = try self.file.reader().readIntLittle(u16);
            _ = cb_size;
            _ = spec;
        }
        
        if(len == 40) {
            _ = try self.file.reader().skipBytes(22,.{});
        }
    }

    fn read_wave_ieee_float(self: *Self, len: u32, specEx: *WavSpecEx) !void {
        const len_ex = (len == 18);
        if (!len_ex and len != 16) return error.Unexpected_Fmt_Size;

        if (len_ex) {
            const cb_size = try self.file.reader().readIntLittle(u16);
            if (cb_size != 0) return error.UnexpectedWaveFormatExSize;
        }

        if (specEx.spec.bits_per_sample != 32) return error.bpsNot32;

        specEx.spec.sample_format = SampleFormat.Float;
    }

    fn read_wave_format_extensible(self: *Self, len: u32, specEx: *WavSpecEx) !void {
        if (len < 40) return error.Unexpected_Fmt_Size;

        const cb_size = try self.file.reader().readIntLittle(u16);
        if (cb_size != 22) return error.UnexpectedWaveFormatExtensibleSize;

        const valid_bits_per_sample = try self.file.reader().readIntLittle(u16);
        const channel_mask = try self.file.reader().readIntLittle(u32);
        _ = channel_mask;
        var subformat: [16]u8 = undefined;
        _ = try self.file.read(&subformat);

        if (std.mem.eql(u8, &subformat, &KSDATAFORMAT_SUBTYPE_PCM)) {
            specEx.spec.sample_format = SampleFormat.Int;
        } else if (std.mem.eql(u8, &subformat, &KSDATAFORMAT_SUBTYPE_IEEE_FLOAT)) {
            specEx.spec.sample_format = SampleFormat.Float;
        } else {
            return error.Unsupported;
        }

        if (valid_bits_per_sample > 0) {
            specEx.spec.bits_per_sample = valid_bits_per_sample;
        }
    }

    fn read_format_chunk(self: *Self, len: u32, specEx: *WavSpecEx) !void {
        if (len < 16) return error.InvalidFormatChunk;

        const format_tag = Fmt.get(try self.file.reader().readIntLittle(u16));

        const num_channels = try self.file.reader().readIntLittle(u16);

        const sample_rate = try self.file.reader().readIntLittle(u32);

        const data_transmission_rate = try self.file.reader().readIntLittle(u32);

        const block_alignment = try self.file.reader().readIntLittle(u16);

        const bits_per_sample = try self.file.reader().readIntLittle(u16);

        if (num_channels == 0) return error.ZeroChannels;

        const bytes_per_sample = block_alignment / num_channels;

        if (bits_per_sample > bytes_per_sample * 8) return error.ExceedsSizeOfSample;

        if (data_transmission_rate != block_alignment * sample_rate) return error.InconsistentFmtChunk;

        if (bits_per_sample % 8 != 0) return error.NotMultiOf8;

        if (bits_per_sample == 0) return error.IsZero;

        specEx.spec.bits_per_sample = bits_per_sample;
        specEx.spec.sample_rate = sample_rate;
        specEx.spec.channels = num_channels;
        specEx.bytes_per_sample = bytes_per_sample;

        //Match format tag now and read more if needed

        switch (format_tag) {
            Fmt.Pcm => try self.read_wave_pcm_format(len, specEx),
            Fmt.Microsoft_Adpcm => return error.Unsupported,
            Fmt.Ieee_float => try self.read_wave_ieee_float(len, specEx),
            Fmt.A_law => return error.Unsupported,
            Fmt.Micro_law => return error.Unsupported,
            Fmt.Gsm => return error.Unsupported,
            Fmt.Adpcm => return error.Unsupported,
            Fmt.Extended => try self.read_wave_format_extensible(len, specEx),
            else => return error.Unsupported,
        }
    }

    pub fn decode(self: *Self, filename: []const u8)!void {
            self.header = try self.decode_header(filename);
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
}

comptime {
    _ = Tests;
}

pub const runAllTests = Tests.runAll;

const Tests = struct {
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
            "read_as_i32_should_equal_read_as_f32",
            "seek_is_consistant"
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

        var nowavey = nowav().init(file);
        
        try nowavey.decode("sine.wav");

        const wav_str = try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{nowavey.header},
        );
        defer allocator.free(wav_str);
        
        const teststr =
            \\============sine.wav==============
            \\file size: 88244
            \\channels: 1
            \\sample rate: 44100
            \\bits per sample: 16
            \\sample format: SampleFormat.Int
            \\bytes per sample: 2
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

        var nowavey = nowav().init(file);
        try nowavey.decode("sine.wav");

        const teststr =
            \\============sine.wav==============
            \\file size: 88244
            \\channels: 1
            \\sample rate: 44100
            \\bits per sample: 16
            \\sample format: SampleFormat.Int
            \\bytes per sample: 2
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
        
        var nowavey = nowav().init(file);
        try nowavey.decode("pcmwaveformat-16bit-44100Hz-mono.wav");

        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
        
        var samples = try nowavey.samples.collect(i16,nowavey.file,nowavey.header.spec_ex.bytes_per_sample,nowavey.header.spec_ex.spec.bits_per_sample);//;//.ToBuf(&samples);
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i16, &[_]i16{2,-3,5,-7},samples);
    }

    test "read_skips_unknown_chunks" {
        test_read_skips_unknown_chunks();
    }
    fn test_read_skips_unknown_chunks() !void {
        // The test samples are the same as without the -extra suffix, but ffmpeg
        // has kindly added some useless chunks in between the fmt and data chunk.
        const files = &[_][]const u8{ 
            "samples/pcmwaveformat-16bit-44100Hz-mono-extra.wav", 
            "samples/waveformatex-16bit-44100Hz-mono-extra.wav" 
        };
        
        for (files) |file| {
            const dataFile = try fs.cwd().openFile(file, .{
                .read = true,
            });
            defer dataFile.close();
            var nowavey = nowav().init(dataFile);
            try nowavey.decode(file[8..]);

            try expect(nowavey.header.spec_ex.spec.channels == 1);
            try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
            try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
            try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
            
            var samples = try nowavey.samples.collect(
                i16,
                nowavey.file,
                nowavey.header.spec_ex.bytes_per_sample,
                nowavey.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples);
        
            try testing.expectEqualSlices(i16, &[_]i16{2,-3,5,-7},samples); 
        }

    }

    test "read_0_valid_bits_fallback" {
        test_read_0_valid_bits_fallback();
    }
    fn test_read_0_valid_bits_fallback() !void {
        const dataFile = try fs.cwd().openFile("samples/nonstandard-02.wav", .{
            .read = true,
        });
        defer dataFile.close();

        var nowavey = nowav().init(dataFile);
        try nowavey.decode("nonstandard-02.wav");

        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
        
        var samples = try nowavey.samples.collect(
                i32,
                nowavey.file,
                nowavey.header.spec_ex.bytes_per_sample,
                nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        
        try testing.expectEqualSlices(i32, &[_]i32{19, -229373, 33587161, -2147483497},samples);         //let samples: Vec<i32> = wav_reader.sample()
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
        
        var nowavey = nowav().init(val);
        try nowavey.decode("pcmwaveformat-8bit-44100Hz-mono.wav");
        
        var nowaveyRef = nowav().init(ref);
        try nowaveyRef.decode("pcmwaveformat-8bit-44100Hz-mono.wav");
        
        const w = try nowavey.samples.collect(
            i16,
            val,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(w);
        
        const r = try nowaveyRef.samples.collect(
            i16,
            ref,
            nowaveyRef.header.spec_ex.bytes_per_sample,
            nowaveyRef.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(r);
        
        try testing.expectEqualSlices(i16,w,r);

    }

    test "read_wave_format_ex_pcm" {
        test_read_wave_format_ex_pcm();
    }
    fn test_read_wave_format_ex_pcm() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-16bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();

        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
        
        const samples = try nowavey.samples.collect(
            i16,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i16,&[_]i16{2,-3,5,-7}, samples);
    }

    test "read_wave_format_ex_ieee_float" {
        test_read_wave_format_ex_ieee_float();
    }
    fn test_read_wave_format_ex_ieee_float() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-ieeefloat-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Float);
        
        const samples = try nowavey.samples.collect(
            f32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(f32,&[_]f32{2.0, 3.0, -16411.0, 1019.0}, samples);
    }

    test "read_wave_stereo" {
        test_read_wave_stereo();
    }
    fn test_read_wave_stereo() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-16bit-44100Hz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 16);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
                
        const samples = try nowavey.samples.collect(
            i16,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i16, &[_]i16{2,-3,5,-7,11,-13,17,-19},samples);
    }

    test "read_pcm_wave_format_8bit" {
        test_read_pcm_wave_format_8bit();
    }
    fn test_read_pcm_wave_format_8bit() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 8);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
                
        const samples = try nowavey.samples.collect(
            i16,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i16, &[_]i16{19,-53,89,-127}, samples);

    }

    test "read_pcm_wave_format_24bit_4byte" {
        test_read_pcm_wave_format_24bit_4byte();
    }
    fn test_read_pcm_wave_format_24bit_4byte() !void {
        const file = try fs.cwd().openFile("samples/pcmwaveformat-24bit-4byte-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();

        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
       
         const samples = try nowavey.samples.collect(
            i32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
         );

         defer alloc.free(samples);
        
         try testing.expectEqualSlices(i32, &[_]i32{-96,23052,8388607, -8360672},samples);

    }

    test "read_waveformatex_pcm_24bit" {
        test_read_waveformatex_pcm_24bit();
    }
    fn test_read_waveformatex_pcm_24bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-24bit-192kHz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 192_000);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
        const samples = try nowavey.samples.collect(
            i32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i32, &[_]i32{-17, 4_194_319, -6_291_437, 8_355_817},samples);
    }

    test "read_waveformatex_8bit" {
        test_read_waveformatex_8bit();
    }
    fn test_read_waveformatex_8bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatex-8bit-11025Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 11025);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 8);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
        const samples  = try nowavey.samples.collect(
            i16,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i16,&[_]i16{-128,-128,-128,-128},samples);
    }

    //extensible format
    test "read_waveformat_extensible_pcm_24bit_4byte" {
        test_read_waveformat_extensible_pcm_24bit_4byte();
    }
    fn test_read_waveformat_extensible_pcm_24bit_4byte() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-24bit-4byte-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.channels == 2);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 48000);
        //try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24); //failed
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
      
        
        const samples  = try nowavey.samples.collect(
            i32,
            nowavey.file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i32,&[_]i32{-96, 23_052, 8_388_607, -8_360_672},samples);
        
    }

    test "read_wav_32bit" {
        test_read_wav_32bit();
    }
    fn test_read_wav_32bit() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-32bit-48kHz-stereo.wav", .{
            .read = true,
        });
        defer file.close();
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);

        const samples =  try nowavey.samples.collect(
            i32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i32,&[_]i32{19, -229_373, 33_587_161, -2_147_483_497},samples);

    }

    test "read_waveformat_extensible_ieee_float" {
        test_read_waveformat_extensible_ieee_float();
    }
    fn test_read_waveformat_extensible_ieee_float() !void {
        const file = try fs.cwd().openFile("samples/waveformatextensible-ieeefloat-44100Hz-mono.wav", .{
            .read = true,
        });
        defer file.close();
        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        try expect(nowavey.header.spec_ex.spec.channels == 1);
        try expect(nowavey.header.spec_ex.spec.sample_rate == 44100);
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 32);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Float);
      
        const samples = try nowavey.samples.collect(
            f32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(f32,&[_]f32{2.0, 3.0, -16411.0, 1019.0},samples);

    }

    //waveformat extensible type
    test "read_nonstandard_01" {
        test_read_nonstandard_01();
    }
    fn test_read_nonstandard_01() !void {
        const file = try fs.cwd().openFile("samples/nonstandard-01.wav", .{
            .read = true,
        });
        defer file.close();

        var nowavey = nowav().init(file);
        try nowavey.decode("test.wav");
        
        try expect(nowavey.header.spec_ex.spec.bits_per_sample == 24);
        try expect(nowavey.header.spec_ex.spec.sample_format == SampleFormat.Int);
      
        const samples = try nowavey.samples.collect(
            i32,
            file,
            nowavey.header.spec_ex.bytes_per_sample,
            nowavey.header.spec_ex.spec.bits_per_sample
        );
        defer alloc.free(samples);
        
        try testing.expectEqualSlices(i32,&[_]i32{0,0},samples);        

    }

    
    
    test "read_as_i32_should_equal_read_as_f32" {
        test_read_as_i32_should_equal_read_as_f32();
    }
    fn test_read_as_i32_should_equal_read_as_f32() !void {
        //blocked scopes so I can run the same names
        {            
            const file_i32 = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
                .read = true,
            });
            defer file_i32.close();

            var no_i32 = nowav().init(file_i32);
            try no_i32.decode("test.wav");        
            const samples_i32 = try no_i32.samples.collect(
                i32,
                file_i32,
                no_i32.header.spec_ex.bytes_per_sample,
                no_i32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_i32);

            const file_f32 = try fs.cwd().openFile("samples/pcmwaveformat-8bit-44100Hz-mono.wav", .{
                .read = true,
            });
            defer file_f32.close();

            var no_f32 = nowav().init(file_f32);
            try no_f32.decode("test.wav");        
            const samples_f32 = try no_f32.samples.collect(
                f32,
                file_f32,
                no_f32.header.spec_ex.bytes_per_sample,
                no_f32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_f32);        
            
            for(samples_i32)|item,idx|{
                try testing.expectEqual(item,@floatToInt(i32,samples_f32[idx]));
                try testing.expectEqual(@intToFloat(f32,item),samples_f32[idx]); 
            }
        }
        {
            const file_i32 = try fs.cwd().openFile("samples/pcmwaveformat-16bit-44100Hz-mono.wav", .{
                .read = true,
            });
            defer file_i32.close();

            var no_i32 = nowav().init(file_i32);
            try no_i32.decode("test.wav");        
            const samples_i32 = try no_i32.samples.collect(
                i32,
                file_i32,
                no_i32.header.spec_ex.bytes_per_sample,
                no_i32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_i32);
        

            const file_f32 = try fs.cwd().openFile("samples/pcmwaveformat-16bit-44100Hz-mono.wav", .{
                .read = true,
            });
            defer file_f32.close();

            var no_f32 = nowav().init(file_f32);
            try no_f32.decode("test.wav");        
            const samples_f32 = try no_f32.samples.collect(
                f32,
                file_f32,
                no_f32.header.spec_ex.bytes_per_sample,
                no_f32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_f32);        
            
            for(samples_i32)|item,idx|{
                try testing.expectEqual(item,@floatToInt(i32,samples_f32[idx]));
                try testing.expectEqual(@intToFloat(f32,item),samples_f32[idx]); 
            } 
        }
        
        
        {
            const file_i32 = try fs.cwd().openFile("samples/waveformatextensible-24bit-192kHz-mono.wav", .{
                .read = true,
            });
            defer file_i32.close();

            var no_i32 = nowav().init(file_i32);
            try no_i32.decode("test.wav");        
            const samples_i32 = try no_i32.samples.collect(
                i32,
                file_i32,
                no_i32.header.spec_ex.bytes_per_sample,
                no_i32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_i32);
        

            const file_f32 = try fs.cwd().openFile("samples/waveformatextensible-24bit-192kHz-mono.wav", .{
                .read = true,
            });
            defer file_f32.close();

            var no_f32 = nowav().init(file_f32);
            try no_f32.decode("test.wav");        
            const samples_f32 = try no_f32.samples.collect(
                f32,
                file_f32,
                no_f32.header.spec_ex.bytes_per_sample,
                no_f32.header.spec_ex.spec.bits_per_sample
            );
            defer alloc.free(samples_f32);        
            
            for(samples_i32)|item,idx|{
                try testing.expectEqual(item,@floatToInt(i32,samples_f32[idx]));
                try testing.expectEqual(@intToFloat(f32,item),samples_f32[idx]); 
            } 
        }   
    
    }    
    test "seek_is_consistant" {
        test_seek_is_consistant();
    }
    fn test_seek_is_consistant() !void {
        
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
        //assert_eq!(file.samples::<f32>().next().unwrap().is_err())     
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
    }};
