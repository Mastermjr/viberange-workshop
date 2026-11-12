-- Rebuild the derived Tetragon table with uniform process extraction for every
-- real Tetragon event family. ir.raw_events remains authoritative.
DROP VIEW IF EXISTS ir.mv_raw_to_tetragon;
TRUNCATE TABLE ir.tetragon_events;
