[![Travis-CI Build Status](https://travis-ci.org/INWT/dbtools.svg?branch=master)](https://travis-ci.org/INWT/dbtools)

This package abstracts typical patterns used when connecting to and retrieving data from databases in R. It aims to provide very few, simple and reliable functions for sending queries and data to databases.

Installation
------------

``` r
devtools::install_github("INWT/dbtools")
```

Basic usage: sendQuery
----------------------

For basic usage consider the simple case where we want to retrieve some data from a SQLite database. At this time we only have `sendQuery` and no `sendData` so we use the standard example for setting up the database:

``` r
library("RSQLite")
con <- dbConnect(SQLite(), "example.db")
USArrests$State <- rownames(USArrests)
dbWriteTable(con, "USArrests", USArrests, row.names = FALSE)
dbDisconnect(con)
```

This will create a database `example.db` to which we can send some queries. To begin with, we have to define an object of class *Credentials* which will store all necessary information to connect to a database. The driver is mandatory, all other arguments depend on the specific back-end.

``` r
library("dbtools")
cred <- Credentials(drv = RSQLite::SQLite, dbname = "example.db")
testConnection(cred)
```

    ## INFO [2016-12-02 11:57:36] example.db OK

``` r
cred
```

    ## An object of class "Credentials"
    ## drv:SQLiteDriver
    ## dbname: example.db

Opposed to the `dbSendQuery` function available from DBI, `sendQuery` needs a *Credentials* instance as argument and will take care of connecting to the database, fetching the results and closing the connection.

``` r
dat <- sendQuery(cred, "SELECT * FROM USArrests;")
dat
```

    ## # A tibble: 50 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 40 more rows

In your normal work-flow you will sometimes want to split up a complex query into more tangible chunks. The approach we take here is to allow for a vector of queries as argument. The result of these queries have to be *row-bindable*. To make an example lets say we want to query each state separately:

``` r
queryFun <- function(state) {
  paste0("SELECT * FROM USArrests WHERE State = '", state, "';")
}

sendQuery(cred, queryFun(dat$State))
```

    ## # A tibble: 50 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 40 more rows

In such a case `sendQuery` will perform all queries on one connection. A different approach is to fetch the results of the original query in chunks, which we do not support yet.

Unstable connections
--------------------

One of the problems we face on a regular basis are connection problems to external servers. To address this `sendQuery` will evaluate everything in a 'try-catch' handler abstracted in `dbtools::reTry`. With this you can state how many tries a query has, how many seconds should be waited between each iteration and how the error messages should be logged:

``` r
dat <- sendQuery(
  cred, 
  "SELECT * FROM USArrest;", # wrong name for illustration
  tries = 2,
  intSleep = 1
)
```

    ## ERROR [2016-12-02 11:57:36] Error in rsqlite_send_query(conn@ptr, statement) : 
    ##   no such table: USArrest
    ## 
    ## ERROR [2016-12-02 11:57:37] Error in rsqlite_send_query(conn@ptr, statement) : 
    ##   no such table: USArrest

    ## Error in reTry(function(...) lapply(query, . %>% sendQuery(db = con, ...)), : Error in rsqlite_send_query(conn@ptr, statement) : 
    ##   no such table: USArrest

Multiple Databases
------------------

Sometimes your data can be distributed on different servers but you want to send the same query to those servers. What you can do is give `sendQuery` a *CredentialsList*.

``` r
file.copy("example.db", "example1.db")
```

Now we want to load the data from `example1.db` and `example.db` which can be implemented as follows:

``` r
cred <- Credentials(
  RSQLite::SQLite, 
  dbname = c("example.db", "example1.db")
)

sendQuery(cred, "SELECT * FROM USArrests;")
```

    ## # A tibble: 100 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 90 more rows

It might also be of interest to query your databases in parallel. For that it is possible to supply a apply/map function which in turn can be a parallel lapply like mclapply or something else:

``` r
sendQuery(
  cred, 
  "SELECT * FROM USArrests;", 
  mc.cores = 2, 
  applyFun = parallel::mclapply
)
```

    ## # A tibble: 100 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 90 more rows

Potentially you can send multiple queries to multiple databases. The results are tried to be simplified by default:

``` r
sendQuery(cred, c("SELECT * FROM USArrests;", "SELECT 1 AS x;"))
```

    ## [[1]]
    ## # A tibble: 100 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 90 more rows
    ## 
    ## [[2]]
    ## # A tibble: 2 × 1
    ##       x
    ##   <int>
    ## 1     1
    ## 2     1

``` r
sendQuery(cred, c("SELECT * FROM USArrests;", "SELECT 1 AS x;"), simplify = FALSE)
```

    ## [[1]]
    ## [[1]][[1]]
    ## # A tibble: 50 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 40 more rows
    ## 
    ## [[1]][[2]]
    ## # A tibble: 1 × 1
    ##       x
    ##   <int>
    ## 1     1
    ## 
    ## 
    ## [[2]]
    ## [[2]][[1]]
    ## # A tibble: 50 × 5
    ##    Murder Assault UrbanPop  Rape       State
    ##     <dbl>   <int>    <int> <dbl>       <chr>
    ## 1    13.2     236       58  21.2     Alabama
    ## 2    10.0     263       48  44.5      Alaska
    ## 3     8.1     294       80  31.0     Arizona
    ## 4     8.8     190       50  19.5    Arkansas
    ## 5     9.0     276       91  40.6  California
    ## 6     7.9     204       78  38.7    Colorado
    ## 7     3.3     110       77  11.1 Connecticut
    ## 8     5.9     238       72  15.8    Delaware
    ## 9    15.4     335       80  31.9     Florida
    ## 10   17.4     211       60  25.8     Georgia
    ## # ... with 40 more rows
    ## 
    ## [[2]][[2]]
    ## # A tibble: 1 × 1
    ##       x
    ##   <int>
    ## 1     1

Parameterized Queries
---------------------

In many applications it is easier and more tangible to separate SQL and R code. Furthermore we oftentimes paste queries together to have something like parameterized statements. There are various solutions for this type of problem but not many for the R language. Hence `dbtools` provides an own interface to what may be understood as *template queries*. These templates solve two issues for us:

1.  Put SQL code where it belongs: a `.sql` file.
2.  Provide a simple way to pass objects to these queries, using parameters.

The use of these features is simple enough. A template is defined as a character and regions in which parameters are substituted are denoted by two curly braces. Users of [Liquid templates](http://shopify.github.io/liquid/) may be familiar with this idea. Everything inside these regions is interpreted as R-expression and can contain arbitrary operations. The result of the evaluation should be a character of length one.

``` r
templateQuery <- "SELECT {{ sqlName(fieldName) }} FROM `someTable`;"
Query(templateQuery, fieldName = "someField")
```

    ## Query:
    ## SELECT `someField` FROM `someTable`;

When such a query lives inside a file we can use a connection object and pass it to `Query`.

``` r
otherTemplateQuery <-
  "SELECT `someField` FROM `someTable` WHERE `primaryKey` IN {{ sqlInNums(ids) }};"
writeLines(otherTemplateQuery, tmpFile <- tempfile())
Query(file(tmpFile), ids = 1:10)
```

    ## Query:
    ## SELECT `someField` FROM `someTable` WHERE `primaryKey` IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
