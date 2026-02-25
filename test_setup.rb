# frozen_string_literal: true

$LOAD_PATH.unshift("lib")

require "opensearch/sugar"
require "dotenv"
Dotenv.load("env.development")

INDEX = "dc"

c = OpenSearch::Sugar::Client.new(host: "https://localhost:9200")
c.indices.delete(index: INDEX) if c.indices.exists?(index: INDEX)

# Elements

DC_HUMAN = {
  dc_cov: "coverage",
  dc_cr: "creator",
  dc_da: "date",
  dc_de: "description",
  dc_fo: "format",
  dc_ge: "geo",
  dc_id: "dc_id",
  dc_la: "language",
  dc_pu: "publisher",
  dc_re: "relation",
  dc_ri: "rights",
  dc_so: "source",
  dc_su: "subject",
  dc_ti: "title",
  dc_type: "type"
}

# FIELD_NAMES = DC_HUMAN.keys + %w[collection_id collection_name item_id uid]

ALL_SEARCH_FIELDS = %w[dc_cr dc_de id dc_re dc_su dc_ti ic_all collection_name]
BROWSE_FIELDS = %w[collection_id dc_la dc_type]

# Our basic text type
ICU_TEXT =
  {
    settings: {
      "analysis" =>
        {"filter" =>
            {"case_fold" =>
                {"type" => "icu_folding",
                 "description" => "case fold, but keep nordics intact",
                 "unicodeSetFilter" => "[^åäöÅÄÖ]"},
             "remove_diacritics" =>
                {"type" => "icu_transform",
                 "description" => "remove diacritics",
                 "id" => "NFD; [:Nonspacing Mark:] Remove; NFC"},
             "nfkc" => {"name" => "nfkc", "type" => "icu_normalizer"},
             "folding" => {"type" => "icu_folding", "unicodeSetFilter" => "[^åäöÅÄÖ]"}},
         "analyzer" =>
            {"icu_text" =>
                {"filter" => %w[nfkc case_fold remove_diacritics trim],
                 "description" =>
                    "Standard text processing pipeline with ICU tokenization and normalization",
                 "type" => "custom",
                 "tokenizer" => "icu_tokenizer"}}}
    }
  }

# FIELDS_FOR_MULTIFIELDS = {
#   search: {type: "text", analyzer: "icu_text"}
# }

ICU_TYPE = {type: "text", analyzer: "icu_text"}

# def keyword_searchable_field(fn)
#   rv = {type: "keyword", fields: FIELDS_FOR_MULTIFIELDS}
#   if ALL_SEARCH_FIELDS.include?(fn.to_s)
#     rv[:copy_to] = "keyword_search"
#   end
#   rv
# end

# All the fields that we can keyword search
MAPPINGS = {
  mappings: {
    properties: ALL_SEARCH_FIELDS.each_with_object({}) { |fn, h| h[fn] = ICU_TYPE }
  }
}

# Define the keyword_search type
# MAPPINGS[:mappings][:properties]["keyword_search"] = {type: "text", analyzer: "icu_text"}

# Now the browse fields, that only need a string type for faceting

BROWSE_FIELDS.each do |bf|
  MAPPINGS[:mappings][:properties][bf] = {type: "keyword"}
end

pp MAPPINGS
pp ICU_TEXT
imgclass = c.open_or_create(INDEX)
imgclass.upload_settings(ICU_TEXT)
imgclass.upload_mappings(MAPPINGS)

# if ARGV.shift == "index"
#   a = File.open("../project-dor-indexing-pilot/data/first_half_imgclass.jsonl").each_slice(1000)
#   10.times { c.bulk(body: a.next.map { |j| JSON.parse(j) }) }
# end
