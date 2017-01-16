import Kitura
import HeliumLogger
import SwiftyJSON
import Foundation
import SwiftRedis


HeliumLogger.use()


let redis = Redis()
redis.connect(host: "localhost", port: 6379) {
    redisError in

    if let error = redisError {
        print(error)
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

let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()