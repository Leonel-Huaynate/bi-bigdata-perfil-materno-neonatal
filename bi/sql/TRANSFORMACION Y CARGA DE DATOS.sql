USE DatamartMaterno_Natal;
GO

-- ============================================================================
-- BLOQUE 0: LIMPIEZA PREVENTIVA E IDEMPOTENCIA
-- Objetivo: Vaciar el Data Mart respetando la integridad referencial (primero
-- la tabla de hechos y luego las 5 dimensiones) y reiniciar los IDENTITY a 0
-- para poder reejecutar el script las veces que sea necesario sin duplicados.
-- ============================================================================
DELETE FROM dm.FACT_NACIMIENTO;
DELETE FROM dm.DIM_TIEMPO;
DELETE FROM dm.DIM_UBICACION;
DELETE FROM dm.DIM_MADRE;
DELETE FROM dm.DIM_RECIEN_NACIDO;
DELETE FROM dm.DIM_PARTO;

DBCC CHECKIDENT ('dm.FACT_NACIMIENTO', RESEED, 0);
DBCC CHECKIDENT ('dm.DIM_TIEMPO', RESEED, 0);
DBCC CHECKIDENT ('dm.DIM_UBICACION', RESEED, 0);
DBCC CHECKIDENT ('dm.DIM_MADRE', RESEED, 0);
DBCC CHECKIDENT ('dm.DIM_RECIEN_NACIDO', RESEED, 0);
DBCC CHECKIDENT ('dm.DIM_PARTO', RESEED, 0);
GO

-- ============================================================================
-- BLOQUE 1: POBLAR DIMENSIÓN TIEMPO (dm.DIM_TIEMPO)
-- Limpieza aplicada:
-- - TRY_CAST(... AS INT): Convierte año y mes de forma segura sin detener la
--   carga ante textos corruptos.
-- - CASE: Traduce el número de mes (1-12) a su nombre en español.
-- - Miembro desconocido (-1, -1, 'IGNORADO'): Absorbe registros sin fecha válida.
-- ============================================================================
BEGIN
    INSERT INTO dm.DIM_TIEMPO (año, mes, nombre_mes)
    SELECT DISTINCT 
        TRY_CAST(FecNac_Año AS INT) AS año,
        TRY_CAST(FecNac_Mes AS INT) AS mes,
        CASE TRY_CAST(FecNac_Mes AS INT)
            WHEN 1  THEN 'Enero'
            WHEN 2  THEN 'Febrero'
            WHEN 3  THEN 'Marzo'
            WHEN 4  THEN 'Abril'
            WHEN 5  THEN 'Mayo'
            WHEN 6  THEN 'Junio'
            WHEN 7  THEN 'Julio'
            WHEN 8  THEN 'Agosto'
            WHEN 9  THEN 'Septiembre'
            WHEN 10 THEN 'Octubre'
            WHEN 11 THEN 'Noviembre'
            WHEN 12 THEN 'Diciembre'
            ELSE 'No registrado'
        END AS nombre_mes
    FROM stg.STG_Nacimientos
    WHERE TRY_CAST(FecNac_Año AS INT) IS NOT NULL
      AND TRY_CAST(FecNac_Mes AS INT) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM dm.DIM_TIEMPO WHERE año = -1 AND mes = -1)
    BEGIN
        INSERT INTO dm.DIM_TIEMPO (año, mes, nombre_mes)
        VALUES (-1, -1, 'IGNORADO');
    END
END
GO

-- ============================================================================
-- BLOQUE 2: POBLAR DIMENSIÓN UBICACIÓN (dm.DIM_UBICACION)
-- Limpieza aplicada:
-- - RIGHT('000000' + ..., 6): Restaura el cero a la izquierda borrado por CSV/Excel
--   en ubigeos de 5 dígitos (ej. '30209' -> '030209').
-- - Miembro desconocido ('-1'): Absorbe ubigeos vacíos, extranjeros o distritos
--   creados después del catálogo INEI 2016.
-- ============================================================================
BEGIN
    INSERT INTO dm.DIM_UBICACION (idUbigeo, departamento, provincia, distrito)
    SELECT DISTINCT 
        RIGHT('000000' + LTRIM(RTRIM(N.IdUbigeoInei)), 6) AS idUbigeo,
        UPPER(LTRIM(RTRIM(U.Departamento))) AS departamento,
        UPPER(LTRIM(RTRIM(U.Provincia))) AS provincia,
        UPPER(LTRIM(RTRIM(U.Distrito))) AS distrito
    FROM stg.STG_Nacimientos N
    INNER JOIN stg.STG_Ubigeo U 
        ON RIGHT('000000' + LTRIM(RTRIM(N.IdUbigeoInei)), 6) = RIGHT('000000' + LTRIM(RTRIM(U.Ubigeo)), 6);

    INSERT INTO dm.DIM_UBICACION (idUbigeo, departamento, provincia, distrito)
    VALUES ('-1', 'IGNORADO', 'IGNORADO', 'IGNORADO');
