# bi-bigdata-perfil-materno-neonatal

Solución integral de Business Intelligence (SQL Server y Power BI) y Big Data (Databricks y Apache Spark) para analizar el perfil materno-neonatal en el Perú (2015–2026), con datos abiertos del MINSA. Incluye cinco experimentos de rendimiento (dos de BI y tres de Big Data).

**Curso:** Base de Datos Avanzadas y Big Data · UPN · 2026-2
**Equipo:** Andrade Pablo P.; Carranza Córdova M.; Huaynate Miramira L.; Prudencio Huaman A.; Quispe Guevara G.
**Versión:** v2.0-Entrega-Final

## Estructura del repositorio

```
├── README.md
├── dataset/            Muestra del dataset, catálogo de ubigeo y ficha de procedencia
├── bi/
│   ├── sql/ddl/        ESTRUCTURA_MODELO_ESTRELLA.sql
│   ├── sql/etl/        EXTRACCION DE DATOS.sql y TRANSFORMACION_Y_CARGA_DE_DATOS.sql
│   ├── sql/experimentos/  EXPERIMENTOS_BI.sql
│   └── powerbi/        Archivo .pbix del dashboard
├── bigdata/
│   └── notebooks/      Notebooks 00 a 08 de Databricks (.ipynb)
├── evidencias/
│   ├── bi/             Capturas de la solución BI
│   ├── bigdata/        Capturas de notebooks, tablas y dashboard de Databricks
│   └── experimentos/   Capturas y tiempos de los cinco experimentos
└── documentacion/      Informe, manual de reproducibilidad y diagramas de arquitectura
```

## Dataset

Fuente: Registro de Certificados de Nacido Vivo del MINSA (datos abiertos). El archivo procesado tiene 1,048,575 filas de datos y 22 columnas (delimitador `;`, UTF-8). Su tamaño coincide con el máximo de filas de una hoja de Excel, por lo que podría estar truncado; se recomienda verificarlo con la fuente.

El archivo completo supera el límite de GitHub para subidas por navegador, por lo que en `dataset/` se incluye una muestra y la ficha de procedencia. Enlace al archivo completo: **[COMPLETAR: enlace]**. Los CSV sintéticos no se suben: se regeneran con el notebook 04.

## Solución BI (SQL Server y Power BI)

1. Ejecutar `bi/sql/ddl/ESTRUCTURA_MODELO_ESTRELLA.sql`.
2. Copiar el CSV a `C:\DATASET\` y ejecutar `bi/sql/etl/EXTRACCION DE DATOS.sql`.
3. Ejecutar `bi/sql/etl/TRANSFORMACION_Y_CARGA_DE_DATOS.sql`.
4. Abrir el `.pbix` y actualizar. Valores esperados: 1,048,575 nacimientos, 6.42 % de bajo peso y 13.16 % de madres adolescentes.

## Solución Big Data (Databricks)

Requisitos: workspace de Databricks con Unity Catalog, volumen `workspace.experimentobigdata.registro_nacidos` y el CSV en su carpeta `dataSet`.

1. Importar los notebooks de `bigdata/notebooks/` en una misma carpeta (Workspace > Import).
2. Ejecutar en orden: `01_bronze_eda`, `02_silver_limpieza`, `03_gold_dashboard`, `04_generacion_datos_faker`. El notebook `00_utilidades` lo llaman los demás con `%run`.
3. Crear el dashboard con los pasos del notebook 03.

Arquitectura Medallion: Bronze (texto crudo), Silver (limpio, particionado por año) y Gold (indicadores), todas en tablas Delta. Todo el procesamiento usa Python con Spark; no se utiliza pandas.

## Experimentos

| ID | Solución | Experimento | Responsables | Dónde |
|---|---|---|---|---|
| B1 | BI | Tiempo del ETL con volumen (1x, 2x, 5x) | Huaynate, Carranza y Prudencio | `EXPERIMENTOS_BI.sql` |
| B2 | BI | Índices en la tabla de hechos | Andrade y Quispe | `EXPERIMENTOS_BI.sql` |
| D1 | Big Data | Escalabilidad en volumen | Prudencio y Quispe | notebook 05 |
| D2 | Big Data | Partición por año | Andrade y Carranza | notebook 06 |
| D3 | Big Data | ETL en Spark frente a SQL Server | Huaynate | notebook 07 |

Procedimiento: generar los datos sintéticos (notebook 04), copiar `sintetico_1M.csv` y `sintetico_4M.csv` a `C:\DATASET\`, ejecutar los experimentos de BI (B1 y B2) en una copia de la base (`DatamartMaterno_Natal_EXP`), ejecutar los notebooks 05 a 07, consolidar en el notebook 08 (los tiempos de B1 y B2 ya vienen cargados). Cada medición usa 3 repeticiones (y 1 calentamiento en Spark).

## Uso de inteligencia artificial

La declaración completa está en el informe (sección 5.7 y anexo I).

## Licencia

MIT License
