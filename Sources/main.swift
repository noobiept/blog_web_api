import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation
import Cryptor


HeliumLogger.use()
let DB = Database()


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


/**
 * Make sure we received an 'username' and a 'password'.
 */
func getUserParameters(request: RouterRequest, response: RouterResponse) throws -> (String, String)? {
    guard let body = request.body else { 
        try badRequest( message: "No body in request.", response: response )
        return nil
    }
    
    guard case .urlEncoded(let values) = body else { 
        try badRequest( message: "Arguments not properly url encoded.", response: response )
        return nil
    }

        // check if 'username' and 'password' exist
    guard let username = values["username"] else { 
        try badRequest( message: "Missing 'username' argument.", response: response )
        return nil
    }

    guard let password = values["password"] else { 
        try badRequest( message: "Missing 'password' argument.", response: response )
        return nil
    }

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
    defer { next() }

    guard let (username, password) = try getUserParameters(request: request, response: response) else {
        return
    }

    guard DB.getUser(name: username) == nil else {
        try badRequest( message: "Invalid 'username' (already exists).", response: response )
        return
    }

        // create the user
    guard let salt = try? Random.generate(byteCount: 64) else { 
        Log.error("Fail to create the 'salt'.")
        return 
    } 
    
    let saltString = CryptoUtils.hexString(from: salt)
    let passwordHash = getPasswordHash(string: password, salt: saltString)

        //save to database
    let added = DB.addUser(name: username, password: passwordHash, salt: saltString)

    var result = [String: Any]()
    result["success"] = true
    result["message"] = "User created."
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}


router.post("/user/login") {
    request, response, next in
    defer { next() }

    guard let (username, password) = try getUserParameters(request: request, response: response) else {
        return
    }

    guard let user = DB.getUser(name: username) else {
        try badRequest(message: "Invalid 'username' (doesn't exist).", response: response)
        return
    }

    let testPassword = getPasswordHash(string: password, salt: user["salt"]!)

    if user["password"]! == testPassword {
        
            // make a new token for the user
        let token = UUID().uuidString

        DB.saveUserToken(username: username, token: token)

            // send the token back to the user
        var result = [String: Any]()
        result["success"] = true
        result["token"] = token

        let json = JSON( result )
        try response.status(.OK).send(json: json).end()
    }
}


    // configure the server
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: serverPort, with: router)
Kitura.run()