import gleam/http/request
import gleam/httpc
import gleam/result

pub fn fetch_frontpage() -> Result(String, httpc.HttpError) {
  let assert Ok(req) = request.to("https://docs.kode24.no/api/frontpage")
  let req = request.prepend_header(req, "accept", "application/json")
  httpc.send(req) |> result.map(fn(response) { response.body })
}
