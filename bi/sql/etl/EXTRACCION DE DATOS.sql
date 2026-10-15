USE DatamartMaterno_Natal
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
GO

BEGIN
    BULK INSERT stg.STG_Nacimientos
    FROM 'C:\DATASET\DataSet Registro Nacidos.CSV'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '\n',
        CODEPAGE = '65001',
        TABLOCK
    )
END

SELECT * FROM stg.STG_Nacimientos
SELECT * FROM stg.STG_Ubigeo

