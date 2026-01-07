const std = @import("std");
const Input = @import("input.zig").Input;

pub const MAX_PLAYERS = 2;

pub const Player = struct {
    x: i32,
    y: i32,
    vx: i32,
    vy: i32,

    pub fn init(x: i32, y: i32) Player {
        return .{
            .x = x,
            .y = y,
            .vx = 0,
            .vy = 0,
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
            if (a.x != b.x or a.y != b.y or a.vx != b.vx or a.vy != b.vy) {
                return false;
            }
        }
        return true;
    }
};

test "state snapshot and restore" {
    var state = GameState.init();
    state.players[0].x = 100;

    const snap = state.snapshot();
    state.players[0].x = 999;

    state.restore(snap);
    try std.testing.expectEqual(@as(i32, 100), state.players[0].x);
}
