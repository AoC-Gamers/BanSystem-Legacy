DELIMITER $$

DROP TABLE IF EXISTS bans_access;
CREATE TABLE `bans_access` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY (`steam_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

DROP TABLE IF EXISTS bans_communication;
CREATE TABLE `bans_communication` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ban_type` int NOT NULL DEFAULT 3,
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY (`steam_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

DROP TABLE IF EXISTS attempts_access;
CREATE TABLE `attempts_access` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

DELIMITER ;