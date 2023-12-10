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

fn unimplemented(op: u16) void {
    std.log.err("unimplemented opcode {x}", .{op});
}

pub const Chip8 = struct {
    memory: [4096]u8,
    registers: [16]u8,
    display: [32]BitSet(64),
    keyboard: BitSet(16),
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
            .keyboard = BitSet(16).initEmpty(),
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
        const op_x: u4 = @truncate(op >> 8);
        const op_y: u4 = @truncate(op >> 4);
        const op_n: u4 = @truncate(op);
        const reg_x = &self.registers[op_x];
        const reg_y = &self.registers[op_y];
        self.pc += 2;
        switch (op) {
            0x00E0 => self.display = [_]BitSet(64){BitSet(64).initEmpty()} ** 32,
            0x00EE => {
                self.pc = std.mem.readInt(u16, self.memory[self.sp..][0..2], .big);
                self.sp += 2;
            },
            0x1000...0x1FFF => self.pc = op & 0xFFF,
            0x2000...0x2FFF => {
                self.sp -= 2;
                std.mem.writeInt(u16, self.memory[self.sp..][0..2], self.pc, .big);
                self.pc = op & 0xFFF;
            },
            0x3000...0x3FFF => {
                if (reg_x.* == (op & 0xFF)) {
                    self.pc += 2;
                }
            },
            0x6000...0x6FFF => reg_x.* = @truncate(op),
            0x7000...0x7FFF => reg_x.* +%= @truncate(op),
            0x8000...0x8FFF => {
                const reg_f = &self.registers[0xF];
                switch (op & 0xF) {
                    0x0 => reg_x.* = reg_y.*,
                    0x1 => reg_x.* |= reg_y.*,
                    0x2 => reg_x.* &= reg_y.*,
                    0x3 => reg_x.* ^= reg_y.*,
                    0x4 => {
                        const result = @addWithOverflow(reg_x.*, reg_y.*);
                        reg_x.* = result[0];
                        reg_f.* = @as(u8, result[1]);
                    },
                    0x5 => {
                        const result = @subWithOverflow(reg_x.*, reg_y.*);
                        reg_x.* = result[0];
                        reg_f.* = @as(u8, ~result[1]);
                    },
                    0x6 => {
                        reg_f.* = reg_y.* & 0x1;
                        reg_x.* = reg_y.* >> 1;
                    },
                    0x7 => {
                        const result = @subWithOverflow(reg_y.*, reg_x.*);
                        reg_x.* = result[0];
                        reg_f.* = @as(u8, ~result[1]);
                    },
                    0xE => {
                        reg_f.* = reg_y.* >> 7;
                        reg_x.* = reg_y.* << 1;
                    },
                    else => unimplemented(op),
                }
            },
            0x9000...0x9FFF => {
                if (reg_x.* != reg_y.*) {
                    self.pc += 2;
                }
            },
            0xA000...0xAFFF => self.idx = op & 0x0FFF,
            0xB000...0xBFFF => self.pc = (op & 0x0FFF) +% @as(u16, self.registers[0]),
            0xC000...0xCFFF => reg_x.* = 0, //TODO Random
            0xD000...0xDFFF => {
                const offset_x: u6 = @truncate(reg_x.*);
                const offset_y: u5 = @truncate(reg_y.*);
                self.registers[0xF] = 0;
                for (0..op_n) |y| {
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
            0xE000...0xEFFF => switch (op & 0xFF) {
                0x9E => {
                    if (self.keyboard.isSet(reg_x.*)) {
                        self.pc += 2;
                    }
                },
                0xA1 => {
                    if (!self.keyboard.isSet(reg_x.*)) {
                        self.pc += 2;
                    }
                },
                else => unimplemented(op),
            },
            0xF000...0xFFFF => switch (op & 0xFF) {
                0x07 => reg_x.* = self.delay_timer,
                0x15 => self.delay_timer = reg_x.*,
                0x18 => self.sound_timer = reg_x.*,
                0x1E => self.idx +%= reg_x.*,
                0x55 => {
                    for (0..op_x + 1) |i| {
                        self.memory[self.idx + i] = self.registers[i];
                    }
                },
                0x65 => {
                    for (0..op_x + 1) |i| {
                        self.registers[i] = self.memory[self.idx + i];
                    }
                },
                else => unimplemented(op),
            },
            else => unimplemented(op),
        }

        if (self.delay_timer > 0) self.delay_timer -= 1;
        if (self.sound_timer > 0) self.sound_timer -= 1;
    }
};
