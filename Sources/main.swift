import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation
import Redbird


HeliumLogger.use()


func configRedis() -> Redbird {
    let redisUrl = ProcessInfo.processInfo.environment["REDIS_URL"]

    var redisHost = "localhost"
    var redisPort: UInt16 = 6379
    var redisPassword: String?

    if let urlString = redisUrl {
        let url = URL(string: urlString)

        if let url = url {
            redisHost = url.host!
            redisPort = UInt16( url.port! )
            redisPassword = url.password!
        }

        else {
            Log.error("Invalid redis URL.")
            exit(1)
        }
    }

    var redisClient: Redbird

    do {
        let config = RedbirdConfig(address: redisHost, port: redisPort, password: redisPassword)
        redisClient = try Redbird(config: config)    
    }
    
    catch {
        print("Redis error: \(error)")
        exit(1)
    }

    return redisClient
}


let REDIS = configRedis()


func initValues() {
    _ = try? REDIS.command("SET", params: ["test", "value22"]).toString() 
}

initValues()


let router = Router()

router.get("/") {
    request, response, next in

    let testValue = try REDIS.command("GET", params: ["test"]).toString()
        
    var result = [String: Any]()
    result["test"] = testValue
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}


    // configure the server
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: serverPort, with: router)
Kitura.run()