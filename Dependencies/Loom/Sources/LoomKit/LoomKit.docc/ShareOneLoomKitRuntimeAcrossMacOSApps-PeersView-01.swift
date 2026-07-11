import LoomKit
import SwiftUI

struct PeersView: View {
    @LoomQuery(.peers(sort: .name)) private var peers: [LoomPeerSnapshot]

    var body: some View {
        List(peers) { peer in
            VStack(alignment: .leading, spacing: 4) {
                Text(peer.name)
                if let appID = peer.appID {
                    Text(appID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
