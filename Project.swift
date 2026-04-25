import ProjectDescription

// MARK: - Constants

let appIdentifierPrefix = "$(AppIdentifierPrefix)"
let organizationName = "Cronx"
let bundleIdBase = "co.cronx.spark"
let appGroup = "group.co.cronx.spark"
let keychainGroup = "\(appIdentifierPrefix)\(bundleIdBase)"
let associatedDomain = "applinks:spark.cronx.co"
let iosDeploymentTarget: DeploymentTargets = .iOS("26.0")
let watchDeploymentTarget: DeploymentTargets = .watchOS("26.0")

// MARK: - Entitlements builders

func appEntitlements() -> Entitlements {
    .dictionary([
        "aps-environment": "development",
        "com.apple.developer.associated-domains": .array([.string(associatedDomain)]),
        "com.apple.developer.healthkit": .boolean(true),
        "com.apple.developer.healthkit.access": .array([]),
        "com.apple.security.application-groups": .array([.string(appGroup)]),
        "keychain-access-groups": .array([.string(keychainGroup)]),
    ])
}

func extensionEntitlements() -> Entitlements {
    .dictionary([
        "com.apple.security.application-groups": .array([.string(appGroup)]),
        "keychain-access-groups": .array([.string(keychainGroup)]),
    ])
}

// MARK: - Info.plist builders

func appInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
        "UILaunchScreen": [:],
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
        ],
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false,
        ],
        "UIBackgroundModes": [
            "remote-notification",
            "fetch",
            "processing",
        ],
        "NSHealthShareUsageDescription":
            "Spark reads your health data to show your daily summary and ring progress.",
        "NSHealthUpdateUsageDescription":
            "Spark writes workouts and mindful sessions you log in the app.",
        "NSLocationWhenInUseUsageDescription":
            "Spark uses your location to tag check-ins and detect place visits.",
        "NSUserActivityTypes": [
            "co.cronx.spark.openToday",
            "co.cronx.spark.openEvent",
        ],
        "CFBundleURLTypes": [
            [
                "CFBundleURLName": "co.cronx.spark.oauth",
                "CFBundleURLSchemes": ["spark"],
            ],
        ],
    ])
}

func widgetInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Widgets",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
        ],
    ])
}

func controlsInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Controls",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
        ],
    ])
}

func liveActivitiesInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Live Activities",
        "NSSupportsLiveActivities": true,
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
        ],
    ])
}

func shareInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Share to Spark",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.share-services",
            "NSExtensionAttributes": [
                "NSExtensionActivationRule": [
                    "NSExtensionActivationSupportsWebURLWithMaxCount": 1,
                    "NSExtensionActivationSupportsImageWithMaxCount": 4,
                    "NSExtensionActivationSupportsText": true,
                ],
            ],
            "NSExtensionPrincipalClass":
                "$(PRODUCT_MODULE_NAME).ShareViewController",
        ],
        "NSCameraUsageDescription":
            "Spark can attach photos you share to bookmarks and check-ins.",
    ])
}

func intentsInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Intents",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.appintents-extension",
        ],
    ])
}

func notificationServiceInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Notification Service",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.usernotifications.service",
            "NSExtensionPrincipalClass":
                "$(PRODUCT_MODULE_NAME).NotificationService",
        ],
    ])
}

func watchInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark",
        "WKApplication": true,
        "WKWatchOnly": false,
    ])
}

func watchWidgetsInfoPlist() -> InfoPlist {
    .extendingDefault(with: [
        "CFBundleDisplayName": "Spark Watch Widgets",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
        ],
    ])
}

// MARK: - Shared settings

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.2",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
    "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "$(DEVELOPMENT_TEAM)",
]

func sharedSettings(bundleId: String) -> Settings {
    .settings(
        base: baseSettings.merging([
            "PRODUCT_BUNDLE_IDENTIFIER": .string(bundleId),
        ]),
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    )
}

// MARK: - Targets

let sparkApp: Target = .target(
    name: "SparkApp",
    destinations: [.iPhone, .iPad],
    product: .app,
    productName: "Spark",
    bundleId: bundleIdBase,
    deploymentTargets: iosDeploymentTarget,
    infoPlist: appInfoPlist(),
    sources: ["SparkApp/Sources/**"],
    resources: ["SparkApp/Resources/**"],
    entitlements: .file(path: "SparkApp/SparkApp.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
        .package(product: "SparkUI"),
        .package(product: "Sentry"),
        .target(name: "SparkWidgets"),
        .target(name: "SparkControls"),
        .target(name: "SparkLiveActivities"),
        .target(name: "SparkShare"),
        .target(name: "SparkIntents"),
        .target(name: "SparkNotificationService"),
    ],
    settings: sharedSettings(bundleId: bundleIdBase)
)

let sparkWidgets: Target = .target(
    name: "SparkWidgets",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).Widgets",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: widgetInfoPlist(),
    sources: ["Extensions/SparkWidgets/Sources/**"],
    resources: ["Extensions/SparkWidgets/Resources/**"],
    entitlements: .file(path: "Extensions/SparkWidgets/SparkWidgets.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
        .package(product: "SparkUI"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).Widgets")
)

