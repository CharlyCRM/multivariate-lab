source("bootstrap.R"); source("R/data.R");source("R/models.R")
dir.create("reports",showWarnings=FALSE)
report<-list(executed_at=as.character(Sys.Date()),seed=2026,protocol="80/20 held-out test; 5-fold training validation; train-only preprocessing; OOF threshold selection")
for(id in c("students","blood")) {
  case<-load_case(id); results<-list()
  for(target in case$spec$tasks) {
    cat("Evaluating",id,target,"\n")
    r<-evaluate_task(case,target)
    results[[target]]<-r[c("source","train_rows","test_rows","test_positive","lambda","threshold","cv","metrics","baseline")]
  }
  report[[id]]<-results
}
for(id in names(case_specs())) {
  case<-load_case(id);e<-explore_case(case)
  report[[paste0(id,"_exploration")]]<-list(source=case$source,rows=case$rows,complete_numeric=sum(complete.cases(case$data[,case$spec$numeric])),missing_after=case$missing_after,variance=e$variance,silhouette=e$silhouette)
}
jsonlite::write_json(report,"reports/evaluation.json",pretty=TRUE,auto_unbox=TRUE,digits=8)
cat("Aggregate report saved to reports/evaluation.json. No raw data or row predictions published.\n")
