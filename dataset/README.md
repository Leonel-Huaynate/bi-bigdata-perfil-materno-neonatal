# 📂 Datasets del Proyecto Materno-Neonatal

Esta carpeta documenta los archivos crudos (origen) utilizados para alimentar la tabla Staging de nuestra base de datos.

## 📄 Archivos incluidos en el repositorio

*   `STG_Ubigeo.csv`: Catálogo oficial de distritos, provincias y departamentos del Perú. Se procesó agregando ceros a la izquierda para garantizar el cruce relacional.
*   `muestra_nacimientos.csv`: Muestra representativa (1,000 registros) de los Certificados de Nacido Vivo del MINSA para validar la estructura del código sin saturar GitHub.

## 🔗 Dataset Completo (Para Reproducibilidad Local)
Debido al límite de 100MB por archivo en GitHub, el dataset original del MINSA (~1.05 millones de registros) que alimenta la `STG_Nacimientos` ha sido alojado en la nube.
*   **👉 [DESCARGAR DATASET COMPLETO AQUÍ] https://comunidadupnedu-my.sharepoint.com/:x:/g/personal/n00419446_upn_pe/cQqC6-Eoc7AvQ7trsgouk_6-EgUC37RMoqGAUiEqMgAOdcIzaQ **

## 🛠️ Mitigación de Errores de Calidad de Datos
Durante el diseño del ETL, descubrimos y solucionamos estas anomalías del archivo original:
1.  **Datos desplazados:** Valores de texto (como `' PERU '`) aparecían incrustados en columnas numéricas de edad y fechas. Se solucionó blindando las inserciones con la función `TRY_CAST` en SQL Server.
2.  **Valores de negocio:** Traducción de códigos internos (País Madre '1' o '2') mediante estructuras `CASE`.
3.  **Gestión de Nulos:** Los datos en blanco fueron normalizados al valor `-1` para métricas o `'IGNORADO'` para datos categóricos usando `ISNULL` y `NULLIF`.