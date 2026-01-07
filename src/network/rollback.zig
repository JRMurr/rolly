const std = @import("std");
const backend = @import("backend.zig");
const state = @import("../simulation/state.zig");
const input_mod = @import("../simulation/input.zig");
const sim = @import("../simulation/sim.zig");

const Backend = backend.Backend;
const Message = backend.Message;
const GameState = state.GameState;
const Input = input_mod.Input;

const MAX_ROLLBACK_FRAMES = 8;
const INPUT_BUFFER_SIZE = 128;

/// Rollback netcode manager.
/// Handles input delay, prediction, rollback, and resimulation.
pub const RollbackManager = struct {
    /// Local player index (0 or 1)
    local_player: u8,

    /// Current simulation tick
    current_tick: u32 = 0,

    /// Ring buffer of state snapshots for rollback
    snapshots: [MAX_ROLLBACK_FRAMES]GameState = undefined,

    /// Input history - confirmed inputs from both players
    /// Index: tick % INPUT_BUFFER_SIZE
    confirmed_inputs: [INPUT_BUFFER_SIZE][2]?Input = [_][2]?Input{.{ null, null }} ** INPUT_BUFFER_SIZE,

    /// Predicted inputs for remote player (when we haven't received them yet)
    predicted_inputs: [INPUT_BUFFER_SIZE]Input = [_]Input{Input.EMPTY} ** INPUT_BUFFER_SIZE,

    /// Last confirmed tick for each player
    last_confirmed_tick: [2]u32 = .{ 0, 0 },

    /// Input delay (local inputs are scheduled this many frames ahead)
    input_delay: u32 = 2,

    /// Statistics
    rollback_count: u32 = 0,
    total_frames_resimulated: u32 = 0,

    pub fn init(local_player: u8) RollbackManager {
        return .{
            .local_player = local_player,
        };
    }

    /// Add local input - will be scheduled for (current_tick + input_delay)
    pub fn addLocalInput(self: *RollbackManager, input: Input, net: Backend) !void {
        const target_tick = self.current_tick + self.input_delay;
        const idx = target_tick % INPUT_BUFFER_SIZE;

        self.confirmed_inputs[idx][self.local_player] = input;
        self.last_confirmed_tick[self.local_player] = target_tick;

        // Send to remote
        try net.send(.{ .input = .{
            .tick = target_tick,
            .player_id = self.local_player,
            .input = input,
        } });
    }

    /// Process incoming network messages
    pub fn processNetwork(self: *RollbackManager, net: Backend) void {
        while (net.poll()) |msg| {
            switch (msg) {
                .input => |inp| {
                    self.receiveRemoteInput(inp.tick, inp.player_id, inp.input);
                },
                else => {},
            }
        }
    }

    fn receiveRemoteInput(self: *RollbackManager, tick: u32, player_id: u8, input: Input) void {
        const idx = tick % INPUT_BUFFER_SIZE;

        // Check if this differs from our prediction
        const predicted = self.predicted_inputs[idx];
        const needs_rollback = !predicted.eql(input) and tick <= self.current_tick;

        self.confirmed_inputs[idx][player_id] = input;
        self.last_confirmed_tick[player_id] = @max(self.last_confirmed_tick[player_id], tick);

        if (needs_rollback) {
            self.rollback_count += 1;
        }
    }

    /// Advance simulation by one tick, handling rollback if needed
    pub fn advance(self: *RollbackManager, game: *GameState) void {
        // Save snapshot for potential rollback
        const snapshot_idx = self.current_tick % MAX_ROLLBACK_FRAMES;
        self.snapshots[snapshot_idx] = game.snapshot();

        // Get inputs for this tick
        const inputs = self.getInputsForTick(self.current_tick);

        // Step simulation
        sim.step(game, inputs);
        self.current_tick += 1;
    }

    /// Get inputs for a tick, using prediction for unconfirmed remote inputs
    fn getInputsForTick(self: *RollbackManager, tick: u32) [2]Input {
        const idx = tick % INPUT_BUFFER_SIZE;
        var inputs: [2]Input = .{ Input.EMPTY, Input.EMPTY };

        for (0..2) |i| {
            if (self.confirmed_inputs[idx][i]) |confirmed| {
                inputs[i] = confirmed;
            } else {
                // Use prediction (repeat last known input)
                inputs[i] = self.predictInput(@intCast(i), tick);
            }
        }

        return inputs;
    }

    /// Predict remote player's input (simple: repeat last known input)
    fn predictInput(self: *RollbackManager, player: u8, tick: u32) Input {
        // Look backwards for last confirmed input
        var t = tick;
        while (t > 0) : (t -= 1) {
            const idx = t % INPUT_BUFFER_SIZE;
            if (self.confirmed_inputs[idx][player]) |inp| {
                // Store prediction
                self.predicted_inputs[tick % INPUT_BUFFER_SIZE] = inp;
                return inp;
            }
        }
        return Input.EMPTY;
    }

    /// Perform rollback and resimulation if needed
    pub fn rollbackIfNeeded(self: *RollbackManager, game: *GameState) void {
        // Find earliest tick with misprediction
        var rollback_to: ?u32 = null;

        for (self.last_confirmed_tick) |confirmed_tick| {
            if (confirmed_tick < self.current_tick) {
                // Check if prediction was wrong
                const idx = confirmed_tick % INPUT_BUFFER_SIZE;
                const predicted = self.predicted_inputs[idx];

                for (self.confirmed_inputs[idx]) |maybe_inp| {
                    if (maybe_inp) |inp| {
                        if (!predicted.eql(inp)) {
                            if (rollback_to == null or confirmed_tick < rollback_to.?) {
                                rollback_to = confirmed_tick;
                            }
                        }
                    }
                }
            }
        }

        if (rollback_to) |target| {
            self.performRollback(game, target);
        }
    }

    fn performRollback(self: *RollbackManager, game: *GameState, target_tick: u32) void {
        // Can only rollback within our snapshot buffer
        if (self.current_tick - target_tick > MAX_ROLLBACK_FRAMES) {
            // Too far back - would need full state sync
            return;
        }

        // Restore snapshot
        const snapshot_idx = target_tick % MAX_ROLLBACK_FRAMES;
        game.restore(self.snapshots[snapshot_idx]);

        // Resimulate from target to current
        const frames_to_resim = self.current_tick - target_tick;
        self.total_frames_resimulated += frames_to_resim;

        var t = target_tick;
        while (t < self.current_tick) : (t += 1) {
            const inputs = self.getInputsForTick(t);
            sim.step(game, inputs);
        }
    }

    /// Get sync status for display
    pub fn getSyncStatus(self: *RollbackManager) struct { behind: u32, rollbacks: u32 } {
        const local_confirmed = self.last_confirmed_tick[self.local_player];
        const remote_confirmed = self.last_confirmed_tick[1 - self.local_player];
        const behind = if (local_confirmed > remote_confirmed)
            local_confirmed - remote_confirmed
        else
            0;

        return .{
            .behind = behind,
            .rollbacks = self.rollback_count,
        };
    }
};

test "rollback manager basic flow" {
    var game = GameState.init();
    var mgr = RollbackManager.init(0);

    // Advance a few ticks
    for (0..10) |_| {
        mgr.advance(&game);
    }

    try std.testing.expectEqual(@as(u32, 10), mgr.current_tick);
    try std.testing.expectEqual(@as(u32, 10), game.tick);
}
