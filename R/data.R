case_specs <- function() list(
  diabetes = list(title = c(es = "Perfiles metabólicos", en = "Metabolic profiles"),
    numeric = c("Pregnancies", "Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI", "DiabetesPedigreeFunction", "Age"),
    label = "Outcome", tasks = character()),
  students = list(title = c(es = "Rendimiento académico", en = "Student performance"),
    numeric = c("Hours_Studied", "Attendance", "Sleep_Hours", "Previous_Scores", "Tutoring_Sessions", "Physical_Activity"),
    label = "Mejora", tasks = c("Exam_Score", "Mejora")),
  blood = list(title = c(es = "Patrones en analíticas", en = "Blood-test patterns"),
    numeric = c("age", "bp", "sg", "al", "su", "bgr", "bu", "sc", "sod", "pot", "hemo", "pcv", "wc", "rc"),
    label = "classification", tasks = c("bgr", "cad")))

# Seeded synthetic fixtures make the public repository runnable without redistributing coursework data.
synthetic_case <- function(id, n = 500, seed = 2026) {
  set.seed(seed)
  z <- rnorm(n); age <- sample(20:80, n, TRUE)
  if (id == "diabetes") {
    d <- data.frame(Pregnancies = rpois(n, 3), Glucose = 110 + 24*z,
      BloodPressure = 72 + 8*z + rnorm(n, 0, 6), SkinThickness = 25 + 5*z,
      Insulin = exp(4.6 + .5*z), BMI = 28 + 4*z, DiabetesPedigreeFunction = runif(n, .1, 1.5), Age = age)
    d$Outcome <- rbinom(n, 1, plogis(-1 + .8*z))
    d$Insulin[sample(n, n/8)] <- 0
  } else if (id == "students") {
    d <- data.frame(Hours_Studied = pmax(1, round(20 + 6*z)), Attendance = sample(60:100, n, TRUE),
      Sleep_Hours = sample(5:9, n, TRUE), Previous_Scores = runif(n, 50, 90),
      Tutoring_Sessions = rpois(n, 1), Physical_Activity = sample(0:6, n, TRUE),
      Parental_Involvement = sample(c("Low", "Medium", "High"), n, TRUE),
      Access_to_Resources = sample(c("Low", "Medium", "High"), n, TRUE),
      Internet_Access = sample(c("Yes", "No"), n, TRUE))
    d$Exam_Score <- pmin(100, pmax(0, 10 + .5*d$Previous_Scores + .9*d$Hours_Studied + .13*d$Attendance + rnorm(n, 0, 6)))
    d$Hours_Studied[sample(n, n/20)] <- NA
  } else {
    d <- data.frame(age = age, bp = 76 + 8*z, sg = sample(c(1.01, 1.015, 1.02), n, TRUE),
      al = sample(0:4, n, TRUE), su = sample(0:4, n, TRUE), bgr = 120 + 25*z + rnorm(n, 0, 15),
      bu = 40 + 8*z, sc = exp(.3 + .4*z), sod = 139 - 3*z, pot = 4.5 + .4*z,
      hemo = 14 - z, pcv = 42 - 3*z, wc = 8000 + 900*z, rc = 5 - .3*z,
      ane = sample(c("yes", "no"), n, TRUE), cad = ifelse(rbinom(n, 1, plogis(-3 + .8*z)), "yes", "no"),
      classification = ifelse(z > .1, "ckd", "notckd"))
  }
  d
}

load_case <- function(id, directory = "data/local") {
  stopifnot(id %in% names(case_specs()))
  files <- c(diabetes = "diabetes.xlsx", students = "StudentPerformance.xlsx", blood = "Blood_test_data.xlsx")
  path <- file.path(directory, files[[id]])
  local <- file.exists(path)
  d <- if (local) as.data.frame(readxl::read_excel(path, sheet = if (id == "blood") "Pacient_data" else 1)) else synthetic_case(id)
  spec <- case_specs()[[id]]
  required <- unique(c(spec$numeric, if(id == "students") "Exam_Score" else spec$label, if(id == "blood") "cad"))
  if (!all(required %in% names(d))) stop("Dataset schema does not match this case.")
  for (v in names(d)) if (is.character(d[[v]])) {
    d[[v]] <- trimws(d[[v]]); d[[v]][d[[v]] %in% c("", "?", "NA")] <- NA
  }
  for (v in spec$numeric) d[[v]] <- as.numeric(d[[v]])
  missing_before <- sum(is.na(d))
  if (id == "diabetes") for (v in c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI")) d[[v]][d[[v]] == 0] <- NA
  if (id == "students") d$Mejora <- as.integer(d$Exam_Score > d$Previous_Scores)
  if (id == "blood") d$cad <- ifelse(is.na(d$cad), NA_integer_, as.integer(d$cad == "yes"))
  list(id = id, data = d, spec = spec, source = if (local) "academic-copy" else "synthetic",
    missing_before = missing_before, missing_after = sum(is.na(d)), rows = nrow(d))
}

task_data <- function(case, target) {
  if (!target %in% case$spec$tasks) stop("Unsupported target.")
  binary <- target %in% c("Mejora", "cad")
  excluded <- if (case$id == "students") c("Exam_Score", "Mejora") else c("bgr", "cad", "classification")
  # For CAD, bgr is an available measured predictor, never the diagnostic class.
  if (target == "cad") excluded <- c("cad", "classification")
  predictors <- setdiff(names(case$data), excluded)
  d <- case$data[!is.na(case$data[[target]]), c(predictors, target), drop = FALSE]
  if (nrow(d) < 30) stop("Insufficient labeled observations.")
  list(x = d[, predictors, drop = FALSE], y = as.numeric(d[[target]]), binary = binary, target = target,
    row_ids = which(!is.na(case$data[[target]])))
}
