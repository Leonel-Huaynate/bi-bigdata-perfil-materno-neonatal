# bi-bigdata-perfil-materno-neonatal
Solución integral de Business Intelligence y procesamiento distribuido (Big Data) para el análisis histórico y comparativo del perfil materno-neonatal en el Perú (2015-2026), procesando más de 1 millón de registros del MINSA.

# Solución de BI y Big Data: Análisis del Perfil Materno-Neonatal en Perú 🏥📊🚀

Este repositorio contiene la implementación de un sistema analítico (Business Intelligence y, próximamente, arquitectura Big Data) diseñado para analizar los cambios en el perfil materno-neonatal de los nacimientos registrados en el Perú (2015-2026). El proyecto utiliza datos abiertos del Ministerio de Salud (MINSA).

## 📂 Estructura del Repositorio

El proyecto está organizado de forma modular:

*   `/bi/sql/`: Scripts T-SQL para la creación del Data Warehouse (Esquema Estrella) y los procesos de carga (ETL defensivo con `TRY_CAST`).
*   `/bi/powerbi/`: Archivo `.pbix` con el modelo semántico relacional y los dashboards interactivos.
*   `/bigdata/`: Espacio reservado para los futuros scripts de procesamiento distribuido (Spark/Hadoop) para el análisis comparativo de la presentación final.
*   `/docs/`: Informes técnicos, documentación del proyecto (T2) y matrices de resultados experimentales.
*   `/dataset/`: Catálogos, muestras de los datos crudos y enlaces al dataset pesado para reproducibilidad.

## 🛠️ Tecnologías y Entorno
*   **Motor BD:** SQL Server 2019 / 2022 (Developer Edition).
*   **Gestor BD:** SQL Server Management Studio (SSMS) v19+.
*   **Visualización:** Power BI Desktop.

## 🚀 Instrucciones de Ejecución (Para el Profesor)
Para replicar esta solución desde cero en un entorno local:
1. Clona este repositorio o descarga el archivo ZIP.
2. Descarga el dataset completo de nacimientos desde el enlace ubicado en `/dataset/README.md`.
3. Abre SSMS y ejecuta los scripts ubicados en `/bi/sql/` para crear la base de datos `dm` y cargar las tablas staging.
4. Ejecuta el script ETL para poblar las dimensiones y realizar el cruce seguro de más de 1.04 millones de registros hacia la `FACT_NACIMIENTO`.
5. Abre el dashboard en `/bi/powerbi/` y actualiza las credenciales de origen de datos al servidor local.

## 🛡️ Ética, Privacidad y Responsabilidad
Se han aplicado procesos de anonimización y limpieza; el dataset procesado no contiene Información de Identificación Personal (PII) como nombres o DNI, cumpliendo rigurosamente con la Ley N° 29733 de Protección de Datos Personales del Perú.
