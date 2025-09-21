// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "swift-sharing",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Sharing",
      targets: ["Sharing"]
    )
  ],
  traits: [
    .trait(
      name: "SharingCombineSchedulers",
      description: "Include combine-schedulers support.",
      enabledTraits: []
    ),
    .trait(
      name: "SharingCustomDump",
      description: "Include swift-custom-dump support.",
      enabledTraits: []
    ),
    .trait(
      name: "SharingDependencies",
      description: "Include swift-dependencies support.",
      enabledTraits: []
    ),
    .trait(
      name: "SharingIdentifiedCollections",
      description: "Include swift-identified-collections support.",
      enabledTraits: []
    ),
    .trait(
      name: "SharingIssueReporting",
      description: "Include swift-issue-reporting (nee xctest-dynamic-overlay) support.",
      enabledTraits: []
    ),
    .trait(
      name: "SharingPerception",
      description: "Include swift-perception support.",
      enabledTraits: ["SharingIssueReporting"]
    ),
    .default(enabledTraits: ["SharingDependencies","SharingPerception"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.3.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.5.1"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-perception", "1.4.1"..<"3.0.0"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "Sharing",
      dependencies: [
        "Sharing1",
        "Sharing2",
        .product(name: "CombineSchedulers", package: "combine-schedulers", condition: .when(traits: ["SharingCombineSchedulers"])),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "CustomDump", package: "swift-custom-dump", condition: .when(traits: ["SharingCustomDump"])),
        .product(name: "Dependencies", package: "swift-dependencies", condition: .when(traits: ["SharingDependencies"])),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections", condition: .when(traits: ["SharingIdentifiedCollections"])),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay", condition: .when(traits: ["SharingIssueReporting"])),
        .product(name: "PerceptionCore", package: "swift-perception", condition: .when(traits: ["SharingPerception"])),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    ),
    .testTarget(
      name: "SharingTests",
      dependencies: [
        "Sharing",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies", condition: .when(traits: ["SharingDependencies"])),
      ],
      exclude: ["Sharing.xctestplan"]
    ),
    .target(
      name: "Sharing1",
      path: "Sources/VersionMarkerModules/Sharing1"
    ),
    .target(
      name: "Sharing2",
      path: "Sources/VersionMarkerModules/Sharing2"
    ),
  ],
  swiftLanguageModes: [.v6]
)
