import core
import gleam/result
import gleam/string
import http_client
import logging.{Error, Info}
import schema.{type JobListing}

pub type AppError {
  HTTPError
  ParseError(msg: String)
}

pub fn main() {
  logging.configure()
  logging.log(Info, "Fetching frontpage")
  use frontpage_json <- result.try(fetch_frontpage())

  logging.log(Info, "Parsing frontpage JSON")
  use jobs <- result.try(extract_jobs(frontpage_json))

  Ok(jobs)
}

fn fetch_frontpage() -> Result(String, AppError) {
  http_client.fetch_frontpage()
  |> result.map_error(fn(e) {
    logging.log(Error, "Error fetching frontpage: " <> string.inspect(e))
    HTTPError
  })
}

fn extract_jobs(frontpage_json: String) -> Result(List(JobListing), AppError) {
  let assert Ok(_) =
    core.extract_jobs(frontpage_json)
    |> result.map_error(fn(parse_error) {
      let error_message = string.inspect(parse_error)
      logging.log(Error, "Error parsing frontpage JSON: " <> error_message)
      ParseError(msg: error_message)
    })
}
