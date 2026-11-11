library(dplyr)
library(tidyr)
library(stringr)

# Load the New Orleans restaurant and review RDS files
restaurants <- readRDS(
  "data/new_orleans/new_orleans_restaurants.rds"
)

reviews <- readRDS(
  "data/new_orleans/new_orleans_reviews.rds"
)

# Recreate the individual business-category data
category_data <- restaurants %>%
  select(business_id, categories) %>%
  separate_rows(categories, sep = ",") %>%
  mutate(
    category = str_to_title(str_squish(categories))
  ) %>%
  filter(!is.na(category), category != "") %>%
  distinct(business_id, category)

# Select the three restaurant categories
selected_categories <- c(
  "Cajun/Creole",
  "Soul Food",
  "Seafood"
)

# Find businesses in at least one selected category
selected_business_ids <- category_data %>%
  filter(category %in% selected_categories) %>%
  distinct(business_id)

# Keep the selected restaurant business information
selected_restaurant_data <- restaurants %>%
  semi_join(
    selected_business_ids,
    by = "business_id"
  ) %>%
  select(
    business_id,
    name,
    address,
    city,
    state,
    postal_code,
    latitude,
    longitude,
    stars,
    review_count,
    categories
  )

# Filter reviews before joining
selected_reviews <- reviews %>%
  semi_join(
    selected_restaurant_data,
    by = "business_id"
  )

# Join restaurant information to review information
restaurant_reviews <- selected_restaurant_data %>%
  inner_join(
    selected_reviews,
    by = "business_id",
    suffix = c("_business", "_review")
  )

# Check the results
dim(selected_restaurant_data)
dim(selected_reviews)
dim(restaurant_reviews)

n_distinct(restaurant_reviews$business_id)
head(restaurant_reviews)

# Save the selected restaurant business data
saveRDS(
  selected_restaurant_data,
  "data/new_orleans/selected_restaurants.rds",
  compress = "xz"
)

# Save the joined data
saveRDS(
  restaurant_reviews,
  "data/new_orleans/selected_restaurant_reviews.rds",
  compress = "xz"
)