#*******************************************************************************
# ANALYZE A TIME SERIES USING BFAST MONITOR
#-------------------------------------------------------------------------------
#---- NOTES: ----
# - It requires the packages zoo, bfast, and lubridate. They must be installed 
#   in each machine in the SciDB cluster. i.e. run:
#   Rscript installPackages.R packages=zoo,bfast,lubridate
#---- DEBUG: ----
#   source("bfastMonitor.R")
#   load("./data/ts.df-27271652")                 # Load a chunk of SciDB data (~40x40 time series)
#   crids <- unique(ts.df[c("cid", "rid")])       # List unique column-row of the time-series
# Random time series
#   crid <- crids[sample(1:nrow(crids), 1), ]     # Select a single time series
#   ts.df <- ts.df[ts.df$cid == crid$cid & ts.df$rid == crid$rid, ]
#   plot(y = ts.df$evi, x = ts.df$tid, type = "l")
#   analyzeTS(ts.df)
# All time series in the chunk
#   res <- parallel::mclapply(1:nrow(crids), mc.cores = parallel::detectCores(), FUN = function(x, crids, input.df){ts.df <- subset(input.df, cid == crids[x,]$cid & rid == crids[x,]$rid); return(analyzeTS(ts.df))}, crids  = crids, input.df = ts.df)
#   (res.df <- do.call(rbind, res))
#*******************************************************************************

# Analyze a time-series using the BFAST MONITOR method
#
# @param ts.df      A data.frame made of MOD13Q1 data. Each row is a pixel. The expected columnas are the pixel's column id, row_di, time_id, vegetation index, quality measure, and realibility measure named as folllows c("cid", "rid", "tid", "evi", "quality", "reliability")
# @return           A data.frame of two columns. The break as YYYYDOY date  and as a string
analyzeTS <- function(ts.df){
  #---- setup ----
  res <- data.frame(cid = ts.df$cid[1], rid = ts.df$rid[1], breakpoint = 0, 
                    breakpointStr = "", stringsAsFactors = F)
  #---- validation ----
  if(nrow(ts.df) == 0 || ncol(ts.df) == 0){
    return(res)
  }
  #---- configuration ----
  veg_index <- "evi"                                                            # name of the vegetation index colum
  period <- 16                                                                  # days in between observations. i.e. 16 days for MOD13Q1
  stable_years <- 7                                                             # number of years considered stable for the BFAST algorithm
  #---- remove low reliability data ----
  ts.df[ts.df$reliability == -1, veg_index] <- NA                               # fill, no data
  ts.df[ts.df$reliability == 2, veg_index] <- NA                                # snow, ice
  ts.df[ts.df$reliability == 3, veg_index] <- NA                                # clouds
  if(sum(is.na(ts.df[veg_index]))/nrow(ts.df) > 0.5){
    return(res)                                                                 # time-series of invalid data - too much NAs after filtering
  }
  #---- remove low quality data ----
  ts.df <- addTSqua(ts.df)
  ts.df[ts.df$VI_useful == "Lowest quality", veg_index] <- NA
  ts.df[ts.df$VI_useful == "L1B data faulty", veg_index] <- NA
  #---- expose time holes ----
  if(sum((seq_along(ts.df$tid) + (ts.df$tid[1] - 1)) - ts.df$tid) != 0){
    ntid.df <- data.frame(tid = seq(from = ts.df$tid[1], to = ts.df$tid[length(ts.df$tid)], by = 1))
    ts.df <- merge(ts.df, ntid.df, by = "tid", all = TRUE)
  }
  #---- fill in the time holes ----
  if(sum(is.na(ts.df[veg_index])) > 0){
    vi.zoo <- zoo::na.locf(zoo::zoo(as.matrix(ts.df[veg_index]), order.by = ts.df$tid))
    ts.df <- data.frame(tid = zoo::index(vi.zoo), zoo::coredata(vi.zoo))
  }
  #---- compute BFAST ----
  vi.ts <- ts(data = ts.df[, veg_index], 
              freq = 365.25/period, 
              start = lubridate::decimal_date(
                as.Date(
                  unlist(time_id2date(ts.df$tid[1], period)), 
                  origin = "1970-01-01"
                )
              )
  )
  
  #---- Manicore experiment ----
  # Parameters used by Msc Thesis "Automating Near Real-Time Deforestation 
  # Monitoring With Satellite Image Time  Series" by Christopher Stephan.
  # The start time of the monitoring end of July 2010, which corresponds to 
  # twelfth MODIS EVI image of year 2010 and thus is the closest date before the 
  # beginning of PRODES year 2011.
  # Parameter_name  Parameter_value     Description
  # start           c(2010, 12)         The starting time in period-cycle notation set to July 2010.
  # formula         response ∼ harmon   The formula for the regression model omitting the trend.
  # history         c(2006, 1)          The starting time of the stable history period set to January 2006.
  # type            MOSUM               type of the monitoring process.
  #
  #bf <-  bfast::bfastmonitor(data = vi.ts, start = c(2010, 12), 
  #                           formula = response ~ harmon, history = c(2006, 1), 
  #                           type = "OLS-MOSUM")
  
  #---- Default BFAST M parameters ----
  bf <-  bfast::bfastmonitor(data = vi.ts, 
                             start = time(vi.ts)[as.integer(365.25/period * stable_years)], 
                             history = "all")  
  #---- Build response ----
  if(!is.null(bf$breakpoint) && !is.na(bf$breakpoint) && is.numeric(bf$breakpoint)){
    #res$breakpoint <- bf$breakpoint
    res$breakpointStr <- format(lubridate::date_decimal(bf$breakpoint), format = "%Y-%m-%d")
    res$breakpoint <- scidbutil::date2ydoy(res$breakpointStr)
  }
  #---- return ----
  return(res)
}



