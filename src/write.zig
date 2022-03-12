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
     
     fn write_u8(self: *Self, alloc: std.mem.Allocator,x: u8) !void {
         var w = self.buffer.writer(alloc); 
         try w.print("{d}", .{x});
         //self.buffer.append(alloc,x);       
     }
    
     fn write_le_i16(self: *Self, alloc: std.mem.Allocator, x: i16) !void {
        try self.write_le_u16(alloc,@bitCast(u16,x));
     }
        
     fn write_le_u16(self: *Self, alloc: std.mem.Allocator, x: u16) !void {
//            var buf: [2]u8 = undefined;
//            buf[0] = @intCast(u8,x & 0xff);
//            buf[1] = @intCast(u8, x >> 8);
            var w = self.buffer.writer(alloc);
            try w.print("{d}",.{x});
            //try self.buffer.appendSlice(alloc,buf[0..]);
     }
     
     fn write_le_i24(self: *Self, alloc: std.mem.Allocator, x: i32) !void {
         try self.write_le_u24(alloc, @bitCast(u32,x));       
     } 
     
     fn write_le_i24_4(self: *Self, alloc: std.mem.Allocator, x: i32) !void {
         try self.write_le_u32(alloc, @bitCast(u32,x) & 0x00_ff_ff_ff);       
     }     
     fn write_le_u24(self: *Self, alloc: std.mem.Allocator, x: u32) !void {
//            var buf: [3]u8 = undefined;
//            buf[0] = @intCast(u8,x >> 00);
//            buf[1] = @intCast(u8, (x >> 08 ) & 0xff);
//            buf[2] = @intCast(u8, (x >> 16) & 0xff);
//            try self.buffer.appendSlice(alloc, buf);
            var w = self.buffer.writer(alloc);
            try w.print("{d}", .{@intCast(u24,x)});
     }
        
     
    fn write_le_i32(self: *Self, alloc: std.mem.Allocator, x: i32) !void {
         try self.write_le_u32(alloc, @bitCast(u32,x));       
     } 
     
     fn write_le_u32(self: *Self, alloc: std.mem.Allocator, x: u32) !void {
 //           var buf: [4]u8 = undefined;
 //           buf[0] = @intCast(u8,x >> 00);
 //           buf[1] = @intCast(u8, (x >> 08 ) & 0xff);
 //           buf[2] = @intCast(u8, (x >> 16) & 0xff);
 //           buf[3] = @intCast(u8, (x >> 24) & 0xff);
 //           try self.buffer.appendSlice(alloc, buf[0..]);
              var w = self.buffer.writer(alloc);
              try w.print("{d}", .{x});
    }     
    
    fn write_le_f32(self: *Self, alloc: std.mem.Allocator, x: f32) !void {
        var val = @bitCast(u32, x);        
        try self.write_le_u32(alloc,val);
    }
        
    fn write_waveformat(self: *Self, allocator: std.mem.Allocator) !void {
         try self.write_le_u16(allocator,self.spec_ex.spec.channels);
         
         try self.write_le_u32(allocator,self.spec_ex.spec.sample_rate);
         
         var bytes_per_sec = self.spec_ex.spec.sample_rate * self.spec_ex.bytes_per_sample * self.spec_ex.spec.channels;
         try self.write_le_u32(allocator, bytes_per_sec);
         try self.write_le_u32(allocator, bytes_per_sec/self.spec_ex.spec.sample_rate);
     }

     fn write_pcmwaveformat(self: *Self, allocator: std.mem.Allocator) !void {
        try self.write_le_u32(allocator,16); //write_le_u32
        
        try switch(self.spec_ex.spec.sample_format){
            lib.SampleFormat.Int => try self.write_le_u32(allocator,1), //write_le_u16
            lib.SampleFormat.Float => if(self.spec_ex.spec.bits_per_sample == 32) try self.buffer.append(allocator,3) else error.InvalidNumberOfBitsPerSample,
        };
            
        try self.write_waveformat(allocator);

        try self.write_le_u16(allocator,self.spec_ex.spec.bits_per_sample);
            
        //Missing WAVEFORMATEX 
        
      }
    
      
      fn write_waveformatExtensible(self: *Self, allocator: std.mem.Allocator) !void {
           try self.write_le_u32(allocator,40);     
           try self.write_le_u16(allocator,0xff); 
           try self.write_le_u16(allocator,0xfe);
           try self.write_waveformat(allocator);
           try self.write_le_u16(allocator, self.spec_ex.bytes_per_sample * 8);
           try self.write_le_u32(allocator, 22);
           try self.write_le_u16(allocator,self.spec_ex.spec.bits_per_sample);
           try self.write_le_u32(allocator, try channel_mask(self.spec_ex.spec.channels));
            
           var subformat_guid: [16]u8 = undefined;
           switch(self.spec_ex.spec.sample_format){
                lib.SampleFormat.Int => subformat_guid = lib.KSDATAFORMAT_SUBTYPE_PCM,
                lib.SampleFormat.Float =>  {
                    if(self.spec_ex.spec.bits_per_sample == 32) subformat_guid = lib.KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
                },
            }
            for(subformat_guid)|item|{
                try self.buffer.append(allocator, item);
            }
          
      }

      pub fn write_format(self: *Self, allocator: std.mem.Allocator) !void {
        const header: []const u8 = "RIFF    WAVE";

        try self.buffer.appendSlice(allocator,header);            
        
        var fmt_kind = lib.Fmt.Pcm;
        if (self.spec_ex.spec.channels > 2 or self.spec_ex.spec.bits_per_sample > 16){
            fmt_kind =  lib.Fmt.Extended;
        }
                                
        var supported = switch (self.spec_ex.spec.bits_per_sample) {
            8 , 16, 24, 32 => true,
            else => false,            
        };
        
        if(!supported){
            return error.Upsupported;
        }
            
        try self.buffer.appendSlice(allocator, "fmt");
        
        switch(fmt_kind){
            lib.Fmt.Pcm => try self.write_pcmwaveformat(allocator),
            else => try self.write_waveformatExtensible(allocator),
        }
            
        //Need position of current buffer? 
                                
      }
        
      pub fn start_data_chunk(self: *Self, alloc: std.mem.Allocator) !void {
        try self.buffer.appendSlice(alloc,"data");
        try self.write_le_u32(0);
        //state ?
      }
        
      fn update_data_chunk_header(self: *Self, alloc: std.mem.Allocator) !void {
          //has to be in data section
          //also has a known format 
          _ = alloc;          
          if(self.buffer.items.len / self.spec_ex.bytes_per_sample % self.spec_ex.spec.channels != 0){
             return error.UnfinishedSample;       
          }      
      }
      fn update_headers(self: *Self, alloc: std.mem.Allocator) !void {
         try self.update_data_chunk_header(alloc);
         //try self.update_riff_header(alloc);
          //scan to the area for length
          //add the length in 
          //scan back      
      }

      pub fn flush(self: *Self,alloc: std.mem.Allocator) !void {
          try self.update_headers(alloc);
      }  

      pub fn finalize(self: *Self,alloc: std.mem.Allocator) !void {

            try self.flush(alloc);
      }

      fn write_padded(self: *Self, alloc: std.mem.Allocator, sample: anytype, bits: u16, bytes: u16) !void {
            _ = self;
            if (bits == 8 and bytes == 1) { 
                try self.write_u8(
                    alloc,
                    lib.u8_from_signed( 
                        try lib.narrow_to_i8(@intCast(i32,sample))
                    )
                );
            }else if(bits == 16 and bytes == 2) {
                try self.write_le_i16(alloc,@intCast(i16,sample));           
            }else if(bits == 24 and bytes == 3) {
                try self.write_le_i24(alloc,@intCast(i32,sample));
            }else if(bits == 24 and bytes == 4){
                try self.write_le_i24_4(alloc,@intCast(i32,sample));
            }else if(bits == 32 and bytes == 4){
                try self.write_le_i32(alloc,@intCast(i32,sample));
            }
      }        
      pub fn write_samples(self: *Self, alloc: std.mem.Allocator, sample: anytype) !void {
            //get spec_ex 
            try self.write_padded(
                alloc,
                sample,
                self.spec_ex.spec.bits_per_sample,
                self.spec_ex.bytes_per_sample
            );
            //written = bytes_per_sample 
            //data state???
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

        {
            var i: usize = 0;
            while(i < (17 * 5 - 1)): (i += 1){
                try w.write_samples(allocator,@intCast(u16,i));           
            }
        }        
        
        try testing.expectError(error.UnfinishedSample,w.finalize(allocator));
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