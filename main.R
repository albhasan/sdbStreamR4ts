################################################################################
# GET THE SCIDB CHUNKS PROVIDED BY SCIDB STREAMING
#-------------------------------------------------------------------------------
# NOTES: 
#
# example 
# Rscript main.R script_folder=/home/scidb/shared/query201706051451-5586 script_name=analyzeTS.R
#
# example SciDB stream query:
# iquery -aq "
# store(
#   stream(
#     cast(
#       project(
#         apply(
#           between(mod13q1_512, 62400, 43200, 0, 62500, 43300, 367), 
#          cid, col_id, rid, row_id, tid, time_id
#         ), 
#         cid, rid, tid, evi, quality, reliability
#       ), 
#      <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]
#     ), 
#     'Rscript main.R script_folder=/home/scidb/shared/query201706051451-5586 script_name=analyzeTS.R', 
#    'format=df', 'types=int32,int32,string'
#  ),
#  query201706051451-5586
# )"
#-------------------------------------------------------------------------------
# TODO:
# - how does one load packages?
#-------------------------------------------------------------------------------
# FAQ:
# - What is WTSPS? Web Time Series Processing Service
#
# - How do users load data files (i.e json)? This script sets the working 
#     directory to the users' WTSPS request folder. That way, the users' script 
#     load data just using the name of the file 
#     json.dat <- jsonlite::read_json("data.json")
################################################################################
#-------------------------------------------------------------------------------
# paramteres
#-------------------------------------------------------------------------------
script_folder <- NA
script_name <- NA
#-------------------------------------------------------------------------------
# get script parameters from command line
#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------
# get SciDB's chunk as data.frame
#-------------------------------------------------------------------------------
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
  #
  input.df = as.data.frame(input_list)
  #-----------------------------------------------------------------------------
  # save chunks as Rdata with randomized names
  #-----------------------------------------------------------------------------
  #save(input.df, file = file.path(script_folder, paste("input.df", sample(10000000:99000000, 1, replace = TRUE), sep = "-"), fsep = .Platform$file.sep))
  #-----------------------------------------------------------------------------
  # local test 
  # NOTE: comment before running the real deal
  #-----------------------------------------------------------------------------
  script_name <- "bfast_example2.R"                                             
  script_folder <- "/home/alber/Documents/Dropbox/alberLocal/inpe/projects/sdb_bfast"
  load(file.path(script_folder, "data/input.df-27271652", fsep = .Platform$file.sep))
  num_cores = getOption("mc.cores", 2L)                                         # use all the cores
  #write(jsonlite::toJSON(data.frame(x = rnorm(10), y = rnorm(10), z = rnorm(10))), file = "data.json")
  #-----------------------------------------------------------------------------
  # configuration
  #-----------------------------------------------------------------------------
  # 32 cores per machine
  # 7 SciDB instances per machine
  # leave at least one core free for the OS
  num_cores = 32 - 7 - 1 # num_cores = getOption("mc.cores", 2L)
  setwd(script_folder)
  #-----------------------------------------------------------------------------
  # load the user's code
  #-----------------------------------------------------------------------------
  #for(f in list.files(path = script_folder, pattern = "\\.R$")){source(file.path(script_folder, f, fsep = .Platform$file.sep))} # load ALL the script files
  source(file.path(script_folder, script_name, fsep = .Platform$file.sep))
  if(!("analyzeTS" %in% ls())){
    stop("The function analyzeTS() was not found!")
  }
  #-----------------------------------------------------------------------------
  # call the script on each time-series of the chunk
  #-----------------------------------------------------------------------------
  crid.df <- unique(input.df[c("cid", "rid")])                                  # get unique pairs of col & rows
  res_script <- parallel::mclapply(1:nrow(crid.df), 
                                   mc.cores = num_cores, 
                                   FUN = function(x, crid.df, input.df){
                                     ts.df <- subset(input.df, cid == crid.df[x,]$cid & rid == crid.df[x,]$rid)
                                     return(analyzeTS(ts.df))                                                    # call the script
                                   },
                                   crid.df  = crid.df, 
                                   input.df = input.df
  )
  #-----------------------------------------------------------------------------
  # transpose res_script
  #-----------------------------------------------------------------------------
  num_col <- length(res_script[[1]])
  num_row <- length(res_script)
  res_list <- lapply(1: num_col, FUN = function(x, res_script){
    return(unlist(lapply(res_script, FUN = function(y, x){return(y[[x]])}, x = x)))
  }, 
  res_script = res_script
  )
  names(res_list) <- names(res_script[[1]])
  #-----------------------------------------------------------------------------
  # cast to stream supported datatypes
  #-----------------------------------------------------------------------------
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
  #-----------------------------------------------------------------------------
  # return top SciDB
  #-----------------------------------------------------------------------------
  writeBin(serialize(res_list, NULL, xdr=FALSE), con_out)
  flush(con_out)
}
close(con_in)
