const std = @import("std");
const Input = @import("input.zig").Input;

pub const MAX_PLAYERS = 2;

pub const Vec2 = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn scale(v: Vec2, s: i32) Vec2 {
        return .{ .x = v.x * s, .y = v.y * s };
    }

    pub fn eql(a: Vec2, b: Vec2) bool {
        return a.x == b.x and a.y == b.y;
    }
};

pub const Player = struct {
    pos: Vec2,
    vel: Vec2,

    pub fn init(x: i32, y: i32) Player {
        return .{
            .pos = .{ .x = x, .y = y },
            .vel = .{},
        };
    }
};

/// Game state - must be trivially copyable for rollback snapshots.
/// No pointers, no allocations, all value types.
pub const GameState = struct {
    tick: u32,
    players: [MAX_PLAYERS]Player,

    pub fn init() GameState {
        return .{
            .tick = 0,
            .players = .{
                Player.init(200, 300),
                Player.init(600, 300),
            },
        };
    }

    /// Create a snapshot for rollback
    pub fn snapshot(self: GameState) GameState {
        return self; // trivial copy
    }

    /// Restore from a snapshot
    pub fn restore(self: *GameState, snap: GameState) void {
        self.* = snap;
    }

    /// Check if two states are identical (for detecting prediction errors)
    pub fn eql(self: GameState, other: GameState) bool {
        if (self.tick != other.tick) return false;
        for (self.players, other.players) |a, b| {
            if (!a.pos.eql(b.pos) or !a.vel.eql(b.vel)) {
                return false;
            }
        }
        return true;
    }
};

test "state snapshot and restore" {
    var state = GameState.init();
    state.players[0].pos.x = 100;

    const snap = state.snapshot();
    state.players[0].pos.x = 999;

    state.restore(snap);
    try std.testing.expectEqual(@as(i32, 100), state.players[0].pos.x);
}

test "vec2 operations" {
    const a = Vec2{ .x = 10, .y = 20 };
    const b = Vec2{ .x = 3, .y = 4 };

    try std.testing.expect(Vec2.add(a, b).eql(.{ .x = 13, .y = 24 }));
    try std.testing.expect(Vec2.sub(a, b).eql(.{ .x = 7, .y = 16 }));
    try std.testing.expect(Vec2.scale(b, 2).eql(.{ .x = 6, .y = 8 }));
}
