    # load function names for auto-completion
    # include ~/usr/vim/words/r.txt #

    # clean the environment
    rm(list=ls())

    # define number of levels and drawing smoothness
    no.levels <- 11
    smoothness.factor <- 200

    # definition functions

    get.shifts <- function (n, series) {
        # get vector of radius shifts for pseudoconcentric arrangement
        shift.init <- (max.factor * max.radius - max.radius)
        shift.abs <- shift.init / 2 ^ (1:(n * 2) - 1)
        shifts <- shift.init
        x <- n * 2
        quiet <- 
        sapply(2:x, function(i) {
            if (i %% 2 == 0) {
                shifts[i] <<- shifts[i - 1] - shift.abs[i - 1]
            } else if (i %% 2 == 1) {
                shifts[i] <<- shifts[i - 1] + shift.abs[i - 1]
            }
        })
        if (series == "upper") {
            elems <- seq(1, x, by=2)
        } else if (series == "lower") {
            elems <- seq(2, x, by=2)
        }
        shifts[elems]
    }

    get.sizes <- function(n, series) {
        # get vector of max radii for pseudoconcentric arrangement
        x <- n * 2
        sizes <-  max.factor * 0.5^(0:x)
        if (series == "upper") {
            elems <- seq(1, x, by=2)
        } else if (series == "lower") {
            elems <- seq(2, x, by=2)
        }
        sizes[elems]
    }

    phi.to.power.of <- function(n) { #
        # return nth element of continuous Fibonacci function
        phi <- 2 / (sqrt(5) - 1)
        return(phi^n - phi)
    }

    fib <- function(n) {
        # return nth of Fibonacci series
        if (n < 2) {
            return(n)
        } else {
            return(fib(n - 1) + fib(n - 2))
        }
    }

    theta.cell.to.col <- function(cell, col) {
        # create vector of theta values from each forking node of a tine
        fork.cell <- 
            ((cell - 1) / smoothness.factor) - (((cell - 1) / smoothness.factor) %% 1) + 1
        fork.test <- 
            forks[, col][fork.cell]
        theta.slice <- thetas[, col][cell:len] 
        stop <- length(theta.slice)
        if (!is.na(fork.test) && fork.test == "r" && stop > 1) {
            theta.temp[cell:len] <- theta.slice + theta.rad[1:stop]  
            return(theta.temp)
        } else if (!is.na(fork.test) && fork.test == "l" && stop > 1) {
            theta.temp[cell:len] <- theta.slice - theta.rad[1:stop]  
            return(theta.temp)
        }
    }

    fork.cell.to.col <- function(fork.cell, col) {
        fork <- forks[, col][fork.cell]
        fork.slice <- forks[, col][fork.cell:no.intervals] 
        stop <- length(fork.slice)
        if (!is.na(fork) && fork == "r" && stop > 1) {
            fork.temp[fork.cell:no.intervals] <- c("n", rep(c("n", "l"), ((stop - 1) / 2) + 1))[1:stop]
            return(fork.temp)
        } else if (!is.na(fork) && fork == "l" && stop > 1) {
            fork.temp[fork.cell:no.intervals] <- c("n", rep("r", stop - 1))
            return(fork.temp)
        }
    }

    theta.col.to.df <- function(col) {
        cells <- 
            (1:no.intervals * smoothness.factor) - smoothness.factor + 1
        new.cols <- 
            lapply(cells, theta.cell.to.col, col)
        not.null <- 
            which(!sapply(new.cols, is.null))
        new.cols <- sapply(not.null, function(x) new.cols[[x]])
        if (length(new.cols) > 0) thetas <<- cbind(thetas, new.cols)
    }

    fork.col.to.df <- function(col) {
        fork.cells <- 1:no.intervals
        new.cols <- lapply(fork.cells, fork.cell.to.col, col)
        not.null <- which(!sapply(new.cols, is.null))
        new.cols <- sapply(not.null, function(x) new.cols[[x]])
        if (length(new.cols) > 0) forks <<- cbind(forks, new.cols)
    }
    #
    no.intervals <- no.levels - 1
    max.radius <- no.intervals
    max.circumfrence <- 2 * pi * max.radius
    smoothness <- ((max.radius - 1) * smoothness.factor) + 1
    len <- smoothness
    radius <- seq(1, max.radius, length=smoothness)
    theta.raw <- phi.to.power.of(radius)
    theta.proportional <- theta.raw / max(theta.raw)
    theta.rad <- 2 * pi * theta.proportional
    theta <- -((2 * pi * theta.proportional) / 2) - (pi / 2)
    theta.temp <- rep(NA, len)
    thetas <- data.frame(radius, theta)
    fork <- rep("r", no.intervals)
    fork.temp <- rep(NA, no.intervals)
    forks <- data.frame(radius=(1:no.intervals), fork)

    iters <- fib(no.levels) + 1
    quiet <- 
    lapply(2:iters, function(x) {
        lapply(x, theta.col.to.df)
        lapply(x, fork.col.to.df)
    })


    # create graphics
    # plot size 
    height.up <- 2
    height.down <- 1
    width.left <- 1
    width.right <- 1

    png("ninninin.png", 
        height=max.radius * 3 * 100,
        width=max.radius * 2 * 100,
        bg=NA, 
        res=300) 
    par(mar=c(0, 0, 0, 0))
    # 
    plot(c(-max.radius * width.left, max.radius * width.right), 
        c(-max.radius * height.down, max.radius * height.up), 
        type="n", bty="n", xaxt="n", 
        yaxt="n", xlab="", ylab="")

    # layers
    n <- 5
    max.factor <- 2
    # layer outer function
    sizes <-  get.sizes(n, "upper")
    shifts <- get.shifts(n, "upper")
    lapply(1:length(sizes), function(i) {
            size <- sizes[i]
            # shift.y <- max.radius / (2^(i - 1))
            shift.y <- shifts[i]
    # layer
    # line attributes
    color <- "#000000"
    size <- size
    # in radians:
    orientation <- pi
    shift.x <- 0
    shift.y <- shift.y

    # points attributes
    point.bg <- "#222222"
    point.color <- "#333333"
    flip <- -1
    # 0 cancels, 1 preserves
    bottom.cancel <- 1

    # draw 
    quiet <- 
    lapply(2:ncol(thetas), function (col) {
        radius <- thetas[, 1] * size
        theta <- thetas[, col] + orientation
        lines(x=(radius * cos(theta) + shift.x), 
            y=(radius * sin(theta) + shift.y), 
            col=color, lwd=3)
    })

    # outer circle
    theta.outer <- seq(0, 2 * pi, length=smoothness) 
    lines(x=max.radius * cos(theta.outer) * size + shift.x, 
        y=max.radius * sin(theta.outer) * size + shift.y,
        col=color, lwd=3)

    # inner line
    lines(x=c(0, 0) + shift.x, 
        y=c(0, -flip) * size + shift.y,
        col=color, lwd=3)

    # points
    # center point
    # points(x=shift.x, y=shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # top point
    # points(x=shift.x, y=(max.radius * size) + shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # bottom point
    # points(x=shift.x * bottom.cancel, y=(-(max.radius * size) + shift.y) * bottom.cancel,
    #        pch=21, col=point.color, bg=point.bg)


    })

    # layer outer function
    sizes <-  get.sizes(n, "upper")
    shifts <- get.shifts(n, "upper")
    lapply(1:length(sizes), function(i) {
            size <- sizes[i]
            # shift.y <- max.radius / (2^(i - 1))
            shift.y <- shifts[i]
    # layer
    # line attributes
    color <- "#cccccc"
    size <- size
    # in radians:
    orientation <- pi
    shift.x <- 0
    shift.y <- shift.y

    # points attributes
    point.bg <- "#222222"
    point.color <- "#333333"
    flip <- -1
    # 0 cancels, 1 preserves
    bottom.cancel <- 1

    # draw 
    quiet <- 
    lapply(2:ncol(thetas), function (col) {
        radius <- thetas[, 1] * size
        theta <- thetas[, col] + orientation
        lines(x=(radius * cos(theta) + shift.x), 
            y=(radius * sin(theta) + shift.y), 
            col=color, lwd=2)
    })

    # outer circle
    theta.outer <- seq(0, 2 * pi, length=smoothness) 
    lines(x=max.radius * cos(theta.outer) * size + shift.x, 
        y=max.radius * sin(theta.outer) * size + shift.y,
        col=color, lwd=2)

    # inner line
    lines(x=c(0, 0) + shift.x, 
        y=c(0, -flip) * size + shift.y,
        col=color, lwd=2)

    # points
    # center point
    # points(x=shift.x, y=shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # top point
    # points(x=shift.x, y=(max.radius * size) + shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # bottom point
    # points(x=shift.x * bottom.cancel, y=(-(max.radius * size) + shift.y) * bottom.cancel,
    #        pch=21, col=point.color, bg=point.bg)


    })

    # layer outer function
    sizes <-  get.sizes(n, "lower")
    shifts <- get.shifts(n, "lower")
    lapply(1:length(sizes), function(i) {
            size <- sizes[i]
            # shift.y <- max.radius / (2^(i - 1))
            shift.y <- shifts[i]
    # layer
    # line attributes
    color <- "#000000"
    size <- size
    # in radians:
    orientation <- 0
    shift.x <- 0
    shift.y <- shift.y

    # points attributes
    point.bg <- "#222222"
    point.color <- "#666666"
    flip <- 1
    # 0 cancels, 1 preserves
    bottom.cancel <- 1

    # draw 
    quiet <- 
    lapply(2:ncol(thetas), function (col) {
        radius <- thetas[, 1] * size
        theta <- thetas[, col] + orientation
        lines(x=(radius * cos(theta) + shift.x), 
            y=(radius * sin(theta) + shift.y), 
            col=color, lwd=3)
    })

    # outer circle
    theta.outer <- seq(0, 2 * pi, length=smoothness) 
    lines(x=max.radius * cos(theta.outer) * size + shift.x, 
        y=max.radius * sin(theta.outer) * size + shift.y,
        col=color, lwd=3)

    # inner line
    lines(x=c(0, 0) + shift.x, 
        y=c(0, -flip) * size + shift.y,
        col=color, lwd=3)

    # points
    # center point
    # points(x=shift.x, y=shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # top point
    # points(x=shift.x, y=(max.radius * size) + shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # bottom point
    # points(x=shift.x * bottom.cancel, y=(-(max.radius * size) + shift.y) * bottom.cancel,
    #        pch=21, col=point.color, bg=point.bg)


    })

    # layer outer function
    sizes <-  get.sizes(n, "lower")
    shifts <- get.shifts(n, "lower")
    lapply(1:length(sizes), function(i) {
            size <- sizes[i]
            # shift.y <- max.radius / (2^(i - 1))
            shift.y <- shifts[i]
    # layer
    # line attributes
    color <- "#999999"
    size <- size
    # in radians:
    orientation <- 0
    shift.x <- 0
    shift.y <- shift.y

    # points attributes
    point.bg <- "#222222"
    point.color <- "#999999"
    flip <- 1
    # 0 cancels, 1 preserves
    bottom.cancel <- 1

    # draw 
    quiet <- 
    lapply(2:ncol(thetas), function (col) {
        radius <- thetas[, 1] * size
        theta <- thetas[, col] + orientation
        lines(x=(radius * cos(theta) + shift.x), 
            y=(radius * sin(theta) + shift.y), 
            col=color, lwd=1)
    })

    # outer circle
    theta.outer <- seq(0, 2 * pi, length=smoothness) 
    lines(x=max.radius * cos(theta.outer) * size + shift.x, 
        y=max.radius * sin(theta.outer) * size + shift.y,
        col=color, lwd=1)

    # inner line
    lines(x=c(0, 0) + shift.x, 
        y=c(0, -flip) * size + shift.y,
        col=color, lwd=1)

    # points
    # center point
    # points(x=shift.x, y=shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # top point
    # points(x=shift.x, y=(max.radius * size) + shift.y,
    #        pch=21, col=point.color, bg=point.bg)
    # bottom point
    # points(x=shift.x * bottom.cancel, y=(-(max.radius * size) + shift.y) * bottom.cancel,
    #        pch=21, col=point.color, bg=point.bg)


    })

    dev.off()
    
