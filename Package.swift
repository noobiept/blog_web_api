import PackageDescription

let package = Package(
    name: "blog_web_api",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 4),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 4),
        .Package(url: "https://github.com/czechboy0/Redbird.git", majorVersion: 1, minor: 0),
        .Package(url: "https://github.com/IBM-Swift/BlueCryptor.git", majorVersion: 0, minor: 8),
    ]
)
