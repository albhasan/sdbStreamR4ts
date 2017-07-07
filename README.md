sdbStreamR4ts
================
Alber Sánchez

sdbStreamR4ts
-------------

sdbStreamR4ts is a set of R scripts for processing time series using SciDB's stream.

[SciDB](https://en.wikipedia.org/wiki/SciDB) is an distributed multidimensional array database meant to process large scientific dataset.

[SciDB stream](https://github.com/Paradigm4/stream/) is a plug-in which implements a SciDB's operator for the AFL language. In a nutshell, stream enables each instance of SciDB to call an arbitrary program (R, Python, Java, C, sh) in parallel. Then, SciDB stores the results of the program for each instance in a single array. Each SciDB instance is responsible for calling the program, passing any parameters and data (one chunk at the time) and finally to collect the response. This map-reduce approach allows SciDB to take advantage of any of the available data-processing libraries and it does not depend on SHIM

Spatio-temporal data in SciDB
-----------------------------

SciDB can store large spatio-temporal arrays built from satellite images such as MODIS and LANDSAT. For example, the following is an schema to store MOD13Q1 data:

`iquery -aq "show(MOD13Q1)" {i} schema {0} 'MOD13Q1 <ndvi:int16, evi:int16, quality:uint16, red:int16, nir:int16, blue:int16, mir:int16, view_zenith:int16, sun_zenith:int16, relative_azimuth:int16, day_of_year:int16, reliability:int8> [col_id=48000:62400:0:40; row_id=38400:48000:0:40; time_id=0:511:0:512]'`

This schema has three dimensions:

-   col\_id. The global identifier of a pixel's column
-   row\_id. The global identifier of a pixel's row
-   time\_id. The global identifier of a pixel's time.

A chunk in this schema is made of 40x40x510 pixels. Note how the *time\_id*'s chunk size is 512, in other words, it is more than enough to hold whole time series. The MODIS mission started at February 2000 and MOD13Q1 is made of 23 a year. This means a chunk in this schema contains 40x40 time series.

Time-series processing using SciDB stream
-----------------------------------------

SciDB stream calls an arbitrary program --- in our case, an R script --- and it passes a chunk of data. Following our example schema, SciDB stream passes 40x40 time-series to an R script. We call this script the `main.R` script.

SciDB stream calls `main.R` one time for each chunk. The `main.R` scripts takes two parameters:

-   script\_folder. A path to a folder available to all the instances of SciDB.
-   script\_name. The name of an user-provided script which must implement the *analyzeTS* function. An example of this script is the `analyzeTS.R` script.

Internally, the `main.R` script does the following:

1.  Read the SciDB chunk provided by stream and cast it into a `data.frame`.
2.  Load (source) the user-provided script i.e. `analyzeTS.R`
3.  Split the chunk data frame into per-time-series data frames. That is, 1600 time-series in our 40x40x512 example.
4.  Call the *analyzeTS* function on each time series. The *analyzeTS* function is provided by the script specified by the `script_name` parameter to the `main.R` script.

The user-provided script --- i.e. `analyzeTS.R` --- should implement the *analyzeTS* function and all other functions required to analyse a single time-series. For example, this script could

-   Load pre-installed packages
-   Load data from files by name as the `main.R` script has already set-up the working directory with the data. i.e. `jsonlite::read_json("data.json")`

At the same time, the *analyzeTS* function must satisfy some conditions:

-   It must take a `data.frame` as unique parameter.
-   It must return a `data.frame`made of a single row. This row must be composed of atomic values i.e. numeric or string.

Advantages
----------

The *sdbStreamR4ts* scripts split the complexities of analysing time-series with the SciDB stream in two parts, handling SciDB stream --- the `main.R` script --- and analysing the time series --- the *analyzeTS* function ---.

In this way, R users can scale up their time-series analysis unaware of the internal details of SciDB and stream, as long as they follow the conditions described above.

On the other hand, SciDB administrators can automatize parallel and distributed analysis of time series as long as they fulfil the requirements of the `main.R`script. In other words, they do not require to know the details of the R packages used for analysing data.

Writting the analyzeTS function
-------------------------------

We provide the bare bones of the `analyzeTS` function in the `analyzeTS.R`script. This script just counts the number of rows and columns in the provided time-series data frame.

Besides, the `data`directory contains some sample SciDB chunks which can be loaded like this:

``` r
load("data/input.df-38447140")
```

This line of code loads the `ts.df` object to the current R session. This chunk was taken from the formerly mentioned array *mod13q1\_512*

Usage examples
--------------

Given the MODIS array *mod13q1\_512* with the following schema:

`<ndvi:int16, evi:int16, quality:uint16, red:int16, nir:int16, blue:int16, mir:int16, view_zenith:int16, sun_zenith:int16, relative_azimuth:int16, day_of_year:int16, reliability:int8> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]`

The *sdbStreamR4ts* scripts could be called like this:

`iquery -aq "store(stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62500, 43300, 367), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript main.R script_folder=/home/scidb/shared/query201706051451-5586 script_name=analyzeTS.R', 'format=df', 'types=int32,int32,string'), arraysQuery201706051451-5586)"`
