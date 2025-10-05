import gleam/bit_array
import gleam/json.{type DecodeError}
import gleam/list
import gleam/option.{type Option, None, Some}
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

pub fn byte_index_of(in haystack: String, find needle: String) -> Option(Int) {
  let haystack_bytes = bit_array.from_string(haystack)
  let haystack_size = bit_array.byte_size(haystack_bytes)
  let needle_bytes = bit_array.from_string(needle)
  let needle_size = bit_array.byte_size(needle_bytes)
  case needle_size {
    0 -> None
    x if x > haystack_size -> None
    _ ->
      find_byte_index_of(
        haystack_bytes,
        haystack_size,
        needle_bytes,
        needle_size,
      )
  }
}

fn find_byte_index_of(
  haystack_bytes: BitArray,
  haystack_length: Int,
  needle_bytes: BitArray,
  needle_length: Int,
) -> Option(Int) {
  let found_index =
    list.range(0, haystack_length - needle_length)
    |> list.find(fn(idx) {
      let slice =
        bit_array.slice(from: haystack_bytes, at: idx, take: needle_length)
      case slice {
        Ok(candidate) -> candidate == needle_bytes
        _ -> False
      }
    })

  case found_index {
    Ok(index) -> Some(index)
    _ -> None
  }
}
