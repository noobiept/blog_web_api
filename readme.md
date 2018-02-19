# Try it out #

[http://blog-web-api.herokuapp.com/](http://blog-web-api.herokuapp.com/)


# Urls #

| Url | Http method | Parameters | Description |
|-----|-------------|------------|-------------|
| /user/create | POST | username / password | Create a user. |
| /user/login | POST | username / password | Get an authentication token. |
| /user/remove | POST | username / password | Remove an existing user (and all his posts). |
| /user/change_password | POST | username / password / newPassword | Change the password. |
| /user/invalidate_tokens | POST | username / password | Invalidate all of the user's previous tokens. Returns a new one. |
| /user/getall | GET | | Get a list with all the users. |
| /user/random | GET | | Get a random user. |
| /blog/add | POST | token / title / body | Add a post to the blog. |
| /blog/get/:blogId | GET |  | Get a specific blog post. |
| /blog/remove | POST | token / blogId | Remove a blog post. |
| /blog/update | POST | token / title / body / blogId | Update an existing blog post. |
| /blog/:username/getall | GET | | Get all the blog posts of a specific user. |
| /blog/random | GET | | Get a random blog post. |
| /blog/getall | GET | | Get a list with all blog ids available. |


# Usage Example #

- curl --data "username=aaa&password=bbbbbb" http://localhost:8000/user/create
- curl --data "token=cccccc&title=The title.&body=The message body." http://localhost:8000/blog/add
- curl http://localhost:8000/blog/get/1
- curl http://localhost:8000/blog/aaa/getall


Use either `http://localhost:8000` (when testing locally) or the `http://blog-web-api.herokuapp.com` url (live server).


# Dependencies #

- [Swift](https://swift.org/)
- [Kitura](http://www.kitura.io/)
- [Redis](https://redis.io/)
- [Heroku build pack](https://github.com/kylef/heroku-buildpack-swift)


# Development #

To try out the application locally, first install `swift` and `redis`, then run:

- `redis-server`
- `swift run`

Now you can use `curl` for example to make requests.


# Testing #

Start the database (`redis-server`) and the application (`swift run`) and then run the tests.

- `python3 Tests/tests.py`


# Relevant Commands #

| Command | Description |
|---------|-------------|
| `redis-cli` | Redis client for testing purposes. |
| `redis-server` | Start the redis server. |
| `swift package update` | Update all dependencies to latest version. |
| `swift run` | Compile and run the server. |
| `python3 Tests/tests.py` | Run the tests. |
| `autopep8 --in-place Tests/tests.py` | Run the auto-formatter for the tests. |
| `git push heroku master` | Deploy to heroku. |


# Database Keys #

| Key | Description | Data Type |
| ----|-------------|-----------|
| LAST_POST_ID | ID of the last post. | Integer |
| user_* | User information. | Hash |
| users | Set with all the usernames. | Set |
| user_posts_* | Set of IDs of posts made by this user. | Set |
| user_tokens_* | Set with all the tokens of a given user. | Set |
| token_* | Authentication token. | String |
| post_* | Blog post information. | Hash |
| posts | All post IDs. | Set |