/* =====================================================================================
   EXPERIMENTOS BI (SQL Server) - Proyecto Materno-Neonatal
   Experimentos incluidos:
     B1 (Huaynate)  : tiempo de carga + ETL al crecer el volumen (1x, 2x, 5x)
     B2 (Andrade)   : indices en la tabla de hechos (sin indices / cubriente / columnstore)

   ANTES DE EMPEZAR (IMPORTANTE)
   1. NO uses la base del dashboard. Crea una COPIA con otro nombre restaurando un respaldo:
      respaldo (copy-only) de DatamartMaterno_Natal y restauracion como DatamartMaterno_Natal_EXP
      (SSMS: clic derecho en la base > Tasks > Back Up; luego clic derecho en Databases > Restore Database).
      No hace falta volver a ejecutar los 3 scripts: la copia ya trae el modelo, los datos y la tabla
      stg.STG_Ubigeo (que se cargo con el asistente de importacion y no esta en los scripts).
   2. Copia los CSV sinteticos descargados de Databricks a C:\DATASET\ (sintetico_1M.csv, sintetico_4M.csv).
   3. Mide siempre con la misma maquina, sin otros programas pesados abiertos.
   NOTA: este script no se pudo ejecutar en el entorno de desarrollo (sin SQL Server). Pruebalo primero con
   sintetico_1M.csv. Si algo falla, copia el mensaje de error.
   ===================================================================================== */

USE DatamartMaterno_Natal_EXP;
GO

/* ---------------------------------------------------------------------------
   PASO 0. Tablas y procedimientos para registrar los tiempos
   --------------------------------------------------------------------------- */
IF SCHEMA_ID('log') IS NULL EXEC('CREATE SCHEMA log');
GO
IF OBJECT_ID('log.EXPERIMENTOS') IS NULL
    CREATE TABLE log.EXPERIMENTOS (
        id INT IDENTITY PRIMARY KEY,
        experimento VARCHAR(30), variante VARCHAR(60), repeticion INT,
        segundos FLOAT, filas BIGINT NULL, fecha DATETIME2 DEFAULT SYSDATETIME());
IF OBJECT_ID('log.INICIO') IS NULL
    CREATE TABLE log.INICIO (experimento VARCHAR(30), variante VARCHAR(60), repeticion INT, momento DATETIME2);
GO
CREATE OR ALTER PROCEDURE log.sp_inicio @exp VARCHAR(30), @var VARCHAR(60), @rep INT AS
BEGIN
    DELETE FROM log.INICIO;
    INSERT log.INICIO VALUES (@exp, @var, @rep, SYSDATETIME());
END
GO
CREATE OR ALTER PROCEDURE log.sp_fin @filas BIGINT = NULL AS
BEGIN
    INSERT log.EXPERIMENTOS (experimento, variante, repeticion, segundos, filas)
    SELECT experimento, variante, repeticion, DATEDIFF_BIG(MILLISECOND, momento, SYSDATETIME()) / 1000.0, @filas
    FROM log.INICIO;
END
GO


/* ===========================================================================
   B1. CARGA + ETL AL CRECER EL VOLUMEN  (Huaynate)
   Escenarios: 1x = CSV real | 2x = real + sintetico_1M | 5x = real + sintetico_4M
   Para cada escenario y cada repeticion (3 en 1x y 2x; 1 en 5x si hay poco tiempo):
     a) Ejecuta EXTRACCION DE DATOS.sql (recrea stg.STG_Nacimientos con el CSV real).
     b) Si el escenario es 2x o 5x, ejecuta el bloque "CARGAR SINTETICO" de abajo (cambia la ruta).
     c) Marca el inicio, ejecuta TRANSFORMACION_Y_CARGA_DE_DATOS.sql y marca el fin.
   El tiempo que se registra es solo el del ETL (stg -> dm). Si tambien quieres incluir la carga del
   CSV, pon el sp_inicio ANTES de (a) y el sp_fin despues de (c).
   =========================================================================== */

/* --- CARGAR SINTETICO: agrega las filas ficticias al staging (sin borrar lo que ya hay) --- */
IF OBJECT_ID('tempdb..#Raw') IS NOT NULL DROP TABLE #Raw;
SELECT TOP 0 * INTO #Raw FROM stg.STG_Nacimientos;

BULK INSERT #Raw
FROM 'C:\DATASET\sintetico_4M.csv'          -- cambia a sintetico_4M.csv o sintetico_1M.csv depedendiedo el escenario
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

INSERT INTO stg.STG_Nacimientos WITH (TABLOCK)
SELECT
    LTRIM(RTRIM(REPLACE(FecNac_Año, '"', ''))), LTRIM(RTRIM(REPLACE(FecNac_Mes, '"', ''))),
    LTRIM(RTRIM(REPLACE(PESO_NACIDO, '"', ''))), LTRIM(RTRIM(REPLACE(TALLA_NACIDO, '"', ''))),
    LTRIM(RTRIM(REPLACE(DUR_EMB_PARTO, '"', ''))), LTRIM(RTRIM(REPLACE(Condicion_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(sexo_nacido, '"', ''))), LTRIM(RTRIM(REPLACE(Tipo_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(Edad_Madre, '"', ''))), LTRIM(RTRIM(REPLACE(Estado_Civil, '"', ''))),
    LTRIM(RTRIM(REPLACE(Nivel_Intruccion_Madre, '"', ''))), LTRIM(RTRIM(REPLACE(DESC_OCUPACION, '"', ''))),
    LTRIM(RTRIM(REPLACE(Num_embar_madre, '"', ''))), LTRIM(RTRIM(REPLACE(Hijos_vivo_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Hijos_fallec_madre, '"', ''))), LTRIM(RTRIM(REPLACE(nacmuer_abort_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Pais_Madre, '"', ''))), LTRIM(RTRIM(REPLACE(IdUbigeoInei, '"', ''))),
    LTRIM(RTRIM(REPLACE(Ipress, '"', ''))), LTRIM(RTRIM(REPLACE(Lugar_Nacido, '"', ''))),
    LTRIM(RTRIM(REPLACE(Atiende_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(Financiador_Parto, ';', ''), '"', ''), CHAR(13), ''), CHAR(10), '')))
