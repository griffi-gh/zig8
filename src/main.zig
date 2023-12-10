const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const chip8 = @import("root.zig");

const WIN_SIZE = raylib.Vector2{ .x = 640, .y = 320 };

pub fn main() !void {
    _ = try std.io.getStdOut().write("\n");

    var buffer: [0xfff]u8 = undefined;

    const file_path = a: {
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var args = try std.process.ArgIterator.initWithAllocator(fba.allocator());

        _ = args.skip();
        const path = args.next() orelse {
            std.log.err("expected at least one file name as an argument\n", .{});
            return;
        };

        break :a path;
    };

    const file_data = a: {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const size = try file.readAll(&buffer);
        break :a buffer[0..size];
    };

    var emu = comptime chip8.Chip8.init();
    emu.load_rom(file_data);

    raylib.SetTraceLogLevel(raylib.LOG_WARNING);
    raylib.SetConfigFlags(raylib.FLAG_VSYNC_HINT);
    raylib.SetTargetFPS(60);

    raylib.InitWindow(WIN_SIZE.x, WIN_SIZE.y, "Chip8");
    defer raylib.CloseWindow();

    const image = raylib.Image{
        .width = 64,
        .height = 32,
        .mipmaps = 1,
        .format = raylib.PIXELFORMAT_UNCOMPRESSED_GRAYSCALE,
    };
    const texture = raylib.LoadTextureFromImage(image);
    defer raylib.UnloadTexture(texture);
    raylib.UnloadImage(image);

    var pixels = [_]u8{0} ** (64 * 32);

    while (!raylib.WindowShouldClose()) {
        emu.step();
        for (emu.display, 0..32) |row_data, row| {
            for (0..64) |col| {
                pixels[row * 64 + col] = if (row_data.isSet(col)) 255 else 0;
            }
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.BLACK);

        raylib.UpdateTexture(texture, @ptrCast(&pixels));
        raylib.DrawTexturePro(
            texture,
            raylib.Rectangle{ .x = 0, .y = 0, .width = 64, .height = 32 },
            raylib.Rectangle{ .x = 0, .y = 0, .width = WIN_SIZE.x, .height = WIN_SIZE.y },
            raylib.Vector2{ .x = 0, .y = 0 },
            0,
            raylib.WHITE,
        );

        raylib.DrawFPS(0, 0);
    }
}
