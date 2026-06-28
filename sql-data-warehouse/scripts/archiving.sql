CREATE SCHEMA IF NOT EXISTS bl_dm_arch;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    WITH active_parts AS (
      SELECT child.relname AS part_name
      FROM pg_inherits
      JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
      JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
      JOIN pg_namespace nsp ON nsp.oid = child.relnamespace
      WHERE nsp.nspname='bl_dm'
        AND parent.relname='fct_order_line_dd'
        AND child.relname ~ 'fct_order_line_dd_p_[0-9]{6}'
    ),
    arch_parts AS (
      SELECT c.relname AS part_name
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname='bl_dm_arch'
        AND c.relname ~ 'fct_order_line_dd_p_[0-9]{6}'
    )
    SELECT a.part_name
    FROM active_parts a
    JOIN arch_parts  b USING (part_name)
  LOOP
    RAISE NOTICE 'Removing duplicate ACTIVE partition (exists in archive): %', r.part_name;

    EXECUTE format('ALTER TABLE bl_dm.fct_order_line_dd DETACH PARTITION bl_dm.%I', r.part_name);
    EXECUTE format('DROP TABLE bl_dm.%I', r.part_name);
  END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE bl_dm.prc_archive_old_partitions()
LANGUAGE plpgsql
AS $$
DECLARE
    v_part  TEXT;
    v_month DATE;
BEGIN
    CREATE SCHEMA IF NOT EXISTS bl_dm_arch;

    FOR v_part IN
        SELECT child.relname
        FROM pg_inherits
        JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
        JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
        JOIN pg_namespace nsp ON nsp.oid = child.relnamespace
        WHERE nsp.nspname = 'bl_dm'
          AND parent.relname = 'fct_order_line_dd'
          AND child.relname ~ 'fct_order_line_dd_p_[0-9]{6}'
    LOOP
        v_month := to_date(right(v_part,6),'YYYYMM');

        IF v_month < date_trunc('month', CURRENT_DATE) - INTERVAL '12 months' THEN

            IF EXISTS (
                SELECT 1
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'bl_dm_arch'
                  AND c.relname = v_part
            ) THEN
                RAISE NOTICE 'Skip (already in archive): %', v_part;
                CONTINUE;
            END IF;

            RAISE NOTICE 'Archiving partition: %', v_part;

            EXECUTE format(
                'ALTER TABLE bl_dm.fct_order_line_dd DETACH PARTITION bl_dm.%I',
                v_part
            );

            EXECUTE format(
                'ALTER TABLE bl_dm.%I SET SCHEMA bl_dm_arch',
                v_part
            );

        END IF;
    END LOOP;
END;
$$;


CALL bl_dm.prc_archive_old_partitions();

SELECT 'ACTIVE' AS scope, child.relname
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
JOIN pg_namespace nsp ON nsp.oid = child.relnamespace
WHERE parent.relname='fct_order_line_dd'
  AND nsp.nspname='bl_dm'
  AND child.relname ~ 'fct_order_line_dd_p_[0-9]{6}'

UNION ALL

SELECT 'ARCHIVE' AS scope, c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname='bl_dm_arch'
  AND c.relname ~ 'fct_order_line_dd_p_[0-9]{6}'
ORDER BY 2,1;


