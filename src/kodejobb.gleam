import core
import gleam/io
import gleam/result
import gleam/string
import http_client
import schema.{type JobListing}

pub type AppError {
  HTTPError
  ParseError(msg: String)
}

pub fn main() {
  io.println("Fetching frontpage")
  use frontpage_json <- result.try(fetch_frontpage())

  io.println("Extracting jobs")
  use jobs <- result.try(extract_jobs(frontpage_json))

  Ok(jobs)
}

fn fetch_frontpage() -> Result(String, AppError) {
  http_client.fetch_frontpage()
  |> result.map_error(fn(_) { HTTPError })
}

fn extract_jobs(frontpage_json: String) -> Result(List(JobListing), AppError) {
  let assert Ok(_) =
    core.extract_jobs(frontpage_json)
    |> result.map_error(fn(parse_error) {
      let error_message = string.inspect(parse_error)
      ParseError(msg: error_message)
    })
}
