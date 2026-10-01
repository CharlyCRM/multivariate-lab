dir.create(".library",showWarnings=FALSE)
.libPaths(c(file.path(getwd(),".library"),path.expand("~/.R/library"),.libPaths()))
packages <- c("shiny","bslib","readxl","MASS","glmnet","cluster","jsonlite","testthat","renv")
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) install.packages(missing,lib=".library",repos="https://cloud.r-project.org",
  type=if(Sys.info()[["sysname"]]=="Darwin") "binary" else "source")
if(file.exists("renv.lock")) {
  message("A version lock is available. For an exact restore: renv::restore(lockfile='renv.lock', library='.library', prompt=FALSE)")
}
