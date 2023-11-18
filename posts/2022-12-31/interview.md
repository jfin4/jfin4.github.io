:::{.title-block}
# Version Control With Git

December 31, 2022
:::

## Life Without Version Control

The lone developer can get by without dedicated version control software. When
it comes time to change code, fix a bug, or add a feature they can simply
make a copy of the project directory, append the date to the directory name of
the old version, and blaze ahead, admiring the ever-lengthening stack of
directories as the residue of productivity.

This approach becomes problematic in a team setting. How can Developer B be
sure they are not steamrolling recent changes made by Developer A? How can
Developers A and B work simultaneously in the same files without bumping into
one another? How can they efficiently inform their supervisor of the changes
they have made?

## Version Control is for Teams

Version control software allows teams to develop code harmoniously and
efficiently. It tracks changes to the codebase as they are made. If a bug is
inadvertently introduced then the code can be rolled back. Changelogs can be
quickly generated for supervisor review. Remote repositories uploaded to the
cloud allow users to always have access to the most recent changes.  Finally,
branching allows developers to work concurrently in the same codebase, and to
test experimental features before merging them back into the main branch.

One of the most popular version control systems used today is git, which
tracks changes in a special database called a repository. Though humble in
name, its virtues are many: it is free and open source, it is widely used and
well documented, it is distributed rather than centralized, it tracks changes
to text rather than making copies changed files so its repositories are
lightweight, and it supports concurrent development through branching. It
integrates with many development environments (RStudio, VSCode, etc.) and is
supported by many websites that will host your repositories for free (Github,
Gitlab, Bitbucket, etc.). All this in exchange for a moderately steep learning
curve.

## Git Demonstration using ReLEPTON

Let us examine git in action. Here I will demonstrate a typical git workflow
in which a stable codebase is given a new feature. We do not want to go
fiddling with the codebase willy-nilly so we will create a new branch for
development and testing before merging the changes back into the main branch
in a three step process. A screencast of these steps can be found
[here](images/screencast.gif).

### Step 0: Current Codebase

[ReLEPTON (ReLEP subaTOmic kNock-off)](https://github.com/jfinmaniv/relepton)
is a fake water quality analysis tool that processes a curated subset of CEDEN
data into a table of temperature exceedances for the lower Salinas River. The
codebase resides in the main branch of a git repository. Here is the entire
codebase:

```
data_import <- read.csv("./data.csv") 
data <- within(data_import, date <- as.Date(date))
criteria <- 21 # C°

# Make LOEs table
loes_total <- as.data.frame(table(data$Monitoring_Site))
names(loes_total) <-  c("Monitoring_Site", "Total")
loes_exceedances <- aggregate(Temperature_C ~ Monitoring_Site, 
                              data = data, 
                              FUN = \(x) sum(x >= criteria))
names(loes_exceedances) <- c("Monitoring_Site", "Exceedances")
loes <- merge(loes_exceedances, loes_total)
# write.csv(loes, "loes.csv")

print(loes)
#>    Monitoring_Site Exceedances Total
#> 1     309-SALIN-32           0     5
#> 2     309-SALIN-33           0     5
#> 3           309BLA          27   173
#> 4           309DAV          61   277
#> 5        309PS0370           0     1
#> 6           309SAC          56   180
#> 7           309SAG          38   117
#> 8        309SAL00L           0     1
#> 9        309SAL00U           0     1
#> 10       309SALDDM           1     1
#> 11       309SALUBD           1     1
#> 12          309SBR           9    56
#> 13          309SDD           9    38
#> 14          309SSP          48   164
```

In addition to this elegant and useful table, Water Board staff would like
ReLEPTON to generate some sort of trend analysis output, preferably with
colors.

### Step 1: Create Development Branch

A development branch can be created with `git checkout -b trend-analysis` and
the code can be amended as shown below: 

```{.r #hl}
library(tidyverse)

data_import <- read.csv("./data.csv") 
data <- within(data_import, Date <- as.Date(Date))
names(data) <- c("Monitoring_Site", "Date", "Temperature_C")
criteria <- 21 # C°

# Make LOEs table
loes_total <- as.data.frame(table(data$Monitoring_Site))
names(loes_total) <-  c("Monitoring_Site", "Total")
loes_exceedances <- aggregate(Temperature_C ~ Monitoring_Site, 
                              data = data, 
                              FUN = \(x) sum(x >= criteria))
names(loes_exceedances) <- c("Monitoring_Site", "Exceedances")
loes <- merge(loes_exceedances, loes_total)
# write.csv(loes, "loes.csv")

# Make trends analysis graph
graph <- 
    ggplot(data, aes(x = Date, 
                     y = Temperature_C, 
                     color = Monitoring_Site)) +
    geom_point() +
    geom_smooth(method = "glm", se = FALSE) +
    ggtitle("Temperature of Lower Salinas River", 
            subtitle = "2000–2021") +
    theme(text = element_text(size = 16))
# png("graph.png", width = 640)
# graph
# dev.off()
```

This additional code will generate a nice, some would say stunning, plot
showing temperature trends in the Lower Salinas River over the past 21 years
(Figure 1). Once you have made your changes you can "commit" them with `git
commit -a -m "Added trend analysis feature"`. Commits are the changes that git
tracks and each commit requires a message describing the changes. More
detailed messages are, of course, more useful.

![Figure 1. Temperature in the Lower Salinas River, 2000--2020. Data are
grouped by monitoring station. What's up with 309SDD?](images/graph.png)

### Step 2: Test the Code

My original intention for this article was to talk about automated testing, or
unit testing, but I don't know as much about it. I think it is important,
though, and would like to learn more. In any case, new code should be
thoroughly tested before being merged back into the main branch.

### Step 3: Merge Main and Development Branches

Once you are confident that the added feature is, in fact, a feature (and not
a bug) you can merge the development branch back into the main branch with
`git checkout main; git merge trend-analysis`. If you have a remote repository
hosted somewhere like Github then you can push these changes to it with `git
push`. These changes can then be accessed by any internet-connected person
with `git pull` or, in this case, `git clone
'https://github.com/jfinmaniv/relepton'`.

## Summary

Advantages of using git:

- Allows teams to work on the same code at the same time
- Tracks changes so code can be reverted if necessary
- Allows for easy distribution of code
- Simplifies summarizing changes for code review
- Transferable, widely used skill

Disadvantages of using git:

- Non-negligible learning curve
