--- local case

-- Just in case if previous tests run left some stuff behind.
DROP TABLE IF EXISTS source_data;

CREATE TABLE source_data (
	pk Int32, sk Int32, val UInt32,
	PRIMARY KEY (pk)
) ENGINE=MergeTree
ORDER BY (pk, sk);

INSERT INTO source_data VALUES (0, 0, 0), (0, 0, 0), (1, 1, 2), (1, 1, 3);

SELECT 'TOTAL rows', count() FROM source_data;

DROP TABLE IF EXISTS full_duplicates;
-- table with duplicates on MATERIALIZED columns
CREATE TABLE full_duplicates  (
	pk Int32, sk Int32, val UInt32, mat UInt32 MATERIALIZED 12345, alias UInt32 ALIAS 2,
	PRIMARY KEY (pk)
) ENGINE=MergeTree
ORDER BY (pk, sk);

-- ERROR cases
OPTIMIZE TABLE full_duplicates DEDUPLICATE BY pk, sk, val, mat, alias; -- { serverError 16 } -- alias column is present
OPTIMIZE TABLE full_duplicates DEDUPLICATE BY sk, val; -- { serverError 8 } -- primary key column is missing
OPTIMIZE TABLE full_duplicates DEDUPLICATE BY; -- { serverError 51 } -- list is empty
OPTIMIZE TABLE full_duplicates DEDUPLICATE BY * EXCEPT(pk, sk, val, mat, alias); -- { serverError 51 } -- list is empty
OPTIMIZE TABLE full_duplicates DEDUPLICATE BY * EXCEPT(pk); -- { serverError 8 } -- primary key column is missing
OPTIMIZE TABLE partial_duplicates DEDUPLICATE BY pk,sk,val,mat EXCEPT mat; -- { clientError 62 } -- invalid syntax

-- Valid cases
-- NOTE: here and below we need FINAL to force deduplication in such a small set of data in only 1 part.

SELECT 'OLD DEDUPLICATE';
INSERT INTO full_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE full_duplicates FINAL DEDUPLICATE;
SELECT * FROM full_duplicates;
TRUNCATE full_duplicates;

SELECT 'DEDUPLICATE BY *';
INSERT INTO full_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE full_duplicates FINAL DEDUPLICATE BY *;
SELECT * FROM full_duplicates;
TRUNCATE full_duplicates;

SELECT 'DEDUPLICATE BY * EXCEPT mat';
INSERT INTO full_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE full_duplicates FINAL DEDUPLICATE BY * EXCEPT mat;
SELECT * FROM full_duplicates;
TRUNCATE full_duplicates;

SELECT 'DEDUPLICATE BY pk,sk,val,mat';
INSERT INTO full_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE full_duplicates FINAL DEDUPLICATE BY pk,sk,val,mat;
SELECT * FROM full_duplicates;
TRUNCATE full_duplicates;

--DROP TABLE full_duplicates;

-- Now to the partial duplicates when MATERIALIZED column alway has unique value.
DROP TABLE IF EXISTS partial_duplicates;
CREATE TABLE partial_duplicates  (
	pk Int32, sk Int32, val UInt32, mat UInt32 MATERIALIZED rand(), alias UInt32 ALIAS 2,
	PRIMARY KEY (pk)
) ENGINE=MergeTree
ORDER BY (pk, sk);

SELECT 'Can not remove full duplicates';

-- should not remove anything
SELECT 'OLD DEDUPLICATE';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE;
SELECT count() FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'DEDUPLICATE BY pk,sk,val,mat';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY pk,sk,val,mat;
SELECT count() FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'Remove partial duplicates';

SELECT 'DEDUPLICATE BY *'; -- all except MATERIALIZED columns, hence will reduce number of rows.
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY *;
SELECT count() FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'DEDUPLICATE BY * EXCEPT mat';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY * EXCEPT mat;
SELECT * FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'DEDUPLICATE BY COLUMNS("*") EXCEPT mat';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY COLUMNS('.*') EXCEPT mat;
SELECT * FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'DEDUPLICATE BY pk,sk';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY pk,sk;
SELECT * FROM partial_duplicates;
TRUNCATE partial_duplicates;

SELECT 'DEDUPLICATE BY COLUMNS(".*k")';
INSERT INTO partial_duplicates SELECT * FROM source_data;
OPTIMIZE TABLE partial_duplicates FINAL DEDUPLICATE BY COLUMNS('.*k');
SELECT * FROM partial_duplicates;
TRUNCATE partial_duplicates;
