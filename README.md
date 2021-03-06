sdbStreamR4ts
================
Alber Sánchez, Luiz Assis, Eduardo Llapa

sdbStreamR4ts
-------------

sdbStreamR4ts is a set of R scripts for processing time series using SciDB's stream.

[SciDB](https://en.wikipedia.org/wiki/SciDB) is an distributed multidimensional array database meant to process large scientific datasets.

[SciDB stream](https://github.com/Paradigm4/stream/) is a plug-in which implements a SciDB's operator for the AFL language. Stream enables each instance of SciDB to call an arbitrary program (R, Python, Java, C, sh) in parallel. Then, SciDB stores the results of the program for each instance in a single array. Each SciDB instance is responsible for calling the program, passing any parameters and data (one chunk at the time) and finally to collect the response. This map-reduce approach allows SciDB to take advantage of any of the available data-processing libraries and it does not depend on SHIM

Pre-requisites
--------------

-   A running cluster of [SciDB](https://en.wikipedia.org/wiki/SciDB) with [SciDB stream](https://github.com/Paradigm4/stream/).
-   [R](https://www.r-project.org) installed in all the machines in the SciDB cluster.
-   A directory shared by all the SciDB's instances.

Files
-----

-   `README.Rmd` An RMarkdown document used to generate the README file
-   `README.md` This document.
-   `analyzeTS.R` An R script. An example of the basic usage of the `analyzeTS` function.
-   `bfastMonitor.R` An R script. It runs the BFAST MONITOR algorithm for one time series.
-   `data.json` A data file. An data sample which can be loaded by the `analyzeTS` function.
-   `installPackages.R` An R script. Install R packages.
-   `main.R` An R script. The main script. It takes a SciDB's chunk of data, converts it to a data frame, splits it into time-series can calls the `analyzeTS` function on each time series.

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

On the other hand, SciDB administrators can automatize parallel and distributed analysis of time series as long as they fulfil the requirements of the `main.R`script. In other words, they do not require to know the details scripts provided by the users to analyze the data.

Writting the analyzeTS function
-------------------------------

We provide the bare bones of the `analyzeTS` function in the `analyzeTS.R`script. This script just counts the number of rows and columns in the provided time-series data frame.

Besides, the `data`directory contains some sample SciDB chunks which can be loaded like this:

`load("data/input.df-38447140")`

This line of code loads the `ts.df` object to the current R session. This chunk was taken from the formerly mentioned array *mod13q1\_512*

Usage examples
--------------

The packages required by the analyzeTS function must be installed in all the machines in the SciDB cluster. This could be automatized using the `installPackages.R` script as follows:

`Rscript installPackages.R packages=scidb,zoo,bfast,lubridate`

Given the MODIS array *mod13q1\_512* with the following schema:

`<ndvi:int16, evi:int16, quality:uint16, red:int16, nir:int16, blue:int16, mir:int16, view_zenith:int16, sun_zenith:int16, relative_azimuth:int16, day_of_year:int16, reliability:int8> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]`

The *sdbStreamR4ts* scripts could be called like this:

`iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62400, 43200, 15), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=analyzeTS.R', 'format=df', 'types=int32,int32,int32,int32,int32')"`

To run a BFAST MONITOR:

`iquery -aq "stream(cast(project(apply(between(mod13q1_512, 62400, 43200, 0, 62409, 43209, 511), cid, col_id, rid, row_id, tid, time_id), cid, rid, tid, evi, quality, reliability), <cid:int32, rid:int32, tid:int32, evi:int32, quality:int32, reliability:int32> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]), 'Rscript /home/scidb/shared/scripts/sdbstream/main.R script_folder=/home/scidb/shared/scripts/sdbstream script_name=bfastMonitor.R', 'format=df', 'types=int32,int32,double,string')"`
