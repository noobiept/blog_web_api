import Foundation
import Redbird
import LoggerAPI
import Cryptor


class Database {
    let client: Redbird


    /**
     * Connect to the redis server.
     */
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


    /**
     * Set up some initial values that are used by the program.
     */
    func setupInitValues() throws {
        try self.client.command("SETNX", params: ["LAST_POST_ID", "-1"])
    }


    /**
     * Add a new user to the database.
     */
    func addUser(name: String, password: String) throws -> Bool {
        guard let salt = try? Random.generate(byteCount: 64) else {
            Log.error("Failed to create the 'salt'.")
            return false
        }

        let saltString = CryptoUtils.hexString(from: salt)
        let passwordHash = getPasswordHash(string: password, salt: saltString)

        try self.client.pipeline()
            .enqueue("MULTI")
            .enqueue("HMSET", params: [
                "user_\(name)",
                "password", passwordHash,
                "salt", saltString
            ])
            .enqueue("SADD", params: ["users", name])
            .enqueue("EXEC")
            .execute()

        return true
    }


    /**
     * Remove an existing user and his posts from the database.
     */
    func removeUser(name: String) throws -> Bool {
            // remove the user's posts
        let posts = try self.getUserPosts(username: name)

        for postId in posts {
            _ = try self.removePost(username: name, id: postId)
        }

            // remove the user information
        try self.client.pipeline()
            .enqueue("MULTI")
            .enqueue("HDEL", params: ["user_\(name)", "password", "salt"])
            .enqueue("SREM", params: ["users", name])
            .enqueue("EXEC")
            .execute()

        return true
    }


    /**
     * Get a list with all the usernames.
     */
    func getAllUsers() throws -> [String] {
        return try self.getAllSetMembers(key: "users")
    }


    /**
     * Generic function, returns all the members of a given redis set in an array.
     */
    func getAllSetMembers(key: String) throws -> [String] {
        let members = try self.client.command("SMEMBERS", params: [ key ]).toArray()

        var all = [String]()

        for member in members {
            all.append( try member.toString() )
        }

        return all
    }


    /**
     * Generic function, get a redis hash from the database, and convert it into a dictionary.
     */
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


    /**
     * Get the information of the given user.
     */
    func getUser(name: String) -> [String: String]? {
        return self.getHash(key: "user_\(name)")
    }


    /**
     * Get the username associated with the given token.
     */
    func getUserName(token: String) throws -> String {
        return try self.client.command("GET", params: ["token_\(token)"]).toString()
    }


    /**
     * Generate the token to be used to authenticate a user.
     */
    func generateUserToken(username: String) throws -> String {
        let token = UUID().uuidString
        let oneDaySeconds = 86_400  // expire the token after 1 day
        let key = "token_\(token)"

        try self.client.pipeline()
            .enqueue("MULTI")
            .enqueue("SET", params: [key, username])
            .enqueue("EXPIRE", params: [key, String( oneDaySeconds )])
            .enqueue("EXEC")
            .execute()

        return token
    }


    /**
     * Returns the Unix timestamp (number of seconds since 1/1/1970).
     */
    func getCurrentTime() throws -> String {
        let time = try self.client.command("TIME").toArray()

        return try time[ 0 ].toString()
    }


    /**
     * Add a new blog post to the database.
     */
    func addBlogPost(username: String, title: String, body: String) throws -> Int? {
        let id = try self.client.command("INCR", params: ["LAST_POST_ID"]).toInt()

        try self.client.pipeline()
            .enqueue("MULTI")
            .enqueue("HMSET", params: [
                "post_\(id)",
                "title", title,
                "body", body,
                "author", username,
                "last_updated", try getCurrentTime()
            ])
            .enqueue("SADD", params: ["user_posts_\(username)", "\(id)"])
            .enqueue("SADD", params: ["posts", "\(id)"])
            .enqueue("EXEC")
            .execute()

        return id
    }


    /**
     * Update the contents of an existing blog post.
     */
    func updateBlogPost(id: String, title: String, body: String) throws {
        try self.client.command("HMSET", params: [
            "post_\(id)",
            "title", title,
            "body", body,
            "last_updated", try getCurrentTime()
        ])
    }


    /**
     * Get the information of the given post.
     */
    func getBlogPost(id: String) -> [String: String]? {
        return self.getHash(key: "post_\(id)")
    }


    /**
     * Get a list of ids of all the posts made by the user.
     */
    func getUserPosts(username: String) throws -> [String] {
        return try self.getAllSetMembers(key: "user_posts_\(username)")
    }


    /**
     * Remove a blog post from the database.
     */
    func removePost(username: String, id: String) throws -> Bool {
        try self.client.pipeline()
            .enqueue("MULTI")
            .enqueue("SREM", params: ["user_posts_\(username)", id])
            .enqueue("SREM", params: ["posts", id])
            .enqueue("DEL", params: ["post_\(id)"])
            .enqueue("EXEC")
            .execute()

        return true
    }


    /**
     * Get a random post ID.
     */
    func getRandomPostId() throws -> String {
        return try self.client.command("SRANDMEMBER", params: ["posts"]).toString()
    }


    /**
     * Get a random username.
     */
    func getRandomUser() throws -> String {
        return try self.client.command("SRANDMEMBER", params: ["users"]).toString()
    }
}