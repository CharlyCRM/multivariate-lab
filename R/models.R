split_indices <- function(y, binary = FALSE, seed = 2026) {
  set.seed(seed)
  groups <- if (binary) split(seq_along(y), y) else list(seq_along(y))
  if (binary && (length(groups) != 2 || min(lengths(groups)) < 7)) stop("At least seven examples per class are required.")
  test <- sort(unlist(lapply(groups, function(g) sample(g, max(1, floor(length(g)*.2))))) )
  list(train = setdiff(seq_along(y), test), test = test)
}

fold_ids <- function(y, binary = FALSE, seed = 2026, k = 5) {
  set.seed(seed)
  groups <- if(binary) split(seq_along(y), y) else list(seq_along(y))
  if (any(lengths(groups) < k)) stop("Insufficient observations for five folds.")
  f <- integer(length(y))
  for (g in groups) f[sample(g)] <- rep(seq_len(k), length.out = length(g))
  f
}

fit_recipe <- function(x) {
  numeric <- vapply(x, is.numeric, logical(1))
  medians <- vapply(x[, numeric, drop = FALSE], function(v) {m <- median(v, na.rm = TRUE); if(is.finite(m)) m else 0}, numeric(1))
  levels <- lapply(x[, !numeric, drop = FALSE], function(v) unique(c(sort(unique(as.character(v[!is.na(v)]))), "__missing__", "__other__")))
  r <- list(numeric = names(numeric)[numeric], categories = names(numeric)[!numeric], medians = medians, levels = levels)
  a <- raw_matrix(x, r)
  r$columns <- colnames(a)[apply(a, 2, sd) > 1e-10]
  if (!length(r$columns)) stop("No varying predictors.")
  r$center <- colMeans(a[, r$columns, drop=FALSE])
  r$scale <- apply(a[, r$columns, drop=FALSE], 2, sd)
  r
}

raw_matrix <- function(x, r) {
  columns <- list()
  for (v in r$numeric) {
    a <- as.numeric(x[[v]]); a[!is.finite(a)] <- r$medians[[v]]
    columns[[v]] <- a
  }
  for (v in r$categories) {
    a <- as.character(x[[v]]); a[is.na(a)] <- "__missing__"
    a[!a %in% r$levels[[v]]] <- "__other__"
    for (level in r$levels[[v]]) columns[[paste(v, level, sep="=")]] <- as.numeric(a == level)
  }
  do.call(cbind, columns)
}

apply_recipe <- function(x, r) {
  a <- raw_matrix(x, r)[, r$columns, drop=FALSE]
  sweep(sweep(a, 2, r$center, "-"), 2, r$scale, "/")
}

fit_model <- function(x, y, binary, lambda) {
  if (lambda == 0) {
    if(binary) return(suppressWarnings(glm.fit(cbind(Intercept=1,x), y, family=binomial())))
    return(lm.fit(cbind(Intercept=1,x), y))
  }
  glmnet::glmnet(x, y, family=if(binary) "binomial" else "gaussian", alpha=0, lambda=lambda, standardize=FALSE)
}

predict_model <- function(model, x, binary, lambda) {
  if (lambda > 0) return(as.numeric(predict(model, newx=x, s=lambda, type="response")))
  coefficients <- model$coefficients; coefficients[is.na(coefficients)] <- 0
  p <- as.numeric(cbind(Intercept=1,x) %*% coefficients)
  if(binary) plogis(p) else p
}

log_loss <- function(y,p) {p <- pmin(1-1e-8,pmax(1e-8,p)); -mean(y*log(p)+(1-y)*log(1-p))}
safe_ratio <- function(a,b) if(b == 0) 0 else a/b
classification_metrics <- function(y,p,threshold=.5) {
  pred <- as.integer(p >= threshold)
  tp <- sum(y==1 & pred==1); fp <- sum(y==0 & pred==1); fn <- sum(y==1 & pred==0); tn <- sum(y==0 & pred==0)
  precision <- safe_ratio(tp,tp+fp); recall <- safe_ratio(tp,tp+fn)
  auc <- if(length(unique(y))==2) (sum(rank(p)[y==1])-sum(y==1)*(sum(y==1)+1)/2)/(sum(y==1)*sum(y==0)) else NA_real_
  cuts <- sort(unique(p),decreasing=TRUE)
  rec <- prec <- numeric(length(cuts))
  for(i in seq_along(cuts)) {positive <- p >= cuts[i]; rec[i] <- safe_ratio(sum(y[positive]==1),sum(y==1)); prec[i] <- mean(y[positive]==1)}
  list(accuracy=mean(y==pred), precision=precision, recall=recall, specificity=safe_ratio(tn,tn+fp),
    f1=safe_ratio(2*precision*recall,precision+recall), roc_auc=auc, average_precision=sum(diff(c(0,rec))*prec),
    brier=mean((p-y)^2), log_loss=log_loss(y,p), tp=tp, fp=fp, fn=fn, tn=tn)
}
regression_metrics <- function(y,p) list(mae=mean(abs(y-p)), rmse=sqrt(mean((y-p)^2)),
  r2=if(sum((y-mean(y))^2)>0) 1-sum((y-p)^2)/sum((y-mean(y))^2) else NA_real_)

