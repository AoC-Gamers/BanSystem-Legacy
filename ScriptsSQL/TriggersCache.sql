CREATE TRIGGER IF NOT EXISTS SetDefaultDateCache
BEFORE INSERT ON BanCache
FOR EACH ROW
WHEN NEW.date_cache IS NULL
BEGIN
    UPDATE BanCache
    SET date_cache = strftime('%s', 'now')
    WHERE rowid = NEW.rowid;
END;

CREATE TRIGGER IF NOT EXISTS DeleteOldCache
AFTER INSERT ON BanCache
BEGIN
    DELETE FROM BanCache
    WHERE strftime('%s', 'now') - date_cache > 604800; -- 604800 seconds = 7 days
END;