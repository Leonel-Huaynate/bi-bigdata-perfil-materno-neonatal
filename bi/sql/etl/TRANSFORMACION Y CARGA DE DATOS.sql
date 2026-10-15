USE DatamartMaterno_Natal
GO

/*T-SQL para cargar los datos del stg.STG_Nacimientos a mi dimension dm.DIM_TIEMPO
Aca tambien transformamos los datos crudos del stg*/
BEGIN
	INSERT INTO dm.DIM_TIEMPO (
		año,
		mes,
		nombre_mes
	)SELECT DISTINCT 
		TRY_CAST(FecNac_Año AS INT),
		TRY_CAST(FecNac_Mes AS INT),
		CASE TRY_CAST(FecNac_Mes AS INT)
			WHEN 1 THEN 'Enero'
			WHEN 2 THEN 'Febrero'
			WHEN 3 THEN 'Marzo'
			WHEN 4 THEN 'Abril'
			WHEN 5 THEN 'Mayo'
			WHEN 6 THEN 'Junio'
			WHEN 7 THEN 'Julio'
			WHEN 8 THEN 'Agosto'
			WHEN 9 THEN 'Septiembre'
			WHEN 10 THEN 'Octubre'
			WHEN 11 THEN 'Noviembre'
			WHEN 12 THEN 'Diciembre'
			ELSE 'No registrado'
		END
	FROM stg.STG_Nacimientos
	WHERE TRY_CAST(FecNac_Año AS INT) IS NOT NULL 
	  AND TRY_CAST(FecNac_Mes AS INT) IS NOT NULL
END

SELECT * FROM dm.DIM_TIEMPO
GO

/*T-SQL para cargar los datos del stg.STG_Nacimientos y tambien de stg.STG_Ubigeo que contiene los nombres del
departamento, provincia y dsitrito para mi dimension dm.DIM_UBICACION
Aca tambien transformamos los datos crudos de los stg,*/
BEGIN
	INSERT INTO dm.DIM_UBICACION(
		idUbigeo,
		departamento,
		provincia,
		distrito
	)SELECT DISTINCT 
		RIGHT('000000'+N.IdUbigeoInei,6),
		U.Departamento,
		U.Provincia,
		U.Distrito
	FROM stg.STG_Nacimientos N INNER JOIN stg.STG_Ubigeo U 
	ON RIGHT('000000'+N.IdUbigeoInei,6)=U.Ubigeo
	--Fila comodin cuando el idUbigeo sea -1 en este caso es porque se ignoro el registro de ubicacion
	INSERT INTO dm.DIM_UBICACION(idUbigeo,
		departamento,
		provincia,
		distrito)
	VALUES('-1','Ignorado','Ignorado','Ignorado')
END

SELECT * FROM dm.DIM_UBICACION
GO

/*T-SQL para cargar los datos del stg.STG_Nacimientos a mi dimension dm.DIM_MADRE
Aca tambien transformamos los datos crudos del stg, lipiamos campos vacios, espacios en blancos
valores anormales,etc*/
BEGIN
	INSERT INTO dm.DIM_MADRE(
		edad_madre,
		estado_civil,
		nivel_instruccion,
		ocupacion,
		pais_origen,
		grupo_edad
	)SELECT DISTINCT
		CASE
			WHEN TRY_CAST(Edad_Madre AS INT) IS NULL THEN -1
			WHEN TRY_CAST(Edad_Madre AS INT) < 10 THEN -1
			ELSE TRY_CAST(Edad_Madre AS INT)
		END,
		UPPER(ISNULL(NULLIF(Estado_Civil,''),'IGNORADO')),
		UPPER(ISNULL(NULLIF(Nivel_Intruccion_Madre,''),'IGNORADO')),
		UPPER(ISNULL(NULLIF(DESC_OCUPACION,''),'IGNORADO')),
		CASE 
            WHEN Pais_Madre = '1' THEN 'PERU'
            WHEN Pais_Madre = '2' THEN 'EXTRANJERO'
            WHEN ISNUMERIC(Pais_Madre) = 1 THEN 'IGNORADO'
            ELSE UPPER(LTRIM(RTRIM(ISNULL(NULLIF(Pais_Madre, ''), 'IGNORADO'))))
        END,
		CASE
			WHEN TRY_CAST(Edad_Madre AS INT) IS NULL THEN 'IGNORADO'
			WHEN TRY_CAST(Edad_Madre AS INT) < 10 THEN 'IGNORADO'
			WHEN TRY_CAST(Edad_Madre AS INT) BETWEEN 10 AND 19 THEN 'ADOLESCENTE' 
			ELSE 'ADULTA'
		END
	FROM stg.STG_Nacimientos
