DROP PROCEDURE IF EXISTS CheckAuthId;
DELIMITER //

CREATE PROCEDURE CheckAuthId(
    IN szAuthId VARCHAR(64),
    OUT result INT,
    OUT out_expire VARCHAR(64)
)
BEGIN
    DECLARE vBanLength INT;
    DECLARE vExpire DATETIME;
    DECLARE vBanType INT;
    DECLARE vNow DATETIME;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN 
         SET result = 0; 
         SET out_expire = NULL; 
    END;
    
    SET vNow = UTC_TIMESTAMP();
    
    IF EXISTS (SELECT 1 FROM `bans_access` WHERE `steam_id` = szAuthId) THEN 
         SELECT `ban_length`, `date_expire` INTO vBanLength, vExpire 
           FROM `bans_access` WHERE `steam_id` = szAuthId;
         IF vBanLength = 0 THEN 
              SET result = -1; 
              SET out_expire = NULL;
         ELSE 
              IF vExpire <= vNow THEN 
                  DELETE FROM `bans_access` WHERE `steam_id` = szAuthId;
                  SET result = 0; 
                  SET out_expire = NULL;
              ELSE 
                  SET result = 1; 
                  SET out_expire = DATE_FORMAT(vExpire, '%Y-%m-%d %H:%i:%s');
              END IF;
         END IF;
    ELSEIF EXISTS (SELECT 1 FROM `bans_communication` WHERE `steam_id` = szAuthId) THEN 
         SELECT `ban_type`, `ban_length`, `date_expire` INTO vBanType, vBanLength, vExpire 
         FROM `bans_communication` WHERE `steam_id` = szAuthId;
         IF vBanLength = 0 THEN
              SET result = (vBanType + 1) * -1; 
              SET out_expire = NULL;
         ELSE 
              IF vExpire <= vNow THEN 
                  DELETE FROM `bans_communication` WHERE `steam_id` = szAuthId;
                  SET result = 0; 
                  SET out_expire = NULL;
              ELSE 
                  SET result = (vBanType + 1);
                  SET out_expire = DATE_FORMAT(vExpire, '%Y-%m-%d %H:%i:%s');
              END IF;
         END IF;
    ELSE 
         SET result = 0; 
         SET out_expire = NULL;
    END IF;
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS GetCheckAuthId;
DELIMITER //

CREATE PROCEDURE GetCheckAuthId(
    IN szAuthId VARCHAR(64)
)
BEGIN
    DECLARE Result INT;
    DECLARE ExpireRes VARCHAR(64);
    
    CALL CheckAuthId(szAuthId, Result, ExpireRes);
    SELECT Result AS result, ExpireRes AS expire;
END //
DELIMITER ;
