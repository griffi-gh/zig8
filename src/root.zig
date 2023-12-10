const std = @import("std");
const BitSet = std.bit_set.IntegerBitSet;

const font: [80]u8 = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub const Chip8 = struct {
    memory: [4096]u8,
    registers: [16]u8,
    display: [32]BitSet(64),
    idx: u16,
    pc: u16,
    sp: u16,
    delay_timer: u8,
    sound_timer: u8,

    pub fn init() Chip8 {
        var chip8 = Chip8{
            .memory = [_]u8{0} ** 4096,
            .registers = [_]u8{0} ** 16,
            .display = [_]BitSet(64){BitSet(64).initEmpty()} ** 32,
            .idx = 0,
            .pc = 0x200,
            .sp = 0xfff,
            .delay_timer = 0,
            .sound_timer = 0,
        };
        for (font, 0..) |byte, i| {
            chip8.memory[i + 0x50] = byte;
        }
        return chip8;
    }

    pub fn load_rom(self: *Chip8, rom: []u8) void {
        for (rom, 0..) |byte, i| {
            self.memory[i] = byte;
        }
    }

    pub fn step(self: *Chip8) void {
        const op = std.mem.readInt(u16, &.{ self.memory[self.pc], self.memory[self.pc + 1] }, .big);
        self.pc += 2;
        switch (op) {
            else => std.debug.panic("unimplemented opcode {}", .{op}),
        }
    }
};
