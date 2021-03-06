#*******************************************************************************
# DETECT DEFORESTATION USING THE KALMAN FILTER AND TIME SERIES OF VEGETATION INDEXES
#---- NOTES: ----
# - The KF code was adapted from https://youtu.be/PZrFFg5_Sd0?list=PLX2gX-ftPVXU3oUFNATxGXY90AULiqnWT
#---- DEBUG: ----
#   load("./data/ts.df-27271652")                 # Load a chunk of SciDB data (~40x40 time series)
#   crids <- unique(ts.df[c("cid", "rid")])       # List unique column-row of the time-series
#   crid <- crids[sample(1:nrow(crids), 1), ]     # Select a single time series
#   ts.df <- ts.df[ts.df$cid == crid$cid & ts.df$rid == crid$rid, ]
#   source("kalmanFilter.R")
#   plot(y = ts.df$evi, x = ts.df$tid, type = "l")
#   analyzeTS(ts.df)


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

# Analyze a time-series using the KALMAN FILTER
#
# @param ts.df      A data.frame made of MOD13Q1 data. Each row is a pixel. The expected columnas are the pixel's column id, row_di, time_id, vegetation index, quality measure, and realibility measure named as folllows c("cid", "rid", "tid", "evi", "quality", "reliability")
# @return           A data.frame of two columns. The break as double (breakpoint) and as a string (dpStr)
analyzeTS <- function(ts.df){
  #---- setup ----
  res <- data.frame(cid = ts.df$cid[1], rid = ts.df$rid[1], breakpoint = 0, 
                    breakpointStr = "", stringsAsFactors = F)
  #---- validation ----
  if(nrow(ts.df) == 0 || ncol(ts.df) == 0){
    return(res)
  }
  #---- configuration ----
  sds <- 3                                                                      # number of standard deviations above and under the mean                                
  veg_index <- "evi"                                                            # name of the vegetation index colum
  period <- 16                                                                  # days in between observations. i.e. 16 days for MOD13Q1
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
  #if(sum(is.na(ts.df[veg_index])) > 0){
  #  vi.zoo <- zoo::na.locf(zoo::zoo(as.matrix(ts.df[veg_index]), order.by = ts.df$tid))
  #  ts.df <- data.frame(tid = zoo::index(vi.zoo), zoo::coredata(vi.zoo))
  #}
  #---- filter ----
  kf <- kalmanfilter(measurement = ts.df[[veg_index]],
                     error_in_measurement = NULL,
                     initial_estimate = NULL,
                     initial_error_in_estimate = NULL)
  #---- KF - VEG_INDEX differences ----
  dif <- kf[["estimation"]] - ts.df[veg_index]
  dif[is.na(dif)] <- 0
  dif <- cbind(dif, cumsum(dif))
  colnames(dif) <- c('kf-mea', 'cumsum')
  #---- cumsum of KF - VEG_INDEX
  csdf <- matrix(data = NA, ncol = 6, nrow = 0)
  for(i in 1:nrow(dif['cumsum'])){
    d <- dif['cumsum'][c(1:i),]
    difmn <- mean(d)
    difmd <- median(d)
    difsd <- sd(d)
    difmad <- mad(d)
    difmax <- max(d)
    difmin <- min(d)
    csdf <- rbind(csdf, c(difmn, difmd, difsd, difmad, difmax, difmin))
  }
  csdf <- as.data.frame(csdf)
  colnames(csdf) <- c("mean", "median", "sd", "mad", "max", "min")
  #---- control limits ----
  controlmn <- data.frame(csdf$mean, csdf$mean + (csdf$sd * sds), csdf$mean - (csdf$sd * sds), dif['cumsum'])
  colnames(controlmn) <- c("mean", paste(sds, "sdup", sep=""), paste(sds, "sddown", sep=""), "cumsum")
  rownames(controlmn) <- unlist(lapply(time_id2date(ts.df$time_id, 16), as.character))
  #---- observation is out of control ----
  controlmn$outofcontrol <- controlmn['cumsum'] > controlmn[paste(sds, "sdup", sep="")] | controlmn['cumsum'] < controlmn[paste(sds, "sddown", sep="")]
  controlmn$outofcontrol[1, ] <- FALSE
  if(sum(controlmn$outofcontrol) > 0){
    tidDeforestation <- ts.df[controlmn$outofcontrol, "tid"][1]
    #TODO: WRONG CASTING?????????????????????????????????????????????????????????????????????
    res$breakpoint <- as.double(time_id2ydoy(time_id = tidDeforestation, period = period))
    res$breakpointStr <- ydoy2date(res$breakpoint)
  }
  #---- res ----
  return(res)
}