END

SELECT * FROM dm.DIM_MADRE
GO

/*T-SQL para cargar los datos del stg.STG_Nacimientos a mi dimension dm.DIM_RECIEN_NACIDO
Aca tambien transformamos los datos crudos del stg, limpiamos campos vacios, espacios en blancos
valores anormales,etc*/
BEGIN
	INSERT INTO dm.DIM_RECIEN_NACIDO(
		sexo,
		tiempo_gestacion,
		talla_nacido
	)SELECT DISTINCT 
		UPPER(ISNULL(NULLIF(sexo_nacido,''),'IGNORADO')),
        ISNULL(TRY_CAST(NULLIF(DUR_EMB_PARTO, '') AS INT), -1),
        ISNULL(TRY_CAST(NULLIF(TALLA_NACIDO, '') AS DECIMAL(4,1)), -1.0)
	FROM stg.STG_Nacimientos
END

SELECT * FROM dm.DIM_RECIEN_NACIDO
GO

/*T-SQL para cargar los datos del stg.STG_Nacimientos a mi dimension dm.DIM_PARTO
Aca tambien transformamos los datos crudos del stg, limpiamos campos vacios, espacios en blancos
valores anormales,etc*/
BEGIN
	INSERT INTO dm.DIM_PARTO(
		condicion_parto,
		tipo_parto,
		lugar_nacido,
		atiende_parto,
		financiador_parto
	)SELECT DISTINCT 
		UPPER(ISNULL(NULLIF(Condicion_Parto,''),'IGNORADO')),
		UPPER(ISNULL(NULLIF(Tipo_Parto,''),'IGNORADO')),
		CASE 
            WHEN TRY_CAST(Lugar_Nacido AS INT) IS NOT NULL THEN 'ESTABLECIMIENTO DE SALUD'
            ELSE UPPER(ISNULL(NULLIF(Lugar_Nacido,''),'IGNORADO'))
        END,
		UPPER(ISNULL(NULLIF(Atiende_Parto,''),'IGNORADO')),
        UPPER(ISNULL(NULLIF(Financiador_Parto,''),'IGNORADO'))
	FROM stg.STG_Nacimientos
END

SELECT * FROM dm.DIM_PARTO
GO

