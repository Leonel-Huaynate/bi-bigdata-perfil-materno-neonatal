USE DatamartMaterno_Natal_EXP;
GO

-- 1. Asegurar que el esquema stg exista
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

-- 2. Reiniciar las tablas (Staging final + tabla temporal de aterrizaje crudo)
DROP TABLE IF EXISTS stg.STG_Nacimientos;
DROP TABLE IF EXISTS #RawNacimientos;
GO

CREATE TABLE stg.STG_Nacimientos (
    FecNac_Año VARCHAR(255),
    FecNac_Mes VARCHAR(255),
    PESO_NACIDO VARCHAR(255),
    TALLA_NACIDO VARCHAR(255),
    DUR_EMB_PARTO VARCHAR(255),
    Condicion_Parto VARCHAR(255),
    sexo_nacido VARCHAR(255),
    Tipo_Parto VARCHAR(255),
    Edad_Madre VARCHAR(255),
    Estado_Civil VARCHAR(255),
    Nivel_Intruccion_Madre VARCHAR(255),
    DESC_OCUPACION VARCHAR(255),
    Num_embar_madre VARCHAR(255),
    Hijos_vivo_madre VARCHAR(255),
    Hijos_fallec_madre VARCHAR(255),
    nacmuer_abort_madre VARCHAR(255),
    Pais_Madre VARCHAR(255),
    IdUbigeoInei VARCHAR(255),
    Ipress VARCHAR(255),
    Lugar_Nacido VARCHAR(255),
    Atiende_Parto VARCHAR(255),
    Financiador_Parto VARCHAR(255)
);

-- Tabla temporal en tempdb con la misma estructura para recibir el CSV crudo
SELECT TOP 0 * INTO #RawNacimientos FROM stg.STG_Nacimientos;
GO

-- 3. Extracción masiva del CSV hacia la tabla temporal (ajusta la ruta si cambia de PC)
BULK INSERT #RawNacimientos
FROM 'C:\DATASET\DataSet Registro Nacidos.CSV'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    TABLOCK
);
GO

-- 4. Inserción limpia en stg.STG_Nacimientos (elimina '"', ';;;;;' y saltos de línea sin UPDATE)
INSERT INTO stg.STG_Nacimientos WITH (TABLOCK)
SELECT
    LTRIM(RTRIM(REPLACE(FecNac_Año, '"', ''))),
    LTRIM(RTRIM(REPLACE(FecNac_Mes, '"', ''))),
    LTRIM(RTRIM(REPLACE(PESO_NACIDO, '"', ''))),
    LTRIM(RTRIM(REPLACE(TALLA_NACIDO, '"', ''))),
    LTRIM(RTRIM(REPLACE(DUR_EMB_PARTO, '"', ''))),
    LTRIM(RTRIM(REPLACE(Condicion_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(sexo_nacido, '"', ''))),
    LTRIM(RTRIM(REPLACE(Tipo_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(Edad_Madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Estado_Civil, '"', ''))),
    LTRIM(RTRIM(REPLACE(Nivel_Intruccion_Madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(DESC_OCUPACION, '"', ''))),
    LTRIM(RTRIM(REPLACE(Num_embar_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Hijos_vivo_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Hijos_fallec_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(nacmuer_abort_madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(Pais_Madre, '"', ''))),
    LTRIM(RTRIM(REPLACE(IdUbigeoInei, '"', ''))),
    LTRIM(RTRIM(REPLACE(Ipress, '"', ''))),
    LTRIM(RTRIM(REPLACE(Lugar_Nacido, '"', ''))),
    LTRIM(RTRIM(REPLACE(Atiende_Parto, '"', ''))),
    LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(Financiador_Parto, ';', ''), '"', ''), CHAR(13), ''), CHAR(10), '')))
FROM #RawNacimientos;

DROP TABLE #RawNacimientos;
GO

-- 5. Verificación inmediata: FecNac_Año sale como 2024 y Financiador_Parto como SIS
SELECT TOP 20 * FROM stg.STG_Nacimientos;
SELECT COUNT(*) AS Total_Filas_Staging FROM stg.STG_Nacimientos;
GO
