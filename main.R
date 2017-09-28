################################################################################
# GET THE SCIDB CHUNKS PROVIDED BY SCIDB STREAMING
#-------------------------------------------------------------------------------
# NOTES: 
# - Use full paths when calling R scripts
# - It doesn't matter if the R scripts' directory is shared among all the 
#   machines in the SciDB cluster
# - The working directory of the main.R script is the same of the script_name.
#   This way, the user provided script can read data and scripts 
# - R packages must be installed in all machines in the SciDB cluster before 
#   calling the main script
#-------------------------------------------------------------------------------
# DEBUG: 
# - The expression write("A debug message", stderr()) writes to SciDB' error log
#   i.e /home/scidb/data/0/0/scidb-stderr.log
#-------------------------------------------------------------------------------
# USAGE:
# - The amount and length of time series is controled by the BETWEEN clause
#
## EXAMPLE 1: A SciDB query returns the properties of a single time series
# iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62400, 43200, 15), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=analyzeTS.R', 'format=df', 'types=int32,int32,int32,int32,int32')"
## Response
# {instance_id,chunk_no,value_no} a0,a1,a2,a3,a4,a5
# {0,0,0} 62400,43200,7,6,1,10
#
## EXAMPLE 2: A SciDB query returns the properties of 9 time series, (col_id, row_id, time_id)
##            from (62400, 43200, 0) to (62402, 43202, 15) 
# iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62402, 43202, 15), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=analyzeTS.R', 'format=df', 'types=int32,int32,int32,int32,int32')"
#
## EXAMPLE 3:  Same as example 2 but it redimension the answer to a 2D array
# iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62402, 43202, 15), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=analyzeTS.R', 'format=df', 'types=int32,int32,int32,int32,int32', 'names=col_id,row_id,nrow,ncol,lenjson'), <nrow:int32, ncol:int32, lenjson:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40])"
#
## EXAMPLE 4:  Same as example 2 but it redimension the answer to a 3D array. Note that, the query results do NOT have a temporal index
# iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62402, 43202, 15), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=analyzeTS.R', 'format=df', 'types=int32,int32,int32,int32,int32', 'names=col_id,row_id,nrow,ncol,lenjson'), <nrow:int32, ncol:int32, lenjson:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512])"
#
## EXAMPLE 5: A SciDB query runs BFAST MONITOR on 100 time series
# iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62409, 43209, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=bfastMonitor.R', 'format=df', 'types=int32,int32,double,string')"
#
## EXAMPLE 6: Same as example 5, but it redimensions the query response to a 2D array
# iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62409, 43209, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=bfastMonitor.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40])"
#
## EXAMPLE 7: Same as example 5, but it redimensions the query response to a 3D array. Note that, the query results do NOT have a temporal index
# iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62409, 43209, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=bfastMonitor.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512])"
################################################################################

#---- get parameters from command line ----
script_folder <- NA
script_name <- NA
argsep <- "="                                                                 # separator between the argument name and its value during invocation i.e. arg=value
keys <- vector(mode = "character", length = 0)
values <- vector(mode = "character", length = 0)
for (arg in commandArgs()){
  if(agrep(argsep, arg) == TRUE){
    pair <- unlist(strsplit(arg, argsep))
    keys <- append(keys, pair[1], after = length(pair))
    values <- append(values, pair[2], after = length(pair))
  }
}   
script_folder <- unlist(strsplit(values[which(keys == "script_folder")], ","))  # path to the folder with all the required files to run the script. It MUST BE SHARED with all the SciDB instances
script_name <- unlist(strsplit(values[which(keys == "script_name")], ","))      # name of the script to run
if(is.na(script_folder) || is.na(script_name)){
  stop("Invalid parameters!")
}
#---- sdb chunk 2 data.frame ----
con_in = file("stdin", "rb")
con_out = pipe("cat", "wb")
while( TRUE )
{
  input_list = unserialize(con_in)
  colnum = length(input_list)
  if(colnum == 0) #this is the last message
  {
    res = list()
    writeBin(serialize(res, NULL, xdr=FALSE), con_out)
    flush(con_out)
    break
  }
  input.df = as.data.frame(input_list, stringsAsFactors = F)
  #---- configuration ----
  # Each machine in the cluster has 32 cores and 7 SciDB instances
  # Leave at least one core free for the OS
  num_cores = 32 - 7 - 1 # num_cores <- parallel::detectCores()
  setwd(script_folder)
  #---- load the analysis function ----
  source(file.path(script_folder, script_name, fsep = .Platform$file.sep))
  if(!("analyzeTS" %in% ls())){
    stop("The function analyzeTS() was not found!")
  }
  #---- call the script on each time-series in the chunk ----
  crid.df <- unique(input.df[c("cid", "rid")])
  res_script <- parallel::mclapply(1:nrow(crid.df), 
                                   mc.cores = num_cores, 
                                   FUN = function(x, crid.df, input.df){
                                     ts.df <- subset(input.df, cid == crid.df[x,]$cid & rid == crid.df[x,]$rid)
                                     return(analyzeTS(ts.df))                                                    # call the script
                                   },
                                   crid.df  = crid.df, 
                                   input.df = input.df
  )
  #---- transpose response ----
  num_col <- length(res_script[[1]])
  num_row <- length(res_script)
  res_list <- lapply(1: num_col, FUN = function(x, res_script){
    return(unlist(lapply(res_script, FUN = function(y, x){return(y[[x]])}, x = x)))
  }, 
  res_script = res_script
  )
  names(res_list) <- names(res_script[[1]])
  #---- cast to stream supported datatypes ----
  res_list <- lapply(res_list, FUN = function(x){
    if(typeof(x) == "integer" || typeof(x) == "logical"){
      x <- as.integer(x)
    }else if(typeof(x) == "double"){
      x <- as.double(x)
    }else if(typeof(x) == "character" || typeof(x) == "complex"){
      x <- as.character(x)
    }else{
      stop("Unsupported data type")
    }
    return(x)
  })
  #---- return to SciDB ----
  writeBin(serialize(res_list, NULL, xdr=FALSE), con_out)
  flush(con_out)
}
close(con_in)
