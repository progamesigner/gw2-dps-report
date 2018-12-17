extern crate futures;
extern crate hyper;
extern crate mktemp;

use futures::future;
use hyper::header::HeaderValue;
use hyper::rt::{self, Future, Stream};
use hyper::service::service_fn;
use hyper::{Body, Method, Request, Response, Server, StatusCode};
use mktemp::Temp;
use std::env;
use std::fs::{self, File};
use std::io::{Error, Read, Write};
use std::path::Path;
use std::process::{Command, Stdio};

type ResponseFuture = Box<Future<Item = Response<Body>, Error = hyper::Error> + Send>;

fn static_file_body(filename: &str) -> Result<Body, Error> {
    let path = format!(
        "{}/{}",
        env::var("SERVER_FILE_PATH").unwrap_or("res".to_string()),
        filename
    );

    let mut data = Vec::new();
    let mut file = File::open(path).expect(&format!("File {} not found", filename));

    match file.read_to_end(&mut data) {
        Ok(_) => Ok(Body::from(data)),
        Err(error) => Err(error),
    }
}

fn evtc_file_body(filename: &str) -> Result<Body, Error> {
    let path = format!(
        "{}/evtc-{}/index.html",
        env::var("FILE_BASE_PATH").unwrap_or("files".to_string()),
        filename
    );

    let mut data = String::new();

    match File::open(path) {
        Ok(mut file) => match file.read_to_string(&mut data) {
            Ok(_) => Ok(Body::from(data)),
            Err(error) => Err(error),
        },
        Err(error) => Err(error),
    }
}

fn response_not_found() -> Response<Body> {
    Response::builder()
        .header("Content-Type", "text/html")
        .status(StatusCode::NOT_FOUND)
        .body(static_file_body("404.html").unwrap())
        .unwrap()
}

fn response_not_authorized() -> Response<Body> {
    Response::builder()
        .header("Content-Type", "application/json")
        .status(StatusCode::FORBIDDEN)
        .body(Body::from("{\"error\": \"Forbidden\"}"))
        .unwrap()
}

fn response_server_error(message: &str) -> Response<Body> {
    Response::builder()
        .header("Content-Type", "application/json")
        .status(StatusCode::INTERNAL_SERVER_ERROR)
        .body(Body::from(format!("{{\"error\": \"{}\"}}", message)))
        .unwrap()
}

fn index(_: Request<Body>) -> ResponseFuture {
    match static_file_body("index.html") {
        Ok(body) => Box::new(future::ok(
            Response::builder()
                .header("Content-Type", "text/html")
                .body(body)
                .unwrap(),
        )),
        Err(_) => Box::new(future::ok(response_not_found())),
    }
}

fn upload(request: Request<Body>) -> ResponseFuture {
    let (parts, body) = request.into_parts();

    let empty = HeaderValue::from_static("");
    let token = env::var("UPLOAD_ACCESS_TOKEN").unwrap_or("".to_string());

    let base = env::var("DPS_BASE_URL").unwrap_or(format!(
        "http://{}:{}",
        env::var("SERVER_LISTEN_ADDR").unwrap_or("127.0.0.1".to_string()),
        env::var("SERVER_LISTEN_PORT").unwrap_or("3000".to_string())
    ));

    if token
        == parts
            .headers
            .get("X-ACCESS-TOKEN")
            .unwrap_or(&empty)
            .to_str()
            .unwrap()
    {
        Box::new(
            body.concat2()
                .map(move |evtc| match parts.headers.get("X-EVTC-FILENAME") {
                    Some(filename) => {
                        let name = filename.to_str().unwrap();
                        let temp = Temp::new_dir().expect("Failed to create temporary directory");
                        let path = format!("{}/{}", temp.to_path_buf().to_str().unwrap(), name);

                        let mut file = File::create(path.clone()).unwrap();
                        let mut command = Command::new(
                            fs::canonicalize(
                                env::var("EVTC_PARSER_PATH").unwrap_or("/bin/parser".to_string()),
                            )
                            .unwrap(),
                        );

                        command
                            .arg(path.clone())
                            .arg(name)
                            .stdout(Stdio::inherit())
                            .stderr(Stdio::inherit());

                        file.write_all(&evtc)
                            .expect("Failed to write temporary file");
                        file.sync_all().expect("Failed to sync temporary file");

                        if command
                            .spawn()
                            .expect("Failed to execute parser")
                            .wait()
                            .expect("Failed to determine parser exit status")
                            .success()
                        {
                            match File::open(format!(
                                "{}/data.txt",
                                temp.to_path_buf().to_str().unwrap()
                            )) {
                                Ok(mut data) => {
                                    let mut name = String::new();
                                    match data.read_to_string(&mut name) {
                                        Ok(_) => Response::builder()
                                            .header("Content-Type", "application/json")
                                            .body(Body::from(format!(
                                                "{{\"url \": \"{}/{}\"}}",
                                                base,
                                                name.trim()
                                            )))
                                            .unwrap(),
                                        Err(_) => response_server_error("Empty result"),
                                    }
                                }
                                Err(_) => response_server_error("Parsing error"),
                            }
                        } else {
                            response_server_error("Parser error")
                        }
                    }
                    None => response_server_error("X-EVTC-FILENAME header is required"),
                }),
        )
    } else {
        Box::new(future::ok(response_not_authorized()))
    }
}

fn serve(request: Request<Body>) -> ResponseFuture {
    let path = Path::new(&request.uri().path()[1..]);

    match evtc_file_body(path.to_str().unwrap()) {
        Ok(body) => Box::new(future::ok(
            Response::builder()
                .header("Content-Type", "text/html")
                .body(body)
                .unwrap(),
        )),
        Err(_) => match static_file_body(path.to_str().unwrap()) {
            Ok(body) => Box::new(future::ok(
                Response::builder()
                    .header(
                        "Content-Type",
                        match path.extension() {
                            Some(extension) => match extension.to_str() {
                                Some("css") => "text/css",
                                Some("html") => "text/html",
                                Some("js") => "text/javascript",
                                Some("json") => "application/json",
                                Some("png") => "image/png",
                                _ => "text/plain",
                            },
                            _ => "text/plain",
                        },
                    )
                    .body(body)
                    .unwrap(),
            )),
            Err(_) => Box::new(future::ok(response_not_found())),
        },
    }
}

fn dispatcher(request: Request<Body>) -> ResponseFuture {
    match (request.method(), request.uri().path()) {
        (&Method::GET, "/") | (&Method::GET, "/index.html") => index(request),
        (&Method::PUT, "/upload") => upload(request),
        _ => serve(request),
    }
}

fn main() {
    let addr = format!(
        "{}:{}",
        env::var("SERVER_LISTEN_ADDR").unwrap_or("127.0.0.1".to_string()),
        env::var("SERVER_LISTEN_PORT").unwrap_or("3000".to_string())
    )
    .parse()
    .unwrap();

    let server = Server::bind(&addr)
        .serve(|| service_fn(dispatcher))
        .map_err(|err| eprintln!("Server error: {}", err));

    println!("Listening on http://{}", addr);

    rt::run(server);
}
