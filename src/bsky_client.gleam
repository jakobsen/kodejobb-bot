import envoy
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import gleam/uri

const base_url = "https://bsky.social"

pub type BskyError {
  HttpError(httpc.HttpError)
  JsonParseError(json.DecodeError)
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
) -> Result(String, BskyError) {
  let now = timestamp.system_time() |> timestamp.to_rfc3339(calendar.utc_offset)
  let post =
    json.object([
      #("$type", json.string("app.bsky.feed.post")),
      #("text", json.string(text)),
      #("createdAt", json.string(now)),
    ])
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
  Ok(response.body)
}

pub type SessionResponse {
  SessionResponse(access_jwt: String, did: String)
}

pub fn session_response_decoder() -> decode.Decoder(SessionResponse) {
  use access_jwt <- decode.field("accessJwt", decode.string)
  use did <- decode.field("did", decode.string)
  decode.success(SessionResponse(access_jwt:, did:))
}

fn get_env_variable(key: String) -> String {
  let assert Ok(value) = envoy.get(key)
    as { "env variable " <> key <> " must be set" }
  value
}
