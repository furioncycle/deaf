const std = @import("std");
const testing = std.testing;

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
};

test "short_write_should_signal_error"{
    test_short_write_should_signal_error();
}
fn test_short_write_should_signal_error()!void{

}

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