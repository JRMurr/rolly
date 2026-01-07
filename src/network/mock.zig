const std = @import("std");
const backend = @import("backend.zig");

const Message = backend.Message;
const Allocator = std.mem.Allocator;

/// Mock network backend for deterministic testing.
/// Connects two MockBackends together to simulate network communication.
pub const MockBackend = struct {
    const DelayedMessage = struct {
        msg: Message,
        deliver_at_poll: u64,
    };

    const MessageList = std.ArrayListUnmanaged(Message);
    const DelayedList = std.ArrayListUnmanaged(DelayedMessage);

    /// Queue of messages to deliver
    recv_queue: MessageList = .{},
    /// Peer backend (for direct delivery in tests)
    peer: ?*MockBackend = null,
    /// Simulated latency in ticks (messages delayed this many polls)
    simulated_latency_ticks: u32 = 0,
    /// Messages waiting to be delivered after latency
    delayed_queue: DelayedList = .{},

    allocator: Allocator,
    connected: bool = false,
    poll_count: u64 = 0,

    pub fn init(allocator: Allocator) MockBackend {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MockBackend) void {
        self.recv_queue.deinit(self.allocator);
        self.delayed_queue.deinit(self.allocator);
    }

    /// Connect two mock backends together for testing
    pub fn connectToPeer(self: *MockBackend, other: *MockBackend) void {
        self.peer = other;
        other.peer = self;
        self.connected = true;
        other.connected = true;
    }

    /// Set simulated network latency (in poll cycles)
    pub fn setLatency(self: *MockBackend, ticks: u32) void {
        self.simulated_latency_ticks = ticks;
    }

    pub fn send(self: *MockBackend, msg: Message) !void {
        if (self.peer) |peer| {
            if (self.simulated_latency_ticks == 0) {
                // Immediate delivery
                try peer.recv_queue.append(peer.allocator, msg);
            } else {
                // Delayed delivery
                try peer.delayed_queue.append(peer.allocator, .{
                    .msg = msg,
                    .deliver_at_poll = peer.poll_count + self.simulated_latency_ticks,
                });
            }
        }
    }

    pub fn poll(self: *MockBackend) ?Message {
        self.poll_count += 1;

        // Check for delayed messages that should now be delivered
        var i: usize = 0;
        while (i < self.delayed_queue.items.len) {
            if (self.delayed_queue.items[i].deliver_at_poll <= self.poll_count) {
                const delayed = self.delayed_queue.orderedRemove(i);
                self.recv_queue.append(self.allocator, delayed.msg) catch {};
            } else {
                i += 1;
            }
        }

        // Return next message from queue
        if (self.recv_queue.items.len > 0) {
            return self.recv_queue.orderedRemove(0);
        }
        return null;
    }

    pub fn isConnected(self: *MockBackend) bool {
        return self.connected;
    }

    pub fn getLatencyMs(self: *MockBackend) u32 {
        // Approximate: assume 16ms per tick
        return self.simulated_latency_ticks * 16;
    }

    /// Inject a message directly (for testing)
    pub fn injectMessage(self: *MockBackend, msg: Message) !void {
        try self.recv_queue.append(self.allocator, msg);
    }
};

test "mock backend peer communication" {
    const allocator = std.testing.allocator;

    var backend1 = MockBackend.init(allocator);
    defer backend1.deinit();
    var backend2 = MockBackend.init(allocator);
    defer backend2.deinit();

    backend1.connectToPeer(&backend2);

    // Send from 1 to 2
    const msg = Message{ .input = .{
        .tick = 42,
        .player_id = 0,
        .input = .{ .left = true },
    } };
    try backend1.send(msg);

    // Should arrive at 2
    const received = backend2.poll();
    try std.testing.expect(received != null);
    try std.testing.expectEqual(@as(u32, 42), received.?.input.tick);
}

test "mock backend simulated latency" {
    const allocator = std.testing.allocator;

    var backend1 = MockBackend.init(allocator);
    defer backend1.deinit();
    var backend2 = MockBackend.init(allocator);
    defer backend2.deinit();

    backend1.connectToPeer(&backend2);
    backend1.setLatency(3); // 3 poll delay

    const msg = Message{ .input = .{
        .tick = 1,
        .player_id = 0,
        .input = .{},
    } };
    try backend1.send(msg);

    // Should not arrive yet (poll increments counter then checks)
    try std.testing.expect(backend2.poll() == null); // poll_count = 1
    try std.testing.expect(backend2.poll() == null); // poll_count = 2

    // Now it should arrive (deliver_at_poll was set to 0 + 3 = 3)
    try std.testing.expect(backend2.poll() != null); // poll_count = 3
}
