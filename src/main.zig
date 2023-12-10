const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const chip8 = @import("root.zig");

const WIN_SIZE = raylib.Vector2{ .x = 640, .y = 320 };
const ROM = @embedFile("./_ibm.ch8");

pub fn main() !void {
    //var allocator = std.heap.GeneralPurposeAllocator(.{}){};

    // const path = try std.process.argsAlloc(allocator.allocator());
    // const file = try std.fs.cwd().openFile(path[0], .{});
    // errdefer file.close();
    // const data = try file.readToEndAlloc(allocator.allocator(), 0xfff - 0x200);
    // file.close();

    var emu = chip8.Chip8.init();
    emu.load_rom(ROM);

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
