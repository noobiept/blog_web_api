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


    func userExists( name: String ) -> Bool {
        let isMember = try? self.client.command("SISMEMBER", params: ["users", name]).toInt()

        if isMember == 1 {
            return true
        }

        return false
    }


    func addUser(name: String, password: String, salt: String) -> Bool {
        let added1 = try? self.client.command("SADD", params: ["users", name]).toInt()
        let added2 = try? self.client.command("HMSET", params: ["user_\(name)", "password", password, "salt", salt]).toString()

        if added1 == 1 && added2 == "OK" {
            return true
        }

        return false
    }
}