################################################################################
# ANALYZE A TIME SERIES
#-------------------------------------------------------------------------------
# NOTES: 
# - This script is meant to be call by main.R, hence it has the same workspace. 
#   This can be used to load resources such as data and other scripts
# - It must process one single time series of data
# - It must implement the function analyzeTS
#-------------------------------------------------------------------------------
# DEBUG: 
# - Sample data is provided in the binary files in the data directory. These 
#   sample data are chunks extracted from SciDB and they correspond to the format 
#   STREAM sends them to R. For example load("data/input.df-38447140")
# - The expression write("A debug message", stderr()) writes to SciDB' error log
#   i.e /home/scidb/data/0/0/scidb-stderr.log
################################################################################

# Analyze a time-series
#
# @param ts.df      A data.frame. Each row is an observation
# @return           A data.frame with one row and N columns made of atomic values
analyzeTS <- function(ts.df){
  dmess <- paste(Sys.time(), " analyzeTS() got a data frame of", nrow(ts.df), 
                 "observations of the variables",  
                 paste(colnames(ts.df), collapse = ", "))
  write(dmess, stderr())                                                        # write the working directory to /home/scidb/data/0/0/scidb-stderr.log
  json.dat <- jsonlite::read_json("data.json")                                  # read data as main.R sets up the working directory
  # Build a response data.frame with the column, the row, the number of rows and 
  # columns and the length of the json file
  res.df <- data.frame(cid = ts.df$cid[1], 
                       rid = ts.df$rid[1], 
                       num_row = nrow(ts.df), 
                       num_col = ncol(ts.df), 
                       len_json = length(json.dat))
  return(res.df)
}
