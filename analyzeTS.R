#-------------------------------------------------------------------------------
# load a chunk # iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62400, 43200, 367), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/rs_test07.R', 'format=df', 'types=int32,int32,string')"
# load("data/input.df-38447140")
# load("data/input.df-27271652")
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