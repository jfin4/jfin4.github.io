:::{.title-block}
# Using ChatGPT to Answer the Questions Given During a Technical Job Interview

January 1, 2023
:::

Me:

> Please read the data at 
> [https://johninman.dev/chatgpt/beneficial-uses.csv](https://johninman.dev/chatgpt/beneficial-uses.csv). 
> Call this data BenUses. BenUses includes a column of waterbodies called
> Waterbody and a column of beneficial uses called BeneficialUse.
> 
> Please read the data at 
> [https://johninman.dev/chatgpt/monitoring-stations.csv](https://johninman.dev/chatgpt/monitoring-stations.csv). 
> Call this data MonStats. MonStats includes a column of waterbodies called
> Waterbody and a column of monitoring stations called StationCode.
> 
> Please read the data at 
> [https://johninman.dev/chatgpt/water-quality.csv](https://johninman.dev/chatgpt/water-quality.csv). 
> Call this data WatQual. WatQual includes a column of analytes called
> AnalyteName, a column of monitoring stations called StationCode, and a
> column of concentrations called Result.
> 
> Using this data, please generate an R script that answers the following
> questions:
>
> 1. What is the mean concentration of the analyte chromium at monitoring
>    station 105SH1452?
> 2. Create a table that summarizes count and mean, median, maximum, and
>    minimum concentration of each analyte in WatQual.
> 3. How many monitoring stations have the beneficial use CO?
> 4. How many monitoring stations do not have any beneficial use?
> 5. Create a table that summarizes the mean concentration of each analyte at
>    each waterbody that has data and the beneficial use MA.

ChatGPT:

> Sure! Here is the R script that answers the questions:
>
>     # Load the necessary packages
>
>     library(tidyverse)
>     
>     # Load the data
>     BenUses <- read.csv("https://johninman.dev/chatgpt/beneficial-uses.csv")
>     MonStats <- read.csv("https://johninman.dev/chatgpt/monitoring-stations.csv")
>     WatQual <- read.csv("https://johninman.dev/chatgpt/water-quality.csv")
>     
>     # Question 1: What is the mean concentration of the analyte chromium at monitoring station 105SH1452?
>     mean_chromium <- WatQual %>%
>       filter(StationCode == "105SH1452", AnalyteName == "Chromium") %>%
>       summarise(mean_concentration = mean(Result)) %>%
>       pull(mean_concentration)
>     cat("The mean concentration of chromium at monitoring station 105SH1452 is", mean_chromium, "\n")
>     
>     # Question 2: Create a table that summarizes count and mean, median, maximum, and minimum concentration of each analyte in WatQual.
>     WatQual_summary <- WatQual %>%
>       group_by(AnalyteName) %>%
>       summarize(count = n(), mean_concentration = mean(Result), median_concentration = median(Result), max_concentration = max(Result), min_concentration = min(Result))
>     print(WatQual_summary)
>     
>     # Question 3: How many monitoring stations have the beneficial use CO?
>     n_CO <- MonStats %>%
>       inner_join(BenUses, by = "Waterbody") %>%
>       filter(BeneficialUse == "CO") %>%
>       distinct(StationCode) %>%
>       nrow()
>     cat("There are", n_CO, "monitoring stations with the beneficial use CO.\n")
>     
>     # Question 4: How many monitoring stations do not have any beneficial use?
>     n_no_use <- MonStats %>%
>       left_join(BenUses, by = "Waterbody") %>%
>       filter(is.na(BeneficialUse)) %>%
>       distinct(StationCode) %>%
>       nrow()
>     cat("There are", n_no_use, "monitoring stations with no beneficial use.\n")
>     
>     # Question 5: Create a table that summarizes the mean concentration of each analyte at each waterbody that has data and the beneficial use MA.
>     mean_table <- WatQual %>%
>       inner_join(MonStats, by = "StationCode") %>%
>       inner_join(BenUses, by = "Waterbody") %>%
>       filter(BeneficialUse == "MA") %>%
>       group_by(Waterbody, AnalyteName) %>%
>       summarize(mean_concentration = mean(Result)) %>%
>       pivot_wider(names_from = AnalyteName, values_from = mean_concentration)
>     print(mean_table)
>
> I hope this helps! Let me know if you have any questions.

Me:

> Please generate an equivalent script in python.

ChatGPT:

> Sure! Here is the equivalent Python script that answers the same questions:
>
>     # Load the necessary packages
>     import pandas as pd
>     
>     # Load the data
>     BenUses = pd.read_csv("https://johninman.dev/chatgpt/beneficial-uses.csv")
>     MonStats = pd.read_csv("https://johninman.dev/chatgpt/monitoring-stations.csv")
>     WatQual = pd.read_csv("https://johninman.dev/chatgpt/water-quality.csv")
>     
>     # Question 1: What is the mean concentration of the analyte chromium at monitoring station 105SH1452?
>     mean_chromium = WatQual.loc[(WatQual["StationCode"] == "105SH1452") & (WatQual["AnalyteName"] == "Chromium"), "Result"].mean()
>     print(f"The mean concentration of chromium at monitoring station 105SH1452 is {mean_chromium}")
>     
>     # Question 2: Create a table that summarizes count and mean, median, maximum, and minimum concentration of each analyte in WatQual.
>     WatQual_summary = WatQual.groupby("AnalyteName").agg(count=("Result", "count"),
>                                                          mean_concentration=("Result", "mean"),
>                                                          median_concentration=("Result", "median"),
>                                                          max_concentration=("Result", "max"),
>                                                          min_concentration=("Result", "min"))
>     print(WatQual_summary)
>     
>     # Question 3: How many monitoring stations have the beneficial use CO?
>     n_CO = MonStats.merge(BenUses, on="Waterbody").query('BeneficialUse == "CO"').loc[:, "StationCode"].nunique()
>     print(f"There are {n_CO} monitoring stations with the beneficial use CO.")
>     
>     # Question 4: How many monitoring stations do not have any beneficial use?
>     n_no_use = MonStats.merge(BenUses, on="Waterbody", how="left").query('BeneficialUse.isna()')['StationCode'].nunique()
>     print(f"There are {n_no_use} monitoring stations with no beneficial use.")
>     
>     # Question 5: Create a table that summarizes the mean concentration of each analyte at each waterbody that has data and the beneficial use MA.
>     mean_table = WatQual.merge(MonStats, on="StationCode").merge(BenUses, on="Waterbody").query('BeneficialUse == "MA"') \
>                       .groupby(["Waterbody", "AnalyteName"])["Result"].mean().unstack()
>     print(mean_table)
>
> I hope this helps! Let me know if you have any questions.

