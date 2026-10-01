# Multivariate Lab

**Carlos Ramírez Martín · R / Shiny / statistical modeling**

Three academic cases rebuilt as an independent interactive application. Explore data quality, PCA and clustering, then evaluate regression and classification using held-out observations. UI and explanations are available in Spanish and English.

## Run locally

Requires R 4.4.2 or compatible newer R. From this repository:

```sh
Rscript setup.R
Rscript tests/run.R
Rscript run.R
```

Open http://127.0.0.1:8504/ (English: `/?lang=en`). The server binds only to loopback. It has not been deployed to Railway. To restore recorded package versions, run `renv::restore(lockfile='renv.lock', library='.library', prompt=FALSE)` after installing renv.

Without private local files, the app generates **explicitly labeled synthetic fixtures** using seed 2026. A fresh public clone therefore works without coursework files or a Kaggle account. Those fixture results are not claims about real students or patients.

## Cases

| Case | Exploration | Supervised tasks |
|---|---|---|
| Diabetes | Physiological zeros → missing; median vs complete cases; PCA; k-means; hierarchical clusters | None: exploratory segmentation only |
| Student performance | Numeric relationships and component loadings | Exam score regression; improvement classification |
| Blood tests | PCA, cluster profiles and diagnostic labels for visualization | Blood glucose regression; coronary-label classification |

PCA plots support brushing. Download exploration and model reports as JSON. Hierarchy and silhouette use a deterministic sample of up to 500 observations. Clusters are descriptive, not clinical diagnoses.

## Evaluation protocol

- Seed 2026, 80% training / 20% untouched test; binary splits are stratified.
- Five-fold validation inside training. Every fold independently fits median imputation, categorical encoding and scaling.
- Compare conventional regression/logistic models and ridge penalties `0.001, 0.01, 0.1, 1, 10`.
- Choose regression by validation MSE and classification by validation log loss. Select the binary threshold by out-of-fold F1, never test F1.
- Compare against training-mean and majority-class baselines. Report MAE/RMSE/R² or confusion counts, precision, recall, specificity, F1, ROC AUC, average precision, Brier score and log loss.
- No observation is removed because of its residual. No preprocessing is fitted on test data. Coronary models exclude the diagnostic `classification` field. Student improvement uses `Previous_Scores`, which is assumed known before the final exam; final-score-derived features are excluded.
- Approximate prediction intervals: a t interval for unpenalized regression, or out-of-fold residual quantiles for ridge. They are not distribution-free guarantees.

Exploration may use the whole case for descriptive plots; those transforms are **not reused** in supervised evaluation.

## Results and limits

`reports/evaluation.json` contains aggregate results executed on the author's **local academic copies**, identified by SHA-256 in `provenance/source-manifest.json`. These are not results from the synthetic defaults.

The academic exam-score test has 1,321 rows: RMSE 2.519 vs 4.181 for the training-mean baseline. The coronary test has only **three positives**; its metrics are unstable and cannot establish clinical utility. Student data versions differ in their score values, so no versions are concatenated. The blood-test copy has 203 records, not the 400 in the original UCI dataset.

This is a statistical portfolio project, **not a medical tool, educational decision system or causal study**. Coefficients describe associations. Prior scores strongly affect the defined improvement target; high classification performance does not demonstrate an effective intervention.

## Academic provenance and immutable originals

Derived from my UOC multivariate-analysis PR2, PR3 and PR4. New reusable modules replace assignment-specific code; institutional templates, prompts and teaching PDFs are not distributed. Original files are never edited, moved or rendered in place.

To reproduce the published academic report with the matching original inputs:

```sh
Rscript scripts/import-academic.R /path/to/UOC
Rscript scripts/evaluate.R
Rscript scripts/verify-originals.R /path/to/UOC
```

The importer checks hashes before copying and refuses to overwrite changed working files. `data/local/` and `provenance/originals/` are excluded from Git. All execution, packages and outputs live here, not inside UOC.

The renal source is identifiable as [UCI Chronic Kidney Disease](https://archive.ics.uci.edu/dataset/336/chronic+kidney+disease), by Rubini, Soundarapandian and Eswaran (2015), CC BY 4.0. The academic subset's selection/transformation history remains unverified. Diabetes and student-copy redistribution licenses have not been established, so their raw files are not published. The MIT license applies to this project's own code, not to third-party datasets or UOC materials.

## Structure

`R/`: data preparation and statistical engine · `app.R`: reactive UI · `tests/`: unit tests · `scripts/`: evaluation and provenance checks · `reports/`: aggregate evidence · `renv.lock`: version lock.

No file uploads, personal-data collection or external model API calls. To change the portfolio return link, set `PORTFOLIO_URL`; default `http://localhost:4322`.
