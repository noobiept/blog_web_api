# Try it out #

[http://blog-web-api.herokuapp.com/](http://blog-web-api.herokuapp.com/)

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
