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


func getPostParameters(keys: [String], request: RouterRequest, response: RouterResponse) throws -> [String: String]? {
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
func getUserParameters(request: RouterRequest, response: RouterResponse) throws -> (String, String)? {
    guard let params = try getPostParameters(keys: ["username", "password"], request: request, response: response) else {
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