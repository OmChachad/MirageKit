import LoomHost

let sharedHost = LoomSharedHostConfiguration(
    appGroupIdentifier: "group.example.loom",
    app: LoomHostAppDescriptor(
        appID: "com.example.alpha",
        displayName: "Alpha",
        metadata: [
            "role": "capture",
        ],
        supportedFeatures: [
            "transfers",
            "shell",
        ]
    )
)