/*T-SQL para cargar los datos a mi tabla de hechos aca enlazamos con todas nuestras tablas
de dimensiones con mi stg.Nacimientos*/
BEGIN
	INSERT INTO dm.FACT_NACIMIENTO(
		id_tiempo,
		id_ubicacion,
		id_madre,
		id_recien_nacido,
		id_parto ,
		cantidad_nacimientos,
		peso_gramos,
		ind_bajo_peso,
		ind_madre_adolesc
	)SELECT Tmp.id_tiempo, 
			Ubi.id_ubicacion,
			M.id_madre,
			Rn.id_recien_nacido,
			P.id_parto,
			1 as cantidad_nacimientos,
			ISNULL(TRY_CAST(NULLIF(Nc.PESO_NACIDO, '') AS INT), -1) AS peso_gramos,
			CASE 
				WHEN TRY_CAST(Nc.PESO_NACIDO AS INT) < 2500 THEN 1 
				ELSE 0 
				END AS ind_bajo_peso,
			CASE 
				WHEN TRY_CAST(Nc.Edad_Madre AS INT) BETWEEN 10 AND 19 THEN 1 
				ELSE 0 
				END AS ind_madre_adolesc
	FROM stg.STG_Nacimientos Nc 
	INNER JOIN dm.DIM_TIEMPO Tmp
		ON TRY_CAST(NC.FecNac_Año AS INT) = Tmp.año AND 
		TRY_CAST(NC.FecNac_Mes AS INT) = Tmp.mes

	INNER JOIN dm.DIM_UBICACION Ubi 
        ON Ubi.idUbigeo = CASE 
                            WHEN Nc.IdUbigeoInei = '-1' THEN '-1' 
                            ELSE RIGHT('000000' + Nc.IdUbigeoInei, 6) 
                          END

	INNER JOIN dm.DIM_MADRE M 
		ON M.Edad_Madre = CASE 
								WHEN TRY_CAST(Nc.Edad_Madre AS INT) IS NULL OR Nc.Edad_Madre = '' THEN -1
								WHEN TRY_CAST(Nc.Edad_Madre AS INT) < 10 THEN -1 
								ELSE TRY_CAST(Nc.Edad_Madre AS INT) 
							END
		AND M.Estado_Civil = UPPER(ISNULL(NULLIF(Nc.Estado_Civil, ''), 'IGNORADO'))
		AND M.Nivel_Instruccion = UPPER(ISNULL(NULLIF(Nc.Nivel_Intruccion_Madre, ''), 'IGNORADO'))
		AND M.Ocupacion = UPPER(ISNULL(NULLIF(Nc.DESC_OCUPACION, ''), 'IGNORADO'))
		AND M.Pais_Origen = CASE 
								WHEN Nc.Pais_Madre = '1' THEN 'PERU'
								WHEN Nc.Pais_Madre = '2' THEN 'EXTRANJERO'
								WHEN ISNUMERIC(Nc.Pais_Madre) = 1 THEN 'IGNORADO'
								ELSE UPPER(LTRIM(RTRIM(ISNULL(NULLIF(Pais_Madre, ''), 'IGNORADO'))))
							END

	INNER JOIN dm.DIM_RECIEN_NACIDO Rn 
		ON Rn.sexo = UPPER(ISNULL(NULLIF(Nc.sexo_nacido,''),'IGNORADO'))
		AND Rn.tiempo_gestacion = ISNULL(TRY_CAST(NULLIF(Nc.DUR_EMB_PARTO, '') AS INT), -1)
		AND Rn.talla_nacido = ISNULL(TRY_CAST(NULLIF(Nc.TALLA_NACIDO, '') AS DECIMAL(4,1)), -1.0)

	INNER JOIN dm.DIM_PARTO P 
		ON P.condicion_parto = UPPER(ISNULL(NULLIF(Nc.Condicion_Parto,''),'IGNORADO'))
		AND P.tipo_parto = UPPER(ISNULL(NULLIF(Nc.Tipo_Parto,''),'IGNORADO'))
		AND P.lugar_nacido = CASE
								WHEN TRY_CAST(Nc.Lugar_Nacido AS INT) IS NOT NULL THEN 'ESTABLECIMIENTO DE SALUD'
								ELSE UPPER(ISNULL(NULLIF(Nc.Lugar_Nacido,''),'IGNORADO'))
							END
		AND P.atiende_parto = UPPER(ISNULL(NULLIF(Nc.Atiende_Parto,''),'IGNORADO'))
		AND P.financiador_parto = UPPER(ISNULL(NULLIF(Nc.Financiador_Parto,''),'IGNORADO'))
END

SELECT TOP 100 * FROM dm.FACT_NACIMIENTO