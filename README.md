# Zig HTTP Server

A simple http server written in Zig for leaning purpose (inspired by [Rust Book](https://doc.rust-lang.org/book/ch20-00-final-project-a-web-server.html))

The server only serves the static home page. To terminate the server:
```
$ nc localhost <PORT>
TRM
```