# Add readable quality data to a MOD13Q1 time series according to its data quality
#
# @param x A data frame containing the column c("quality")
# @return A data frame with additional columns.
addTSqua <- function(x){
  # get the codes
  rqa <- invertString(R.utils::intToBin(x$quality)) # inverted binary quality
  x$MODLAND_QA <- invertString(substr(rqa, 1, 2))
  x$VI_useful <- invertString(substr(rqa, 2, 5))
  x$AerQuantity <- invertString(substr(rqa, 6, 7))
  x$AdjCloud <- invertString(substr(rqa, 8, 8))
  x$AtmBRDF <- invertString(substr(rqa, 9, 9))
  x$MixCloud <- invertString(substr(rqa, 10, 10))
  x$LandWater <- invertString(substr(rqa, 11, 13))
  x$snowice <- invertString(substr(rqa, 14, 14))
  x$shadow <-  invertString(substr(rqa, 15, 15))
  # convet codesz to factors
  x$MODLAND_QA <- as.factor(x$MODLAND_QA)
  levels(x$MODLAND_QA)[levels(x$MODLAND_QA)=="00"] <- "VI produced, good quality"
  levels(x$MODLAND_QA)[levels(x$MODLAND_QA)=="01"] <- "VI produced, but check other QA"
  levels(x$MODLAND_QA)[levels(x$MODLAND_QA)=="10"] <- "Pixel produced, but most probably cloudy"
  levels(x$MODLAND_QA)[levels(x$MODLAND_QA)=="11"] <- "Pixel not produced due to other reasons than clouds"
  x$VI_useful <- as.factor(x$VI_useful)
  levels(x$VI_useful)[levels(x$VI_useful)=="0000"] <- "Highest quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="0001"] <- "Lower quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="0010"] <- "Decreasing quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="0100"] <- "Decreasing quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="1000"] <- "Decreasing quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="1001"] <- "Decreasing quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="1010"] <- "Decreasing quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="1100"] <- "Lowest quality"
  levels(x$VI_useful)[levels(x$VI_useful)=="1101"] <- "Quality so low that it is not useful"
  levels(x$VI_useful)[levels(x$VI_useful)=="1110"] <- "L1B data faulty"
  levels(x$VI_useful)[levels(x$VI_useful)=="1111"] <- "Not useful for any other reason/not processed"
  x$AerQuantity <- as.factor(x$AerQuantity)
  levels(x$AerQuantity)[levels(x$AerQuantity)=="00"] <- "Climatology"
  levels(x$AerQuantity)[levels(x$AerQuantity)=="01"] <- "Low"
  levels(x$AerQuantity)[levels(x$AerQuantity)=="10"] <- "Average"
  levels(x$AerQuantity)[levels(x$AerQuantity)=="11"] <- "High"
  x$AdjCloud <- sapply(x$AdjCloud, tn2bool)
  x$AtmBRDF <- sapply(x$AtmBRDF, tn2bool)
  x$MixCloud <- sapply(x$MixCloud, tn2bool)
  x$LandWater <- as.factor(x$LandWater)
  levels(x$LandWater)[levels(x$LandWater)=="000"] <- "Shallow ocean"
  levels(x$LandWater)[levels(x$LandWater)=="001"] <- "Land (Nothing else but land)"
  levels(x$LandWater)[levels(x$LandWater)=="010"] <- "Ocean coastlines and lake shorelines"
  levels(x$LandWater)[levels(x$LandWater)=="011"] <- "Shallow inland water"
  levels(x$LandWater)[levels(x$LandWater)=="100"] <- "Ephemeral water"
  levels(x$LandWater)[levels(x$LandWater)=="101"] <- "Deep inland water"
  levels(x$LandWater)[levels(x$LandWater)=="110"] <- "Moderate or continental ocean"
  levels(x$LandWater)[levels(x$LandWater)=="111"] <- "Deep ocean"
  x$snowice <- sapply(x$snowice, tn2bool)
  x$shadow <- sapply(x$shadow, tn2bool)
  return(x)
}



