const std = @import("std");
const rl = @import("raylib");

// Modules
const state = @import("simulation/state.zig");
const input_mod = @import("simulation/input.zig");
const sim = @import("simulation/sim.zig");
const renderer = @import("render/renderer.zig");
const network = @import("network/backend.zig");
const mock = @import("network/mock.zig");
const rollback = @import("network/rollback.zig");

const GameState = state.GameState;
const Input = input_mod.Input;
const Renderer = renderer.Renderer;
const Backend = network.Backend;
const MockBackend = mock.MockBackend;
const RollbackManager = rollback.RollbackManager;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize raylib
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Rolly - Rollback Netcode Demo");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Initialize game state
    var game = GameState.init();

    // Initialize renderer
    var render = Renderer.init();

    // Initialize network (using mock backend for now)
    var mock_backend = MockBackend.init(allocator);
    defer mock_backend.deinit();

    // For local testing: create a "remote" mock that we control
    var mock_remote = MockBackend.init(allocator);
    defer mock_remote.deinit();
    mock_backend.connectToPeer(&mock_remote);

    const net = Backend{ .mock = &mock_backend };

    // Initialize rollback manager (player 0 = local)
    var rollback_mgr = RollbackManager.init(0);

    // Game loop
    while (!rl.windowShouldClose()) {
        // Gather local input
        const local_input = gatherInput();

        // Add to rollback manager and send over network
        rollback_mgr.addLocalInput(local_input, net) catch {};

        // Simulate remote player input (for testing - mirror local with delay)
        simulateRemoteInput(&mock_remote, &rollback_mgr);

        // Process incoming network messages
        rollback_mgr.processNetwork(net);

        // Check for rollback
        rollback_mgr.rollbackIfNeeded(&game);

        // Advance simulation
        rollback_mgr.advance(&game);

        // Render
        rl.beginDrawing();
        defer rl.endDrawing();

        render.render(&game, 1.0);

        // Draw network stats
        drawNetStats(&rollback_mgr);
    }
}

fn gatherInput() Input {
    return .{
        .left = rl.isKeyDown(rl.KeyboardKey.a) or rl.isKeyDown(rl.KeyboardKey.left),
        .right = rl.isKeyDown(rl.KeyboardKey.d) or rl.isKeyDown(rl.KeyboardKey.right),
        .up = rl.isKeyDown(rl.KeyboardKey.w) or rl.isKeyDown(rl.KeyboardKey.up),
        .down = rl.isKeyDown(rl.KeyboardKey.s) or rl.isKeyDown(rl.KeyboardKey.down),
        .action1 = rl.isKeyDown(rl.KeyboardKey.space),
        .action2 = rl.isKeyDown(rl.KeyboardKey.left_shift),
    };
}

/// Simulate a remote player for local testing
fn simulateRemoteInput(remote: *MockBackend, mgr: *RollbackManager) void {
    // Simple AI: just send empty inputs periodically
    if (mgr.current_tick % 5 == 0) {
        const msg = network.Message{ .input = .{
            .tick = mgr.current_tick + 2,
            .player_id = 1,
            .input = Input.EMPTY,
        } };
        remote.send(msg) catch {};
    }
}

fn drawNetStats(mgr: *RollbackManager) void {
    const stats = mgr.getSyncStatus();

    var buf: [128]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "Rollbacks: {d} | Behind: {d} frames", .{
        stats.rollbacks,
        stats.behind,
    }) catch "Stats: ???";

    rl.drawText(text, 10, 55, 16, rl.Color.yellow);
}

// Re-export tests from submodules
test {
    _ = @import("simulation/state.zig");
    _ = @import("simulation/input.zig");
    _ = @import("simulation/sim.zig");
    _ = @import("network/mock.zig");
    _ = @import("network/rollback.zig");
}
