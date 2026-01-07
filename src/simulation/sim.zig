const std = @import("std");
const state = @import("state.zig");
const input = @import("input.zig");

const GameState = state.GameState;
const Player = state.Player;
const Input = input.Input;

const MOVE_SPEED: i32 = 5;
const FRICTION: i32 = 1;
const BOUNDS_X: i32 = 800;
const BOUNDS_Y: i32 = 600;
const PLAYER_SIZE: i32 = 50;

/// Pure, deterministic simulation step.
/// Takes current state and inputs, advances state by one tick.
/// No side effects, no randomness (without seeded RNG passed in).
pub fn step(game: *GameState, inputs: [2]Input) void {
    // Process each player
    for (&game.players, inputs) |*player, inp| {
        updatePlayer(player, inp);
    }

    game.tick += 1;
}

fn updatePlayer(player: *Player, inp: Input) void {
    // Apply input to velocity
    if (inp.left) player.vx -= MOVE_SPEED;
    if (inp.right) player.vx += MOVE_SPEED;
    if (inp.up) player.vy -= MOVE_SPEED;
    if (inp.down) player.vy += MOVE_SPEED;

    // Apply friction
    player.vx = applyFriction(player.vx);
    player.vy = applyFriction(player.vy);

    // Clamp velocity
    player.vx = std.math.clamp(player.vx, -20, 20);
    player.vy = std.math.clamp(player.vy, -20, 20);

    // Update position
    player.x += player.vx;
    player.y += player.vy;

    // Clamp to bounds
    player.x = std.math.clamp(player.x, 0, BOUNDS_X - PLAYER_SIZE);
    player.y = std.math.clamp(player.y, 0, BOUNDS_Y - PLAYER_SIZE);
}

fn applyFriction(vel: i32) i32 {
    if (vel > 0) {
        return @max(0, vel - FRICTION);
    } else if (vel < 0) {
        return @min(0, vel + FRICTION);
    }
    return 0;
}

test "deterministic simulation" {
    // Same inputs should always produce same state
    var state1 = GameState.init();
    var state2 = GameState.init();

    const inputs = [2]Input{
        .{ .right = true, .down = true },
        .{ .left = true, .up = true },
    };

    // Run 100 ticks
    for (0..100) |_| {
        step(&state1, inputs);
        step(&state2, inputs);
    }

    try std.testing.expect(state1.eql(state2));
}

test "input affects state" {
    var game = GameState.init();
    const start_x = game.players[0].x;

    // Move right for a few ticks
    for (0..10) |_| {
        step(&game, .{ .{ .right = true }, input.EMPTY });
    }

    try std.testing.expect(game.players[0].x > start_x);
}
