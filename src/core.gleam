import gleam/json.{type DecodeError}
import gleam/list
import gleam/result
import gleam/set.{type Set}
import schema.{type JobListing}

pub fn extract_jobs(
  frontpage_json: String,
) -> Result(List(JobListing), DecodeError) {
  json.parse(from: frontpage_json, using: schema.api_response_decoder())
  |> result.map(fn(response) { response.jobs })
}

pub fn reject_seen_jobs(
  jobs: List(JobListing),
  seen_job_ids: Set(String),
) -> List(JobListing) {
  jobs
  |> list.filter(fn(job) { !set.contains(this: job.id, in: seen_job_ids) })
}
