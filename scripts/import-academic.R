source("bootstrap.R")
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1 || !dir.exists(args[1])) stop("Usage: Rscript scripts/import-academic.R /path/to/UOC")
root<-normalizePath(args[1],mustWork=TRUE)
manifest<-jsonlite::read_json("provenance/source-manifest.json",simplifyVector=TRUE)$files
dir.create("data/local",recursive=TRUE,showWarnings=FALSE)
dir.create("provenance/originals",recursive=TRUE,showWarnings=FALSE)
for(i in seq_len(nrow(manifest))) {
  origin<-file.path(root,manifest$path[i])
  if(!file.exists(origin) || digest::digest(file=origin,algo="sha256")!=manifest$sha256[i]) stop(paste("Unexpected source hash:",manifest$path[i]))
  destination<-file.path(if(endsWith(origin,".xlsx")) "data/local" else "provenance/originals",basename(origin))
  if(file.exists(destination)) {
    if(digest::digest(file=destination,algo="sha256")!=manifest$sha256[i]) stop("Refusing to overwrite a changed working copy.")
  } else if(!file.copy(origin,destination,overwrite=FALSE)) stop("Copy failed.")
}
cat("Independent local copies ready. No source file was written.\n")
