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
            try self.setupInitValues()
        }
        
        catch {
            Log.error("Redis error: \(error)")
            exit(1)
        }
    }


    func setupInitValues() throws {
        try self.client.command("SETNX", params: ["LAST_POST_ID", "-1"])
    }


    func addUser(name: String, password: String, salt: String) -> Bool {
        let added = try? self.client.command("HMSET", params: [
                "user_\(name)", 
                "password", password, 
                "salt", salt
            ]).toString()

        if added == "OK" {
            return true
        }

        return false
    }


    func getHash(key: String) -> [String: String]? {
            // returns an array instead of a hash, where every field is followed by its value
        let hash = try? self.client.command("HGETALL", params: [ key ]).toArray()

        guard let hashList = hash else {
            return nil
        }

        guard hashList.count > 0 else {
            return nil
        }

        var dict = [String: String]()
        var a = 0

        while (a < hashList.count) {
            let field = try! hashList[ a ].toString()
            let value = try! hashList[ a + 1 ].toString()

            dict[ field ] = value
            a += 2
        }
    
        return dict
    }


    func getUser(name: String) -> [String: String]? {
        return self.getHash(key: "user_\(name)")
    }


    func getUserName(token: String) -> String? {
        return try? self.client.command("GET", params: ["token_\(token)"]).toString()
    }


    /**
     * Generate the token to be used to authenticate a user.
     */
    func generateUserToken(username: String) -> String {
        let token = UUID().uuidString
        let oneDaySeconds = 86_400  // expire the token after 1 day
        let key = "token_\(token)"

        _ = try? self.client.command("SET", params: [key, username])
        _ = try? self.client.command("EXPIRE", params: [key, String( oneDaySeconds )])

        return token
    }


    /**
     * Returns the Unix timestamp (number of seconds since 1/1/1970).
     */
    func getCurrentTime() throws -> String {
        let time = try self.client.command("TIME").toArray()

        return try time[ 0 ].toString()
    }


    func addBlogPost(username: String, title: String, body: String) throws -> Int? {
        let id = try self.client.command("INCR", params: ["LAST_POST_ID"]).toInt()

        _ = try self.client.command("HMSET", params: [
                "post_\(id)",
                "title", title,
                "body", body,
                "author", username,
                "time", try getCurrentTime()
            ])
    
        return id
    }


    func getBlogPost(id: String) -> [String: String]? {
        return self.getHash(key: "post_\(id)")
    }
}