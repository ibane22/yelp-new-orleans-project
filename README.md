# yelp-new-orleans-project

## Selected geographic region

I selected ZIP Code 70113 as the main geographic region because it had the highest average Yelp rating among ZIP Code areas containing at least 10 selected restaurants. ZIP Code 70113 contained 16 Cajun/Creole, seafood, or soul food restaurants, with an average business rating of 4.19 stars and a median rating of 4 stars.

The CSV table shows the comparison of all ZIP Code areas with at least 10 selected restaurants. ZIP Code 70113 ranked first by average business rating. Requiring at least 10 restaurants makes the comparison more reliable than choosing a ZIP Code based on only one or two businesses.

The complete comparison table is available here:

[zcta_restaurant_comparison.csv](data/new_orleans/zcta_restaurant_comparison.csv)

![Map highlighting ZIP Code 70113](figures/zip_70113_map.png)

## Step 6: Geographic comparison

### Selected geographic system

I selected ZIP Code Tabulation Areas (ZCTAs) as the main geographic system and compared them with Census tracts.

I selected ZCTAs because all 607 selected restaurants were assigned to a ZCTA, while 13 restaurants were unmatched using Census tracts. ZCTAs also produced fewer and larger areas, making them easier to understand and visualize. Census tracts provided more detail, but their smaller boundaries created a more complicated map and included areas with very few restaurants.

### Geographic comparison table

| Geographic system | Number of areas | Restaurants assigned | Unmatched restaurants | Smallest area count | Largest area count |
|---|---:|---:|---:|---:|---:|
| ZIP/ZCTA | 22 | 607 | 0 | 1 | 194 |
| Census tract | 108 | 594 | 13 | 1 | 102 |

### ZIP Code map

![New Orleans specialty restaurants by ZIP Code area](figures/zcta_map.png)

### Census tract map

![New Orleans specialty restaurants by Census tract](figures/tract_map.png)