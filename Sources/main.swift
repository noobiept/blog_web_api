import Kitura
import HeliumLogger
import SwiftyJSON
import PostgreSQL


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

Kitura.addHTTPServer(onPort: 8000, with: router)
Kitura.run()