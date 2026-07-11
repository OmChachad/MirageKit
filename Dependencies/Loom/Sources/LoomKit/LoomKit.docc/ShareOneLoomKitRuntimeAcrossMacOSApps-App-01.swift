import LoomKit

let appGroup = LoomAppGroupConfiguration(
    appGroupIdentifier: "group.com.example.studio",
    app: LoomAppGroupAppDescriptor(
        appID: "com.example.studio.mac",
        displayName: "Studio",
        metadata: ["role": "editor"],
        supportedFeatures: ["studio.projects.v1"]
    )
)
