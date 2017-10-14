#!/bin/bash
################################################################################
# DEFORESTATION DETECTION USING THE KALMAN FILTER AND BFAST MONITOR
#-------------------------------------------------------------------------------
# NOTES:
# - ran using SciDB 16.9 & stream on SciDB cluster e-sensing2
# - the tested areas are in Manicore in Brasil
# - the areas were tested previously by Chrostopher Stephan in his Msc thesis
# #-------------------------------------------------------------------------------
# SciDB 16.9
################################################################################

# PRODES 2016 data loaded matches this extent
#     col_id row_id
#[1,]  57028  47091
#[2,]  57297  46860

iquery -naq "remove(RESULT_KF)"     2> /dev/null 
iquery -naq "remove(RESULT_BF)"   2> /dev/null 

echo "Running KALMAN FILTER ..."
time iquery -naq "store(redimension(stream(cast(project(apply(between(mod13q1_512, 57028, 46860, 0, 57297, 47091, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=kf4deforestation.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40]), RESULT_KF)"

echo "Running BFAST MONITOR..."
time iquery -naq "store(redimension(stream(cast(project(apply(between(mod13q1_512, 57028, 46860, 0, 57297, 47091, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=bfastMonitor.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40]), RESULT_BF)"


#Running KALMAN FILTER ...
#Query was executed successfully
#real    2m35.375s
#user    0m0.008s
#sys     0m0.004s
#Running BFAST MONITOR...
#Query was executed successfully
#real    1m58.048s
#user    0m0.012s
#sys     0m0.004s

#Running KALMAN FILTER ...
#Query was executed successfully
#real    2m36.702s
#user    0m0.016s
#sys     0m0.000s
#Running BFAST MONITOR...
#Query was executed successfully
#real    1m59.940s
#user    0m0.012s
#sys     0m0.004s



#-------------------------------------------------------------------------------

# Study site A
#   col_id row_id
#   57084  46857
#   57104  46881

# KALMAN FILTER
#iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 57084, 46857, 0, 57104, 46881, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=kf4deforestation.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40])"

# BFAST MONITOR - CHRIS STEPHAN
#iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62409, 43209, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=bfastMonitor_01.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40])"



# Study site B
#   col_id row_id
#   56995  46840
#   57264  47069

# KALMAN FILTER
#iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 56995, 46840, 0, 57264, 47069, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=kf4deforestation.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40])"

# BFAST MONITOR - CHRIS STEPHAN
#iquery -aq "redimension(stream(cast(project(apply(between(mod13q1_512, 56995, 46840, 0, 57264, 47069, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbStreamR4ts/main.R script_folder=/home/scidb/shared/scripts/sdbStreamR4ts script_name=bfastMonitor_01.R', 'format=df', 'types=int32,int32,double,string', 'names=col_id,row_id,breakpoint,breakpointStr'), <breakpoint:double, breakpointStr:string> [col_id=0:172799:0:40; row_id=0:86399:0:40])"

