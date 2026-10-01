source("bootstrap.R")
source("R/data.R"); source("R/models.R")
testthat::test_dir("tests/testthat",reporter="summary",stop_on_failure=TRUE)