# Invert strings
#
# @param x A vector made of strings
# @return Character. A vector where the characters of each string are inverted
invertString <- function(x){
  sapply(lapply(strsplit(x, NULL), rev), paste, collapse="")  
}



# Cast a boolean represented as string to Logical
#
# @param val  A boolean represented as either "0" or "1"
# @return     A logical
tn2bool <- function(val){ 
  if(val == "0") return(FALSE)
  if(val == "1") return(TRUE)
  return(NA)
}



# Transform a time_id into dates
#
# @param time_id.vector Vector of time indexes 
# @param period         Days between images (MOD09Q1 is 8, MOD13Q1 is 16)
# @return               A list of Date objects
time_id2date <- function(time_id.vector, period){
  ydoy <- sapply(time_id.vector, FUN = time_id2ydoy, period = period)
  res <- lapply(ydoy, FUN = ydoy2date)
  return(res)
}


# Transform a time_id into year-day_of_the_year
#
# @param time_id A time id
# @param freqperyear Number of time_ids a year
# @return A number
time_id2ydoy <- function(time_id, period){
  freqperyear <- round(365/period)
  YYYY <- as.integer(time_id / freqperyear) + 2000
  tid <- as.numeric(time_id)
  if(tid < freqperyear){
    DOY <- tid * period
  }else{
    DOY <- (tid)%%freqperyear * period
  }
  YYYY * 1000 + DOY + 1
}




# Transform a date in the year-day_of_the_year format to a date
#
# @param YYYYDOY Numeric or character with 4 digits for the year and 3 for the day of the year (i.e 2012324)
# @return A date object
ydoy2date <- function(YYYYDOY){
  #http://disc.gsfc.nasa.gov/julian_calendar.shtml
  res <- ""
  if(is.numeric(YYYYDOY)){
    year.vec <- YYYYDOY %/% 1000
    doy.vec <- YYYYDOY - (year.vec * 1000)
  }else if(is.character(YYYYDOY)){
    year.vec <- as.numeric(substr(YYYYDOY, 1, 4))
    doy.vec <- as.numeric(substr(YYYYDOY, 5, 7))
  }else{
    stop("Unexpected datatype")
  }
  if (!(doy.vec > 0 && doy.vec < 367)){
    stop("Invalid day-of-the-year interval")
  }
  charDates <- sapply(1:length(YYYYDOY), .ydoy2dateHelper, year.vec = year.vec, doy.vec = doy.vec)
  return (as.Date(charDates))
}
.ydoy2dateHelper <- function(i, year.vec, doy.vec){
  year <- year.vec[i]
  doy <- doy.vec[i]
  firstdayRegular <- c(1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366)
  firstdayLeap    <- c(1, 32, 61, 92, 122, 153, 183, 214, 245, 275, 306, 336, 367)
  if(isLeapYear(year)){
    firstday <- firstdayLeap
  }else{
    firstday <- firstdayRegular
  }
  for (i in 1:(length(firstday) - 1)){
    start <- firstday[i]
    end <- firstday[i + 1]
    if(doy >= start && doy < end){
      month <- i
      break
    }
  }
  day <- doy - firstday[month] + 1
  return(paste(year, month, day, sep = "/"))
}



# Is the given year is a leap year?
#
# @param year NUmeric year
# @return TRUE is the year is leap, FALSE otherwise
isLeapYear <- function(year){
  leapyear <- sapply(year, .isLeapYearHelper)
  return (leapyear)
}
.isLeapYearHelper <- function(year){
  leapyear <- FALSE
  if (year %% 4 != 0){
    leapyear <- FALSE
  }else if (year %% 100 != 0){
    leapyear <- TRUE
  }else if (year %% 400 == 0){
    leapyear <- TRUE
  }
}
