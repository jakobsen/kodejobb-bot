import bsky_client
import core
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string
import http_client
import schema.{type JobListing}
import simplifile
import storage

pub type AppError {
  HTTPError
  ParseError(msg: String)
  FileError(from: simplifile.FileError)
  BskyError(from: bsky_client.BskyError)
}

pub fn main() {
  io.println("Fetching frontpage")
  use frontpage_json <- result.try(fetch_frontpage())

  io.println("Extracting jobs")
  use jobs <- result.try(extract_jobs(frontpage_json))

  io.println("Getting seen job IDs")
  use seen_jobs <- result.try(get_seen_jobs())

  let new_jobs = core.reject_seen_jobs(jobs, seen_jobs)

  io.println("Posting new jobs to bluesky")
  use _ <- result.try(post_new_jobs_thread(new_jobs))

  io.println("Storing IDs of posted jobs")
  storage.append_job_ids(new_jobs) |> result.map_error(FileError)
}

fn thread_root(new_jobs: List(JobListing)) -> String {
  let number_of_jobs = list.length(new_jobs)
  let number_word = case number_of_jobs {
    1 -> "en"
    2 -> "to"
    3 -> "tre"
    4 -> "fire"
    5 -> "fem"
    6 -> "seks"
    7 -> "sju"
    8 -> "åtte"
    9 -> "ni"
    10 -> "ti"
    x -> int.to_string(x)
  }
  let pluralized_jobs = case number_of_jobs {
    1 -> "jobb"
    _ -> "jobber"
  }
  "Det er "
  <> number_word
  <> " nye "
  <> pluralized_jobs
  <> " på https://kodejobb.no"
}

fn job_message(job: JobListing) -> String {
  job.company.name <> " søker " <> job.application_title
}

fn post_new_jobs_thread(new_jobs: List(JobListing)) -> Result(Nil, AppError) {
  case new_jobs {
    [] -> Ok(Nil)
    jobs -> {
      use bsky_session <- result.try(
        bsky_client.create_session() |> result.map_error(BskyError),
      )
      let job_posts = jobs |> list.map(job_message)
      bsky_client.create_thread(
        [thread_root(new_jobs), ..job_posts],
        bsky_session,
      )
      |> result.map_error(BskyError)
    }
  }
}

fn fetch_frontpage() -> Result(String, AppError) {
  http_client.fetch_frontpage()
  |> result.map_error(fn(_) { HTTPError })
}

fn extract_jobs(frontpage_json: String) -> Result(List(JobListing), AppError) {
  core.extract_jobs(frontpage_json)
  |> result.map_error(fn(parse_error) {
    let error_message = string.inspect(parse_error)
    ParseError(msg: error_message)
  })
}

fn get_seen_jobs() -> Result(Set(String), AppError) {
  storage.read_job_ids() |> result.map_error(FileError)
}
