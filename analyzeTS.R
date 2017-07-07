#-------------------------------------------------------------------------------
## load test chunks from the data directory. i.e.
# load("data/input.df-38447140")
#-------------------------------------------------------------------------------

# Analyze a time-series
#
# @param ts.df      A data.frame. Each row is an observation
# @return           A data.frame with one row and N columns made of atomic values
analyzeTS <- function(ts.df){
  json.dat <- jsonlite::read_json("data.json")                                  # read data as main.R sets up the working directory
  res.df <- data.frame(cid = ts.df$cid[1], rid = ts.df$rid[1], num_row = nrow(ts.df), num_col = ncol(ts.df), stuff = "I'm so cool", len_json = length(json.dat))
  return(res.df)
}
