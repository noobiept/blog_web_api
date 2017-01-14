import PackageDescription

let package = Package(
    name: "blog_web_api",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/postgresql.git", majorVersion: 1),
    ]
)
