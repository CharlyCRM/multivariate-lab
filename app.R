source("bootstrap.R")
source("R/data.R"); source("R/models.R")
library(shiny)
plot_theme <- function() par(bg="#101925",fg="#d0deeb",col.axis="#9daec0",col.lab="#d0deeb",col.main="#edf2f7",mar=c(5,4,2,1),family="sans")
palette <- c("#40d9dd","#b8f277","#be9cff","#ffa66b","#ff7795","#8cb9ff","#f4d86b","#b0d9c0")
ui <- fluidPage(theme=bslib::bs_theme(version=5,bg="#080c12",fg="#edf2f7",primary="#40d9dd"),
  tags$head(tags$link(rel="stylesheet",href="style.css")),
  div(class="app-shell",
    div(class="app-nav",uiOutput("back_link"),
      span(class="signature","CARLOS RAMÍREZ MARTÍN / R + DATA SCIENCE")),
    div(class="hero-copy",p(class="eyebrow","01 / MULTIVARIATE LAB"),uiOutput("title"),uiOutput("intro")),
    div(class="workspace",
      div(class="controls",h3("Explorar / Explore"),
        selectInput("language","Idioma / Language",c("Español"="es","English"="en")),
        selectInput("case","Caso / Case",c("Diabetes"="diabetes","Estudiantes / Students"="students","Analíticas / Blood tests"="blood")),
        uiOutput("variables"),selectInput("strategy","Ausencias / Missing values",c("Mediana / Median"="median","Casos completos / Complete cases"="complete")),
        sliderInput("components","Componentes / Components",min=2,max=8,value=2,step=1),
        sliderInput("k","Grupos / Clusters",min=2,max=8,value=3,step=1),
        selectInput("color","Color PCA",c("Grupos / Clusters"="cluster","Etiqueta observada / Observed label"="label")),
        downloadButton("download_exploration","Exportar exploración / Export exploration")),
      div(class="content",uiOutput("stats"),uiOutput("source_note"),
        tabsetPanel(id="tabs",
          tabPanel("Datos / Data",div(class="panel",h3("Calidad / Quality"),plotOutput("missing",height=300)),
            div(class="panel",h3("Resumen / Summary"),tableOutput("summary")),div(class="panel",h3("Correlaciones / Correlations"),plotOutput("correlation",height=430))),
          tabPanel("PCA",div(class="plot-grid",
            div(class="panel",h3("Varianza / Variance"),plotOutput("variance",height=290)),
            div(class="panel",h3("Cargas / Loadings"),tableOutput("loadings"))),
            div(class="panel",h3("Espacio factorial / Factor space"),plotOutput("pca",height=430,brush=brushOpts("pca_brush",resetOnNew=TRUE)),
              uiOutput("brush_note"),uiOutput("pca_note"))),
          tabPanel("Grupos / Clusters",div(class="panel",h3("Perfiles / Profiles"),tableOutput("profiles")),
            div(class="plot-grid",div(class="panel",h3("Número de grupos / Cluster count"),plotOutput("elbow",height=320)),
              div(class="panel",h3("Jerarquía / Hierarchy"),plotOutput("hierarchy",height=320))),uiOutput("cluster_note")),
          tabPanel("Modelos / Models",div(class="panel",uiOutput("target_control"),actionButton("evaluate","Evaluar / Evaluate",class="btn-primary"),uiOutput("protocol")),
            uiOutput("model_stats"),div(class="panel",tableOutput("comparison")),
            div(class="panel",plotOutput("predictions",height=380)),
            div(class="plot-grid",div(class="panel",h3("Validación cruzada / Cross-validation"),tableOutput("cv")),
              div(class="panel",h3("Coeficientes / Coefficients"),tableOutput("coefficients"))),
            uiOutput("model_note"),downloadButton("download_model","Exportar evaluación / Export evaluation"))))),
    p(class="footer-note","Origen académico · UOC / Rebuilt as an independent portfolio application · No clinical decisions")))

