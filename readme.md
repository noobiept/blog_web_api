# Try it out #

[http://blog-web-api.herokuapp.com/](http://blog-web-api.herokuapp.com/)

# Commands #

| Command | Description |
|---------|-------------|
| curl --data "username=aaa&password=bbbbbb" http://localhost:8000/user/create | Create a user. |
| curl --data "username=aaa&password=bbbbbb" http://localhost:8000/user/login | Get an authentication token. |
| curl --data "token=cccccc&title=title&body=body" http://localhost:8000/blog/add | Add a blog post. |
| curl http://localhost:8000/blog/get/:blogId | Get a specific blog post. |

# Dependencies #

- [Kitura](http://www.kitura.io/)
- [Redis](https://redis.io/)
- [Heroku build pack](https://github.com/kylef/heroku-buildpack-swift)

# Development #

| Command | Description |
|---------|-------------|
| `redis-server` | Start the redis server. |
| `swift build && .build/debug/blog_web_api` | Compile and run the server. |
| `git push heroku master` | Deploy to heroku. |

# Database Keys #

| Key | Description | Data Type |
| ----|-------------|-----------|
| LAST_POST_ID | ID of the last post. | Integer |
| user_* | User information. | Hash |
| users | Set with all the usernames. | Set |
| user_posts_* | Set of IDs of posts made by this user. | Set |
| token_* | Authentication token. | String |
| post_* | Blog post information. | Hash |
| posts | All post IDs. | Set |