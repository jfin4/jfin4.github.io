# set up
library("tidyverse")
library("fs")
library("readxl")
library("writexl")
library("gstat")
library("sp")
library("ggforce")
library("magrittr")

# generate data
# ------------------------------------------------------------------------------

# 95% of plants between 1 and 2 meters
# total cover is ~ 40%

make_circle <- function(max, mean, sd) {
    tibble(x = runif(n = 1, max = max),
           y = runif(n = 1, max = max),
           r = rnorm(n = 1, mean = mean, sd = sd))
}

check_for_overlap <- function(x, y, r, data) {
    distance <- sqrt((x - data$x)^2 + (y - data$y)^2)
    # or(r > distance, 
    #    data$r > distance)  %>%
    (r + data$r > distance)  %>%
    any()
}

calculate_cover <- function(data, dim) {
        area <- data$r^2 * pi
        sum(area) / (dim^2)
}

make_plants <- function(plot_dim, plant_width, target_cover) {
    plants <- make_circle(plot_dim, plant_width / 2, plant_width / 12)
    percent_cover <- 0
    while (percent_cover < target_cover) {
        plant <- make_circle(plot_dim, plant_width / 2, plant_width / 12)
        has_overlap <- check_for_overlap(plant$x, plant$y, plant$r, plants)
        if (!has_overlap) {
            plants <- bind_rows(plants, plant)
        }
        percent_cover <- calculate_cover(plants, plot_dim)
    }
    return(plants)
}

make_points <- function(points_interval, plot_dim, plants) {
    tibble(x = seq(from = points_interval, 
                    to = plot_dim, 
                    by = points_interval),
            y = plot_dim / 2) %>% 
    mutate(r = 0,
            has_overlap = pmap_lgl(list(x, y, r), function(x, y, r) {
                                        check_for_overlap(x, y, r, plants)
                    }),
            result = factor(if_else(has_overlap, "Present", "Absent"),
                            levels = c("Present", "Absent"))) # legend order
}

get_semivariance <- function(data, lag) {
    # γ(h) = ½ × E[(Z(x) - Z(x+h))²]
    data %>% 
    mutate(value_lag = lag(has_overlap, n = lag),
           variance = (value_lag - has_overlap)^2) %>%
    filter(!is.na(value_lag)) %>%
    pull(variance) %>% 
    mean() * 0.5
}

make_variogram <- function(lags) {
    plants <- make_plants(plot_dim, plant_width, target_cover)
    points <- make_points(points_interval, plot_dim, plants)
    tibble(lag = lags,
            dist = points$x[lags],
            semivariance = map_dbl(lags, function(x) get_semivariance(points, x)))
}

# make plants
set.seed(0112358)
plot_dim <- 10
plant_width <- 1.5
target_cover <- 0.5
plants <- make_plants(plot_dim, plant_width, target_cover)

# make points
points_interval <- 0.25
points <- make_points(points_interval, plot_dim, plants)

# Calculate for multiple lags
lags <- 1:20
n <- 1e2
variogram <- 
    map(1:n, function(x) make_variogram(lags)) %>%
    reduce(`+`) %>%
    mutate(across(everything(), function(x) x / n))
# Plot manual variogram
ggplot(variogram, aes(dist, semivariance)) +
  geom_point() +
  geom_line() +
  labs(title = "Empirical Variogram")

# plot plot
plant_alpha <- 0.2
plant_color <- "#006600"
point_color <- "#990000"
point_size <- 2
image_size <- 1594
text_size <- 13
font <- "Calibri"
plot <- ggplot() +
    geom_circle(data = plants,
                aes(x0 = x, y0 = y, r = r),
                fill = plant_color,
                alpha = plant_alpha,
                color = NA ) + # border color
    geom_point(data = points,
               aes(x = x, y = y, fill = result), # Map fill to status
               shape = 21, # Shape 21 allows fill and border color
               color = point_color, # Set border color directly
               size = point_size) +
    scale_fill_manual(name = NULL, # No legend title
                      values = c("Present" = point_color, 
                                 "Absent" = "white"),
                      drop = FALSE) + # absent levels are shown 
    coord_fixed(ratio = 1, 
                xlim = c(0, plot_dim), 
                ylim = c(0, plot_dim), 
                expand = FALSE) + # clips circles
    scale_x_continuous(breaks = c(0, plot_dim),
                       labels = c("0", paste0(plot_dim, " m"))) +
    # theme_void(base_size = text_size) +
    theme_void() +
    theme(
          plot.margin = margin(t = 0, r = 0, b = 0, l = text_size / 2),  # tweak as needed
          panel.border = element_rect(color = "black", linewidth = 1),
          axis.text.x = element_text(size = text_size, family = font),
          legend.text = element_text(size = text_size, family = font),
    )
