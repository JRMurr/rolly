const std = @import("std");

/// Compact input representation - must be serializable for network transmission.
/// Backing integer ensures exactly 1 byte with automatic padding.
pub const Input = packed struct(u8) {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    action1: bool = false,
    action2: bool = false,
    _: u2 = 0, // padding to fill u8
};

pub const EMPTY: Input = .{};

pub fn eql(a: Input, b: Input) bool {
    return @as(u8, @bitCast(a)) == @as(u8, @bitCast(b));
}

pub fn serialize(input: Input) u8 {
    return @bitCast(input);
}

pub fn deserialize(byte: u8) Input {
    return @bitCast(byte);
}

/// Inputs for all players in a single tick
pub const TickInputs = struct {
    inputs: [2]Input,

    pub fn init() TickInputs {
        return .{ .inputs = .{ EMPTY, EMPTY } };
    }
};

test "input serialization roundtrip" {
    const input: Input = .{
        .left = true,
        .right = false,
        .up = true,
        .down = false,
        .action1 = true,
        .action2 = false,
    };

    const serialized = serialize(input);
    const deserialized = deserialize(serialized);

    try std.testing.expect(eql(input, deserialized));
}
