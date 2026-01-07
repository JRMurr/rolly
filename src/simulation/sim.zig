const std = @import("std");
const state = @import("state.zig");
const input = @import("input.zig");

const GameState = state.GameState;
const Player = state.Player;
const Vec2 = state.Vec2;
const Input = input.Input;

const MOVE_SPEED: i32 = 5;
const FRICTION: i32 = 1;
const BOUNDS: Vec2 = .{ .x = 1280, .y = 720 };
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
    if (inp.left) player.vel.x -= MOVE_SPEED;
    if (inp.right) player.vel.x += MOVE_SPEED;
    if (inp.up) player.vel.y -= MOVE_SPEED;
    if (inp.down) player.vel.y += MOVE_SPEED;

    // Apply friction
    player.vel.x = applyFriction(player.vel.x);
    player.vel.y = applyFriction(player.vel.y);

    // Clamp velocity
    player.vel.x = std.math.clamp(player.vel.x, -20, 20);
    player.vel.y = std.math.clamp(player.vel.y, -20, 20);

    // Update position
    player.pos = Vec2.add(player.pos, player.vel);

    // Clamp to bounds
    player.pos.x = std.math.clamp(player.pos.x, 0, BOUNDS.x - PLAYER_SIZE);
    player.pos.y = std.math.clamp(player.pos.y, 0, BOUNDS.y - PLAYER_SIZE);
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
    const start_x = game.players[0].pos.x;

    // Move right for a few ticks
    for (0..10) |_| {
        step(&game, .{ .{ .right = true }, input.EMPTY });
    }

    try std.testing.expect(game.players[0].pos.x > start_x);
}
