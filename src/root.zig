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

    pub fn load_rom(self: *Chip8, rom: []const u8) void {
        for (rom, 0x200..) |byte, i| {
            self.memory[i] = byte;
        }
    }

    pub fn step(self: *Chip8) void {
        const op = std.mem.readInt(u16, self.memory[self.pc..][0..2], .big);
        self.pc += 2;
        switch (op) {
            0x00E0 => self.display = [_]BitSet(64){BitSet(64).initEmpty()} ** 32,
            0x1000...0x1FFF => self.pc = op & 0x0FFF,
            0x6000...0x6FFF => self.registers[(op & 0x0F00) >> 8] = @truncate(op),
            0x7000...0x7FFF => self.registers[(op & 0x0F00) >> 8] += @truncate(op),
            0xA000...0xAFFF => self.idx = op & 0x0FFF,
            0xD000...0xDFFF => {
                const n: u4 = @truncate(op);
                const xr: u4 = @truncate(op >> 8);
                const yr: u4 = @truncate(op >> 4);
                const offset_x: u6 = @truncate(self.registers[xr]);
                const offset_y: u5 = @truncate(self.registers[yr]);
                self.registers[0xF] = 0;
                for (0..n) |y| {
                    const mem_row = BitSet(8){ .mask = self.memory[self.idx + y] };
                    if (mem_row.mask == 0) continue;
                    var mem_row_iter = mem_row.iterator(.{});
                    while (mem_row_iter.next()) |x| {
                        const display_x = (7 - x) + @as(usize, offset_x);
                        const display_y = y + @as(usize, offset_y);
                        const display_row = &self.display[display_y];
                        if (display_row.isSet(display_x)) {
                            self.registers[0xF] = 1;
                        }
                        display_row.toggle(display_x);
                    }
                }
            },
            else => std.log.err("unimplemented opcode {}", .{op}),
        }
    }
};
