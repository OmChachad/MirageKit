import LoomKit
import SwiftUI

struct RemoteAccessView: View {
    @Environment(\.loomContext) private var loomContext
    @LoomQuery(.peers(filter: .remoteAccessEnabled, sort: .name))
    private var remotePeers: [LoomPeerSnapshot]

    var body: some View {
        List {
            Section("Reachability") {
                Button("Publish Remote Reachability") {
                    Task {
                        try? await loomContext.publishRemoteReachability(
                            sessionID: "studio-mac",
                            publicHostForTCP: "studio.example.com"
                        )
                    }
                }

                Button("Stop Publishing Reachability") {
                    Task {
                        await loomContext.stopPublishingRemoteReachability()
                    }
                }

                Text(
                    loomContext.isPublishingRemoteReachability
                        ? "Publishing remote signaling reachability"
                        : "Remote signaling reachability not published"
                )
                    .foregroundStyle(.secondary)
            }

            Section("Remote Peers") {
                ForEach(remotePeers) { peer in
                    Text(peer.name)
                }
            }
        }
        .navigationTitle("Remote Access")
    }
}
