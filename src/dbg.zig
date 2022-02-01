const nowav = @import("nowav.zig");
const write = @import("write.zig");

pub fn main() !void {
    try nowav.runAllTests();
    try write.runAllTests();
}
