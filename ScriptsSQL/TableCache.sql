CREATE TABLE IF NOT EXISTS BanCache (
    `ban_id` INT NOT NULL DEFAULT 0,
    `steam_id` VARCHAR(64) NOT NULL,
    `date_cache` INTEGER DEFAULT (strftime('%s', 'now'))
);