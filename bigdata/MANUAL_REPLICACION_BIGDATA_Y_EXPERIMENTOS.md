---
title: "Manual de replicación: solución Big Data y experimentos"
subtitle: "Solución de Inteligencia de Negocio y Big Data para el análisis del perfil materno-neonatal (Perú, 2015–2026)"
---

# 1. Objetivo y alcance

Este manual complementa el *Manual de Reproducibilidad BI* (SQL Server y Power BI). Explica cómo reproducir desde cero: (a) la solución Big Data en Databricks, (b) la generación de datos sintéticos, (c) la preparación de SQL Server para los experimentos y (d) los cinco experimentos (B1 a B2 y D1 a D3). Cualquier persona con los archivos del repositorio y acceso a Databricks y SQL Server puede seguirlo en orden.

# 2. Requisitos

| Componente | Requisito |
|---|---|
| Databricks | Workspace con Unity Catalog y un cómputo (por ejemplo Serverless de la edición gratuita). |
| SQL Server | 2019 o superior (Developer o Express; Express limita cada base a 10 GB) y SSMS. |
| Power BI | Power BI Desktop. |
| Archivos | CSV del MINSA (`DataSet Registro Nacidos.CSV`), `Ubigeo-2016.csv` y los notebooks de `/bigdata/notebooks/`. |
| Disco local | 3 GB libres como mínimo (CSV sintéticos de 165 MB y 661 MB más las bases de datos). |

# 3. Preparar Databricks

1. En **Catalog**, dentro del catálogo `workspace`, crear el esquema `experimentobigdata` y, dentro de él, el volumen `registro_nacidos`.
2. Crear la carpeta `dataSet` dentro del volumen y subir allí `DataSet Registro Nacidos.CSV` y, opcionalmente, `Ubigeo-2016.csv` (se lee con separador `;`).
3. En **Workspace**, crear una carpeta (por ejemplo `proyecto_bigdata`) e importar en ella los 9 notebooks (00 a 08). Deben estar en la misma carpeta, porque se llaman entre sí con `%run`.
4. Abrir `00_utilidades` y confirmar que `RUTA_CSV` coincide exactamente con el nombre del archivo (se distinguen mayúsculas).

# 4. Solución Big Data (notebooks 01 a 04)

Ejecutar cada notebook en orden, celda por celda (`Shift + Enter`).

| Notebook | Qué hace | Resultado esperado |
|---|---|---|
| 01_bronze_eda | Lee el CSV, crea la tabla Bronze y el análisis exploratorio. | 1,048,575 filas y 22 columnas; 115 duplicados exactos. |
| 02_silver_limpieza | Limpia y crea la tabla Silver. | Bronze 1,048,575 y Silver 1,048,575 (retención 100.00 %). Indicadores: 1,048,575 / 6.42 % / 13.16 %. |
| 03_gold_dashboard | Crea cinco tablas Gold. | Tablas `gold_*` en Catalog. Si se sube `Ubigeo-2016.csv`, el departamento muestra su nombre. |
| 04_generacion_datos_faker | Genera datos sintéticos, escalas 5x y 10x y CSV para SQL Server. | 9,000,000 filas sintéticas (≈ 81 s); `silver_nacimientos_5x` con 5,048,575 y `_10x` con 10,048,575 filas; `sintetico_1M.csv` (≈ 165 MB) y `sintetico_4M.csv` (≈ 661 MB). |

**Dashboard.** En **Dashboards > Create dashboard**, crear cinco datasets con las consultas del notebook 03 (totales, por año, por departamento, por nivel de instrucción y por semanas de gestación) y siete visualizaciones (tres contadores, una línea y tres barras). Publicar el dashboard.

**Datos sintéticos.** Faker (es_ES) genera bloques de 10,000 filas con semilla 42 más el número de bloque, con las frecuencias del archivo real. Con la misma semilla y los mismos datos de origen, el resultado es reproducible. No se usa pandas.

# 5. Preparar SQL Server para los experimentos de BI

Los experimentos se ejecutan en una **copia** del Data Mart, porque el ETL borra las tablas `dm` en cada ejecución.

**Opción A (recomendada): respaldo y restauración.**

1. Con el Data Mart ya cargado (`SELECT COUNT(*) FROM dm.FACT_NACIMIENTO` debe dar 1,048,575), hacer un respaldo *copy-only* de `DatamartMaterno_Natal` (clic derecho en la base > Tasks > Back Up).
2. Restaurarlo con el nombre `DatamartMaterno_Natal_EXP` (clic derecho en Databases > Restore Database; en la página *Files*, los archivos de destino deben terminar en `_EXP`).
3. Verificar: `SELECT COUNT(*) FROM dm.FACT_NACIMIENTO;` y `SELECT COUNT(*) FROM stg.STG_Nacimientos;` deben dar 1,048,575.

