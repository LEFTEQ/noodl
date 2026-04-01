import ProjectDescription

let project = Project(
    name: "Noodl",
    organizationName: "LEFTEQ",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "DEVELOPMENT_TEAM": "6K3D34L95L",
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGN_IDENTITY": "Apple Development",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "Noodl",
            destinations: .macOS,
            product: .app,
            bundleId: "com.lefteq.noodl",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Noodl",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "LSMinimumSystemVersion": "15.0",
                "LSUIElement": true,
            ]),
            sources: ["Noodl/Sources/**/*.swift"],
            resources: ["Noodl/Resources/**"],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "Noodl",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "Noodl",
            shared: true,
            buildAction: .buildAction(targets: ["Noodl"]),
            runAction: .runAction(configuration: "Debug", executable: "Noodl")
        ),
    ]
)
