library(dplyr)
library(tidyr)
library(stringr)

restaurants <- readRDS(
  "data/new_orleans/new_orleans_restaurants.rds"
)

# Separate categories, clean whitespace, and standardize capitalization
category_data <- restaurants %>%
  select(business_id, categories) %>%
  separate_rows(categories, sep = ",") %>%
  mutate(
    category = str_to_title(str_squish(categories))
  ) %>%
  filter(!is.na(category), category != "") %>%
  distinct(business_id, category)

# Count individual categories
category_counts <- category_data %>%
  count(category, sort = TRUE)

print(category_counts, n = 30)

# Find categories that occur together
category_pairs <- category_data %>%
  inner_join(
    category_data,
    by = "business_id",
    suffix = c("_1", "_2"),
    relationship = "many-to-many"
  ) %>%
  filter(category_1 < category_2) %>%
  count(category_1, category_2, sort = TRUE)

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

# Number of unique restaurants in the selected group
nrow(selected_restaurants)

# Number of restaurants in each selected category
category_data %>%
  filter(category %in% selected_categories) %>%
  count(category, sort = TRUE)

selected_pairs <- category_pairs %>%
  filter(
    category_1 %in% selected_categories &
      category_2 %in% selected_categories
  )

selected_pairs

# Inclusion rule:
# Include a restaurant if it belongs to at least one selected category.

selected_restaurant_data <- restaurants %>%
  semi_join(selected_restaurants, by = "business_id")

# Confirm the number of unique selected restaurants
nrow(selected_restaurant_data)

# Check for duplicate business IDs
n_distinct(selected_restaurant_data$business_id)

# Create the output folder if it does not already exist
dir.create(
  "data/new_orleans",
  recursive = TRUE,
  showWarnings = FALSE
)

# Save the selected restaurant data
saveRDS(
  selected_restaurant_data,
  "data/new_orleans/selected_restaurants.rds",
  compress = "xz"
)

# Save category results for the report
write.csv(
  category_counts,
  "data/new_orleans/category_counts.csv",
  row.names = FALSE
)

write.csv(
  selected_pairs,
  "data/new_orleans/selected_category_pairs.csv",
  row.names = FALSE
)