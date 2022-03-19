const std = @import("std");
const writer = @import("write.zig");
const lib = @import("lib.zig");

pub fn write_padded(comptime T: type, w: *writer.writer(), alloc: std.mem.Allocator, sample: T, bits: u16, bytes: u16) !void {
  if (bits == 8 and bytes == 1) { 
     try w.write_u8(
          alloc,
          lib.u8_from_signed( 
          try lib.narrow_to_i8(@intCast(i32,sample))
          )
        );
  }else if(bits == 16 and bytes == 2) {
     try w.write_le_i16(alloc,@intCast(i16,sample));           
  }else if(bits == 24 and bytes == 3) {
     try w.write_le_i24(alloc,@intCast(i32,sample));
   }else if(bits == 24 and bytes == 4){
     try w.write_le_i24_4(alloc,@intCast(i32,sample));
   }else if(bits == 32 and bytes == 4){
     try w.write_le_i32(alloc,@intCast(i32,sample));
   }   
}

