import core
import gleam/option.{Some}
import gleam/result
import gleam/set
import schema.{Company, JobListing}

pub fn extract_jobs_success_test() {
  let input =
    "
  {
    \"jobs\": [
      {
        \"id\": \"abc\",
        \"published_url\": \"/gleam-dev\",
        \"applicationTitle\": \"Gleam-utvikler\",
        \"title\": \"Superbra jobb!!\",
        \"hideFrom\": \"2025-02-01\",
        \"published\": \"2025-01-01\",
        \"type\": \"premium\",
        \"company\": {
          \"imageUrl\": \"https://cdn2.thecatapi.com/images/dmt.jpg\",
          \"logoReal\": \"https://cdn2.thecatapi.com/images/dmt.jpg\",
          \"logoWithoutSize\": \"https://cdn2.thecatapi.com/images/dmt.jpg\",
          \"name\": \"Eriks rør og kjør\"
        }
      }
    ]
  }
  "
  let result = core.extract_jobs(input)
  let assert Ok([
    JobListing(
      id: "abc",
      published_url: "/gleam-dev",
      application_title: "Gleam-utvikler",
      title: "Superbra jobb!!",
      hide_from: "2025-02-01",
      published: "2025-01-01",
      job_type: "premium",
      company: Company(
        image_url: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_real: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_without_size: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        name: "Eriks rør og kjør",
      ),
    ),
  ]) = result
}

pub fn extract_jobs_empty_list_test() {
  let assert Ok([]) = core.extract_jobs("{\"jobs\": []}")
}

pub fn extract_jobs_failure_test() {
  let result = core.extract_jobs("nonsense")
  assert result.is_error(result)
}

pub fn reject_seen_jobs_test() {
  let job_to_keep =
    JobListing(
      id: "1",
      published_url: "/gleam-dev",
      application_title: "Gleam-utvikler",
      title: "Superbra jobb!!",
      hide_from: "2025-02-01",
      published: "2025-01-01",
      job_type: "premium",
      company: Company(
        image_url: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_real: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_without_size: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        name: "Eriks rør og kjør",
      ),
    )
  let job_to_reject =
    JobListing(
      id: "2",
      published_url: "/trash",
      application_title: "Ikke så bra",
      title: "vil ikke jobbe her",
      hide_from: "2025-02-01",
      published: "2025-01-01",
      job_type: "premium",
      company: Company(
        image_url: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_real: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        logo_without_size: Some("https://cdn2.thecatapi.com/images/dmt.jpg"),
        name: "Eriks rør og kjør",
      ),
    )
  let seen_job_ids = set.new() |> set.insert(job_to_reject.id)
  let jobs = [job_to_reject, job_to_keep]
  let filtered_jobs = core.reject_seen_jobs(jobs, seen_job_ids)
  assert filtered_jobs == [job_to_keep]
}
