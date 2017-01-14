import Kitura
import HeliumLogger
import SwiftyJSON
import PostgreSQL
import Foundation


HeliumLogger.use()


let postgreSQL = PostgreSQL.Database(
    dbname: "blog_web_api",
    user: "",
    password: ""
)


let router = Router()

router.get("/") {
    request, response, next in

    var result = [String: Any]()
    let json = JSON( result )

    try response.status(.OK).send(json: json).end()
}

let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8000") ?? 8000

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()