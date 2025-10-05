import envoy
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import gleam/uri

const base_url = "https://bsky.social"

pub type BskyError {
  HttpError(httpc.HttpError)
  JsonParseError(json.DecodeError)
  EmptyThread
}

fn base_uri() -> uri.Uri {
  let assert Ok(uri) = uri.parse(base_url)
  uri
}

/// Log in to Bluesky. Requires `BSKY_HANDLE` and `BSKY_PASSWORD`
/// to be set as environment variables.
pub fn create_session() -> Result(SessionResponse, BskyError) {
  let handle = get_env_variable("BSKY_HANDLE")
  let password = get_env_variable("BSKY_PASSWORD")
  let body =
    json.object([
      #("identifier", json.string(handle)),
      #("password", json.string(password)),
    ])
    |> json.to_string()

  let assert Ok(req) =
    uri.Uri(..base_uri(), path: "/xrpc/com.atproto.server.createSession")
    |> request.from_uri()

  use response <- result.try(
    req
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
    |> httpc.send()
    |> result.map_error(HttpError),
  )

  json.parse(from: response.body, using: session_response_decoder())
  |> result.map_error(JsonParseError)
}

pub fn create_post(
  text: String,
  session: SessionResponse,
  reply: Option(BskyReply),
) -> Result(BskyCreatePostResponse, BskyError) {
  let post = create_post_payload(text, reply)

  let body =
    json.object([
      #("repo", json.string(session.did)),
      #("collection", json.string("app.bsky.feed.post")),
      #("record", post),
    ])
    |> json.to_string()

  let assert Ok(req) =
    uri.Uri(..base_uri(), path: "/xrpc/com.atproto.repo.createRecord")
    |> request.from_uri()

  use response <- result.try(
    req
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("authorization", { "bearer " <> session.access_jwt })
    |> httpc.send()
    |> result.map_error(HttpError),
  )
  json.parse(from: response.body, using: create_post_response_decoder())
  |> result.map_error(JsonParseError)
}

pub fn create_post_payload(text: String, reply: Option(BskyReply)) -> Json {
  let now = timestamp.system_time() |> timestamp.to_rfc3339(calendar.utc_offset)
  let base_fields = [
    #("$type", json.string("app.bsky.feed.post")),
    #("text", json.string(text)),
    #("createdAt", json.string(now)),
  ]
  let reply_fields = case reply {
    None -> []
    Some(reply) -> [
      #(
        "reply",
        json.object([
          #(
            "root",
            json.object([
              #("uri", json.string(reply.root.uri)),
              #("cid", json.string(reply.root.cid)),
            ]),
          ),
          #(
            "parent",
            json.object([
              #("uri", json.string(reply.parent.uri)),
              #("cid", json.string(reply.parent.cid)),
            ]),
          ),
        ]),
      ),
    ]
  }
  json.object(list.append(base_fields, reply_fields))
}

pub fn create_thread(
  posts: List(String),
  session: SessionResponse,
) -> Result(Nil, BskyError) {
  case posts {
    [] -> Error(EmptyThread)
    [first_post, ..rest] -> start_thread(first_post, rest, session)
  }
}

fn start_thread(
  first_post: String,
  rest: List(String),
  session: SessionResponse,
) -> Result(Nil, BskyError) {
  use root_post <- result.try(create_post(first_post, session, None))
  continue_thread(root_post, root_post, rest, session)
}

fn continue_thread(
  root: BskyCreatePostResponse,
  parent: BskyCreatePostResponse,
  remaining_posts: List(String),
  session: SessionResponse,
) -> Result(Nil, BskyError) {
  case remaining_posts {
    [] -> Ok(Nil)
    [next_post, ..rest] -> {
      use next_parent <- result.try(create_post(
        next_post,
        session,
        Some(BskyReply(root:, parent:)),
      ))
      continue_thread(root, next_parent, rest, session)
    }
  }
}

pub type SessionResponse {
  SessionResponse(access_jwt: String, did: String)
}

pub fn session_response_decoder() -> decode.Decoder(SessionResponse) {
  use access_jwt <- decode.field("accessJwt", decode.string)
  use did <- decode.field("did", decode.string)
  decode.success(SessionResponse(access_jwt:, did:))
}

pub type BskyCreatePostResponse {
  BskyCreatePostResponse(uri: String, cid: String)
}

pub type BskyReply {
  BskyReply(root: BskyCreatePostResponse, parent: BskyCreatePostResponse)
}

fn create_post_response_decoder() -> decode.Decoder(BskyCreatePostResponse) {
  use uri <- decode.field("uri", decode.string)
  use cid <- decode.field("cid", decode.string)
  decode.success(BskyCreatePostResponse(uri:, cid:))
}

fn get_env_variable(key: String) -> String {
  let assert Ok(value) = envoy.get(key)
    as { "env variable " <> key <> " must be set" }
  value
}
