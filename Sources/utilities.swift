import Kitura
import KituraNet
import Cryptor


/**
 * Hash a password.
 */
func getPasswordHash(string: String, salt: String) -> String {
    let key = PBKDF.deriveKey(fromPassword: string, salt: salt, prf: .sha512, rounds: 250_000, derivedKeyLength: 64)
    return CryptoUtils.hexString(from: key)
}


/**
 * Return an unsuccessful message.
 */
func unsuccessfulRequest(_ message: String, _ response: RouterResponse, _ code: HTTPStatusCode) throws {
    var result = [String: Any]()
    result["success"] = false
    result["message"] = message

    try response.status( code ).send( json: result ).end()
}


/**
 * Check if the required post parameters were sent.
 */
func getPostParameters(_ keys: [String], _ request: RouterRequest, _ response: RouterResponse) throws -> [String: String]? {
    guard let body = request.body else {
        try unsuccessfulRequest("No body in request.", response, .badRequest)
        return nil
    }

    guard case .urlEncoded(let values) = body else {
        try unsuccessfulRequest("Arguments not properly url encoded.", response, .badRequest)
        return nil
    }

    var params = [String: String]()

    for key in keys {
        guard let param = values[ key ] else {
            try unsuccessfulRequest("Missing '\(key)' argument.", response, .badRequest)
            return nil
        }

        params[ key ] = param
    }

    return params
}


/**
 * An 'username' needs to be between 3 and 20 characters.
 */
func validateUserName(_ username: String, _ response: RouterResponse) throws -> String? {
    if username.count < 3 || username.count > 20 {
        try unsuccessfulRequest("'username' needs to be between 3 an 20 characters.", response, .badRequest)
        return nil
    }

    return username
}


/**
 * A 'password' needs to be between 6 and 20 characters.
 */
func validatePassword(_ password: String, _ response: RouterResponse) throws -> String? {
    if password.count < 6 || password.count > 20 {
        try unsuccessfulRequest("'password' needs to be between 6 and 20 characters.", response, .badRequest)
        return nil
    }

    return password
}


/**
 * Check if the 'token' has a valid 'username' associated.
 */
func validateToken(_ params: [String: String], _ response: RouterResponse) throws -> String? {
    guard let username = try DB.getUserName(token: params["token"]!) else {
        try unsuccessfulRequest("Invalid authentication 'token'.", response, .notFound)
        return nil
    }

    return username
}


/**
 * Validate the 'title' and 'body' values.
 */
func validateTitleBody(_ params: [String: String], _ response: RouterResponse) throws -> (String, String)? {

    let title = params["title"]!
    let body = params["body"]!

    guard title.count >= 5 && title.count <= 100 else {
        try unsuccessfulRequest("'title' needs to be between 5 and 100 characters.", response, .badRequest)
        return nil
    }

    guard body.count >= 10 && body.count <= 10_000 else {
        try unsuccessfulRequest("'body' needs to be between 10 and 10000 characters.", response, .badRequest)
        return nil
    }

    return (title, body)
}


/**
 * See if a blog post with the given ID exists.
 */
func validateBlogPost(_ blogId: String, _ response: RouterResponse) throws -> [String: String]? {
    guard let post = DB.getBlogPost(id: blogId) else {
        try unsuccessfulRequest("Didn't find the blog post.", response, .notFound)
        return nil
    }

    return post
}


/**
 * Check if we received the necessary 'blogId' parameter.
 */
func validateBlogId(_ request: RouterRequest, _ response: RouterResponse) throws -> String? {
    guard let blogId = request.parameters["blogId"] else {
        try unsuccessfulRequest("Missing 'blogId' argument.", response, .badRequest)
        return nil
    }

    return blogId
}


/**
 * See if the username is the same as the post author.
 */
func validateAuthor(_ post: [String: String], _ username: String, _ response: RouterResponse) throws -> Bool {
    guard post["author"]! == username else {
        try unsuccessfulRequest("The blog posts state can only be changed by its author.", response, .forbidden)
        return false
    }

    return true
}


/**
 * Checks if the username/password pair is correct.
 */
func authenticateUser(_ username: String, _ password: String, _ response: RouterResponse) throws -> Bool {
    guard let user = DB.getUser(name: username) else {
        try unsuccessfulRequest("Invalid 'username' (doesn't exist).", response, .notFound)
        return false
    }

    let testPassword = getPasswordHash(string: password, salt: user["salt"]!)

    guard user["password"]! == testPassword else {
        try unsuccessfulRequest("Invalid password.", response, .badRequest)
        return false
    }

    return true
}