END
GO

-- ============================================================================
-- BLOQUE 3: POBLAR DIMENSIÓN MADRE (dm.DIM_MADRE)
-- Limpieza y reglas de negocio:
-- - Edades nulas o < 10 años (anomalías) pasan a -1.
-- - NULLIF(..., '') + ISNULL(..., 'IGNORADO') elimina cadenas vacías.
-- - Decodifica Pais_Madre ('1' -> 'PERU', '2' -> 'EXTRANJERO').
-- - Clasifica grupo_edad en 'ADOLESCENTE' (10-19 años) o 'ADULTA' (>=20).
-- ============================================================================
BEGIN
    INSERT INTO dm.DIM_MADRE (edad_madre, estado_civil, nivel_instruccion, ocupacion, pais_origen, grupo_edad)
    SELECT DISTINCT
        CASE 
            WHEN TRY_CAST(Edad_Madre AS INT) IS NULL THEN -1
            WHEN TRY_CAST(Edad_Madre AS INT) < 10 THEN -1
            ELSE TRY_CAST(Edad_Madre AS INT)
        END AS edad_madre,
        UPPER(ISNULL(NULLIF(Estado_Civil, ''), 'IGNORADO')) AS estado_civil,
        UPPER(ISNULL(NULLIF(Nivel_Intruccion_Madre, ''), 'IGNORADO')) AS nivel_instruccion,
        UPPER(ISNULL(NULLIF(DESC_OCUPACION, ''), 'IGNORADO')) AS ocupacion,
        CASE 
            WHEN Pais_Madre = '1' THEN 'PERU'
            WHEN Pais_Madre = '2' THEN 'EXTRANJERO'
            WHEN ISNUMERIC(Pais_Madre) = 1 THEN 'IGNORADO'
            ELSE UPPER(ISNULL(NULLIF(Pais_Madre, ''), 'IGNORADO'))
        END AS pais_origen,
        CASE 
            WHEN TRY_CAST(Edad_Madre AS INT) IS NULL THEN 'IGNORADO'
            WHEN TRY_CAST(Edad_Madre AS INT) < 10 THEN 'IGNORADO'
            WHEN TRY_CAST(Edad_Madre AS INT) BETWEEN 10 AND 19 THEN 'ADOLESCENTE'
            ELSE 'ADULTA'
        END AS grupo_edad
    FROM stg.STG_Nacimientos;

    -- Asegura que exista el perfil comodín completo en 'IGNORADO'
    IF NOT EXISTS (
        SELECT 1 FROM dm.DIM_MADRE 
        WHERE edad_madre = -1 AND estado_civil = 'IGNORADO' 
          AND nivel_instruccion = 'IGNORADO' AND ocupacion = 'IGNORADO' 
          AND pais_origen = 'IGNORADO'
    )
    BEGIN
        INSERT INTO dm.DIM_MADRE (edad_madre, estado_civil, nivel_instruccion, ocupacion, pais_origen, grupo_edad)
        VALUES (-1, 'IGNORADO', 'IGNORADO', 'IGNORADO', 'IGNORADO', 'IGNORADO');
    END
END
GO

