import core
import gleam/result
import gleam/string
import http_client
import logging.{Info}

pub type AppError {
  HTTPError
  ParseError(msg: String)
}

pub fn main() {
  logging.configure()
  logging.log(Info, "Fetching frontpage")
  use frontpage_json <- result.try(
    http_client.fetch_frontpage() |> result.map_error(fn(_) { HTTPError }),
  )
  use jobs <- result.try(
    core.extract_jobs(frontpage_json)
    |> result.map_error(fn(parse_error) {
      ParseError(msg: string.inspect(parse_error))
    }),
  )
  Ok(jobs)
}
