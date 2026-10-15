# bi-bigdata-perfil-materno-neonatal
Solución integral de Business Intelligence y procesamiento distribuido (Big Data) para el análisis histórico y comparativo del perfil materno-neonatal en el Perú (2015-2026), procesando más de 1 millón de registros del MINSA.

# Solución de BI y Big Data: Análisis del Perfil Materno-Neonatal en Perú 🏥📊🚀

Este repositorio contiene la implementación completa de un sistema analítico híbrido (Business Intelligence tradicional + Arquitectura Big Data) diseñado para analizar los cambios en el perfil materno-neonatal de los nacimientos registrados en el Perú (2015-2026). El proyecto utiliza datos abiertos del Ministerio de Salud (MINSA) y está diseñado para un experimento comparativo de rendimiento y escalabilidad.

## 📂 Estructura del Repositorio

El proyecto está organizado de forma modular separando ambos enfoques tecnológicos:

### 📊 Solución BI (Business Intelligence)
*   `/bi/sql/ddl/`: Scripts T-SQL para la creación del Data Warehouse (Esquema Estrella).
*   `/bi/sql/etl/`: Scripts de extracción, transformación defensiva (`TRY_CAST`) y carga.
*   `/bi/powerbi/`: Archivos `.pbix` con el modelo semántico relacional y dashboards interactivos.

### 🚀 Solución Big Data (Procesamiento Distribuido)
*   `/bigdata/ingesta/`: Scripts para la ingesta masiva de datos en el Data Lake.
*   `/bigdata/notebooks/`: Notebooks (ej. Jupyter / Databricks) con código PySpark/Scala para transformación y limpieza distribuida.
*   `/bigdata/experimentos/`: Scripts de benchmarking para medir latencia, throughput y uso de recursos (CPU/RAM/Nodos).

### 📄 Documentación y Datos
*   `/docs/`: Informes técnicos, diccionario de datos y matrices de resultados experimentales.
*   `/dataset/`: Muestra del dataset original anonimizado y enlaces a la fuente pública.

## 🛠️ Tecnologías y Entorno

**Entorno BI:**
*   Motor BD: SQL Server 2019+ (Developer Edition)
*   Herramientas: SQL Server Management Studio (SSMS), Power BI Desktop

**Entorno Big Data (En desarrollo):**
*   Procesamiento: Apache Spark / PySpark
*   Almacenamiento: HDFS / Data Lake (AWS S3, Azure Data Lake o Hadoop local)
*   Lenguajes: Python, SQL

## ⚙️ Instrucciones de Ejecución y Reproducibilidad

### Fase 1: Despliegue de la Solución BI
1.  Clonar este repositorio.
2.  Ejecutar los scripts de `/bi/sql/ddl/` en SQL Server para preparar la base de datos `dm`.
3.  Cargar el CSV de nacimientos en la tabla staging.
4.  Ejecutar los scripts de `/bi/sql/etl/` para poblar las 5 dimensiones y finalmente la tabla de hechos `FACT_NACIMIENTO` (asegurando el cruce de ~1.04M registros).
5.  Abrir el dashboard en `/bi/powerbi/` y actualizar las credenciales del origen de datos.

### Fase 2: Despliegue de la Solución Big Data
1.  Configurar el entorno distribuido o clúster local (ver `/docs/configuracion_cluster.md`).
2.  Ejecutar los notebooks ubicados en `/bigdata/notebooks/` para aplicar el particionamiento y procesamiento masivo sobre los datos crudos.
3.  Ejecutar las consultas de validación en el motor distribuido.

### Fase 3: Ejecución del Experimento Comparativo
*   Para replicar los escenarios del Capítulo IV, ejecutar el script de benchmarking ubicado en `/bigdata/experimentos/run_tests.py` (o .sh), el cual capturará la latencia y throughput de ambas arquitecturas para generar la matriz comparativa de resultados.

## 🛡️ Ética, Privacidad y Responsabilidad
Este proyecto utiliza datos de acceso público del MINSA con fines estrictamente académicos e investigativos. Se han aplicado procesos de anonimización; ningún dataset procesado o mostrado contiene Información de Identificación Personal (PII) como nombres, apellidos o DNI, cumpliendo rigurosamente con la Ley N° 29733 de Protección de Datos Personales del Perú.
