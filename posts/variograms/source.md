Draft: About Variograms
==============================================================================

2025-05-22

i have generated data to simulate canopy cover of a shrub with these constraints:
    simulated pen is 10 x 10 m
    mean shrub width is 1.5 m
    shrub width sd is 0.125 m
    center of shrubs cannot be overlapped by neighboring shrubs
    cumulative canopy cover of pen (not accounting for canoyp overlap) is about 50%

i have simulated point-intersect plant transect data based on simulated shrub data with these constraints:
    points occur along a transect every 0.25 meters
    points can have a value of presence or absence
    if points intercept a simulated canopy, its a precense
    if points don't intercept a simulated canopy, its an absence

based on these constraints, is it possible to calculate the expected range/sill of a variogram based on the simulated transect data?
