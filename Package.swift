// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "blog_web_api",
    products: [
        .executable( name: "blog_web_api", targets: [ "blog_web_api" ] )
    ],
    dependencies: [
        .package( url: "https://github.com/IBM-Swift/Kitura.git",       .upToNextMajor( from: "2.2.0" ) ),
        .package( url: "https://github.com/IBM-Swift/HeliumLogger.git", .upToNextMajor( from: "1.7.0" ) ),
        .package( url: "https://github.com/IBM-Swift/BlueCryptor.git",  .upToNextMajor( from: "0.8.0" ) ),
        .package( url: "https://github.com/vapor/redis.git",            .upToNextMajor( from: "2.2.0" ) ),
    ],
    targets: [
        .target(
            name: "blog_web_api",
            dependencies: [
                "Kitura",
                "HeliumLogger",
                "Cryptor",
                "Redis",
            ],
            path: "./Sources"
        )
    ]
)
