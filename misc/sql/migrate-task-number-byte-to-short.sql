-- Migration of TASK numbering from 2-character hexadecimal segments to 4-character ones.
-- Run with the application stopped and after a full backup.

-- MySQL 8+
ALTER TABLE TASK MODIFY COLUMN TSK_PATH VARCHAR(512) NOT NULL;
ALTER TABLE TASK MODIFY COLUMN TSK_NUMBER VARCHAR(4) NOT NULL;

WITH RECURSIVE migrated_paths AS (
    SELECT
        root.TSK_ID,
        root.TSK_PATH AS OLD_PATH,
        UPPER(root.TSK_NUMBER) AS OLD_NUMBER,
        LPAD(UPPER(root.TSK_NUMBER), 4, '0') AS NEW_NUMBER,
        CAST('' AS CHAR(4096)) AS NEW_PATH
    FROM TASK root
    WHERE root.TSK_PATH = ''
    UNION ALL
    SELECT
        child.TSK_ID,
        child.TSK_PATH AS OLD_PATH,
        UPPER(child.TSK_NUMBER) AS OLD_NUMBER,
        LPAD(UPPER(child.TSK_NUMBER), 4, '0') AS NEW_NUMBER,
        CONCAT(parent.NEW_PATH, parent.NEW_NUMBER) AS NEW_PATH
    FROM TASK child
    JOIN migrated_paths parent
        ON child.TSK_PATH = CONCAT(parent.OLD_PATH, parent.OLD_NUMBER)
)
UPDATE TASK target
JOIN migrated_paths src ON src.TSK_ID = target.TSK_ID
SET target.TSK_NUMBER = src.NEW_NUMBER,
    target.TSK_PATH = src.NEW_PATH;

-- HSQLDB / H2:
-- 1. ALTER TABLE TASK ALTER COLUMN TSK_PATH VARCHAR(512) NOT NULL;
-- 2. ALTER TABLE TASK ALTER COLUMN TSK_NUMBER VARCHAR(4) NOT NULL;
-- 3. UPDATE TASK SET TSK_NUMBER = RIGHT('0000' || UPPER(TSK_NUMBER), 4);
-- 4. Rebuild TSK_PATH with an equivalent recursive CTE adapted to your engine.
