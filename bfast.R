################################################################################
# BFAST
# bfast.R
################################################################################
#------------------------------------------------------------
# preliminars
#------------------------------------------------------------
# tunnel to esensing2
# ssh -L 8080:150.163.2.206:8080 ssh.dpi.inpe.br

library(scidb)
library(sp)
library(ggplot2)

source("/home/alber/Documents/ghProjects/scidbutil/scidbUtil.R")
setwd("/home/alber/Documents/Dropbox/alberLocal/inpe/projects/sdb_bfast")

#------------------------------------------------------------
# paramaters
#------------------------------------------------------------
veg_index <- "ndvi"
veg_index <- "evi"
latitude <- -14.919100049
longitude <- -59.11781088
period <- 16 # days in between observations
#------------------------------------------------------------
# get col_id & row_id from lon & lat
#------------------------------------------------------------
crid <- .wgs84gmpi(cbind(longitude, latitude), .calcPixelSize(4800, .calcTileWidth()))
crid <- as.vector(crid)
#------------------------------------------------------------
# get data from SciDB
#------------------------------------------------------------
# con <- scidbconnect(host = "127.0.0.1", port = 8080)
# afl <- paste("between(mod13q1_512,", paste(c(crid, 0, crid, 400), collapse = ","), ")", sep = '')
# vi.sdb <- iquery(con, afl, return = TRUE, binary = FALSE)
# save(vi.sdb, file = "vi.Rdata")
load("vi.Rdata")
#------------------------------------------------------------
# export TS to data frame
#------------------------------------------------------------
vi.df <- vi.sdb[c(veg_index, "reliability", "quality", "time_id")]
# vi.df["timeIndex"] <- (1:nrow(vi.df) + 2)                                     # adjustment if first observations is at time_index == 0
#------------------------------------------------------------
# plot original data by realibility
#------------------------------------------------------------
plot(vi.df$evi, type = "l")
#------------------------------------------------------------
# expose holes in the time_id
#------------------------------------------------------------
if(sum((seq_along(vi.df$time_id) + (vi.df$time_id[1] - 1)) - vi.df$time_id)){
  ntid.df <- data.frame(time_id = seq(from = vi.df$time_id[1], to = vi.df$time_id[length(vi.df$time_id)], by = 1))
  vi.df <- merge(vi.df, ntid.df, by = "time_id", all = TRUE)
}
#------------------------------------------------------------
# filter
#------------------------------------------------------------
#
#------------------------------------------------------------
# fill in the NAs
# NOTE: time_id MUST BE the first column
#------------------------------------------------------------
vi.zoo <- zoo::na.locf(zoo::zoo(as.matrix(vi.df[-1]), order.by = vi.df$time_id)) # fill in the NAs
vi.df <- data.frame(time_id = zoo::index(vi.zoo), zoo::coredata(vi.zoo))
#------------------------------------------------------------
# BFAST THE WHOLE TS AT ONCE
#------------------------------------------------------------
vi.ts <- ts(data = vi.df[, veg_index], 
            freq = 365.25/period, 
            start = lubridate::decimal_date(as.Date(unlist(.time_id2date(vi.df$time_id[1], period))))
)
stable_years <- 7
# bf <-  bfast::bfastmonitor(vi.ts, start = time(vi.ts)[as.integer(365.25/period * stable_years)], history = time(vi.ts)[1])
bf <-  bfast::bfastmonitor(vi.ts, start = time(vi.ts)[as.integer(365.25/period * stable_years)], history = "all")
plot(bf)
print(bf$breakpoint)
# TODO: Where do I get the start & history parameters?

