import LoomKit
import SwiftUI

struct RemoteAccessView: View {
    @Environment(\.loomContext) private var loomContext
    @LoomQuery(.peers(filter: .remoteAccessEnabled, sort: .name))
    private var remotePeers: [LoomPeerSnapshot]

    @State private var statusLine = "Idle"

    var body: some View {
        List {
            Section("Reachability") {
                Button("Publish Remote Reachability") {
                    Task {
                        do {
                            try await loomContext.publishRemoteReachability(
                                sessionID: "studio-mac",
                                publicHostForTCP: "studio.example.com"
                            )
                            statusLine = "Publishing remote signaling presence"
                        } catch {
                            statusLine = error.localizedDescription
                        }
                    }
                }

                Button("Stop Publishing Reachability") {
                    Task {
                        await loomContext.stopPublishingRemoteReachability()
                        statusLine = "Stopped publishing remote signaling reachability"
                    }
                }
            }

            Section("Remote Peers") {
                ForEach(remotePeers) { peer in
                    Button(peer.name) {
                        Task {
                            await connect(to: peer)
                        }
                    }
                }
            }

            Section("Status") {
                Text(statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Remote Access")
    }

    private func connect(to peer: LoomPeerSnapshot) async {
        do {
            let connection = try await loomContext.connect(peer)
            try await connection.send("hello from remote signaling")
            statusLine = "Connected to \(peer.name)"
        } catch {
            statusLine = error.localizedDescription
        }
    }
}
