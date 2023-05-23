WITH
PARAMETERS AS
(
	SELECT
		-- FACT_TABLE_OWNER
		'OWNER' OWNER,
		-- FACT_TABLE_NAME
		'NAME' TABLE_NAME,
		-- FAKT_TABLE_ALIAS
		'F_ALIAS' F_ALIAS,
		-- DIMENSION_CONSTRAINT_SUBSTR
		'D_SUBSTR' D_SUBSTR,
		-- DIMENSION_CONSTRAINT_ALIAS
		'D_ALIAS' D_ALIAS
	FROM
		DUAL
),
FAKT_COLUMNS AS
(
	SELECT
		P.OWNER,
		P.TABLE_NAME,
		T.COLUMN_NAME,
		ROW_NUMBER() 
		OVER 
			(
				PARTITION BY 1 
				ORDER BY
					P.OWNER,
					P.TABLE_NAME,
					T.COLUMN_NAME
			) LEVEL_2
	FROM
		PARAMETERS P
		INNER JOIN ALL_TAB_COLUMNS T
		ON
			T.TABLE_NAME = P.TABLE_NAME AND
			T.OWNER = P.OWNER
	ORDER BY
		P.OWNER,
		P.TABLE_NAME,
		T.COLUMN_NAME
),
JOINT_COLUMNS AS
(
	SELECT
		F_OWNER,
		F_TABLE_NAME,
		F_COLUMN_NAME,
		D_OWNER,
		D_TABLE_NAME,
		D_COLUMN_NAME,
		POSITION,
		CONSTRAINT_NAME,
		ROW_NUMBER() 
		OVER 
		(
			PARTITION BY 1 
			ORDER BY 
				D_OWNER, 
				D_TABLE_NAME, 
				D_COLUMN_NAME,
				CONSTRAINT_NAME
		) LEVEL_2,
		ROW_NUMBER() 
		OVER 
		(
			PARTITION BY 
				D_OWNER,
				D_TABLE_NAME,
				D_COLUMN_NAME,
				CONSTRAINT_NAME
			ORDER BY 
				POSITION
		) LEVEL_4
	FROM
	(
		SELECT 
			B.OWNER F_OWNER,
			B.TABLE_NAME F_TABLE_NAME,
			B.COLUMN_NAME F_COLUMN_NAME,
			C.OWNER D_OWNER,
			C.TABLE_NAME D_TABLE_NAME,
			C.COLUMN_NAME D_COLUMN_NAME,
			B.POSITION,
			A.CONSTRAINT_NAME
		FROM 
			PARAMETERS P,
			ALL_CONS_COLUMNS B,
			ALL_CONS_COLUMNS C,
			ALL_CONSTRAINTS A
		WHERE 
			B.OWNER = P.OWNER
			AND B.TABLE_NAME = P.TABLE_NAME
			AND B.CONSTRAINT_NAME = A.CONSTRAINT_NAME
			AND A.OWNER = B.OWNER
			AND B.POSITION  = C.POSITION
			AND C.CONSTRAINT_NAME = A.R_CONSTRAINT_NAME
			AND C.OWNER = A.R_OWNER
			AND A.CONSTRAINT_TYPE = 'R'
	)
	UNION ALL
	(
		-- CUSTOM COLUMN JOINS
		SELECT
			'F_OWNER_1' F_OWNER,
			'F_TABEL_NAME_1' F_TABLE_NAME,
			'F_COLUMN_NAME_1' F_COLUMN_NAME,
			'D_OWNER_1' D_OWNER,
			'D_TABLE_NAME_1' D_TABLE_NAME,
			'D_COLUMN_NAME_1' D_COLUMN_NAME,
			1 POSITION,
			'CONSTRAINT_NAME_1' CONSTRAINT_NAME,
			1 LEVEL_2,
			1 LEVEL_4
		FROM DUAL
		/*
		UNION ALL
		SELECT
			'F_OWNER_2' F_OWNER,
			'F_TABEL_NAME_2' F_TABLE_NAME,
			'F_COLUMN_NAME_2' F_COLUMN_NAME,
			'D_OWNER_2' D_OWNER,
			'D_TABLE_NAME_2' D_TABLE_NAME,
			'D_COLUMN_NAME_2' D_COLUMN_NAME,
			1 POSITION,
			'CONSTRAINT_NAME_2' CONSTRAINT_NAME,
			1 LEVEL_2,
			1 LEVEL_4
		FROM DUAL
		*/
	)
),
JOINT_TABLES AS
(
	SELECT
		D_OWNER,
		D_TABLE_NAME,
		POSITION,
		CONSTRAINT_NAME,
		ROW_NUMBER() OVER (PARTITION BY 1 ORDER BY D_OWNER, D_TABLE_NAME, CONSTRAINT_NAME) LEVEL_2
	FROM
	 JOINT_COLUMNS
),
QUERY AS
(
	-- SELECT Keyword
	SELECT 
		0 LEVEL_0,
		0 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		'' TABS,
		'!SELECT' TEXT
	FROM
		DUAL 
	UNION ALL
	-- COLUMNS FROM FACT TABLE
	SELECT
		1 LEVEL_0,
		0 LEVEL_1,
		F.LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		DECODE(P.F_ALIAS, NULL,
		F.OWNER||'.'||F.TABLE_NAME,
		P.F_ALIAS)||'.'||F.COLUMN_NAME||',' TEXT
	FROM
		PARAMETERS P
		CROSS JOIN
		FAKT_COLUMNS F
	UNION ALL
	-- HEADER, COLUMNS FROM DIMENSION TABLE, JOINED WITH FACT TABLE
	SELECT
		1 LEVEL_0,
		0 LEVEL_1,
		F.LEVEL_2,
		1 LEVEL_3,
		CHR(9) TABS,
		'-- '||C.CONSTRAINT_NAME||', '||C.D_OWNER||'.'||C.D_TABLE_NAME TEXT
	FROM
		FAKT_COLUMNS F 
		INNER JOIN 
		JOINT_COLUMNS C
		ON
			F.OWNER = C.F_OWNER AND
			F.TABLE_NAME = C.F_TABLE_NAME AND
			F.COLUMN_NAME = C.F_COLUMN_NAME
	WHERE
		C.POSITION = 1
	UNION ALL
	-- COLUMNS FROM DIMENSION TABLE
	SELECT
		1 LEVEL_0,
		0 LEVEL_1,
		F.LEVEL_2,
		2+ROW_NUMBER()
		OVER (PARTITION BY 1 ORDER BY  A.COLUMN_NAME) LEVEL_3,
		CHR(9)||CHR(9) TABS,
		REPLACE(C.CONSTRAINT_NAME, P.D_SUBSTR, P.D_ALIAS)||'.'||A.COLUMN_NAME||
			' /* '||REPLACE(C.CONSTRAINT_NAME,P.D_SUBSTR, P.D_ALIAS)||'.'||A.COLUMN_NAME||' */,' TEXT
	FROM
		PARAMETERS P
		CROSS JOIN
		FAKT_COLUMNS F 
		INNER JOIN 
		JOINT_COLUMNS C
		ON
			F.OWNER = C.F_OWNER AND
			F.TABLE_NAME = C.F_TABLE_NAME AND
			F.COLUMN_NAME = C.F_COLUMN_NAME
		INNER JOIN ALL_TAB_COLUMNS A
		ON
			A.OWNER = C.D_OWNER AND
			A.TABLE_NAME = C.D_TABLE_NAME
	WHERE
		C.POSITION = 1 AND
		A.COLUMN_NAME <> C.D_COLUMN_NAME
	UNION ALL
	-- LAST COLUMN IN SELECT STATEMENT
	SELECT
		1 LEVEL_0,
		1 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		'!NULL NONE' TEXT
	FROM
		DUAL
	UNION ALL
	-- FROM KEYWORD
	SELECT
		1 LEVEL_0,
		2 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		'' TABS,
		'!FROM' TEXT
	FROM
		DUAL
	UNION ALL
	-- FACT TABLE
	SELECT
		1 LEVEL_0,
		3 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		'!'||P.OWNER||'.'||P.TABLE_NAME||' '||DECODE(P.F_ALIAS, NULL,'', P.F_ALIAS) TEXT
	FROM
		PARAMETERS P
	UNION ALL
	-- HEADER FOR DIMENSTION TABLE
	SELECT
		2 LEVEL_0,
		1 LEVEL_1,
		LEVEL_2*4 LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		'-- '||CONSTRAINT_NAME TEXT
	FROM
		JOINT_TABLES
	WHERE
		POSITION = 1
	UNION ALL
	-- JOIN WITH DIMENSTION TABLE
	SELECT
		2 LEVEL_0,
		1 LEVEL_1,
		LEVEL_2*4+1 LEVEL_2,
		0 LEVEL_3,
		CHR(9)||CHR(9) TABS,
		'!INNER JOIN '||C.D_OWNER||'.'||C.D_TABLE_NAME||' '||
		REPLACE(C.CONSTRAINT_NAME, P.D_SUBSTR, P.D_ALIAS) TEXT
	FROM
		PARAMETERS P
		CROSS JOIN 
		JOINT_TABLES C
	WHERE
		POSITION = 1
	UNION ALL
	-- JOIN WITH DIMENSTION TABLE
	SELECT
		2 LEVEL_0,
		1 LEVEL_1,
		T.LEVEL_2*4+2 LEVEL_2,
		0 LEVEL_3,
		CHR(9)||CHR(9) TABS,
		'!ON '||
		DECODE(P.F_ALIAS, NULL,
		C.F_OWNER||'.'||C.F_TABLE_NAME,
		P.F_ALIAS)||'.'||C.F_COLUMN_NAME  TEXT
	FROM
		PARAMETERS P
		CROSS JOIN 
		JOINT_TABLES T
		INNER JOIN
		JOINT_COLUMNS C
		ON 
			T.D_OWNER = C.D_OWNER AND
			T.D_TABLE_NAME = C.D_TABLE_NAME AND
			T.CONSTRAINT_NAME = C.CONSTRAINT_NAME
	WHERE
		T.POSITION = 1
	UNION ALL
	-- JOIN WITH DIMENSTION TABLE
	SELECT
		2 LEVEL_0,
		1 LEVEL_1,
		T.LEVEL_2*4+3 LEVEL_2,
		1 LEVEL_3,
		CHR(9)||CHR(9) TABS,
		'!= '||REPLACE(C.CONSTRAINT_NAME, P.D_SUBSTR, P.D_ALIAS)||'.'||C.D_COLUMN_NAME TEXT
	FROM
		PARAMETERS P
		CROSS JOIN
		JOINT_TABLES T
		INNER JOIN
		JOINT_COLUMNS C
		ON 
			T.D_OWNER = C.D_OWNER AND
			T.D_TABLE_NAME = C.D_TABLE_NAME AND
			T.CONSTRAINT_NAME = C.CONSTRAINT_NAME
	WHERE
		T.POSITION = 1
	UNION ALL
	-- WHERE KEYWORD
	SELECT
		3 LEVEL_0,
		1 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		'' TABS,
		'!WHERE' TEXT
	FROM
		DUAL
	UNION ALL
	-- DUMMY TRUE CONDITION
	SELECT
		3 LEVEL_0,
		2 LEVEL_1,
		0 LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		'!1=1' TEXT
	FROM
		DUAL
	UNION ALL
	-- HEADER FOR DIMENSTION TABLE EXAMPLE CONDITIONS
	SELECT
		3 LEVEL_0,
		3 LEVEL_1,
		LEVEL_2*4 LEVEL_2,
		0 LEVEL_3,
		CHR(9) TABS,
		'-- '||CONSTRAINT_NAME TEXT
	FROM
		JOINT_TABLES
	WHERE
		POSITION = 1
	UNION ALL
	-- JOIN WITH DIMENSTION TABLE
	SELECT
		3 LEVEL_0,
		3 LEVEL_1,
		T.LEVEL_2*4 LEVEL_2,
		1 LEVEL_3,
		CHR(9)||CHR(9) TABS,
		'!-- AND '||REPLACE(C.CONSTRAINT_NAME, P.D_SUBSTR, P.D_ALIAS)||'.'||C.D_COLUMN_NAME||' IS NULL' TEXT
	FROM
		PARAMETERS P
		CROSS JOIN
		JOINT_TABLES T
		INNER JOIN
		JOINT_COLUMNS C
		ON 
			T.D_OWNER = C.D_OWNER AND
			T.D_TABLE_NAME = C.D_TABLE_NAME AND
			T.CONSTRAINT_NAME = C.CONSTRAINT_NAME
	WHERE
		T.POSITION = 1
)
SELECT
	TABS||TEXT TEXT
FROM
	QUERY
ORDER BY
	LEVEL_0,
	LEVEL_1,
	LEVEL_2,
	LEVEL_3