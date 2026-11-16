# Step 7: Analyze ratings for open restaurants
# Reviewer threshold: at least 7 reviews per reviewer
# Final requirement: at least 100 different eligible reviewers

library(dplyr)
library(lubridate)
library(ggplot2)
library(sf)
library(tigris)

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# Load open selected restaurants
selected_restaurants <- readRDS(
  "data/new_orleans/selected_restaurants.rds"
) %>%
  filter(
    !is.na(is_open),
    is_open == 1
  )

# Load New Orleans reviews
new_orleans_reviews <- readRDS(
  "data/new_orleans/new_orleans_reviews.rds"
)

# Keep reviews for open selected restaurants
category_reviews <- new_orleans_reviews %>%
  semi_join(
    selected_restaurants,
    by = "business_id"
  ) %>%
  mutate(
    review_date = as.Date(as.character(date)),
    review_year = year(review_date)
  )

# Check the data
nrow(selected_restaurants)
nrow(category_reviews)

# ------------------------------------------------------------
# Ratings using all reviewers
# ------------------------------------------------------------

all_reviewer_summary <- category_reviews %>%
  group_by(business_id) %>%
  summarise(
    number_of_reviews_all_reviewers = n(),
    average_stars_all_reviewers = mean(stars, na.rm = TRUE),
    median_stars_all_reviewers = median(stars, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(average_stars_all_reviewers))

top_10_all_reviewers <- all_reviewer_summary %>%
  slice_head(n = 10)

as.data.frame(top_10_all_reviewers)

write.csv(
  all_reviewer_summary,
  "data/new_orleans/all_reviewer_summary.csv",
  row.names = FALSE
)

# ------------------------------------------------------------
# Reviewer activity
# ------------------------------------------------------------

reviewer_activity <- category_reviews %>%
  count(
    user_id,
    name = "reviews_in_selected_categories"
  ) %>%
  arrange(desc(reviews_in_selected_categories))

# Reviewers must have at least seven reviews
minimum_reviewer_reviews <- 7

eligible_reviewers <- reviewer_activity %>%
  filter(
    reviews_in_selected_categories >= minimum_reviewer_reviews
  )

selected_reviewer_reviews <- category_reviews %>%
  semi_join(
    eligible_reviewers,
    by = "user_id"
  )

nrow(eligible_reviewers)
nrow(selected_reviewer_reviews)

percentage_reviews_retained <-
  nrow(selected_reviewer_reviews) /
  nrow(category_reviews) *
  100

percentage_reviews_retained

# ------------------------------------------------------------
# Compare reviewer thresholds
# ------------------------------------------------------------

threshold_comparison <- data.frame(
  minimum_reviews = c(5, 6, 7, 8, 10)
)

threshold_comparison$reviewers_retained <- sapply(
  threshold_comparison$minimum_reviews,
  function(threshold) {
    sum(
      reviewer_activity$reviews_in_selected_categories >= threshold
    )
  }
)

threshold_comparison$reviews_retained <- sapply(
  threshold_comparison$minimum_reviews,
  function(threshold) {
    eligible_ids <- reviewer_activity %>%
      filter(
        reviews_in_selected_categories >= threshold
      ) %>%
      pull(user_id)
    
    sum(category_reviews$user_id %in% eligible_ids)
  }
)

threshold_comparison$percent_of_reviews_retained <-
  threshold_comparison$reviews_retained /
  nrow(category_reviews) *
  100

threshold_comparison

write.csv(
  threshold_comparison,
  "data/new_orleans/threshold_comparison.csv",
  row.names = FALSE
)

# ------------------------------------------------------------
# Reviewer baselines and normalized scores
# ------------------------------------------------------------

reviewer_baselines <- category_reviews %>%
  group_by(user_id) %>%
  summarise(
    reviewer_mean = mean(stars, na.rm = TRUE),
    reviewer_median = median(stars, na.rm = TRUE),
    reviewer_review_count = n(),
    .groups = "drop"
  )

category_reviews_adjusted <- category_reviews %>%
  left_join(
    reviewer_baselines,
    by = "user_id"
  ) %>%
  mutate(
    normalized_mean_score = stars - reviewer_mean,
    normalized_median_score = stars - reviewer_median
  )

eligible_adjusted_reviews <- category_reviews_adjusted %>%
  semi_join(
    eligible_reviewers,
    by = "user_id"
  )

# Should return 7
min(eligible_adjusted_reviews$reviewer_review_count)

# ------------------------------------------------------------
# Restaurant-level comparison
# ------------------------------------------------------------

eligible_restaurant_summary <- eligible_adjusted_reviews %>%
  group_by(business_id) %>%
  summarise(
    number_of_eligible_reviews = n(),
    number_of_eligible_reviewers = n_distinct(user_id),
    average_stars_eligible_reviewers =
      mean(stars, na.rm = TRUE),
    average_normalized_score =
      mean(normalized_mean_score, na.rm = TRUE),
    median_normalized_score =
      median(normalized_mean_score, na.rm = TRUE),
    .groups = "drop"
  )

restaurant_summary <- selected_restaurants %>%
  select(
    business_id,
    business_name = name,
    city,
    postal_code,
    latitude,
    longitude
  ) %>%
  left_join(
    all_reviewer_summary,
    by = "business_id"
  ) %>%
  left_join(
    eligible_restaurant_summary,
    by = "business_id"
  ) %>%
  arrange(desc(average_normalized_score))

# ------------------------------------------------------------
# Final ranking: at least 100 different eligible reviewers
# ------------------------------------------------------------

top_10_adjusted_7_100_reliable <- restaurant_summary %>%
  filter(
    number_of_eligible_reviewers >= 100
  ) %>%
  arrange(desc(average_normalized_score)) %>%
  slice_head(n = 10)

as.data.frame(top_10_adjusted_7_100_reliable)

# Should return 62
number_meeting_100_reviewer_requirement <- restaurant_summary %>%
  summarise(
    restaurants_with_at_least_100_reviewers =
      sum(number_of_eligible_reviewers >= 100, na.rm = TRUE)
  )

number_meeting_100_reviewer_requirement

# Raw-rating comparison
top_10_raw_reliable <- restaurant_summary %>%
  filter(
    number_of_reviews_all_reviewers >= 10
  ) %>%
  arrange(desc(average_stars_all_reviewers)) %>%
  slice_head(n = 10)

as.data.frame(top_10_raw_reliable)

# ------------------------------------------------------------
# Save result tables
# ------------------------------------------------------------

write.csv(
  restaurant_summary,
  "data/new_orleans/restaurant_summary_raw_adjusted.csv",
  row.names = FALSE
)

write.csv(
  top_10_adjusted_7_100_reliable,
  "data/new_orleans/final_top_10_restaurants.csv",
  row.names = FALSE
)

write.csv(
  top_10_raw_reliable,
  "data/new_orleans/top_10_raw_reliable_restaurants.csv",
  row.names = FALSE
)

# ------------------------------------------------------------
# Rating comparison graph
# ------------------------------------------------------------

rating_comparison_plot <- ggplot(
  restaurant_summary %>%
    filter(
      !is.na(average_stars_all_reviewers),
      !is.na(average_normalized_score)
    ),
  aes(
    x = average_stars_all_reviewers,
    y = average_normalized_score
  )
) +
  geom_hline(
    yintercept = 0,
    color = "grey70"
  ) +
  geom_point(
    aes(size = number_of_reviews_all_reviewers),
    color = "steelblue",
    alpha = 0.65
  ) +
  labs(
    title = "Raw Ratings Compared with Reviewer-Adjusted Scores",
    subtitle = "Open Cajun/Creole, seafood, and soul food restaurants",
    x = "Average stars from all reviewers",
    y = "Average normalized score",
    size = "All reviews"
  ) +
  theme_minimal()

rating_comparison_plot

ggsave(
  "figures/rating_comparison_open.png",
  plot = rating_comparison_plot,
  width = 8,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------
# Create restaurant points
# ------------------------------------------------------------

restaurant_points <- selected_restaurants %>%
  filter(
    !is.na(longitude),
    !is.na(latitude)
  ) %>%
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

options(tigris_use_cache = TRUE)

zcta_boundaries <- tigris::zctas(
  cb = TRUE,
  year = 2020,
  class = "sf"
) %>%
  st_transform(st_crs(restaurant_points))

# Match final restaurants to map points
top_10_points <- restaurant_points %>%
  inner_join(
    top_10_adjusted_7_100_reliable %>%
      select(
        business_id,
        business_name,
        average_normalized_score
      ),
    by = "business_id"
  )

# ------------------------------------------------------------
# Final top-10 map
# ------------------------------------------------------------

top_10_map <- ggplot() +
  geom_sf(
    data = zcta_boundaries,
    fill = "grey95",
    color = "grey55",
    linewidth = 0.4
  ) +
  geom_sf(
    data = top_10_points,
    aes(color = average_normalized_score),
    size = 3,
    alpha = 0.9
  ) +
  scale_color_viridis_c(
    option = "C",
    name = "Reviewer-adjusted\nscore"
  ) +
  coord_sf(
    xlim = c(-90.25, -89.75),
    ylim = c(29.85, 30.20),
    expand = FALSE
  ) +
  labs(
    title = "Top 10 Open New Orleans Specialty Restaurants",
    subtitle = paste(
      "Seven-review threshold and at least 100 eligible reviewers"
    ),
    caption = "Points show restaurant locations. ZIP Code boundaries are shown."
  ) +
  theme_minimal()

top_10_map

ggsave(
  "figures/final_top_10_restaurants_map.png",
  plot = top_10_map,
  width = 10,
  height = 7,
  dpi = 300
)