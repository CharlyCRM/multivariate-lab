.libPaths(c(file.path(getwd(), ".library"), path.expand("~/.R/library"), .libPaths()))
required <- c("shiny","bslib","readxl","MASS","glmnet","cluster","jsonlite","testthat","renv")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly=TRUE)]
if(length(missing)) stop(paste("Run Rscript setup.R first. Missing:",paste(missing,collapse=", ")))