evaluate_task <- function(case, target, seed=2026) {
  task <- task_data(case,target); split <- split_indices(task$y,task$binary,seed)
  train <- task$x[split$train,,drop=FALSE]; y <- task$y[split$train]
  folds <- fold_ids(y,task$binary,seed)
  lambdas <- c(0,.001,.01,.1,1,10)
  oof <- matrix(NA_real_,nrow(train),length(lambdas))
  for(f in 1:5) {
    fit_ids <- which(folds!=f); val_ids <- which(folds==f)
    recipe <- fit_recipe(train[fit_ids,,drop=FALSE])
    a <- apply_recipe(train[fit_ids,,drop=FALSE],recipe); b <- apply_recipe(train[val_ids,,drop=FALSE],recipe)
    for(j in seq_along(lambdas)) {
      model <- fit_model(a,y[fit_ids],task$binary,lambdas[j])
      p <- predict_model(model,b,task$binary,lambdas[j])
      oof[val_ids,j] <- if(all(is.finite(p))) p else NA_real_
    }
  }
  scores <- vapply(seq_along(lambdas),function(j) {
    if(any(!is.finite(oof[,j]))) return(Inf)
    if(task$binary) log_loss(y,oof[,j]) else mean((y-oof[,j])^2)
  },numeric(1))
  best <- which.min(scores); lambda <- lambdas[best]
  if(!is.finite(scores[best])) stop("No model produced finite validation predictions.")
  threshold <- .5
  if(task$binary) {
    thresholds <- seq(.05,.95,.01)
    f1 <- vapply(thresholds,function(t) {
      positive <- oof[,best] >= t
      safe_ratio(2*sum(positive & y==1),2*sum(positive & y==1)+sum(positive & y==0)+sum(!positive & y==1))
    },numeric(1))
    threshold <- thresholds[which.max(f1)]
  }
  recipe <- fit_recipe(train); a <- apply_recipe(train,recipe)
  model <- fit_model(a,y,task$binary,lambda)
  test <- task$x[split$test,,drop=FALSE]; truth <- task$y[split$test]
  predictions <- predict_model(model,apply_recipe(test,recipe),task$binary,lambda)
  baseline <- rep(if(task$binary) mean(y) else mean(y),length(truth))
  metrics <- if(task$binary) classification_metrics(truth,predictions,threshold) else regression_metrics(truth,predictions)
  baseline_metrics <- if(task$binary) classification_metrics(truth,baseline,.5) else regression_metrics(truth,baseline)
  coefficients <- if(lambda>0) as.matrix(coef(model,s=lambda))[,1] else model$coefficients
  # Intervalos aproximados: t para OLS y cuantiles de residuos de validación para ridge.
  intervals <- NULL
  if(!task$binary) {
    if(lambda==0) {
      sigma <- sqrt(sum(model$residuals^2)/model$df.residual)
      design <- cbind(1,a); inv <- MASS::ginv(crossprod(design)); new_design <- cbind(1,apply_recipe(test,recipe))
      leverage <- rowSums((new_design %*% inv)*new_design)
      radius <- qt(.975,model$df.residual)*sigma*sqrt(1+leverage)
      intervals <- data.frame(lower=predictions-radius,upper=predictions+radius)
    } else {
      bounds <- quantile(y-oof[,best],c(.025,.975),na.rm=TRUE)
      intervals <- data.frame(lower=predictions+bounds[1],upper=predictions+bounds[2])
    }
  }
  list(case=case$id,source=case$source,target=target,binary=task$binary,seed=seed,
    train_rows=length(split$train),test_rows=length(split$test),test_positive=if(task$binary) sum(truth) else NULL,
    lambda=lambda,threshold=threshold,cv=data.frame(lambda=lambdas,score=scores),
    metrics=metrics,baseline=baseline_metrics,observations=data.frame(row_id=task$row_ids[split$test],actual=truth,prediction=predictions),
    coefficients=data.frame(term=names(coefficients),coefficient=as.numeric(coefficients)),intervals=intervals,
    recipe=recipe,split=split,folds=folds)
}

explore_case <- function(case, variables=case$spec$numeric, strategy="median", components=2, k=3) {
  variables <- intersect(variables,case$spec$numeric)
  if(length(variables)<2) stop("Select at least two numeric variables.")
  x <- case$data[,variables,drop=FALSE]; ids <- seq_len(nrow(x))
  if(strategy=="complete") {keep <- complete.cases(x); x<-x[keep,,drop=FALSE];ids<-ids[keep]}
  for(v in names(x)) {m<-median(x[[v]],na.rm=TRUE); if(!is.finite(m)) stop("Entirely missing variable.");x[[v]][is.na(x[[v]])]<-m}
  x <- x[,vapply(x,sd,numeric(1))>1e-10,drop=FALSE]
  if(ncol(x)<2 || nrow(x)<=k || k<2) stop("Insufficient variation or observations.")
  pca <- prcomp(x,center=TRUE,scale.=TRUE)
  scaled <- scale(x); set.seed(2026); fit<-kmeans(scaled,centers=k,nstart=25,algorithm="Lloyd",iter.max=1000)
  # Limitamos la muestra para que silhouette y el clustering jerárquico sean manejables.
  sample_ids<-unique(round(seq(1,nrow(x),length.out=min(500,nrow(x)))))
  distances<-dist(scaled[sample_ids,,drop=FALSE])
  hierarchical<-hclust(distances,method="complete")
  silhouette <- if(length(unique(fit$cluster[sample_ids]))>1) mean(cluster::silhouette(fit$cluster[sample_ids],distances)[,3]) else NA_real_
  list(pca=pca,variance=pca$sdev^2/sum(pca$sdev^2),cluster=fit$cluster,rows=nrow(x),ids=ids,
    x=x,correlation=cor(x),silhouette=silhouette,hierarchy=hierarchical,sample_ids=sample_ids,
    profiles=aggregate(x,list(cluster=fit$cluster),mean),components=min(components,ncol(x)),
    labels=case$data[[case$spec$label]][ids])
}
