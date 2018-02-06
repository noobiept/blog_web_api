import Foundation
import Redis
import LoggerAPI
import Cryptor


class Database {
    let client: TCPClient


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
            self.client = try TCPClient(hostname:redisHost, port: redisPort, password: redisPassword)
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
        try self.client.command(.set, ["LAST_POST_ID", "-1", "NX"])
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

        try self.client.makePipeline()
            .enqueue(
                .custom("MULTI".makeBytes())
            )
            .enqueue(
                .custom("HMSET".makeBytes()), [
                    "user_\(name)",
                    "password",
                    passwordHash,
                    "salt",
                    saltString
                ]
            )
            .enqueue(
                .custom("SADD".makeBytes()), [
                    "users",
                    name
                ]
            )
            .enqueue(
                .custom("EXEC".makeBytes())
            )
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

            // remove all the associated tokens
        try self.removeAllTokens(username: name)

            // remove the user information
        try self.client.makePipeline()
            .enqueue(
                .custom("MULTI".makeBytes())
            )
            .enqueue(
                .custom("HDEL".makeBytes()), [
                    "user_\(name)",
                    "password",
                    "salt"
                ]
            )
            .enqueue(
                .custom("SREM".makeBytes()), [
                    "users",
                    name
                ]
            )
            .enqueue(
                .custom("EXEC".makeBytes())
            )
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
        let response = try self.client.command(
            .custom("SMEMBERS".makeBytes()), [
                key
            ]
        )
        var all = [String]()

        guard let members = response?.array else {
            return all
        }

        for member in members {
            let value = member?.string

            if value != nil {
                all.append( value! )
            }
        }

        return all
    }


    /**
     * Generic function, get a redis hash from the database, and convert it into a dictionary.
     */
    func getHash(key: String) -> [String: String]? {
            // returns an array instead of a hash, where every field is followed by its value
        let response = try? self.client.command(.custom("HGETALL".makeBytes()), [ key ])

        guard let hashData = response else {
            return nil
        }

        guard let hashList = hashData!.array else {
            return nil
        }

        guard hashList.count > 0 else {
            return nil
        }

        var dict = [String: String]()
        var a = 0

        while (a < hashList.count) {
            let field = hashList[ a ]!.string!
            let value = hashList[ a + 1 ]!.string!

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
    func getUserName(token: String) throws -> String? {
        return try self.client.command(.get, ["token_\(token)"])?.string
    }


    /**
     * Generate the token to be used to authenticate a user.
     */
    func generateUserToken(username: String) throws -> String {
        let token = UUID().uuidString
        let oneDaySeconds = 86_400  // expire the token after 1 day
        let key = "token_\(token)"

        try self.client.makePipeline()
            .enqueue(
                .custom("MULTI".makeBytes())
            )
            .enqueue(
                .set, [
                    key,
                    username
                ]
            )
            .enqueue(
                .custom("EXPIRE".makeBytes()), [
                    key,
                    String( oneDaySeconds )
                ]
            )
            .enqueue(
                .custom("SADD".makeBytes()), [
                    "user_tokens_\(username)",
                    token
                ]
            )
            .enqueue(
                .custom("EXEC".makeBytes())
            )
            .execute()

        return token
    }


    /**
     * Each token has an expiration date. Remove the ones that have expired from the "user_tokens_*" set.
     */
    func cleanUserTokens(username: String) throws {
        let userTokensKey = "user_tokens_\(username)"
        let tokens = try self.client.command(
            .custom("SMEMBERS".makeBytes()), [
                userTokensKey
            ])!.array!

        for tokenObj in tokens {
            guard let token = tokenObj?.string else {
                continue
            }

            let checkToken = try self.client.command(.get, ["token_\(token)"])?.string

                // doesn't exist anymore, clear from the set as well
            if checkToken == nil {
                try self.client.command(
                    .custom("SREM".makeBytes()), [
                        userTokensKey,
                        token
                    ]
                )
            }
        }
    }


    /**
     * Remove all the tokens associated with the given user.
     */
    func removeAllTokens(username: String) throws {
        let userTokensKey = "user_tokens_\(username)"
        let tokens = try self.client.command(
            .custom("SMEMBERS".makeBytes()), [
                userTokensKey
            ])!.array!

        for tokenObj in tokens {
            guard let token = tokenObj?.string else {
                continue
            }

            try self.client.command(
                .custom("DEL".makeBytes()), [
                    "token_\(token)"
                ]
            )
            try self.client.command(
                .custom("SREM".makeBytes()), [
                    userTokensKey,
                    token
                ]
            )
        }
    }


    /**
     * Returns the Unix timestamp (number of seconds since 1/1/1970).
     */
    func getCurrentTime() throws -> String {
        let time = try self.client.command(
            .custom("TIME".makeBytes())
            )!.array!

        return time[ 0 ]!.string!
    }


    /**
     * Add a new blog post to the database.
     */
    func addBlogPost(username: String, title: String, body: String) throws -> Int? {
        let id = try self.client.command(
            .custom("INCR".makeBytes()), [
                "LAST_POST_ID"
            ])!.int!

        try self.client.makePipeline()
            .enqueue(
                .custom("MULTI".makeBytes())
            )
            .enqueue(
                .custom("HMSET".makeBytes()), [
                    "post_\(id)",
                    "title", title,
                    "body", body,
                    "author", username,
                    "last_updated", try getCurrentTime()
                ]
            )
            .enqueue(
                .custom("SADD".makeBytes()), [
                    "user_posts_\(username)",
                    "\(id)"
                ]
            )
            .enqueue(
                .custom("SADD".makeBytes()), [
                    "posts",
                    "\(id)"
                ]
            )
            .enqueue(
                .custom("EXEC".makeBytes())
            )
            .execute()

        return id
    }


    /**
     * Update the contents of an existing blog post.
     */
    func updateBlogPost(id: String, title: String, body: String) throws {
        try self.client.command(
            .custom("HMSET".makeBytes()), [
                "post_\(id)",
                "title", title,
                "body", body,
                "last_updated", try getCurrentTime()
            ]
        )
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
        try self.client.makePipeline()
            .enqueue(
                .custom("MULTI".makeBytes())
            )
            .enqueue(
                .custom("SREM".makeBytes()), [
                    "user_posts_\(username)",
                    id
                ]
            )
            .enqueue(
                .custom("SREM".makeBytes()), [
                    "posts",
                    id
                ]
            )
            .enqueue(
                .custom("DEL".makeBytes()), [
                    "post_\(id)"
                ]
            )
            .enqueue(
                .custom("EXEC".makeBytes())
            )
            .execute()

        return true
    }


    /**
     * Get a random post ID.
     */
    func getRandomPostId() throws -> String? {
        return try self.client.command(
            .custom("SRANDMEMBER".makeBytes()), [
                "posts"
            ]
        )?.string
    }


    /**
     * Return a list with all the blog posts ids.
     */
    func getAllPosts() throws -> [String] {
        return try getAllSetMembers(key: "posts")
    }


    /**
     * Get a random username.
     */
    func getRandomUser() throws -> String? {
        return try self.client.command(
            .custom("SRANDMEMBER".makeBytes()), [
                "users"
            ]
        )?.string
    }
}