-- ============================================================================
-- BLOQUE 4: POBLAR DIMENSIÓN RECIÉN NACIDO (dm.DIM_RECIEN_NACIDO)
-- Limpieza aplicada:
-- - Estandariza sexo en mayúsculas y convierte semanas de gestación (INT) y
--   talla (DECIMAL(4,1)) asignando -1 / -1.0 ante valores vacíos o inválidos.
-- ============================================================================
BEGIN
    INSERT INTO dm.DIM_RECIEN_NACIDO (sexo, tiempo_gestacion, talla_nacido)
    SELECT DISTINCT 
        UPPER(ISNULL(NULLIF(sexo_nacido, ''), 'IGNORADO')) AS sexo,
        ISNULL(TRY_CAST(NULLIF(DUR_EMB_PARTO, '') AS INT), -1) AS tiempo_gestacion,
        ISNULL(TRY_CAST(NULLIF(TALLA_NACIDO, '') AS DECIMAL(4,1)), -1.0) AS talla_nacido
    FROM stg.STG_Nacimientos;

    -- Asegura que exista el perfil comodín completo en 'IGNORADO'
    IF NOT EXISTS (
        SELECT 1 FROM dm.DIM_RECIEN_NACIDO 
        WHERE sexo = 'IGNORADO' AND tiempo_gestacion = -1 AND talla_nacido = -1.0
    )
    BEGIN
        INSERT INTO dm.DIM_RECIEN_NACIDO (sexo, tiempo_gestacion, talla_nacido)
        VALUES ('IGNORADO', -1, -1.0);
    END
END
GO

-- ============================================================================
-- BLOQUE 5: POBLAR DIMENSIÓN PARTO (dm.DIM_PARTO)
-- Restricción aplicada (Lista Blanca Oficial MINSA):
-- - Acepta ÚNICAMENTE las 9 categorías oficiales de Financiador_Parto para
--   garantizar que ningún texto desplazado (ej. 'IGNORADOESSALUD') contamine
--   los filtros de Power BI. Las filas desplazadas se redirigen al miembro
--   desconocido 'IGNORADO' mediante LEFT JOIN en el Bloque 6 sin perderse.
-- ============================================================================
BEGIN
    INSERT INTO dm.DIM_PARTO (condicion_parto, tipo_parto, lugar_nacido, atiende_parto, financiador_parto)
    SELECT DISTINCT 
        UPPER(ISNULL(NULLIF(Condicion_Parto, ''), 'IGNORADO')) AS condicion_parto,
        UPPER(ISNULL(NULLIF(Tipo_Parto, ''), 'IGNORADO')) AS tipo_parto,
        CASE 
            WHEN TRY_CAST(Lugar_Nacido AS INT) IS NOT NULL THEN 'ESTABLECIMIENTO DE SALUD'
            ELSE UPPER(ISNULL(NULLIF(Lugar_Nacido, ''), 'IGNORADO'))
        END AS lugar_nacido,
        UPPER(ISNULL(NULLIF(Atiende_Parto, ''), 'IGNORADO')) AS atiende_parto,
        UPPER(ISNULL(NULLIF(Financiador_Parto, ''), 'IGNORADO')) AS financiador_parto
    FROM stg.STG_Nacimientos
    WHERE UPPER(ISNULL(NULLIF(Financiador_Parto, ''), 'IGNORADO')) IN (
        'SIS', 'ESSALUD', 'PARTICULAR', 'PRIVADOS',
        'SANIDAD EP', 'SANIDAD FAP', 'SANIDAD NAVAL', 'SANIDAD PNP',
        'IGNORADO'
    )
    AND TRY_CAST(Atiende_Parto AS INT) IS NULL
    AND UPPER(ISNULL(Atiende_Parto, '')) NOT IN ('ESTABLECIMIENTO DE SALUD', 'PERU', 'VENEZUELA')
    AND UPPER(ISNULL(Lugar_Nacido, '')) NOT IN ('PERU', 'VENEZUELA', 'NINGUNO');

    -- Asegura que exista el registro comodín completo en 'IGNORADO'
    IF NOT EXISTS (
        SELECT 1 FROM dm.DIM_PARTO 
        WHERE condicion_parto = 'IGNORADO' AND tipo_parto = 'IGNORADO' 
          AND lugar_nacido = 'IGNORADO' AND atiende_parto = 'IGNORADO' 
          AND financiador_parto = 'IGNORADO'
    )
    BEGIN
        INSERT INTO dm.DIM_PARTO (condicion_parto, tipo_parto, lugar_nacido, atiende_parto, financiador_parto)
        VALUES ('IGNORADO', 'IGNORADO', 'IGNORADO', 'IGNORADO', 'IGNORADO');
    END
END
GO

