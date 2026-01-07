const rl = @import("raylib");
const state = @import("../simulation/state.zig");

const GameState = state.GameState;
const Player = state.Player;

const PLAYER_SIZE = 50;

const PLAYER_COLORS = [_]rl.Color{
    rl.Color.blue,
    rl.Color.red,
};

/// Stateless renderer - reads GameState and draws to screen.
/// Can be extended to interpolate between ticks for smooth visuals.
pub const Renderer = struct {
    /// Optional: previous state for interpolation
    prev_state: ?GameState = null,

    pub fn init() Renderer {
        return .{};
    }

    /// Main render function - draws the current game state
    pub fn render(self: *Renderer, game: *const GameState, alpha: f32) void {
        _ = alpha; // TODO: use for interpolation
        _ = self;

        rl.clearBackground(rl.Color.dark_gray);

        // Draw players
        for (game.players, 0..) |player, i| {
            drawPlayer(&player, PLAYER_COLORS[i]);
        }

        // Draw HUD
        drawHud(game);
    }

    /// Store state for next frame's interpolation
    pub fn storePrevState(self: *Renderer, game: *const GameState) void {
        self.prev_state = game.*;
    }
};

fn drawPlayer(player: *const Player, color: rl.Color) void {
    rl.drawRectangle(
        player.x,
        player.y,
        PLAYER_SIZE,
        PLAYER_SIZE,
        color,
    );

    // Draw velocity indicator
    rl.drawLine(
        player.x + PLAYER_SIZE / 2,
        player.y + PLAYER_SIZE / 2,
        player.x + PLAYER_SIZE / 2 + player.vx * 2,
        player.y + PLAYER_SIZE / 2 + player.vy * 2,
        rl.Color.white,
    );
}

fn drawHud(game: *const GameState) void {
    var buf: [64]u8 = undefined;
    const tick_text = std.fmt.bufPrintZ(&buf, "Tick: {d}", .{game.tick}) catch "Tick: ???";

    const screen_height = rl.getScreenHeight();

    // Use larger font sizes for crisp text at higher resolutions
    rl.drawText(tick_text, 10, 10, 24, rl.Color.light_gray);
    rl.drawText("Rolly - Rollback Netcode Demo", 10, 40, 20, rl.Color.gray);
    rl.drawText("WASD to move | ESC to exit", 10, screen_height - 30, 20, rl.Color.gray);
}

const std = @import("std");
