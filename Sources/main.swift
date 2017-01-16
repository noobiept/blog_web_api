import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation
import SwiftRedis


HeliumLogger.use()

    // environment variables
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000
let redisUrl = ProcessInfo.processInfo.environment["REDIS_URL"]

var redisHost = "localhost"
var redisPort: Int32 = 6379

if let urlString = redisUrl {
    let url = URL(string: urlString)

    if let url = url {
        redisHost = "\(url.scheme!)://\(url.user!):\(url.password!)@\(url.host!)"
        redisPort = Int32(url.port!)
    }

    else {
        Log.error("Invalid redis URL.")
        exit(1)
    }
}


let redis = Redis()
redis.connect(host: redisHost, port: redisPort) {
    redisError in

    if let error = redisError {
        print(error)
        exit(1)
    }

    else {
        redis.set("test", value: "value22") {
            (result: Bool, redisError: NSError?) in

            if let error = redisError {
                print(error)
            }
        }
    }
}


let router = Router()

router.get("/") {
    request, response, next in

    redis.get("test") {
        (string: RedisString?, redisError: NSError?) in

        if let error = redisError {
            print(error)
        
        }
        
        else if let string = string?.asString {
            do {
                var result = [String: Any]()
                result["test"] = string
                let json = JSON( result )
            
                try response.status(.OK).send(json: json).end()
            }
            catch {
                next()
            }
        }  
    }
}


Kitura.addHTTPServer(onPort: serverPort, with: router)
Kitura.run()