-- ============================================================================
-- BLOQUE 6: POBLAR TABLA DE HECHOS (dm.FACT_NACIMIENTO)
-- Estrategia Kimball (LEFT JOIN + Miembro Desconocido -1):
-- - Enlaza las 5 dimensiones mediante LEFT JOIN e ISNULL(..., @IdIgnorado).
-- - Ningún registro válido se pierde por falta de coincidencia en una dimensión:
--   si algún atributo viene corrupto o fuera de catálogo, hereda el ID comodín
--   'IGNORADO' de esa dimensión mientras conserva sus demás datos clínicos.
-- - Descarta únicamente filas totalmente en blanco al final del CSV.
-- ============================================================================
BEGIN
    DECLARE @IdTiempoIgnorado INT = (SELECT TOP 1 id_tiempo FROM dm.DIM_TIEMPO WHERE año = -1 AND mes = -1);
    DECLARE @IdUbicacionIgnorado INT = (SELECT TOP 1 id_ubicacion FROM dm.DIM_UBICACION WHERE idUbigeo = '-1');
    DECLARE @IdMadreIgnorado INT = (SELECT TOP 1 id_madre FROM dm.DIM_MADRE WHERE edad_madre = -1 AND estado_civil = 'IGNORADO' AND nivel_instruccion = 'IGNORADO' AND ocupacion = 'IGNORADO' AND pais_origen = 'IGNORADO');
    DECLARE @IdRecienNacidoIgnorado INT = (SELECT TOP 1 id_recien_nacido FROM dm.DIM_RECIEN_NACIDO WHERE sexo = 'IGNORADO' AND tiempo_gestacion = -1 AND talla_nacido = -1.0);
    DECLARE @IdPartoIgnorado INT = (SELECT TOP 1 id_parto FROM dm.DIM_PARTO WHERE condicion_parto = 'IGNORADO' AND tipo_parto = 'IGNORADO' AND lugar_nacido = 'IGNORADO' AND atiende_parto = 'IGNORADO' AND financiador_parto = 'IGNORADO');

    INSERT INTO dm.FACT_NACIMIENTO WITH (TABLOCK) (
        id_tiempo,
        id_ubicacion,
        id_madre,
        id_recien_nacido,
        id_parto,
        cantidad_nacimientos,
        peso_gramos,
        ind_bajo_peso,
        ind_madre_adolesc
    )
    SELECT 
        ISNULL(Tmp.id_tiempo, @IdTiempoIgnorado)               AS id_tiempo,
        ISNULL(Ubi.id_ubicacion, @IdUbicacionIgnorado)         AS id_ubicacion,
        ISNULL(M.id_madre, @IdMadreIgnorado)                   AS id_madre,
        ISNULL(Rn.id_recien_nacido, @IdRecienNacidoIgnorado)   AS id_recien_nacido,
        ISNULL(P.id_parto, @IdPartoIgnorado)                   AS id_parto,
        1 AS cantidad_nacimientos,
        ISNULL(TRY_CAST(NULLIF(Nc.PESO_NACIDO, '') AS INT), -1) AS peso_gramos,
        CASE 
            WHEN TRY_CAST(Nc.PESO_NACIDO AS INT) > 0 
             AND TRY_CAST(Nc.PESO_NACIDO AS INT) < 2500 THEN 1 
            ELSE 0 
        END AS ind_bajo_peso,
        CASE 
            WHEN TRY_CAST(Nc.Edad_Madre AS INT) BETWEEN 10 AND 19 THEN 1 
            ELSE 0 
        END AS ind_madre_adolesc
    FROM stg.STG_Nacimientos Nc

    LEFT JOIN dm.DIM_TIEMPO Tmp
        ON Tmp.año = TRY_CAST(Nc.FecNac_Año AS INT)
       AND Tmp.mes = TRY_CAST(Nc.FecNac_Mes AS INT)

    LEFT JOIN dm.DIM_UBICACION Ubi
        ON Ubi.idUbigeo = RIGHT('000000' + LTRIM(RTRIM(ISNULL(Nc.IdUbigeoInei, ''))), 6)

    LEFT JOIN dm.DIM_MADRE M
        ON M.edad_madre = CASE 
                            WHEN TRY_CAST(Nc.Edad_Madre AS INT) IS NULL THEN -1
                            WHEN TRY_CAST(Nc.Edad_Madre AS INT) < 10 THEN -1
                            ELSE TRY_CAST(Nc.Edad_Madre AS INT)
                          END
       AND M.estado_civil = UPPER(ISNULL(NULLIF(Nc.Estado_Civil, ''), 'IGNORADO'))
       AND M.nivel_instruccion = UPPER(ISNULL(NULLIF(Nc.Nivel_Intruccion_Madre, ''), 'IGNORADO'))
       AND M.ocupacion = UPPER(ISNULL(NULLIF(Nc.DESC_OCUPACION, ''), 'IGNORADO'))
       AND M.pais_origen = CASE 
                            WHEN Nc.Pais_Madre = '1' THEN 'PERU'
                            WHEN Nc.Pais_Madre = '2' THEN 'EXTRANJERO'
                            WHEN ISNUMERIC(Nc.Pais_Madre) = 1 THEN 'IGNORADO'
                            ELSE UPPER(ISNULL(NULLIF(Nc.Pais_Madre, ''), 'IGNORADO'))
                          END

    LEFT JOIN dm.DIM_RECIEN_NACIDO Rn
        ON Rn.sexo = UPPER(ISNULL(NULLIF(Nc.sexo_nacido, ''), 'IGNORADO'))
       AND Rn.tiempo_gestacion = ISNULL(TRY_CAST(NULLIF(Nc.DUR_EMB_PARTO, '') AS INT), -1)
       AND Rn.talla_nacido = ISNULL(TRY_CAST(NULLIF(Nc.TALLA_NACIDO, '') AS DECIMAL(4,1)), -1.0)

    LEFT JOIN dm.DIM_PARTO P
        ON P.condicion_parto = UPPER(ISNULL(NULLIF(Nc.Condicion_Parto, ''), 'IGNORADO'))
       AND P.tipo_parto = UPPER(ISNULL(NULLIF(Nc.Tipo_Parto, ''), 'IGNORADO'))
       AND P.lugar_nacido = CASE 
                              WHEN TRY_CAST(Nc.Lugar_Nacido AS INT) IS NOT NULL THEN 'ESTABLECIMIENTO DE SALUD'
                              ELSE UPPER(ISNULL(NULLIF(Nc.Lugar_Nacido, ''), 'IGNORADO'))
                            END
       AND P.atiende_parto = UPPER(ISNULL(NULLIF(Nc.Atiende_Parto, ''), 'IGNORADO'))
       AND P.financiador_parto = UPPER(ISNULL(NULLIF(Nc.Financiador_Parto, ''), 'IGNORADO'))

    -- Filtra únicamente líneas completamente vacías del archivo plano
    WHERE NULLIF(LTRIM(RTRIM(Nc.FecNac_Año)), '') IS NOT NULL
       OR NULLIF(LTRIM(RTRIM(Nc.PESO_NACIDO)), '') IS NOT NULL
       OR NULLIF(LTRIM(RTRIM(Nc.Edad_Madre)), '') IS NOT NULL;
