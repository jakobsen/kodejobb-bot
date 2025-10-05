import bsky_client

pub fn parse_facets_test() {
  assert bsky_client.parse_uri_facets(
      "✨ example mentioning @atproto.com to share the URL 👨‍❤️‍👨 https://en.wikipedia.org/wiki/CBOR.",
    )
    == [
      bsky_client.LinkFacet(
        index: bsky_client.Index(byte_start: 74, byte_end: 108),
        uri: "https://en.wikipedia.org/wiki/CBOR",
      ),
    ]
}

pub fn parse_facets_kodejobb_no_test() {
  assert bsky_client.parse_uri_facets(
      "Det er én ny jobb på https://kodejobb.no",
    )
    == [
      bsky_client.LinkFacet(
        index: bsky_client.Index(byte_start: 23, byte_end: 42),
        uri: "https://kodejobb.no",
      ),
    ]
}
