import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation


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

    guard let params   = try getPostParameters(["username", "password"], request, response) else { return }
    guard let username = try validateUserName(params["username"]!, response)                else { return }
    guard let password = try validatePassword(params["password"]!, response)                else { return }

    guard DB.getUser(name: username) == nil else {
        try unsuccessfulRequest("Invalid 'username' (already exists).", response, .forbidden)
        return
    }

        // create the user
    guard let added = try? DB.addUser(name: username, password: password) else {
        try unsuccessfulRequest("Failed to create the user.", response, .internalServerError)
        return
    }
    
    var result = [String: Any]()
    result["success"] = true
    result["message"] = "User created."
    result["token"] = DB.generateUserToken(username: username)

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/user/login") {
    request, response, next in

    guard let params   = try getPostParameters(["username", "password"], request, response) else { return }
    guard let username = try validateUserName(params["username"]!, response)                else { return }
    guard let password = try validatePassword(params["password"]!, response)                else { return }
    guard                try authenticateUser(username, password, response)                 else { return }

        // make a new token and send it back to the user
    var result = [String: Any]()
    result["success"] = true
    result["token"] = DB.generateUserToken(username: username)

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/user/change_password") {
    request, response, next in

    guard let params      = try getPostParameters(["username", "password", "newPassword"], request, response) else { return }
    guard let username    = try validateUserName(params["username"]!, response)    else { return }
    guard let password    = try validatePassword(params["password"]!, response)    else { return }
    guard let newPassword = try validatePassword(params["newPassword"]!, response) else { return }
    guard                   try authenticateUser(username, password, response) else     { return }

    guard try DB.addUser(name: username, password: newPassword) else {
        try unsuccessfulRequest("Failed to change the password.", response, .internalServerError)
        return
    }

    var result = [String: Any]()
    result["success"] = true

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.get("/user/getall") {
    request, response, next in

    guard let users = try? DB.getAllUsers() else {
        try unsuccessfulRequest("Failed to get all the users.", response, .notFound)
        return
    }

    var result = [String: Any]()
    result["success"] = true
    result["users"] = users

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/blog/add") {
    request, response, next in

    guard let params        = try getPostParameters(["token", "title", "body"], request, response) else { return }
    guard let username      = try validateToken(params, response)                                  else { return }
    guard let (title, body) = try validateTitleBody(params, response)                              else { return }

    let postId = try DB.addBlogPost(username: username, title: title, body: body) 

    var result = [String: Any]()
    result["success"] = true
    result["post_id"] = postId

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.get("/blog/get/:blogId") {
    request, response, next in

    guard let blogId = try validateBlogId(request, response)  else { return }
    guard let post   = try validateBlogPost(blogId, response) else { return }

    var result = [String: Any]()
    result["success"] = true
    result["post"] = post

    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/blog/remove") {
    request, response, next in

    guard let params   = try getPostParameters(["token", "blogId"], request, response) else { return }
    guard let username = try validateToken(params, response)                           else { return }
    
    let blogId = params["blogId"]!
    guard let post = try validateBlogPost(params["blogId"]!, response) else { return }
    guard try validateAuthor(post, username, response)                 else { return }


    guard let _ = try? DB.removePost(username: username, id: blogId) else {
        try unsuccessfulRequest("Failed to remove the post.", response, .internalServerError)
        return
    }

    var result = [String: Any]()
    result["success"] = true
    
    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.post("/blog/update") {
    request, response, next in

    guard let params        = try getPostParameters(["token", "title", "body", "blogId"], request, response) else { return }
    guard let username      = try validateToken(params, response)               else { return }
    guard let (title, body) = try validateTitleBody(params, response)           else { return }
    guard let post          = try validateBlogPost(params["blogId"]!, response) else { return }
    guard                     try validateAuthor(post, username, response)      else { return }

    guard let _ = try? DB.updateBlogPost(id: params["blogId"]!, title: title, body: body) else {
        try unsuccessfulRequest("Failed to update the post.", response, .internalServerError)
        return
    }

    var result = [String: Any]()
    result["success"] = true
    
    let json = JSON( result )
    try response.status(.OK).send(json: json).end()
}


router.get("/blog/:username/getall") {
    request, response, next in

    guard let username = request.parameters["username"] else {
        try unsuccessfulRequest("Missing 'username' argument.", response, .badRequest)
        return
    }

    guard let postsList = try? DB.getUserPosts(username: username) else {
        try unsuccessfulRequest("No posts found.", response, .notFound)
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