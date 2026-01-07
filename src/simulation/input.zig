const std = @import("std");

/// Compact input representation - must be serializable for network transmission.
/// Using packed struct for consistent wire format.
pub const Input = packed struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    action1: bool = false,
    action2: bool = false,
    _padding: u2 = 0,

    pub const EMPTY: Input = .{};

    pub fn eql(self: Input, other: Input) bool {
        return @as(u8, @bitCast(self)) == @as(u8, @bitCast(other));
    }

    pub fn serialize(self: Input) u8 {
        return @bitCast(self);
    }

    pub fn deserialize(byte: u8) Input {
        return @bitCast(byte);
    }
};

/// Inputs for all players in a single tick
pub const TickInputs = struct {
    inputs: [2]Input,

    pub fn init() TickInputs {
        return .{ .inputs = .{ Input.EMPTY, Input.EMPTY } };
    }
};

test "input serialization roundtrip" {
    const input = Input{
        .left = true,
        .right = false,
        .up = true,
        .down = false,
        .action1 = true,
        .action2 = false,
    };

    const serialized = input.serialize();
    const deserialized = Input.deserialize(serialized);

    try std.testing.expect(input.eql(deserialized));
}
