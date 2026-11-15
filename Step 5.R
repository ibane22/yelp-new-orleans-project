# Step 5: Add official geographic boundaries

library(sf)
library(tigris)
library(ggplot2)
library(dplyr)

# Save downloaded Census files for future use
options(tigris_use_cache = TRUE)

# Load only the selected restaurants marked as open
new_orleans_restaurants <- readRDS(
  "data/new_orleans/selected_restaurants.rds"
)

# Confirm the number of restaurants
nrow(new_orleans_restaurants)

# Download official Louisiana city boundaries
louisiana_places <- tigris::places(
  state = "LA",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# Convert restaurants into geographic points
restaurant_points <- new_orleans_restaurants %>%
  filter(
    !is.na(longitude),
    !is.na(latitude)
  ) %>%
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

# Make boundary CRS match restaurant CRS
louisiana_places <- louisiana_places %>%
  st_transform(st_crs(restaurant_points))

# Assign restaurants to official place boundaries
restaurants_with_place <- restaurant_points %>%
  st_join(
    louisiana_places %>%
      select(
        GEOID,
        place_name = NAME
      ),
    join = st_within,
    left = TRUE
  )

# Compare Yelp city labels with Census place names
city_comparison <- restaurants_with_place %>%
  st_drop_geometry() %>%
  count(city, place_name, sort = TRUE)

city_comparison

# Keep the official New Orleans boundary
new_orleans_boundary <- louisiana_places %>%
  filter(NAME == "New Orleans")

# Keep restaurants assigned to New Orleans
new_orleans_map_data <- restaurants_with_place %>%
  filter(place_name == "New Orleans")

# Download roads and streets for Orleans Parish
orleans_roads <- tigris::roads(
  state = "LA",
  county = "Orleans",
  year = 2024,
  class = "sf"
)

# Download rivers and streams
orleans_rivers <- tigris::linear_water(
  state = "LA",
  county = "Orleans",
  year = 2024,
  class = "sf"
)

# Download larger water areas
orleans_water <- tigris::area_water(
  state = "LA",
  county = "Orleans",
  year = 2024,
  class = "sf"
)

# Match all map layers to the restaurant CRS
orleans_roads <- orleans_roads %>%
  st_transform(st_crs(restaurant_points))

orleans_rivers <- orleans_rivers %>%
  st_transform(st_crs(restaurant_points))

orleans_water <- orleans_water %>%
  st_transform(st_crs(restaurant_points))

# Create the map
open_restaurants_map <- ggplot() +
  
  # Official New Orleans boundary
  geom_sf(
    data = new_orleans_boundary,
    fill = "grey95",
    color = "grey35"
  ) +
  
  # Larger water areas
  geom_sf(
    data = orleans_water,
    fill = "lightblue",
    color = NA,
    alpha = 0.6
  ) +
  
  # Rivers and streams
  geom_sf(
    data = orleans_rivers,
    color = "steelblue",
    linewidth = 0.5,
    alpha = 0.8
  ) +
  
  # Streets and roads
  geom_sf(
    data = orleans_roads,
    color = "grey60",
    linewidth = 0.15,
    alpha = 0.5
  ) +
  
  # Open restaurant locations
  geom_sf(
    data = new_orleans_map_data,
    aes(color = stars),
    alpha = 0.75,
    size = 1.5
  ) +
  
  scale_color_viridis_c(
    option = "C",
    limits = c(1, 5),
    name = "Business\nstars"
  ) +
  
  labs(
    title = "Open Specialty Restaurants in New Orleans",
    subtitle = "Cajun/Creole, seafood, and soul food restaurants",
    caption = "Only restaurants marked open in the Yelp data are shown."
  ) +
  
  theme_minimal()

# Display the map
open_restaurants_map

# Save the map
dir.create("figures", showWarnings = FALSE)

ggsave(
  "figures/open_restaurants_map.png",
  plot = open_restaurants_map,
  width = 8,
  height = 6,
  dpi = 300
)

# Save the spatially joined data
saveRDS(
  restaurants_with_place,
  "data/new_orleans/restaurants_with_place.rds",
  compress = "xz"
)