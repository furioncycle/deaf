const std = @import("std");
const clap = @import("clap");

const debug = std.debug;
const io = std.io;
const fs = std.fs;

pub fn main() anyerror!void {    
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-w, --wave <STR>...  a wave file to be passed in    ") catch unreachable,
    };
    
    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag}) catch |err| {
        //Report usefull errors and exit
        diag.report(io.getStdErr().writer(),err) catch {};
        return err;
    };
    defer args.deinit();
    
    for(args.options("--wave"))|s|{
        //Grab from cwd 
        const file = try fs.cwd().openFile(
            s,
            .{ .read = true, },
        );
        defer file.close();
        
        const stat = try file.stat();
        
        debug.print("{s}\n size: {d}\n kind: {s}",.{s,stat.size,stat.kind});
    }
}