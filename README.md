# MirageKit

Drop-in window and desktop streaming for Apple platforms. Stream a Mac to iPad, Vision Pro, or another Mac in a few lines of Swift — discovery, transport, decode, presentation, and input forwarding are handled for you.

> Pre-release. APIs and behavior may still change.

## What you get

- Window, app, and full-desktop streaming from any modern Mac
- Bonjour discovery with peer-to-peer transport over AWDL
- Drop-in SwiftUI views backed by `AVSampleBufferDisplayLayer`
- Input forwarding for mouse, keyboard, scroll, gestures, Apple Pencil, and direct touch
- Virtual display capture for pixel-perfect remote screens
- Native sizing on iOS and visionOS using `nativeBounds` and `nativeScale`
- Menu bar passthrough, remote unlock, and shared clipboard built in

## Requirements

- macOS 26+ for hosting, macOS 13+ / iOS 26+ / visionOS 26+ for clients
- Swift 6.2+ to build (macOS 13 clients are cross-compiled from a newer Mac;
  Xcode on macOS 13 cannot compile Swift 6)

### macOS 13 client backport

The package's macOS floor is 13.0 so Intel Macs on Ventura can run
`MirageKitClient`:

- Client and core code genuinely run on macOS 13: `ObservableObject`-based
  state (`MirageClientService`, `MirageClientSessionStore`,
  `MirageStreamSessionState`), a `CVDisplayLink` presentation-pacing fallback,
  layer-level `AVSampleBufferDisplayLayer` playback control, and bundled
  cursor images where macOS 15 frame-resize cursors are missing.
- Host-only code (`MirageKitHost`) still requires macOS 26 at runtime; newer
  APIs it uses are availability-gated so the package compiles at the 13 floor.
- Loom is vendored at `Dependencies/Loom` with its own macOS 13 backport
  (see `Dependencies/Loom/VENDORED.md`).
- `MirageEncoderOverrides.intelDisplayClient()` provides encoder settings
  tuned for Intel hardware HEVC decode over Thunderbolt.

## Install

```swift
.package(url: "https://github.com/EthanLipnik/MirageKit.git", from: "1.0.5"),
```

Pick the products you need:

- `MirageKitClient` — connect to a host, render the stream, send input
- `MirageKitHost` — capture, encode, and serve a Mac to clients
- `MirageKit` — shared types and protocol (added automatically)
- `MirageHostBootstrapRuntime` — pre-login and unlock support

## Host a Mac

```swift
import MirageKitHost

@MainActor
final class HostController: MirageHostDelegate {
    private let host = MirageHostService()

    init() { host.delegate = self }

    func start() async throws {
        try await host.start()
    }
}
```

## Connect from a client

```swift
import MirageKitClient

@MainActor
final class ClientController: MirageClientDelegate {
    let client = MirageClientService()

    init() { client.delegate = self }

    func connect(to host: LoomPeer) async throws {
        try await client.connect(to: host)
        try await client.requestWindowList()
    }
}
```

## Render the stream

```swift
import MirageKitClient
import SwiftUI

struct StreamView: View {
    let streamID: StreamID

    var body: some View {
        MirageStreamViewRepresentable(
            streamID: streamID,
            onInputEvent: { event in /* forward to MirageClientService */ },
            onDrawableMetricsChanged: { metrics in /* request resize */ }
        )
    }
}
```

For most apps, `MirageStreamContentView` is even simpler — wire it up to a `MirageClientSessionStore` and the input, focus, and resize plumbing comes along for the ride:

```swift
let sessionStore = MirageClientSessionStore()
let client = MirageClientService(sessionStore: sessionStore)

MirageStreamContentView(
    session: session,
    sessionStore: sessionStore,
    clientService: client,
    isDesktopStream: false
)
```

## Configuration

Defaults are tuned for low-latency interactive streaming. When you need to override, `MirageEncoderConfiguration` exposes codec, frame rate, encoder quality, and bit depth, and `MirageEncoderOverrides` lets clients request per-stream tweaks.

Streaming modes:

- **Window** — capture a single window with ScreenCaptureKit
- **App** — group windows by bundle identifier and follow new windows as they spawn
- **Desktop** — mirror a virtual display sized to the client for 1:1 pixels

## Input

`MirageInputEvent` carries normalized intent for mouse, keyboard, scroll, magnify, and rotate. Apple Pencil sends pressure, tilt, and configurable Double Tap / Squeeze gestures. Direct touch supports a normal cursor mode and a drag-cursor mode with native scroll physics, tap-to-click, and long-press drag.

## Permissions

The macOS host needs Screen Recording for ScreenCaptureKit, and Accessibility for input forwarding and window activation.

Both ends need local network access for Bonjour. Add this to your app's Info.plist:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_miragekit._tcp</string>
</array>

<key>NSLocalNetworkUsageDescription</key>
<string>Discover and connect to nearby Mirage devices.</string>
```

For App Store distribution you'll also need the `com.apple.developer.networking.multicast` entitlement.

## Networking

MirageKit's transport is built on [Loom](https://github.com/EthanLipnik/Loom).

## Testing

```bash
swift build --package-path .
swift test --package-path .
```

## Contributing

Contributions are welcome. Most of MirageKit was built with agentic coding tools — using them is fine as long as you understand and can explain what you submit.

## License

MirageKit is licensed under PolyForm Shield 1.0.0. Use, modification, and distribution are allowed for non-competing products; providing products that compete with Mirage or other dedicated remote window/desktop/secondary display/drawing-tablet streaming applications and services is prohibited. See `LICENSE`.
