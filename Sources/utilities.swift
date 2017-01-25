import Kitura
import Cryptor
import SwiftyJSON


func getPasswordHash(string: String, salt: String) -> String {
    let key = PBKDF.deriveKey(fromPassword: string, salt: salt, prf: .sha512, rounds: 250_000, derivedKeyLength: 64)
    return CryptoUtils.hexString(from: key)
}


func badRequest(message: String, response: RouterResponse) throws {
    var result = [String: Any]()
    result["success"] = false
    result["message"] = message

    let json = JSON( result )
    try response.status( .badRequest ).send( json: json ).end()
}


func getPostParameters(_ keys: [String], _ request: RouterRequest, _ response: RouterResponse) throws -> [String: String]? {
    guard let body = request.body else { 
        try badRequest( message: "No body in request.", response: response )
        return nil
    }
    
    guard case .urlEncoded(let values) = body else { 
        try badRequest( message: "Arguments not properly url encoded.", response: response )
        return nil
    }

    var params = [String: String]()

    for key in keys {
        guard let param = values[ key ] else {
            try badRequest(message: "Missing '\(key)' argument.", response: response)
            return nil
        }

        params[ key ] = param
    }

    return params
}


/**
 * Make sure we received an 'username' and a 'password'.
 */
func validateUserParameters(_ request: RouterRequest, _ response: RouterResponse) throws -> (String, String)? {
    guard let params = try getPostParameters(["username", "password"], request, response) else {
        return nil
    }

    let username = params["username"]!
    let password = params["password"]!

    if username.characters.count < 3 || username.characters.count > 20 {
        try badRequest( message: "'username' needs to be between 3 an 20 characters.", response: response )
        return nil
    }

    if password.characters.count < 6 || password.characters.count > 20 {
        try badRequest( message: "'password' needs to be between 6 and 20 characters.", response: response )
        return nil
    }

    return (username, password)
}


func validateUserName(_ params: [String: String], _ response: RouterResponse) throws -> String? {
    guard let username = try? DB.getUserName(token: params["token"]!) else {
        try badRequest(message: "Invalid authentication 'token'.", response: response)
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
    
    guard title.characters.count >= 5 && title.characters.count <= 100 else {
        try badRequest(message: "'title' needs to be between 5 and 100 characters.", response: response)
        return nil
    }

    guard body.characters.count >= 10 && body.characters.count <= 10_000 else {
        try badRequest(message: "'body' needs to be between 10 and 10000 characters.", response: response)
        return nil
    }

    return (title, body)
}


func validateBlogPost(_ blogId: String, _ response: RouterResponse) throws -> [String: String]? {
    guard let post = DB.getBlogPost(id: blogId) else {
        try badRequest(message: "Didn't find the blog post.", response: response)
        return nil
    }

    return post
}


func validateBlogId(_ request: RouterRequest, _ response: RouterResponse) throws -> String? {
    guard let blogId = request.parameters["blogId"] else {
        try badRequest(message: "Missing 'blogId' argument.", response: response)
        return nil
    }

    return blogId
}


/**
 * See if the username is the same as the post author.
 */
func validateAuthor(_ post: [String: String], _ username, _ response: RouterResponse) throws -> Bool {
    guard post["author"]! == username else {
        try badRequest(message: "The blog posts state can only be changed by its author.", response: response)
        return false
    }

    return true
}