END
GO

-- ============================================================================
-- BLOQUE 7: AUDITORÍA Y VALIDACIÓN FINAL DE CARGA
-- ============================================================================
SELECT DISTINCT financiador_parto 
FROM dm.DIM_PARTO 
ORDER BY financiador_parto;

SELECT 
    (SELECT COUNT(*) FROM dm.DIM_TIEMPO)        AS Filas_Tiempo,
    (SELECT COUNT(*) FROM dm.DIM_UBICACION)     AS Filas_Ubicacion,
    (SELECT COUNT(*) FROM dm.DIM_MADRE)         AS Filas_Madre,
    (SELECT COUNT(*) FROM dm.DIM_RECIEN_NACIDO) AS Filas_RecienNacido,
    (SELECT COUNT(*) FROM dm.DIM_PARTO)         AS Filas_Parto,
    (SELECT COUNT(*) FROM dm.FACT_NACIMIENTO)   AS Filas_Hechos;

SELECT 
    (SELECT COUNT(*) FROM stg.STG_Nacimientos) AS Total_Staging,
    (SELECT COUNT(*) FROM dm.FACT_NACIMIENTO)   AS Total_Hechos,
    CAST((SELECT COUNT(*) FROM dm.FACT_NACIMIENTO) * 100.0 / 
         (SELECT COUNT(*) FROM stg.STG_Nacimientos) AS DECIMAL(5,2)) AS Porcentaje_Retencion;
GO

