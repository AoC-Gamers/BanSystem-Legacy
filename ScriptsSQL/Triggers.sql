DROP TRIGGER IF EXISTS trg_bans_access_before_insert;
DELIMITER //
CREATE TRIGGER trg_bans_access_before_insert
BEFORE INSERT ON bans_access
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_bans_access_before_update;
DELIMITER //
CREATE TRIGGER trg_bans_access_before_update
BEFORE UPDATE ON bans_access
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_bans_communication_before_insert;
DELIMITER //
CREATE TRIGGER trg_bans_communication_before_insert
BEFORE INSERT ON bans_communication
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_bans_communication_before_update;
DELIMITER //
CREATE TRIGGER trg_bans_communication_before_update
BEFORE UPDATE ON bans_communication
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END //
DELIMITER ;