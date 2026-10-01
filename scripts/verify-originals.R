source("bootstrap.R")
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1 || !dir.exists(args[1])) stop("Provide the read-only UOC root directory.")
manifest<-jsonlite::read_json("provenance/source-manifest.json",simplifyVector=TRUE)$files
for(i in seq_len(nrow(manifest))) {
  path<-file.path(args[1],manifest$path[i])
  if(!file.exists(path) || digest::digest(file=path,algo="sha256")!=manifest$sha256[i]) stop(paste("Source changed:",manifest$path[i]))
}
cat(nrow(manifest),"original input hashes unchanged. No files were written.\n")
