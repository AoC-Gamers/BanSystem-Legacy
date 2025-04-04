DROP PROCEDURE IF EXISTS AttemptAccess;
DELIMITER //
CREATE PROCEDURE AttemptAccess(
    IN szSteamId VARCHAR(64),
    IN szPlayerName VARCHAR(64),
    IN szIpAddress VARCHAR(64)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    INSERT INTO attempts_access (steam_id, player_name, ip_address)
    VALUES (szSteamId, szPlayerName, szIpAddress);
    
    UPDATE bans_access
    SET player_name = szPlayerName, ip_address = szIpAddress
    WHERE steam_id = szSteamId;
    
    COMMIT;
END //
DELIMITER ;