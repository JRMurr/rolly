const std = @import("std");
const Input = @import("../simulation/input.zig").Input;

/// Network message types
pub const Message = union(enum) {
    /// Input for a specific tick
    input: InputMessage,
    /// Request to sync state
    sync_request: SyncRequest,
    /// Full state sync response
    sync_response: SyncResponse,
    /// Ping for latency measurement
    ping: PingMessage,
    pong: PingMessage,
};

pub const InputMessage = struct {
    tick: u32,
    player_id: u8,
    input: Input,
};

pub const SyncRequest = struct {
    from_tick: u32,
};

pub const SyncResponse = struct {
    tick: u32,
    checksum: u32,
    // In real impl, would include serialized state
};

pub const PingMessage = struct {
    timestamp: i64,
    sequence: u32,
};

/// Network backend interface - allows swapping between real UDP and mock for testing
pub const Backend = union(enum) {
    udp: *@import("udp.zig").UdpBackend,
    mock: *@import("mock.zig").MockBackend,

    pub fn send(self: Backend, msg: Message) !void {
        switch (self) {
            .udp => |b| try b.send(msg),
            .mock => |b| try b.send(msg),
        }
    }

    pub fn poll(self: Backend) ?Message {
        return switch (self) {
            .udp => |b| b.poll(),
            .mock => |b| b.poll(),
        };
    }

    pub fn isConnected(self: Backend) bool {
        return switch (self) {
            .udp => |b| b.isConnected(),
            .mock => |b| b.isConnected(),
        };
    }

    pub fn getLatencyMs(self: Backend) u32 {
        return switch (self) {
            .udp => |b| b.getLatencyMs(),
            .mock => |b| b.getLatencyMs(),
        };
    }
};
