import LoomKit
import SwiftUI

@main
struct StudioApp: App {
    let loomContainer = try! LoomContainer(
        for: LoomContainerConfiguration(
            serviceType: "_studio._tcp",
            serviceName: "Studio Mac",
            deviceIDSuiteName: "group.com.example.studio.device",
            appGroup: LoomAppGroupConfiguration(
                appGroupIdentifier: "group.com.example.studio",
                app: LoomAppGroupAppDescriptor(
                    appID: "com.example.studio.mac",
                    displayName: "Studio",
                    metadata: ["role": "editor"],
                    supportedFeatures: ["studio.projects.v1"]
                )
            )
        )
    )

    var body: some Scene {
        WindowGroup {
            PeersView()
        }
        .loomContainer(loomContainer)
    }
}
