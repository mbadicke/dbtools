#' Copy data to database tables
#'
#' This functions copies data frames to database tables
#'
#' @param db one in:
#'   \cr (\link{Credentials}) the credentials to get a connection to a database.
#'   \cr (DBIConnection) \link[DBI]{DBIConnection-class}
#' @param name (character, length >= 1) data base table name(s)
#' @param value one in:
#'   \cr (\link[base]{data.frame})
#'   \cr (\link[base]{list}) of data.frames
#' @inheritParams sendQuery
#'
#' @export
sendData <- function(db, name, value, ...) {
  writeData(db = db, name = name, value = value, replace = FALSE, ...)
}