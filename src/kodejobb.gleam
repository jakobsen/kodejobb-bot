import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result
import logging.{Info}

pub type AppError {
  HTTPError
  ParseError
}

pub type Company {
  Company(
    image_url: String,
    logo_real: String,
    logo_without_size: String,
    name: String,
  )
}

pub type JobListing {
  JobListing(
    id: String,
    published_url: String,
    application_title: String,
    title: String,
    hide_from: String,
    published: String,
    job_type: String,
    company: Company,
  )
}

pub type ApiResponse {
  ApiResponse(jobs: List(JobListing))
}

pub fn main() {
  logging.configure()
  logging.log(Info, "Fetching frontpage")
  use frontpage_json <- result.try(fetch_frontpage())
  use jobs <- result.try(parse_jobs(frontpage_json))
  echo jobs
  Ok(jobs)
}

pub fn company_decoder() -> decode.Decoder(Company) {
  use image_url <- decode.field("imageUrl", decode.string)
  use logo_real <- decode.field("logoReal", decode.string)
  use logo_without_size <- decode.field("logoWithoutSize", decode.string)
  use name <- decode.field("name", decode.string)

  decode.success(Company(image_url:, logo_real:, logo_without_size:, name:))
}

pub fn job_listing_decoder() -> decode.Decoder(JobListing) {
  use id <- decode.field("id", decode.string)
  use published_url <- decode.field("published_url", decode.string)
  use application_title <- decode.field("applicationTitle", decode.string)
  use title <- decode.field("title", decode.string)
  use hide_from <- decode.field("hideFrom", decode.string)
  use published <- decode.field("published", decode.string)
  use job_type <- decode.field("type", decode.string)
  use company <- decode.field("company", company_decoder())

  decode.success(JobListing(
    id:,
    published_url:,
    application_title:,
    title:,
    hide_from:,
    published:,
    job_type:,
    company:,
  ))
}

pub fn api_response_decoder() -> decode.Decoder(ApiResponse) {
  use jobs <- decode.field("jobs", decode.list(of: job_listing_decoder()))

  decode.success(ApiResponse(jobs:))
}

fn parse_jobs(frontpage_json: String) -> Result(List(JobListing), AppError) {
  case json.parse(from: frontpage_json, using: api_response_decoder()) {
    Ok(parsed_response) -> Ok(parsed_response.jobs)
    Error(_) -> {
      Error(ParseError)
    }
  }
}

fn fetch_frontpage() -> Result(String, AppError) {
  let assert Ok(req) = request.to("https://docs.kode24.no/api/frontpage")
  let req = request.prepend_header(req, "accept", "application/json")
  case httpc.send(req) {
    Ok(response) -> Ok(response.body)
    Error(_) -> Error(HTTPError)
  }
}
