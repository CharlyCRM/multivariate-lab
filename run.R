source("bootstrap.R")
args <- commandArgs(trailingOnly=TRUE)
port <- if(length(args)) as.integer(sub("^--port=","",args[1])) else 8504L
if(is.na(port) || port<1024 || port>65535) stop("Invalid port.")
shiny::runApp(".",host="127.0.0.1",port=port,launch.browser=FALSE)
