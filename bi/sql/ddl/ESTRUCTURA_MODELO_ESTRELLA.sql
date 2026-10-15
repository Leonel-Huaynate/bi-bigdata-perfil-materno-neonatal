CREATE DATABASE DatamartMaterno_Natal
GO
USE DatamartMaterno_Natal
GO

CREATE SCHEMA stg	
GO

CREATE SCHEMA dm
GO

DROP TABLE dm.DIM_TIEMPO
CREATE TABLE dm.DIM_TIEMPO(
	id_tiempo INT PRIMARY KEY IDENTITY,
	año INT,
	mes INT,
	nombre_mes VARCHAR(12)
)
GO

DROP TABLE dm.DIM_UBICACION

CREATE TABLE dm.DIM_UBICACION(
	id_ubicacion INT PRIMARY KEY IDENTITY,
	idUbigeo VARCHAR(10),
	departamento VARCHAR(100),
	provincia VARCHAR(100),
	distrito VARCHAR(100)
)
GO

DROP TABLE dm.DIM_MADRE
CREATE TABLE dm.DIM_MADRE(
	id_madre INT PRIMARY KEY IDENTITY,
	edad_madre INT,
	estado_civil VARCHAR(50),
	nivel_instruccion VARCHAR(80),
	ocupacion VARCHAR(200),
	pais_origen VARCHAR(60),
	grupo_edad VARCHAR(40)
)
GO

DROP TABLE dm.DIM_RECIEN_NACIDO
CREATE TABLE dm.DIM_RECIEN_NACIDO(
	id_recien_nacido INT PRIMARY KEY IDENTITY,
	sexo VARCHAR(40),
	tiempo_gestacion INT,
	talla_nacido DECIMAL(4,1)
)
GO

DROP TABLE dm.DIM_PARTO
CREATE TABLE dm.DIM_PARTO(
	id_parto INT PRIMARY KEY IDENTITY,
	condicion_parto VARCHAR(80),
	tipo_parto VARCHAR(80),
	lugar_nacido VARCHAR(80),
	atiende_parto VARCHAR(80),
	financiador_parto VARCHAR(80)
)
GO

CREATE TABLE dm.FACT_NACIMIENTO(
	id_nacimiento INT PRIMARY KEY IDENTITY,
	id_tiempo INT FOREIGN KEY REFERENCES dm.DIM_TIEMPO(id_tiempo),
	id_ubicacion INT FOREIGN KEY REFERENCES dm.DIM_UBICACION(id_ubicacion),
	id_madre INT FOREIGN KEY REFERENCES dm.DIM_MADRE(id_madre),
	id_recien_nacido INT FOREIGN KEY REFERENCES dm.DIM_RECIEN_NACIDO(id_recien_nacido),
	id_parto INT FOREIGN KEY REFERENCES dm.DIM_PARTO(id_parto),
	cantidad_nacimientos INT,
	peso_gramos INT,
	ind_bajo_peso INT,
	ind_madre_adolesc INT
)
GO

SELECT * FROM sys.tables