ggsave('_public/pen.svg', width = image_size, height = image_size, units = "px")


# gstat
# ------------------------------------------------------------------------------
# Convert to spatial object
points_sp <- points
coordinates(points_sp) <- ~x + y
# Calculate empirical variogram
v <- variogram(has_overlap ~ 1, points_sp)
ggplot(v, aes(dist, gamma)) +
  geom_point() +
  geom_line() +
  labs(title = "Empirical Variogram")

  # # Convert to raster and calculate total coverage
# library(raster)

# # Create a fine-resolution raster grid
# grid_res <- 0.1  # 10cm resolution
# r <- raster(extent(0, 10, 0, 10), res = grid_res)

# # For each shrub, create a circular raster
# shrub_rasters <- list()
# for(i in 1:nrow(shrub_data)) {
  # # Create points around shrub perimeter
  # center_x <- shrub_data$x[i]
  # center_y <- shrub_data$y[i]
  # radius <- shrub_data$width[i] / 2

  # # Rasterize shrub as circle
  # shrub_rasters[[i]] <- rasterize(circle_polygon, r, field = 1)
# }

# # Combine all shrubs (overlaps automatically handled)
# total_canopy <- Reduce(`+`, shrub_rasters)
# total_canopy[total_canopy > 0] <- 1  # Convert to binary

# # Calculate actual area
# actual_area <- sum(values(total_canopy), na.rm = TRUE) * (grid_res^2)
# coverage_percent <- actual_area / 100  # For 10x10m pen

library(sf)

# Convert shrubs to circular polygons
shrub_circles <- list()
for(i in 1:nrow(shrub_data)) {
  center <- st_point(c(shrub_data$x[i], shrub_data$y[i]))
  radius <- shrub_data$width[i] / 2
  shrub_circles[[i]] <- st_buffer(center, radius)
}

# Union all polygons (automatically handles overlaps)
all_shrubs <- do.call(c, shrub_circles)
union_polygon <- st_union(all_shrubs)

# Calculate actual area
actual_area <- st_area(union_polygon)

# make and plot circles
# ------------------------------------------------------------------------------
library(sf)
library(ggplot2)

# > plants
# # A tibble: 29 × 3
#        x     y     r
#    <dbl> <dbl> <dbl>
#  1 5.68   7.22 0.737
#  2 3.60   7.16 0.696
#  3 5.57   5.47 0.888
#  4 4.15   2.96 0.787
#  5 9.90   2.03 0.668
#  6 6.12   3.65 0.724
#  7 0.563  3.88 0.605
#  8 0.185  9.87 0.329
#  9 8.65   7.79 0.833
# 10 2.23   5.69 0.613
# # ℹ 19 more rows
# # ℹ Use `print(n = ...)` to see more rows
# Create circles as sf objects
shrub_circles <- lapply(1:nrow(plants), function(i) {
  center <- st_point(c(plants$x[i], plants$y[i]))
  st_buffer(st_sfc(center), plants$r[i])
})
# Combine into single sf object
all_circles <- do.call(c, shrub_circles)
circles_sf <- st_sf(geometry = all_circles, shrub_id = 1:length(all_circles))
# > circles_sf <- st_sf(geometry = all_circles, shrub_id = 1:length(all_circles))
# Error in st_sf(geometry = all_circles, shrub_id = 1:length(all_circles)) :
#   no simple features geometry column present

# Union all polygons (automatically handles overlaps)
union_polygon <- st_union(all_circles)

# Calculate actual area
actual_area <- st_area(union_polygon)

# Plot
ggplot(circles_sf) +
  geom_sf(fill = "lightgreen", color = "darkgreen", alpha = 0.7) +
  theme_minimal()