FROM #Raw;
DROP TABLE #Raw;
SELECT COUNT(*) AS filas_en_staging FROM stg.STG_Nacimientos;   -- 2x debe dar 2,048,575 | 5x: 5,048,575
GO

/* --- PATRON DE MEDICION DEL ETL (repite 3 veces por escenario) ---
   Cada ejecucion se ejecuta en TRES pasos, cada uno por separado:

   Paso 1:   EXEC log.sp_inicio 'B1', 'sql_etl_2x', 1;      -- (cambia variante y repeticion)
   Paso 2:   ejecuta TRANSFORMACION_Y_CARGA_DE_DATOS.sql completo
   Paso 3:   EXEC log.sp_fin @filas = 2048575;

   Resultados:
   SELECT experimento, variante, repeticion, segundos FROM log.EXPERIMENTOS WHERE experimento = 'B1' ORDER BY variante, repeticion;
*/

/* ===========================================================================
   B2. INDICES EN LA TABLA DE HECHOS  (Andrade)
   Requiere el Data Mart cargado con el escenario grande (2x o 5x).
   Compara la misma consulta con 3 configuraciones:  sin indices | indice cubriente | columnstore.
   Cada variante: crear/dejar el indice, medir 3 veces con cache limpia.
   =========================================================================== */

/* Limpieza: deja la tabla solo con su clave primaria */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FACT_cubriente' AND object_id = OBJECT_ID('dm.FACT_NACIMIENTO'))
    DROP INDEX IX_FACT_cubriente ON dm.FACT_NACIMIENTO;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'NCCI_FACT' AND object_id = OBJECT_ID('dm.FACT_NACIMIENTO'))
    DROP INDEX NCCI_FACT ON dm.FACT_NACIMIENTO;
GO

/* ---------------------------------------------------------------------------
   BLOQUE DE MEDICION B2 (se repite igual en las 3 variantes; solo cambia @variante).
   Mide la consulta 3 veces, cada una con cache limpia, y guarda cada tiempo en log.EXPERIMENTOS.
   --------------------------------------------------------------------------- */
DECLARE @variante VARCHAR(60) = 'columnstore';        -- <-- cambia: 'sin_indices' | 'indice_cubriente' | 'columnstore'
DECLARE @i INT = 1, @t0 DATETIME2, @filas BIGINT = (SELECT COUNT_BIG(*) FROM dm.FACT_NACIMIENTO);
WHILE @i <= 3
BEGIN
    CHECKPOINT;
    DBCC DROPCLEANBUFFERS;
    DBCC FREEPROCCACHE;
    SET @t0 = SYSDATETIME();
    SELECT T.año, U.departamento,
           COUNT(*) AS total, SUM(F.ind_bajo_peso) AS n_bajo_peso,
           SUM(CASE WHEN F.peso_gramos > 0 THEN 1 ELSE 0 END) AS n_con_peso,
           SUM(F.ind_madre_adolesc) AS n_adolescentes
    INTO #r
    FROM dm.FACT_NACIMIENTO F
    JOIN dm.DIM_TIEMPO T ON T.id_tiempo = F.id_tiempo
    JOIN dm.DIM_UBICACION U ON U.id_ubicacion = F.id_ubicacion
    GROUP BY T.año, U.departamento;
    INSERT log.EXPERIMENTOS (experimento, variante, repeticion, segundos, filas)
    VALUES ('B2', @variante, @i, DATEDIFF_BIG(MILLISECOND, @t0, SYSDATETIME()) / 1000.0, @filas);
    DROP TABLE #r;
    SET @i += 1;
END
SELECT variante, repeticion, segundos, filas FROM log.EXPERIMENTOS WHERE experimento = 'B2' AND variante = @variante ORDER BY repeticion;
GO

/* --- VARIANTE 1: sin indices. Ejecuta el BLOQUE DE MEDICION con @variante = 'sin_indices'.
       Luego: EXEC sp_spaceused 'dm.FACT_NACIMIENTO';*/

/* --- VARIANTE 2: indice cubriente (rowstore). Crea el indice, luego ejecuta el BLOQUE con @variante = 'indice_cubriente' --- */
CREATE NONCLUSTERED INDEX IX_FACT_cubriente
    ON dm.FACT_NACIMIENTO (id_tiempo, id_ubicacion)
    INCLUDE (peso_gramos, ind_bajo_peso, ind_madre_adolesc);
GO
EXEC sp_spaceused 'dm.FACT_NACIMIENTO';      
GO

/* --- VARIANTE 3: columnstore no agrupado. Quita el indice anterior, crea el columnstore y ejecuta el BLOQUE con @variante = 'columnstore' --- */
DROP INDEX IX_FACT_cubriente ON dm.FACT_NACIMIENTO;
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FACT
    ON dm.FACT_NACIMIENTO (id_tiempo, id_ubicacion, peso_gramos, ind_bajo_peso, ind_madre_adolesc);
GO
EXEC sp_spaceused 'dm.FACT_NACIMIENTO';       -- captura el resultado
GO
/* Al terminar, dejar la tabla como estaba: */
DROP INDEX NCCI_FACT ON dm.FACT_NACIMIENTO;
GO
SELECT variante, repeticion, segundos
FROM log.EXPERIMENTOS WHERE experimento = 'B2'
ORDER BY variante, repeticion;
