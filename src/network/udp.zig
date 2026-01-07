const std = @import("std");
const backend = @import("backend.zig");

const Message = backend.Message;
const Allocator = std.mem.Allocator;

/// Real UDP network backend for production use
pub const UdpBackend = struct {
    const MessageList = std.ArrayListUnmanaged(Message);

    // Socket and connection state
    remote_addr: ?std.net.Address = null,
    socket: ?std.posix.socket_t = null,
    connected: bool = false,
    latency_ms: u32 = 0,

    // Receive buffer
    recv_queue: MessageList = .{},
    allocator: Allocator,

    pub fn init(allocator: Allocator) UdpBackend {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UdpBackend) void {
        if (self.socket) |sock| {
            std.posix.close(sock);
        }
        self.recv_queue.deinit(self.allocator);
    }

    pub fn connect(self: *UdpBackend, host: []const u8, port: u16) !void {
        self.remote_addr = try std.net.Address.parseIp4(host, port);

        self.socket = try std.posix.socket(
            std.posix.AF.INET,
            std.posix.SOCK.DGRAM,
            0,
        );

        // Set non-blocking
        const flags = try std.posix.fcntl(self.socket.?, std.posix.F.GETFL);
        _ = try std.posix.fcntl(
            self.socket.?,
            std.posix.F.SETFL,
            @as(u32, @bitCast(flags)) | std.posix.SOCK.NONBLOCK,
        );

        self.connected = true;
    }

    pub fn send(self: *UdpBackend, msg: Message) !void {
        if (self.socket == null or self.remote_addr == null) {
            return error.NotConnected;
        }

        const bytes = serializeMessage(msg);
        _ = try std.posix.sendto(
            self.socket.?,
            &bytes,
            0,
            &self.remote_addr.?.any,
            self.remote_addr.?.getOsSockLen(),
        );
    }

    pub fn poll(self: *UdpBackend) ?Message {
        if (self.socket == null) return null;

        // Try to receive
        var buf: [256]u8 = undefined;
        const result = std.posix.recvfrom(self.socket.?, &buf, 0, null, null);

        if (result) |bytes_read| {
            if (bytes_read > 0) {
                return deserializeMessage(buf[0..bytes_read]);
            }
        } else |_| {
            // Would block or error - no data available
        }

        return null;
    }

    pub fn isConnected(self: *UdpBackend) bool {
        return self.connected;
    }

    pub fn getLatencyMs(self: *UdpBackend) u32 {
        return self.latency_ms;
    }
};

fn serializeMessage(msg: Message) [256]u8 {
    // TODO: proper serialization
    _ = msg;
    return .{0} ** 256;
}

fn deserializeMessage(bytes: []const u8) ?Message {
    // TODO: proper deserialization
    _ = bytes;
    return null;
}
