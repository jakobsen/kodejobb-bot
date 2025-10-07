import core
import envoy
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
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
  let uri_facets =
    parse_uri_facets(text)
    |> list.map(fn(facet) {
      json.object([
        #(
          "index",
          json.object([
            #("byteStart", json.int(facet.index.byte_start)),
            #("byteEnd", json.int(facet.index.byte_end)),
          ]),
        ),
        #(
          "features",
          json.preprocessed_array([
            json.object([
              #("$type", json.string("app.bsky.richtext.facet#link")),
              #("uri", json.string(facet.uri)),
            ]),
          ]),
        ),
      ])
    })

  base_fields
  |> list.append(reply_fields)
  |> list.append([#("facets", json.preprocessed_array(uri_facets))])
  |> json.object()
}

pub type Facet {
  LinkFacet(index: Index, uri: String)
}

pub type Index {
  Index(byte_start: Int, byte_end: Int)
}

pub fn parse_uri_facets(post: String) -> List(Facet) {
  let assert Ok(uri_regex) =
    regexp.from_string(
      "\\b(https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*[-a-zA-Z0-9@%_\\+~#//=])?)",
    )
  regexp.scan(content: post, with: uri_regex)
  |> list.map(fn(match) -> Option(Facet) {
    case match {
      regexp.Match(_, [Some(link), ..]) -> {
        let byte_start = core.byte_index_of(in: post, find: link)
        case byte_start {
          Some(byte_start) -> {
            let link_byte_length =
              bit_array.from_string(link) |> bit_array.byte_size()
            Some(LinkFacet(
              index: Index(byte_start, byte_start + link_byte_length),
              uri: link,
            ))
          }
          None -> None
        }
      }
      _ -> None
    }
  })
  |> option.values()
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
