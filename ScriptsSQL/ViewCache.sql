DROP VIEW IF EXISTS BanCache_Valid;
CREATE VIEW IF NOT EXISTS BanCache_Valid AS
SELECT *
FROM BanCache
WHERE date_cache >= strftime('%s', 'now') - 604800;