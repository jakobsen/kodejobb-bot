import gleam/dynamic/decode
import gleam/option.{type Option}

pub type ApiResponse {
  ApiResponse(jobs: List(JobListing))
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

pub type Company {
  Company(
    image_url: Option(String),
    logo_real: Option(String),
    logo_without_size: Option(String),
    name: String,
  )
}

pub fn company_decoder() -> decode.Decoder(Company) {
  use image_url <- decode.field("imageUrl", decode.optional(decode.string))
  use logo_real <- decode.field("logoReal", decode.optional(decode.string))
  use logo_without_size <- decode.field(
    "logoWithoutSize",
    decode.optional(decode.string),
  )
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
