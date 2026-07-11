# Vendored Loom

This is a vendored copy of [EthanLipnik/Loom](https://github.com/EthanLipnik/Loom)
at tag `2.0.11`, with a macOS 13 backport applied:

- `platforms` lowered from macOS 26 to macOS 13.
- `@Observable` classes converted to `ObservableObject` + `@Published`
  (`LoomNode`, `LoomDiscovery`, `LoomTrustStore`, `LoomOverlayDirectory`,
  `LoomCloudKitManager`, `LoomCloudKitPeerProvider`, `LoomCloudKitPeerManager`).
- The QUIC transport (`NetworkConnection`/`NetworkListener`/`QUIC`) is gated
  behind `@available(macOS 26.0, *)`; `LoomConnection.quic` carries a
  type-erased box, and QUIC connect/listen attempts throw below macOS 26.
  Mirage only uses TCP/UDP direct transports, so behavior is unchanged.
- `NWParameters.allowUltraConstrainedPaths` is applied only on macOS 26+.
- `LoomIdentityManager` falls back to a device-local (non-synchronizable)
  keychain write when the synchronizable write fails with
  `errSecMissingEntitlement`/`errSecParam` (apps without provisioning
  entitlements, and macOS 13 login keychains). Reads already query
  `kSecAttrSynchronizableAny`, so either kind of stored key is found.
