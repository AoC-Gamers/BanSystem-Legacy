DROP TRIGGER IF EXISTS DeleteOldCacheForSteamID;
CREATE TRIGGER DeleteOldCacheForSteamID
BEFORE INSERT ON BanCache
BEGIN
    DELETE FROM BanCache
    WHERE steam_id = NEW.steam_id;
END;