# Compute the Kalman filter
#
# @param measurement                    A vector of measurements
# @param error_in_measurement           A vector of errors in the measuments
# @param initial_estimate               A first estimation of the measurement
# @param initial_error_in_estimate      A first error in the estimation
# @return                               A matrix of 3 columns estimate, error_in_estimate, and kalman_gain
kalmanfilter <- function(measurement,
                         error_in_measurement = NULL,
                         initial_estimate = NULL,
                         initial_error_in_estimate = NULL){
  kg <- vector(mode = "logical", length = length(measurement) + 1)
  est <- vector(mode = "logical", length = length(measurement) + 1)
  e_est <- vector(mode = "logical", length = length(measurement) + 1)
  #
  # default values
  if(is.null(initial_estimate) || is.na(initial_estimate)){
    initial_estimate <- base::mean(measurement, na.rm = TRUE)
  }
  if(is.null(initial_error_in_estimate) || is.na(initial_error_in_estimate)){
    initial_error_in_estimate <- base::abs(stats::sd(measurement, na.rm = TRUE))
  }
  if(is.null(error_in_measurement)){
    error_in_measurement <- rep(stats::sd(measurement, na.rm = TRUE), length.out = base::length(measurement))
  }
  #
  # Compute the Kalman gain
  #
  # @param e_est  A numeric. The error in the estimate
  # @param e_mea  A numeric. The error in the measurement
  # @return       A numeric. The Kalman gain
  .KG <- function(e_est, e_mea){
    return(e_est/(e_est + e_mea))
  }
  #
  # Compute the current estimate
  #
  # @param kg     A numeric. The Kalman gain
  # @param est_t1 A numeric. The estimate at t-1
  # @param mea    A numeric. The current measurement
  # @return       A numeric. The current estimate
  .EST_t <- function(kg, est_t1, mea){
    est_t1 + kg * (mea - est_t1)
  }
  #
  # Compute the error in the current estimate
  #
  # @param kg       A numeric. The Kalman gain
  # @param e_est_t1 A numeric. The error in the estimate at t-1
  # @return         A numeric. The error in the current estimate
  .E_EST_t <- function(kg, e_est_t1){
    (1 - kg) * e_est_t1
  }
  #
  # add initial results
  est[1] <- initial_estimate[1]
  e_est[1] <- initial_error_in_estimate[1]
  kg[1] <- NA
  # compute
  for(i in 2:(length(measurement) + 1)){
    kg[i] <- .KG(e_est[i - 1], error_in_measurement[i - 1])
    m <- measurement[i - 1]
    if(is.na(m)){
      m <- est[i - 1]                                                           # if the measurement is missing, use the estimation instead
    }
    est[i] <- .EST_t(kg[i], est[i - 1], m)
    e_est[i] <- .E_EST_t(kg[i], e_est[i - 1])
  }
  # format the results: remove the row before the first measurement (t-1)
  return(
    list(
      estimation = est[2:length(est)],
      error_in_estimate = e_est[2:length(e_est)],
      kalman_gain = kg[2:length(kg)]
    )
  )
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
  return(charDates)# return(as.Date(charDates))
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
