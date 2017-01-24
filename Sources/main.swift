import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation
import Cryptor


HeliumLogger.use()
let DB = Database()


let router = Router()
router.all(middleware: BodyParser())


router.get("/") {
    request, response, next in
       
    var result = [String: Any]()
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}


router.post("/user/create") {
    request, response, next in

    guard let (username, password) = try getUserParameters(request: request, response: response) else {
        return
    }

    guard DB.getUser(name: username) == nil else {
        try badRequest( message: "Invalid 'username' (already exists).", response: response )
        return
    }

        // create the user
    guard let salt = try? Random.generate(byteCount: 64) else { 
        Log.error("Failed to create the 'salt'.")
        return 
    } 
    
    let saltString = CryptoUtils.hexString(from: salt)
    let passwordHash = getPasswordHash(string: password, salt: saltString)

        //save to database
    let added = DB.addUser(name: username, password: passwordHash, salt: saltString)

    var result = [String: Any]()
    result["success"] = true
    result["message"] = "User created."
    result["token"] = DB.generateUserToken(username: username)

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/user/login") {
    request, response, next in

    guard let (username, password) = try getUserParameters(request: request, response: response) else {
        return
    }

    guard let user = DB.getUser(name: username) else {
        try badRequest(message: "Invalid 'username' (doesn't exist).", response: response)
        return
    }

    let testPassword = getPasswordHash(string: password, salt: user["salt"]!)

    guard user["password"]! == testPassword else {
        try badRequest(message: "Invalid password.", response: response)
        return
    }

        // make a new token and send it back to the user
    var result = [String: Any]()
    result["success"] = true
    result["token"] = DB.generateUserToken(username: username)

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/blog/add") {
    request, response, next in

    guard let params = try getPostParameters(keys: ["token", "title", "body"], request: request, response: response) else {
        return
    }

    guard let username = DB.getUserName(token: params["token"]!) else {
        try badRequest(message: "Invalid 'token'.", response: response)
        return
    }
    
    let title = params["title"]!
    let body = params["body"]!
    
    guard title.characters.count >= 5 && title.characters.count <= 100 else {
        try badRequest(message: "'title' needs to be between 5 and 100 characters.", response: response)
        return
    }

    guard body.characters.count >= 10 && body.characters.count <= 10_000 else {
        try badRequest(message: "'body' needs to be between 10 and 10000 characters.", response: response)
        return
    }


    let postId = try DB.addBlogPost(username: username, title: title, body: body) 

    var result = [String: Any]()
    result["success"] = true
    result["post_id"] = postId

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.get("/blog/get/:blogId") {
    request, response, next in

    guard let blogId = request.parameters["blogId"] else {
        try badRequest(message: "Missing 'blogId' argument.", response: response)
        return
    }

    guard let post = DB.getBlogPost( id: blogId ) else {
        try badRequest(message: "Didn't find the blog post.", response: response)
        return
    }

    var result = [String: Any]()
    result["success"] = true
    result["post"] = post

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.get("/blog/:username/getall") {
    request, response, next in

    guard let username = request.parameters["username"] else {
        try badRequest(message: "Missing 'username' argument.", response: response)
        return
    }

    guard let postsList = try? DB.getUserPosts(username: username) else {
        try badRequest(message: "No posts found.", response: response)
        return
    }

    var result = [String: Any]()
    result["success"] = true
    result["posts_ids"] = postsList

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}



    // configure the server
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: serverPort, with: router)
Kitura.run()