server <- function(input,output,session) {
  tr <- function(es,en) if(input$language=="en") en else es
  output$back_link <- renderUI(a(href=paste0(sub("/$","",Sys.getenv("PORTFOLIO_URL","http://localhost:4322")),"/",input$language,"/projects/multivariate-lab/"),class="portfolio-back","← Portfolio / Carlos Ramírez Martín"))
  observeEvent(session$clientData$url_search,{
    query<-parseQueryString(session$clientData$url_search)
    if(!is.null(query$lang) && query$lang %in% c("es","en")) updateSelectInput(session,"language",selected=query$lang)
  },once=TRUE,ignoreNULL=FALSE)
  output$title <- renderUI(h1(tr("Del patrón al modelo.","From pattern to model.")))
  output$intro <- renderUI(p(class="lead",tr("Tres casos, una metodología: entender la calidad de los datos, descubrir estructura y poner a prueba lo que un modelo puede predecir. Explora las visualizaciones o ejecuta una evaluación independiente.","Three cases, one methodology: understand data quality, discover structure and test what a model can predict. Explore the visualizations or run an independent evaluation.")))
  case <- reactive(load_case(input$case))
  output$variables <- renderUI(checkboxGroupInput("variables","Variables numéricas / Numeric variables",case()$spec$numeric,selected=case()$spec$numeric))
  exploration <- reactive({req(input$variables);tryCatch(explore_case(case(),input$variables,input$strategy,input$components,input$k),error=function(e) validate(need(FALSE,conditionMessage(e))))})
  output$source_note <- renderUI(div(class="note warning",
    if(case()$source=="synthetic") tr("DATOS SINTÉTICOS. Ejemplo generado con semilla fija; sus métricas no describen una población real.","SYNTHETIC DATA. A seeded generated example; its metrics do not describe a real population.") else
      tr("COPIA ACADÉMICA LOCAL. Los originales de la UOC no se modifican. La procedencia y las transformaciones de estos datos deben tenerse en cuenta al interpretar resultados.","LOCAL ACADEMIC COPY. UOC originals are never modified. Consider data provenance and transformations when interpreting results.")))
  stat <- function(value,label) div(class="stat",strong(value),span(label))
  output$stats <- renderUI(div(class="stat-grid",stat(format(case()$rows,big.mark=" "),tr("Registros originales","Original rows")),
    stat(exploration()$rows,tr("Registros explorados","Explored rows")),stat(length(input$variables),tr("Variables seleccionadas","Selected variables"))))
  output$missing <- renderPlot({plot_theme();d<-case()$data;v<-case()$spec$numeric;m<-colSums(is.na(d[,v,drop=FALSE]));
    barplot(m,col="#40d9dd",border=NA,las=2,cex.names=.7,ylab=tr("Valores ausentes","Missing values"),ylim=c(0,max(1,m)*1.2))})
  output$summary <- renderTable({x<-exploration()$x;data.frame(variable=names(x),mean=vapply(x,mean,numeric(1)),sd=vapply(x,sd,numeric(1)),min=vapply(x,min,numeric(1)),max=vapply(x,max,numeric(1)))},digits=2)
  output$correlation <- renderPlot({plot_theme();c<-exploration()$correlation;n<-ncol(c);par(mar=c(8,8,2,2));
    image(seq_len(n),seq_len(n),c,col=colorRampPalette(c("#7e559b","#101925","#40d9dd"))(60),zlim=c(-1,1),axes=FALSE,xlab="",ylab="")
    axis(1,seq_len(n),colnames(c),las=2,cex.axis=.7);axis(2,seq_len(n),colnames(c),las=2,cex.axis=.7)})
  output$variance <- renderPlot({plot_theme();v<-exploration()$variance;barplot(v*100,col=ifelse(seq_along(v)<=exploration()$components,"#40d9dd","#3a4a5e"),border=NA,names.arg=paste0("PC",seq_along(v)),ylab="%",ylim=c(0,100));
    lines(seq_along(v)*1.2-.5,cumsum(v)*100,col="#b8f277",type="b",pch=16)})
  output$loadings <- renderTable({e<-exploration();round(e$pca$rotation[,seq_len(min(3,e$components)),drop=FALSE],3)},rownames=TRUE)
  output$pca <- renderPlot({plot_theme();e<-exploration();g<-if(input$color=="label") as.integer(factor(e$labels)) else e$cluster;
    plot(e$pca$x[,1:2],col=adjustcolor(palette[(g-1)%%length(palette)+1],alpha.f=.65),pch=16,cex=.65,xlab="PC1",ylab="PC2");abline(h=0,v=0,col="#344357",lty=3)})
  output$brush_note <- renderUI({e<-exploration();n<-if(is.null(input$pca_brush)) 0 else nrow(brushedPoints(as.data.frame(e$pca$x),input$pca_brush,xvar="PC1",yvar="PC2"));
    p(class="note",tr(paste("Arrastra sobre el gráfico para seleccionar puntos:",n),paste("Drag on the chart to select points:",n)))})
  output$pca_note <- renderUI(p(class="note",tr("PCA resume variabilidad, no establece causalidad ni diagnostica. El signo de las componentes puede invertirse sin cambiar su significado geométrico. Esta vista es exploratoria; no se utiliza para ajustar el test de los modelos.","PCA summarizes variation; it does not establish causality or diagnose. Component signs can flip without changing their geometry. This exploratory view is not used to fit the models’ test data.")))
  output$profiles <- renderTable(exploration()$profiles,digits=2)
  output$elbow <- renderPlot({plot_theme();x<-scale(exploration()$x);ks<-2:min(8,nrow(x)-1);set.seed(2026);
    wss<-vapply(ks,function(k) kmeans(x,k,nstart=10,algorithm="Lloyd",iter.max=1000)$tot.withinss,numeric(1));plot(ks,wss,type="b",pch=16,col="#40d9dd",xlab="k",ylab="WSS");abline(v=input$k,lty=3,col="#b8f277")})
  output$hierarchy <- renderPlot({plot_theme();plot(exploration()$hierarchy,labels=FALSE,main="",xlab=tr("Muestra determinista ≤500 registros","Deterministic sample ≤500 rows"),sub="",ylab="Distance");rect.hclust(exploration()$hierarchy,k=input$k,border="#40d9dd")})
  output$cluster_note <- renderUI(p(class="note",tr(paste0("Silhouette en muestra acotada: ",round(exploration()$silhouette,3),". El número de grupos es una hipótesis exploratoria; los grupos no equivalen a clases clínicas."),paste0("Silhouette on a bounded sample: ",round(exploration()$silhouette,3),". Cluster count is an exploratory hypothesis; clusters are not clinical classes."))))
  output$target_control <- renderUI({tasks<-case()$spec$tasks;if(!length(tasks)) return(p(class="note","Exploración y segmentación: selecciona estudiantes o analíticas para evaluar modelos. / Exploration and segmentation: select students or blood tests to evaluate models."));selectInput("target","Variable objetivo / Target",tasks)})
  output$protocol <- renderUI(p(class="note",tr("Test reservado del 20 % · 5 particiones de validación · semilla 2026. Imputación, escalado, selección y umbral se ajustan sin consultar el test. Los controles de exploración no cambian este protocolo.","20% held-out test · 5-fold validation · seed 2026. Imputation, scaling, selection and threshold are fitted without consulting test data. Exploration controls do not change this protocol.")))
  result <- reactiveVal(NULL)
  observeEvent(list(input$case,input$target),result(NULL),ignoreInit=TRUE)
  observeEvent(input$evaluate,{
    if(is.null(input$target) || !input$target %in% case()$spec$tasks) {showNotification(tr("Selecciona un caso supervisado.","Select a supervised case."),type="message");return()}
    withProgress(message=tr("Validación cruzada y test independiente…","Cross-validation and independent test…"),value=.2,{
      tryCatch(result(evaluate_task(case(),input$target)),error=function(e) showNotification(conditionMessage(e),type="error",duration=15))
    })
  })
  output$model_stats <- renderUI({req(result());r<-result();div(class="stat-grid",stat(r$train_rows,"TRAIN"),stat(r$test_rows,"TEST"),
    stat(if(r$binary) sprintf("%.3f",r$metrics$recall) else sprintf("%.2f",r$metrics$rmse),if(r$binary) "RECALL / TEST" else "RMSE / TEST"))})
  output$comparison <- renderTable({req(result());r<-result();keys<-if(r$binary)c("accuracy","precision","recall","specificity","f1","roc_auc","average_precision","brier","log_loss") else c("mae","rmse","r2");
    data.frame(metric=keys,model=unlist(r$metrics[keys]),baseline=unlist(r$baseline[keys]))},digits=4)
  output$predictions <- renderPlot({req(result());plot_theme();r<-result();d<-r$observations;
    if(r$binary) {
      matrix<-matrix(c(r$metrics$tn,r$metrics$fp,r$metrics$fn,r$metrics$tp),2,byrow=TRUE)
      image(1:2,1:2,t(matrix),col=colorRampPalette(c("#101925","#40d9dd"))(50),axes=FALSE,xlab=tr("Predicción","Prediction"),ylab=tr("Observación","Observation"))
      axis(1,1:2,c("0","1"));axis(2,1:2,c("0","1"));for(i in 1:2) for(j in 1:2) text(j,i,matrix[i,j],col="#edf2f7",cex=2)
    } else {plot(d$actual,d$prediction,pch=16,col=adjustcolor("#40d9dd",.5),xlab=tr("Observado en test","Observed in test"),ylab=tr("Predicción","Prediction"));abline(0,1,col="#b8f277",lty=2)}
  })
  output$cv <- renderTable({req(result());result()$cv},digits=4)
  output$coefficients <- renderTable({req(result());d<-result()$coefficients;head(d[order(abs(d$coefficient),decreasing=TRUE),],12)},digits=3)
  output$model_note <- renderUI({req(result());r<-result();div(class="note warning",
    p(tr(paste0("Modelo seleccionado: ",if(r$lambda==0) "convencional" else "ridge", " · λ = ",r$lambda," · umbral = ",round(r$threshold,2)),paste0("Selected model: ",if(r$lambda==0) "conventional" else "ridge"," · λ = ",r$lambda," · threshold = ",round(r$threshold,2)))),
    if(r$binary) p(tr(paste("Positivos en test:",r$test_positive,". Las métricas pueden variar mucho cuando hay pocos casos; no son evidencia de utilidad clínica."),paste("Test positives:",r$test_positive,". Metrics can vary substantially with few cases; they are not evidence of clinical utility."))) else
      p(tr("Los intervalos descargables son aproximados: intervalo t para el modelo lineal o cuantiles de residuos fuera de partición para ridge. No garantizan cobertura en otra población.","Downloadable intervals are approximate: a t interval for the linear model or out-of-fold residual quantiles for ridge. They do not guarantee coverage in another population.")),
    p(tr("Coeficientes sobre predictores estandarizados y categorías codificadas. Interpretación asociativa, no causal.","Coefficients use standardized predictors and encoded categories. Associations are not causal effects.")))})
  output$download_exploration <- downloadHandler(filename=function() paste0(input$case,"-exploration.json"),content=function(file) {
    e<-exploration();jsonlite::write_json(list(source=case()$source,rows=e$rows,strategy=input$strategy,variance=e$variance,loadings=e$pca$rotation,profiles=e$profiles,silhouette=e$silhouette),file,pretty=TRUE,auto_unbox=TRUE,digits=8)
  })
  output$download_model <- downloadHandler(filename=function() "held-out-evaluation.json",content=function(file) {req(result());r<-result();r$recipe<-r$split<-r$folds<-NULL;jsonlite::write_json(r,file,pretty=TRUE,auto_unbox=TRUE,digits=8)})
}
shinyApp(ui,server)