**Opción B: desde cero en una máquina nueva.** Seguir el *Manual de Reproducibilidad BI* (DDL, tabla `stg.STG_Ubigeo`, extracción y ETL) en una base llamada `DatamartMaterno_Natal`. Después, hacer la copia de la Opción A. Si se prefiere crear directamente la base de experimentos, reemplazar el nombre de la base en los tres scripts, importar también `stg.STG_Ubigeo` en ella y ejecutarlos en orden.

**Archivos para los experimentos.** Descargar de Databricks (Catalog > `export_sql`) `sintetico_1M.csv` y `sintetico_4M.csv` y copiarlos a `C:\DATASET\`.

# 6. Experimentos de BI (B1 a B2)

**Importante:** los scripts `EXTRACCION DE DATOS.sql` y `TRANSFORMACION_Y_CARGA_DE_DATOS.sql` empiezan con `USE DatamartMaterno_Natal;`. Para no modificar el Data Mart original, guardar copias (`EXTRACCION_EXP.sql` y `TRANSFORMACION_EXP.sql`), reemplazar en ellas el nombre de la base por `DatamartMaterno_Natal_EXP` y, en `EXTRACCION_EXP.sql`, borrar los pasos 6 y 7 del final.

1. Abrir `EXPERIMENTOS_BI.sql` en SSMS y ejecutar el **PASO 0** (crea `log.EXPERIMENTOS`, `log.INICIO` y los procedimientos `log.sp_inicio` y `log.sp_fin`).
2. **B1 (ETL con volumen):** en `TRANSFORMACION_EXP.sql`, agregar `EXEC log.sp_inicio 'B1', 'sql_etl_1x', 1;` debajo del `USE` y `EXEC log.sp_fin;` al final, y ejecutarlo completo con un solo F5 (3 repeticiones, cambiando el último número). Para 2x, agregar al staging `sintetico_1M.csv` con el bloque «CARGAR SINTETICO» (debe dar 2,048,575 filas). Para 5x, reiniciar el staging con `EXTRACCION_EXP.sql` y cargar `sintetico_4M.csv` (5,048,575 filas).
3. **B2 (índices en la tabla de hechos):** con el Data Mart 5x cargado, ejecutar el *bloque de medición* tres veces, una por variante (`sin_indices`, `indice_cubriente` y `columnstore`), creando el índice correspondiente antes de cada una.

# 7. Experimentos de Big Data (D1 a D3)

Ejecutar los notebooks `05_exp_D1_escalabilidad`, `06_exp_D2_particionado` y `07_exp_D3_etl_spark_vs_sql`. Cada medición hace 1 ejecución de calentamiento (no se cuenta) y 3 repeticiones, y guarda su fila en la tabla `resultados_experimentos`. El notebook 07 usa los tiempos de SQL de B1, que ya vienen cargados.

# 8. Consolidación

En el notebook `08_consolidacion_resultados`, los tiempos de B1 y B2 ya vienen cargados. Pegar los tiempos de B3 y B4 (de `log.EXPERIMENTOS` y de Power BI) en la lista `BI`, ejecutar y obtener la tabla consolidada. Con ella se arman las tablas 6.3 y 6.5 del informe.

# 9. Lista de verificación

| Control | Valor esperado |
|---|---|
| Filas del CSV, Bronze y Silver 1x | 1,048,575 |
| Indicadores I1 / I2 / I3 | 1,048,575 / 6.42 % / 13.16 % |
| Datos sintéticos | 9,000,000 filas; 6.44 % de bajo peso y 13.15 % de madres adolescentes |
| Escalas | 5,048,575 y 10,048,575 filas |
| Data Mart y copia de experimentos | 1,048,575 filas en `dm.FACT_NACIMIENTO` |

# 10. Problemas frecuentes

| Síntoma | Causa y solución |
|---|---|
| `Path does not exist` en Databricks | El nombre del archivo en `RUTA_CSV` no coincide exactamente (mayúsculas y espacios). |
| `Ubigeo cannot be resolved` | El archivo se lee con separador `;`. Usar `sep=";"` en la lectura del catálogo. |
| El dashboard de Power BI muestra 1,046 mill. | El Data Mart no tiene la corrección de los `LEFT JOIN`: ejecutar de nuevo el ETL y actualizar el modelo. |
| «Access denied» al hacer el respaldo | Usar la carpeta de respaldo que SSMS propone por defecto. |
| Error de «archivo ya existe» al restaurar | Cambiar los nombres de los archivos de destino a `..._EXP` en la página *Files*. |
| `DROP COLUMN column5, column6` falla | Ya se ejecutó antes. Omitir ese paso. |
| Cambiar la configuración de Spark da error | El cómputo serverless no permite algunas configuraciones; el notebook 08 las omite y mide `repartition`. |
