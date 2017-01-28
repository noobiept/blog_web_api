# Try it out #


[http://blog-web-api.herokuapp.com/](http://blog-web-api.herokuapp.com/)


# Urls #


| Url | Http method | Parameters | Description | 
|-----|-------------|------------|-------------|
| /user/create | POST | username / password | Create a user. |
| /user/login | POST | username / password | Get an authentication token. |
| /user/change_password | POST | username / password / newPassword | Change the password. |
| /user/getall | GET | | Get a list with all the users. |
| /user/random | GET | | Get a random user. |
| /blog/add | POST | token / title / body | Add a post to the blog. |
| /blog/get/:blogId | GET |  | Get a specific blog post. |
| /blog/remove | POST | token / blogId | Remove a blog post. |
| /blog/update | POST | token / title / body / blogId | Update an existing blog post. |
| /blog/:username/getall | GET | | Get all the blog posts of a specific user. |
| /blog/random | GET | | Get a random blog post. |


# Example #


- curl --data "username=aaa&password=bbbbbb" http://localhost:8000/user/create
- curl --data "token=cccccc&title=title&body=body" http://localhost:8000/blog/add
- curl http://localhost:8000/blog/get/0

Use either `http://localhost:8000` (when testing locally) or the `http://blog-web-api.herokuapp.com` url (live server).


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