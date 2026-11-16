# Step 3: Select and analyze restaurant categories

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

# Confirm the number of open New Orleans restaurants
nrow(restaurants)

# Separate categories and clean the category names
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

# Count individual categories
category_counts <- category_data %>%
  count(category, sort = TRUE)

print(category_counts, n = 30)

# Find categories that appear together
category_pairs <- category_data %>%
  inner_join(
    category_data,
    by = "business_id",
    suffix = c("_1", "_2"),
    relationship = "many-to-many"
  ) %>%
  filter(category_1 < category_2) %>%
  count(category_1, category_2, sort = TRUE)

print(category_pairs, n = 20)

# Select the project categories
selected_categories <- c(
  "Cajun/Creole",
  "Soul Food",
  "Seafood"
)

# Find restaurants matching at least one selected category
selected_restaurants <- category_data %>%
  filter(category %in% selected_categories) %>%
  distinct(business_id)

# Number of selected open restaurants
nrow(selected_restaurants)

# Count restaurants in each selected category
selected_category_counts <- category_data %>%
  filter(category %in% selected_categories) %>%
  count(category, sort = TRUE)

selected_category_counts

# Show selected category pairs
selected_pairs <- category_pairs %>%
  filter(
    category_1 %in% selected_categories,
    category_2 %in% selected_categories
  )

selected_pairs

# Inclusion rule:
# Include a restaurant if it belongs to at least one selected category.

selected_restaurant_data <- restaurants %>%
  semi_join(
    selected_restaurants,
    by = "business_id"
  )

# Confirm results
nrow(selected_restaurant_data)

n_distinct(selected_restaurant_data$business_id)

# Create the output folder
dir.create(
  "data/new_orleans",
  recursive = TRUE,
  showWarnings = FALSE
)

# Save selected open restaurants
saveRDS(
  selected_restaurant_data,
  "data/new_orleans/selected_restaurants.rds",
  compress = "xz"
)

# Save category results
write.csv(
  category_counts,
  "data/new_orleans/category_counts.csv",
  row.names = FALSE
)

write.csv(
  selected_category_counts,
  "data/new_orleans/selected_category_counts.csv",
  row.names = FALSE
)

write.csv(
  selected_pairs,
  "data/new_orleans/selected_category_pairs.csv",
  row.names = FALSE
)