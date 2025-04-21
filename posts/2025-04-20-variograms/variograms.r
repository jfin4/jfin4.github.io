# set up
# ------------------------------------------------------------------------------
library(tidyverse)
library(ggforce)

set.seed(123)

n_circles <- 15
n_points <- 40
plot_dim <- 10
point_y <- plot_dim / 2
point_x_start <- 0.25
point_x_end <- plot_dim
radius_mean <- 1.0
radius_sd <- 0.25
circle_color <- "#009900"
circle_alpha <- 0.5
hit_color <- "#ff0000"
miss_color <- "white"
point_border_color <- hit_color
point_size <- 1.5

# make data
# ------------------------------------------------------------------------------
circles <- tibble(id = 1:n_circles,
                      x = runif(n_circles, 0, plot_dim),
                      y = runif(n_circles, 0, plot_dim),
                      radius = rnorm(n_circles, 
                                     mean = radius_mean, 
                                     sd = radius_sd))

points <- tibble(x = seq(point_x_start, point_x_end, length.out = n_points),
                     y = rep(point_y, n_points)
)

# check intersections
is_hit <- function(px, py, circles) {
    dist_sq <- (px - circles$x)^2 + (py - circles$y)^2
    any(dist_sq <= circles$radius^2)
}

points <- 
    points %>%
    mutate(is_hit = map2_lgl(x, y, \(x, y) is_hit(x, y, circles)),
           status = factor(if_else(is_hit, "Presence", "Absence"),
                           levels = c("Presence", "Absence"))) # legend order

# plot
# ------------------------------------------------------------------------------
ggplot() +
    geom_circle(data = circles,
                aes(x0 = x, y0 = y, r = radius),
                fill = circle_color,
                alpha = circle_alpha,
                color = NA ) + # border color
    geom_point(data = points,
               aes(x = x, y = y, fill = status), # Map fill to status
               shape = 21, # Shape 21 allows fill and border color
               color = point_border_color, # Set border color directly
               size = point_size) +
    scale_fill_manual(name = NULL, # No legend title
                      values = c("Presence" = hit_color, 
                                 "Absence" = miss_color),
                      drop = FALSE) + # absent levels are shown 
    coord_fixed(ratio = 1, 
                xlim = c(0, plot_dim), 
                ylim = c(0, plot_dim), 
                expand = FALSE) + # clips circles
    scale_x_continuous(breaks = c(0, plot_dim),
                        labels = c("0", paste0(plot_dim, " m"))) +
    scale_y_continuous(breaks = NULL) + # No y-axis labels
    theme_minimal() +
    theme(panel.border = element_rect(colour = "black", 
                                      fill = NA, 
                                      linewidth = 0.5),
          panel.grid = element_blank(), # No grid lines
          axis.title = element_blank(), # No axis titles
          axis.text.y = element_blank(), # No y-axis text
          axis.ticks = element_blank(), # No tick marks
          axis.line = element_blank()) # No axis lines

ggsave('plot.png')
