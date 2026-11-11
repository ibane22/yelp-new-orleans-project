library(sf)
library(tigris)
library(dplyr)
library(ggplot2)
library(stringr)

options(tigris_use_cache = TRUE)

# Load spatial restaurant data from Step 5
restaurants_with_place <- readRDS(
  "data/new_orleans/restaurants_with_place.rds"
)

# Keep restaurants serving New Orleans-associated cuisines
selected_restaurant_data <- restaurants_with_place %>%
  filter(
    !is.na(categories),
    str_detect(
      categories,
      regex(
        "Cajun/Creole|Soul Food|Seafood",
        ignore_case = TRUE
      )
    )
  )

# The restaurants are already sf points
restaurant_points <- selected_restaurant_data

# Download 2020 ZIP Code Tabulation Areas
zcta_boundaries <- tigris::zctas(
  cb = TRUE,
  starts_with = "70",
  year = 2020,
  class = "sf"
)

# Find the correct ZCTA ID column
zcta_id_column <- intersect(
  c("ZCTA5CE20", "GEOID20", "ZCTA5CE"),
  names(zcta_boundaries)
)[1]

# Download 2024 Census tracts for Orleans Parish
tract_boundaries <- tigris::tracts(
  state = "LA",
  county = "Orleans",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# Make boundary layers use the same CRS as the restaurant points
zcta_boundaries <- zcta_boundaries %>%
  st_transform(st_crs(restaurant_points))

tract_boundaries <- tract_boundaries %>%
  st_transform(st_crs(restaurant_points))

# Assign restaurants to ZIP Code areas
restaurants_zcta <- restaurant_points %>%
  st_join(
    zcta_boundaries %>%
      mutate(area = .data[[zcta_id_column]]) %>%
      select(area),
    join = st_within,
    left = TRUE
  )

# Assign restaurants to Census tracts
restaurants_tract <- restaurant_points %>%
  st_join(
    tract_boundaries %>%
      select(area = GEOID),
    join = st_within,
    left = TRUE
  )

# Summarize ZIP Code areas
zcta_summary <- restaurants_zcta %>%
  st_drop_geometry() %>%
  filter(!is.na(area)) %>%
  group_by(area) %>%
  summarise(
    restaurant_count = n(),
    average_rating = mean(stars, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(average_rating))

# Summarize Census tracts
tract_summary <- restaurants_tract %>%
  st_drop_geometry() %>%
  filter(!is.na(area)) %>%
  group_by(area) %>%
  summarise(
    restaurant_count = n(),
    average_rating = mean(stars, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(average_rating))

# Create the comparison table
geographic_comparison <- tibble(
  geographic_system = c(
    "ZIP/ZCTA",
    "Census tract"
  ),
  
  number_of_areas = c(
    n_distinct(restaurants_zcta$area, na.rm = TRUE),
    n_distinct(restaurants_tract$area, na.rm = TRUE)
  ),
  
  restaurants_assigned = c(
    sum(!is.na(restaurants_zcta$area)),
    sum(!is.na(restaurants_tract$area))
  ),
  
  unmatched_restaurants = c(
    sum(is.na(restaurants_zcta$area)),
    sum(is.na(restaurants_tract$area))
  ),
  
  smallest_area_count = c(
    min(zcta_summary$restaurant_count),
    min(tract_summary$restaurant_count)
  ),
  
  largest_area_count = c(
    max(zcta_summary$restaurant_count),
    max(tract_summary$restaurant_count)
  )
)

# Display the comparison table
geographic_comparison

# Display areas with very few restaurants
head(
  zcta_summary[order(zcta_summary$restaurant_count), ],
  10
)

head(
  tract_summary[order(tract_summary$restaurant_count), ],
  10
)

# Create the ZIP Code map
zcta_map <- ggplot() +
  geom_sf(
    data = zcta_boundaries,
    fill = NA,
    color = "grey60",
    linewidth = 0.3
  ) +
  geom_sf(
    data = restaurants_zcta %>%
      filter(!is.na(area)),
    aes(color = stars),
    alpha = 0.75,
    size = 1.5
  ) +
  scale_color_viridis_c(
    option = "C",
    limits = c(1, 5)
  ) +
  labs(
    title = "New Orleans Specialty Restaurants by ZIP Code Area",
    color = "Business\nstars"
  ) +
  coord_sf(
    xlim = c(-90.25, -89.75),
    ylim = c(29.85, 30.20),
    expand = FALSE
  ) +
  theme_minimal()

print(zcta_map)

# Create the Census tract map
tract_map <- ggplot() +
  geom_sf(
    data = tract_boundaries,
    fill = NA,
    color = "grey60",
    linewidth = 0.3
  ) +
  geom_sf(
    data = restaurants_tract %>%
      filter(!is.na(area)),
    aes(color = stars),
    alpha = 0.75,
    size = 1.5
  ) +
  scale_color_viridis_c(
    option = "C",
    limits = c(1, 5)
  ) +
  labs(
    title = "New Orleans Specialty Restaurants by Census Tract",
    color = "Business\nstars"
  ) +
  coord_sf(
    xlim = c(-90.25, -89.75),
    ylim = c(29.85, 30.20),
    expand = FALSE
  ) +
  theme_minimal()

print(tract_map)

# Save the comparison table
write.csv(
  geographic_comparison,
  "data/new_orleans/geographic_comparison.csv",
  row.names = FALSE
)

# Save the geographic summaries
saveRDS(
  zcta_summary,
  "data/new_orleans/zcta_summary.rds",
  compress = "xz"
)

saveRDS(
  tract_summary,
  "data/new_orleans/tract_summary.rds",
  compress = "xz"
)

# Save the spatially joined data
saveRDS(
  restaurants_zcta,
  "data/new_orleans/restaurants_zcta.rds",
  compress = "xz"
)

saveRDS(
  restaurants_tract,
  "data/new_orleans/restaurants_tract.rds",
  compress = "xz"
)

dir.create("figures", showWarnings = FALSE)

ggsave(
  "figures/zcta_map.png",
  plot = zcta_map,
  width = 8,
  height = 6,
  dpi = 300
)

ggsave(
  "figures/tract_map.png",
  plot = tract_map,
  width = 8,
  height = 6,
  dpi = 300
)

# Analyze selected restaurants by ZIP Code Tabulation Area

zcta_restaurants <- restaurant_points %>%
  st_join(
    zcta_boundaries %>%
      select(
        zcta = all_of(zcta_id_column)
      ),
    join = st_within,
    left = TRUE
  )

# Calculate restaurant statistics for each ZIP Code area
restaurants_by_zcta <- zcta_restaurants %>%
  st_drop_geometry() %>%
  filter(!is.na(zcta)) %>%
  group_by(zcta) %>%
  summarise(
    number_of_restaurants = n_distinct(business_id),
    average_business_stars = mean(stars, na.rm = TRUE),
    median_business_stars = median(stars, na.rm = TRUE),
    total_reviews = sum(review_count, na.rm = TRUE),
    average_reviews_per_restaurant = mean(review_count, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(average_business_stars))

# Display every ZIP Code area
print(restaurants_by_zcta, n = Inf)

# Display ZIP Code areas with at least 10 restaurants
reliable_zcta_areas <- restaurants_by_zcta %>%
  filter(number_of_restaurants >= 10) %>%
  arrange(
    desc(average_business_stars),
    desc(number_of_restaurants)
  )

print(reliable_zcta_areas, n = Inf)

# Save the table
write.csv(
  restaurants_by_zcta,
  "data/new_orleans/restaurants_by_zcta.csv",
  row.names = FALSE
)

write.csv(
  reliable_zcta_areas,
  "data/new_orleans/reliable_zcta_areas.csv",
  row.names = FALSE
)

# Create a table for the selected region

selected_region_table <- reliable_zcta_areas %>%
  filter(zcta == "70113")

selected_region_table

# Prepare ZIP Code boundaries for the map

zcta_map_boundaries <- zcta_boundaries %>%
  mutate(
    selected_area = as.character(.data[[zcta_id_column]]) == "70113"
  )

# Create the map highlighting ZIP Code 70113

zcta_70113_map <- ggplot() +
  
  # Draw all ZIP Code boundaries
  geom_sf(
    data = zcta_map_boundaries,
    aes(fill = selected_area),
    color = "grey45",
    linewidth = 0.4
  ) +
  
  # Highlight ZIP Code 70113 with a stronger outline
  geom_sf(
    data = zcta_map_boundaries %>%
      filter(selected_area),
    fill = "gold",
    color = "black",
    alpha = 0.35,
    linewidth = 1.2
  ) +
  
  # Draw the restaurant locations
  geom_sf(
    data = zcta_restaurants %>%
      filter(!is.na(zcta)),
    aes(color = stars),
    size = 2,
    alpha = 0.8
  ) +
  
  scale_fill_manual(
    values = c(
      "FALSE" = "grey92",
      "TRUE" = "gold"
    ),
    labels = c(
      "FALSE" = "Other ZIP Code areas",
      "TRUE" = "ZIP Code 70113"
    ),
    name = "Geographic area"
  ) +
  
  scale_color_viridis_c(
    option = "C",
    limits = c(1, 5),
    name = "Business\nstars"
  ) +
  
  coord_sf(
    xlim = c(-90.25, -89.75),
    ylim = c(29.85, 30.20),
    expand = FALSE
  ) +
  
  labs(
    title = "ZIP Code 70113: Highest-Rated Specialty Restaurant Area",
    subtitle = "16 selected restaurants; average rating = 4.19",
    caption = "Selected restaurants are shown by Yelp business rating."
  ) +
  
  theme_minimal() +
  
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "right"
  )

# Display the map
zcta_70113_map

# Save the map
ggsave(
  "figures/zip_70113_map.png",
  plot = zcta_70113_map,
  width = 8,
  height = 6,
  dpi = 300
)