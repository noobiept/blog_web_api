import Foundation
import Redbird
import LoggerAPI


class Database {
    let client: Redbird

    init() {
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

        do {
            let config = RedbirdConfig(address: redisHost, port: redisPort, password: redisPassword)
            self.client = try Redbird(config: config)    
        }
        
        catch {
            Log.error("Redis error: \(error)")
            exit(1)
        }
    }


    func addUser(name: String, password: String, salt: String) -> Bool {
        let added = try? self.client.command("HMSET", params: ["user_\(name)", "password", password, "salt", salt]).toString()

        if added == "OK" {
            return true
        }

        return false
    }


    func getUser(name: String) -> [String: String]? {
            // returns an array instead of a hash, where every field is followed by its value
        let userInfo = try? self.client.command("HGETALL", params: ["user_\(name)"]).toArray()

        guard let info = userInfo else {
            return nil
        }

        guard info.count > 0 else {
            return nil
        }

        var user = [String: String]()
        var a = 0

        while (a < info.count) {
            let field = try! info[ a ].toString()
            let value = try! info[ a + 1 ].toString()

            user[ field ] = value
            a += 2
        }
    
        return user
    }


    func saveUserToken(username: String, token: String) {
        let oneDaySeconds = 86_400  // expire the token after 1 day
        let key = "token_\(token)"

        _ = try? self.client.command("SET", params: [key, username])
        _ = try? self.client.command("EXPIRE", params: [key, String( oneDaySeconds )])
    }
}