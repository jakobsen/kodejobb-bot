import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string
import schema
import simplifile.{type FileError}

const filepath = "jobs.txt"

fn ensure_file_exists() -> Result(Nil, FileError) {
  case simplifile.is_file(filepath) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> simplifile.create_file(filepath)
    Error(error) -> Error(error)
  }
}

pub fn read_job_ids() -> Result(Set(String), FileError) {
  use _ <- result.try(ensure_file_exists())
  use file_content <- result.try(simplifile.read(filepath))
  file_content
  |> string.split(on: "\n")
  |> list.map(string.trim)
  |> set.from_list
  |> Ok
}

pub fn append_job_ids(jobs: List(schema.JobListing)) -> Result(Nil, FileError) {
  case jobs {
    [] -> Ok(Nil)

    jobs -> {
      use _ <- result.try(ensure_file_exists())
      jobs
      |> list.map(fn(job) { job.id })
      |> string.join("\n")
      |> string.append("\n")
      |> simplifile.append(to: filepath, contents: _)
    }
  }
}