let sparkControls: Target = .target(
    name: "SparkControls",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).Controls",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: controlsInfoPlist(),
    sources: ["Extensions/SparkControls/Sources/**"],
    entitlements: .file(path: "Extensions/SparkControls/SparkControls.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).Controls")
)

let sparkLiveActivities: Target = .target(
    name: "SparkLiveActivities",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).LiveActivities",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: liveActivitiesInfoPlist(),
    sources: ["Extensions/SparkLiveActivities/Sources/**"],
    entitlements: .file(path: "Extensions/SparkLiveActivities/SparkLiveActivities.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).LiveActivities")
)

let sparkShare: Target = .target(
    name: "SparkShare",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).Share",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: shareInfoPlist(),
    sources: ["Extensions/SparkShare/Sources/**"],
    resources: ["Extensions/SparkShare/Resources/**"],
    entitlements: .file(path: "Extensions/SparkShare/SparkShare.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).Share")
)

let sparkIntents: Target = .target(
    name: "SparkIntents",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).Intents",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: intentsInfoPlist(),
    sources: ["Extensions/SparkIntents/Sources/**"],
    entitlements: .file(path: "Extensions/SparkIntents/SparkIntents.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).Intents")
)

let sparkNotificationService: Target = .target(
    name: "SparkNotificationService",
    destinations: [.iPhone, .iPad],
    product: .appExtension,
    bundleId: "\(bundleIdBase).NotificationService",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: notificationServiceInfoPlist(),
    sources: ["Extensions/SparkNotificationService/Sources/**"],
    entitlements: .file(path: "Extensions/SparkNotificationService/SparkNotificationService.entitlements"),
    dependencies: [
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).NotificationService")
)

// Watch placeholders — minimal stubs for Phase 5.
let sparkWatch: Target = .target(
    name: "SparkWatch",
    destinations: [.appleWatch],
    product: .app,
    productName: "SparkWatch",
    bundleId: "\(bundleIdBase).watchkitapp",
    deploymentTargets: watchDeploymentTarget,
    infoPlist: watchInfoPlist(),
    sources: ["Watch/SparkWatch/Sources/**"],
    resources: ["Watch/SparkWatch/Resources/**"],
    entitlements: .file(path: "Watch/SparkWatch/SparkWatch.entitlements"),
    settings: sharedSettings(bundleId: "\(bundleIdBase).watchkitapp")
)

let sparkWatchWidgets: Target = .target(
    name: "SparkWatchWidgets",
    destinations: [.appleWatch],
    product: .appExtension,
    bundleId: "\(bundleIdBase).watchkitapp.widgets",
    deploymentTargets: watchDeploymentTarget,
    infoPlist: watchWidgetsInfoPlist(),
    sources: ["Watch/SparkWatchWidgets/Sources/**"],
    entitlements: .file(path: "Watch/SparkWatchWidgets/SparkWatchWidgets.entitlements"),
    settings: sharedSettings(bundleId: "\(bundleIdBase).watchkitapp.widgets")
)

// MARK: - Test targets

let sparkAppTests: Target = .target(
    name: "SparkAppTests",
    destinations: [.iPhone, .iPad],
    product: .unitTests,
    bundleId: "\(bundleIdBase).tests",
    deploymentTargets: iosDeploymentTarget,
    infoPlist: .default,
    sources: ["Tests/SparkAppTests/**"],
    dependencies: [
        .target(name: "SparkApp"),
        .package(product: "SparkKit"),
    ],
    settings: sharedSettings(bundleId: "\(bundleIdBase).tests")
)

// MARK: - Schemes

let sparkAppScheme: Scheme = .scheme(
    name: "SparkApp",
    shared: true,
    buildAction: .buildAction(targets: ["SparkApp"]),
    testAction: .targets(
        ["SparkAppTests"],
        configuration: .debug,
        options: .options(coverage: true, codeCoverageTargets: ["SparkApp"])
    ),
    runAction: .runAction(configuration: .debug, executable: "SparkApp"),
    archiveAction: .archiveAction(configuration: .release),
    profileAction: .profileAction(configuration: .release, executable: "SparkApp"),
    analyzeAction: .analyzeAction(configuration: .debug)
)

// MARK: - Project

let project = Project(
    name: "Spark",
    organizationName: organizationName,
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    packages: [
        .local(path: "Packages/SparkKit"),
        .local(path: "Packages/SparkUI"),
        .local(path: "Packages/SparkSync"),
        .local(path: "Packages/SparkIntelligence"),
        .local(path: "Packages/SparkHealth"),
        .local(path: "Packages/SparkLocation"),
        .remote(
            url: "https://github.com/getsentry/sentry-cocoa",
            requirement: .upToNextMajor(from: "9.5.1")
        ),
    ],
    settings: .settings(
        base: baseSettings,
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        sparkApp,
        sparkWidgets,
        sparkControls,
        sparkLiveActivities,
        sparkShare,
        sparkIntents,
        sparkNotificationService,
        sparkWatch,
        sparkWatchWidgets,
        sparkAppTests,
    ],
    schemes: [sparkAppScheme]
)
