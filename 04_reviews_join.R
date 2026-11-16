# Step 4: Join open restaurants to reviews

library(dplyr)
library(tidyr)
library(stringr)

# Load New Orleans restaurants and keep only businesses marked open
restaurants <- readRDS(
  "data/new_orleans/new_orleans_restaurants.rds"
) %>%
  filter(
    !is.na(is_open),
    is_open == 1
  )

# Load New Orleans reviews
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
  filter(
    !is.na(category),
    category != ""
  ) %>%
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

# Keep selected open restaurant information
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
    categories,
    is_open
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

# Confirm that all selected restaurants are open
table(selected_restaurant_data$is_open)

# Save selected open restaurant data
saveRDS(
  selected_restaurant_data,
  "data/new_orleans/selected_restaurants.rds",
  compress = "xz"
)

# Save the joined restaurant-review data
saveRDS(
  restaurant_reviews,
  "data/new_orleans/selected_restaurant_reviews.rds",
  compress = "xz"
)