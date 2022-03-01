const std = @import("std");
const testing = std.testing;

const lib = @import("lib.zig");

pub fn writer() type {
    return struct {
      spec_ex: lib.WavSpecEx,
      buffer: std.ArrayListUnmanaged(u8),

      const Self = @This();      
    
      pub fn init(buffer: std.ArrayListUnmanaged(u8), spec: lib.WavSpec) Self {
            return Self{
                .buffer = buffer,
                .spec_ex = lib.WavSpecEx{
                    .spec = spec,
                    .bytes_per_sample = (spec.bits_per_sample +7)/8,
                },                    
            };  
      }
        
      pub fn write_format(self: *Self, allocator: std.mem.Allocator) !void {
        //self.buffer.append(allocator,"RIFF\0\0\0\0WAVE");
        //write "RIFF\0\0\0\0WAVE" 
        _ = allocator;
        _ = self;
            
      }
        
      pub fn start_data_chunk(self: *Self) !void {
        _ = self;
      }

    }; 

}

pub fn channel_mask(channels: u16) !u32 {
    var count: u32 = 0;
    var acc: u32 = 0;
    while(count < channels):(count += 1){
       acc |= std.math.shl(u32,1,count);
    } 
    
    return acc;    
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
            "verify_channel_mask",
            "short_write_should_signal_error"
        };

        print("Running tests...\n", .{});
        inline for (tests) |fn_name| {
            print("{s}...\n", .{fn_name});
            try @field(@This(), "test_" ++ fn_name)();
        }
        print("All {d} tests passed. \n", .{tests.len});
    }

    test "verify_channel_mask"{
        test_verify_channel_mask();
    }
    fn test_verify_channel_mask() !void{

        try testing.expectEqual(try channel_mask(0),0);
        try testing.expectEqual(try channel_mask(1),1);
        try testing.expectEqual(try channel_mask(2),3);
        try testing.expectEqual(try channel_mask(3),7);
        try testing.expectEqual(try channel_mask(4),15);
    }
    
    
    test "short_write_should_signal_error"{
        test_short_write_should_signal_error();
    }
    fn test_short_write_should_signal_error()!void{

        var buffer= std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);        

        const write_spec = lib.WavSpec{
            .channels= 17,
            .sample_rate= 48000,
            .bits_per_sample= 8,
            .sample_format= lib.SampleFormat.Int,        
        };

        // Deliberately write one sample less than 17 * 5.
        var w = writer().init(buffer,write_spec);
        try w.write_format(allocator);
//    let mut writer = WavWriter::new(&mut buffer, write_spec).unwrap();
//    for s in 0..17 * 5 - 1 {
//        writer.write_sample(s as i16).unwrap();
//    }
//    let error = writer.finalize().err().unwrap();

//    match error {
//        Error::UnfinishedSample => {}
//        _ => panic!("UnfinishedSample error should have been returned."),
//    }
    }
};



test "wide_write_should_signal_error" {
    test_wide_write_should_signal_error();
}
fn test_wide_write_should_signal_error() !void {
    
}

test "s24_wav_write"{
    test_s24_wav_write();
}
fn test_s24_wav_write() !void {
    

}