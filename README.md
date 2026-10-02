# Del patrón al modelo

¿Qué podemos descubrir al mirar varias variables a la vez? Esta aplicación reúne tres casos para explorar relaciones, encontrar perfiles parecidos y poner a prueba modelos de predicción.

El proyecto parte de mis trabajos de análisis multivariante en la UOC. Reorganicé sus ideas en una aplicación con R y Shiny para pasar de la exploración visual a una evaluación del modelo, sin confundir lo que vemos en un gráfico con lo que podemos predecir en datos nuevos.

[Abrir la aplicación](https://multivariate-lab-production.up.railway.app) · [Ver el proyecto en mi portfolio](https://carlos-ramirez-martin.up.railway.app/es/projects/multivariate-lab/)

## Qué puedes explorar

Selecciona variables, revisa valores ausentes, observa relaciones y resume la información mediante componentes principales (PCA). K-means y clustering jerárquico ayudan a comparar observaciones con perfiles parecidos. En el gráfico de PCA puedes seleccionar puntos para examinarlos con más detalle.

| Caso | Qué permite estudiar |
| --- | --- |
| Perfiles metabólicos | Explorar el caso de diabetes y buscar grupos. No tiene evaluación supervisada. |
| Rendimiento académico | Explorar hábitos y resultados; predecir la nota del examen o clasificar si supera la nota anterior. |
| Analíticas sanguíneas | Explorar perfiles, predecir glucemia o estudiar una clasificación con la etiqueta coronaria disponible. |

Puedes descargar informes de exploración y evaluación en JSON. Para que el clustering jerárquico y silhouette sigan siendo manejables, utilizan una muestra reproducible de hasta 500 observaciones.

La interfaz está en español e inglés. La demo se suspende cuando no se utiliza, por lo que puede tardar en arrancar.

## Datos de la demo y resultados académicos

El repositorio público funciona con ejemplos sintéticos de semilla fija, identificados en la interfaz. No necesitas mis archivos universitarios ni una cuenta de Kaggle. Permiten probar la aplicación, pero sus resultados no describen estudiantes ni pacientes reales.

[reports/evaluation.json](reports/evaluation.json) corresponde a otra ejecución, sobre mis copias académicas locales. Su procedencia se registra mediante SHA-256 en `provenance/source-manifest.json`; los archivos de datos no se publican.

En la evaluación académica de notas, el RMSE fue 2,519 frente a 4,181 de la referencia que predice la media de entrenamiento, sobre 1.321 registros de test. El caso coronario solo tiene tres positivos en el test: no permite concluir utilidad clínica. La copia de analíticas contiene 203 registros, no los 400 del dataset original de UCI. Las versiones de estudiantes tienen notas distintas y no se han unido como si fueran un único conjunto.

## Cómo evalúo los modelos

Reservo un 20 % para el test y uso el 80 % restante para entrenar y elegir el modelo, con cinco particiones de validación cruzada y semilla 2026. En clasificación, la separación mantiene la proporción de clases.

La imputación por mediana, la codificación y el escalado se ajustan dentro de cada partición de entrenamiento. Comparo regresión convencional y logística con variantes ridge y penalizaciones `0.001, 0.01, 0.1, 1, 10`. Elijo según el error cuadrático de validación en regresión y la pérdida logarítmica en clasificación. El umbral se selecciona por F1 sobre predicciones de validación, nunca consultando el test.

Comparo cada resultado con una referencia sencilla: la media de entrenamiento o la clase mayoritaria. El informe incluye MAE, RMSE y R², y en clasificación la matriz de confusión, precisión, recall, especificidad, F1, AUC, average precision, Brier y pérdida logarítmica.

No retiro observaciones por sus residuos ni ajusto el preprocesamiento sobre el test. Los modelos coronarios excluyen `classification`. Para estudiar la mejora de estudiantes, supongo que `Previous_Scores` se conoce antes del examen y excluyo variables derivadas de la nota final.

La exploración visual puede usar todo el caso, pero sus transformaciones no se reutilizan en la evaluación. Los intervalos de predicción son aproximados: un intervalo t en regresión sin penalización y cuantiles de residuos de validación en ridge, sin garantías independientes de la distribución.

## Qué no se puede concluir

Los grupos describen semejanzas, no diagnósticos. Las asociaciones no prueban causas y clasificar bien la mejora académica no demuestra que una intervención funcione: la nota anterior influye directamente en cómo se define ese objetivo. Este proyecto permite explorar métodos estadísticos; no es una herramienta médica ni un sistema para decidir sobre estudiantes.

## Ejecutarlo en local

El proyecto se preparó con R 4.4.2. Desde la carpeta del repositorio:

```sh
Rscript setup.R
Rscript tests/run.R
Rscript run.R
```

Abre http://127.0.0.1:8504/; añade `/?lang=en` para entrar en inglés. El servidor solo escucha en tu equipo. Para restaurar las versiones registradas, instala `renv` y ejecuta:

```r
renv::restore(lockfile = "renv.lock", library = ".library", prompt = FALSE)
```

`R/` contiene los datos y modelos; `app.R`, la interfaz; `tests/`, las pruebas; y `scripts/`, las evaluaciones y comprobaciones de procedencia. `PORTFOLIO_URL` cambia el enlace de regreso y usa `http://localhost:4322` por defecto.

## Procedencia y licencia

El punto de partida fueron mis PR2, PR3 y PR4 de análisis multivariante. Los módulos se reconstruyeron para esta aplicación; no se distribuyen plantillas, enunciados ni PDF docentes. Los originales no se editan ni se mueven.

Solo si tienes acceso a los archivos académicos originales puedes reproducir ese informe:

```sh
Rscript scripts/import-academic.R /ruta/a/UOC
Rscript scripts/evaluate.R
Rscript scripts/verify-originals.R /ruta/a/UOC
```

El importador comprueba hashes antes de copiar y no sobrescribe copias modificadas. `data/local/` y `provenance/originals/` quedan fuera de Git. Paquetes y resultados se guardan aquí, nunca en la carpeta de la UOC.

El origen del caso renal se identifica como [UCI Chronic Kidney Disease](https://archive.ics.uci.edu/dataset/336/chronic+kidney+disease), de Rubini, Soundarapandian y Eswaran (2015), bajo CC BY 4.0. No he podido verificar cómo se seleccionó o transformó el subconjunto académico. Tampoco está establecida la autorización para redistribuir las copias de diabetes y estudiantes, por lo que no publico sus datos.

La licencia MIT se aplica al código propio, no a datasets ni materiales universitarios. La aplicación no admite subidas de archivos, no recoge datos personales y no llama a APIs externas de modelos.

Carlos Ramírez Martín
