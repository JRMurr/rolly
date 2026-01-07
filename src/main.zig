const std = @import("std");
const rl = @import("raylib");

// Game constants
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

pub fn main() !void {
    // Initialize window
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Rolly - Rollback Netcode Demo");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Game loop
    while (!rl.windowShouldClose()) {
        // Update
        update();

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        draw();
    }
}

fn update() void {
    // TODO: Game state update logic
    // TODO: Input handling
    // TODO: Rollback netcode integration
}

fn draw() void {
    // Placeholder: draw a simple sprite/rectangle
    rl.drawRectangle(
        SCREEN_WIDTH / 2 - 25,
        SCREEN_HEIGHT / 2 - 25,
        50,
        50,
        rl.Color.ray_white,
    );

    rl.drawText("Rolly - Rollback Netcode Demo", 10, 10, 20, rl.Color.light_gray);
    rl.drawText("Press ESC to exit", 10, SCREEN_HEIGHT - 30, 16, rl.Color.gray);
}

test "basic test" {
    // Placeholder test
    try std.testing.expect(true);
}
