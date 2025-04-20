# Load required libraries
library(ggplot2)
library(dplyr)

# Set seed for reproducibility
set.seed(123)

# Create 15 random circles with normally distributed radii between 0.5 and 1.5
n_circles <- 15
circle_centers <- data.frame(
  x = runif(n_circles, 0, 10),
  y = runif(n_circles, 0, 10)
)
circle_centers$radius <- rnorm(n_circles, mean = 1, sd = 0.25) |> 
  pmax(0.5) |> 
  pmin(1.5)

# Create 40 points for horizontal bisection
points_data <- data.frame(
  x = seq(0.25, 10, length.out = 40),
  y = rep(5, 40)  # Horizontal line at y = 5
)

# Function to check if a point is inside any circle
is_point_in_any_circle <- function(px, py, circles) {
  for (i in 1:nrow(circles)) {
    distance <- sqrt((px - circles$x[i])^2 + (py - circles$y[i])^2)
    if (distance <= circles$radius[i]) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Determine if each point is inside any circle
points_data$in_circle <- sapply(1:nrow(points_data), function(i) {
  is_point_in_any_circle(points_data$x[i], points_data$y[i], circle_centers)
})

# Create a dataframe for drawing the circles
# Each circle is approximated by 100 points
circle_data <- do.call(rbind, lapply(1:n_circles, function(i) {
  theta <- seq(0, 2 * pi, length.out = 100)
  data.frame(
    x = circle_centers$x[i] + circle_centers$radius[i] * cos(theta),
    y = circle_centers$y[i] + circle_centers$radius[i] * sin(theta),
    circle_id = i
  )
}))

# Create the plot
p <- ggplot() +
  # Add circles
  geom_polygon(data = circle_data, 
               aes(x = x, y = y, group = circle_id), 
               fill = "darkgreen", 
               alpha = 0.3,
               color = NA) +
  # Add points
  geom_point(data = points_data, 
             aes(x = x, y = y, fill = in_circle, shape = in_circle), 
             size = 3, 
             color = "red") +
  # Set plot limits and remove grid, title, etc.
  scale_x_continuous(limits = c(0, 10), breaks = c(0, 10), labels = c("0", "10m")) +
  scale_y_continuous(limits = c(0, 10), breaks = NULL) +
  scale_fill_manual(values = c("white", "darkgreen"), 
                   labels = c("absence", "presence"),
                   name = NULL) +
  scale_shape_manual(values = c(21, 21), 
                    labels = c("absence", "presence"),
                    name = NULL) +
  # Set theme
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.title = element_blank(),
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.5),
    legend.position = "right",
    legend.box.margin = margin(0, 0, 0, 10),
    legend.title = element_blank(),
    aspect.ratio = 1  # Square plot area
  )

# Print the plot
print(p)

