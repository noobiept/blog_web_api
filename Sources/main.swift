import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import Foundation
import Redbird
import Cryptor


HeliumLogger.use()


func configRedis() -> Redbird {
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

    var redisClient: Redbird

    do {
        let config = RedbirdConfig(address: redisHost, port: redisPort, password: redisPassword)
        redisClient = try Redbird(config: config)    
    }
    
    catch {
        print("Redis error: \(error)")
        exit(1)
    }

    return redisClient
}


let REDIS = configRedis()


func initValues() {
    _ = try? REDIS.command("SET", params: ["test", "value22"]).toString() 
}

initValues()


func userExists( name: String ) -> Bool {
    let isMember = try? REDIS.command("SISMEMBER", params: ["users", name]).toInt()

    if isMember == 1 {
        return true
    }

    return false
}


func addUser(name: String, password: String, salt: String) -> Bool {
    let added1 = try? REDIS.command("SADD", params: ["users", name]).toInt()
    let added2 = try? REDIS.command("HMSET", params: ["user_\(name)", "password", password, "salt", salt]).toString()

    if added1 == 1 && added2 == "OK" {
        return true
    }

    return false
}


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


let router = Router()


router.get("/") {
    request, response, next in

    let testValue = try REDIS.command("GET", params: ["test"]).toString()
        
    var result = [String: Any]()
    result["test"] = testValue
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}


router.post("/user/create", middleware: BodyParser())
router.post("/user/create") {
    request, response, next in
    defer { next() }

    guard let body = request.body else { 
        try badRequest( message: "No body in request.", response: response )
        return 
    }
    
    guard case .urlEncoded(let values) = body else { 
        try badRequest( message: "Arguments not properly url encoded.", response: response )
        return 
    }

        // check if 'username' and 'password' exist
    guard let username = values["username"] else { 
        try badRequest( message: "Missing 'username' argument.", response: response )
        return 
    }

    guard let password = values["password"] else { 
        try badRequest( message: "Missing 'password' argument.", response: response )
        return 
    }

    if username.characters.count < 3 || username.characters.count > 20 {
        try badRequest( message: "'username' needs to be between 3 an 20 characters.", response: response )
        return 
    }

    if password.characters.count < 6 || password.characters.count > 20 {
        try badRequest( message: "'password' needs to be between 6 and 20 characters.", response: response )
        return 
    }

    if userExists( name: username ) {
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
    let added = addUser(name: username, password: passwordHash, salt: saltString)

    var result = [String: Any]()
    result["success"] = true
    result["message"] = "User created."
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}


    // configure the server
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: serverPort, with: router)
Kitura.run()