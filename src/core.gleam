import gleam/json.{type DecodeError}
import gleam/result
import schema.{type JobListing}

pub fn extract_jobs(
  frontpage_json: String,
) -> Result(List(JobListing), DecodeError) {
  json.parse(from: frontpage_json, using: schema.api_response_decoder())
  |> result.map(fn(response) { response.jobs })
}
