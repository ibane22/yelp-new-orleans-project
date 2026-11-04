list.files("data/raw")

install.packages("jsonlite")
library(jsonlite)

business_file <- "data/raw/yelp_academic_dataset_business.json"

businesses <- stream_in(
  file(business_file, open = "r"),
  verbose = TRUE
)

dim(businesses)
names(businesses)
head(businesses)

new_orleans_restaurants <- businesses[
  businesses$city == "New Orleans" &
    businesses$state == "LA" &
    grepl("Restaurants", businesses$categories, ignore.case = TRUE),
]

dim(new_orleans_restaurants)
head(new_orleans_restaurants)

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)

saveRDS(
  new_orleans_restaurants,
  "data/new_orleans/new_orleans_restaurants.rds",
  compress = "xz"
)

file.exists("data/new_orleans/new_orleans_restaurants.rds")


"Reviews data"

restaurant_ids <- new_orleans_restaurants$business_id

reviews_kept <- list()

review_handler <- function(review_chunk) {
  matching_reviews <- review_chunk[
    review_chunk$business_id %in% restaurant_ids,
    c(
      "review_id",
      "user_id",
      "business_id",
      "stars",
      "useful",
      "funny",
      "cool",
      "text",
      "date"
    ),
    drop = FALSE
  ]
  
  if (nrow(matching_reviews) > 0) {
    reviews_kept[[length(reviews_kept) + 1]] <<- matching_reviews
  }
}

review_file <- "data/raw/yelp_academic_dataset_review.json"
review_connection <- file(review_file, open = "r")

stream_in(
  review_connection,
  handler = review_handler,
  pagesize = 10000,
  verbose = TRUE
)

close(review_connection)

new_orleans_reviews <- do.call(rbind, reviews_kept)
rownames(new_orleans_reviews) <- NULL

dim(new_orleans_reviews)
head(new_orleans_reviews)

saveRDS(
  new_orleans_reviews,
  "data/new_orleans/new_orleans_reviews.rds",
  compress = "xz"
)

file.exists("data/new_orleans/new_orleans_reviews.rds")

getwd()
list.files("data/new_orleans")

file.info(
  c(
    "data/new_orleans/new_orleans_restaurants.rds",
    "data/new_orleans/new_orleans_reviews.rds"
  )
)$size / 1024^2