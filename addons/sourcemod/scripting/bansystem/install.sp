/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

char
	g_szTableAccess[] = "bans_access",
    g_szTableComm[] = "bans_communication",
    g_szTableDataAccess[] = "attempts_access",
    g_szTableCache[] = "BanCache";

ConVar
	g_cvRegAttemptAccess;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

vOnPluginStart_Install()
{
    g_cvRegAttemptAccess = CreateConVar("sm_bansystem_Attempt", "1", "Enables a table with additional information that is collected on access attempts.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegAdminCmd("sm_bs_install_db", aInstallDBCmd, ADMFLAG_ROOT, "Install the BanSystem plugin.");
    RegAdminCmd("sm_bs_install_cache", aInstallCacheCmd, ADMFLAG_ROOT, "Install the BanSystem plugin.");
}

Action aInstallDBCmd(int iClient, int iArgs)
{
	if (!bTableExists(g_szTableAccess))
		vDBTable(kAccess);

	if (!bTableExists(g_szTableComm))
		vDBTable(kComm);

    if (g_cvRegAttemptAccess.BoolValue && !bTableExists(g_szTableDataAccess))
        vDBTable(kRegData);

    if (!bProcedureExists("CheckAuthId"))
        vPLCheckAuthId();

    if (!bProcedureExists("AttemptAccess"))
        vPLAttemptAccess();

    if(!bMySQLTriggerExists("trg_bans_access_before_insert"))
        vTRGAccessExpire();

    if(!bMySQLTriggerExists("trg_bans_access_before_update"))
        vTRGAccessExpireUpdate();

	return Plugin_Handled;
}

Action aInstallCacheCmd(int iClient, int iArgs)
{
    if (!bTableExists(g_szTableCache))
        vCacheTable();
    
    if (!bSQLiteTriggerExists("DeleteOldCache"))
        vTRGDeleteOldCache();
        
	return Plugin_Handled;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Checks if a table exists in the database.
 *
 * @param szTable       The name of the table to check.
 * @return              True if the table exists, false otherwise.
 */
stock bool bTableExists(const char[] szTable)
{
	char szQuery[255];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SHOW TABLES LIKE '%s'", szTable);

	LogSQL("[bTableExists] Query: %s", szQuery);

	DBResultSet hQueryTableExists = SQL_Query(g_dbDatabase, szQuery);
	if (hQueryTableExists == null)
		return false;

	bool bExists = hQueryTableExists.FetchRow();
	delete hQueryTableExists;

	return bExists;
}

/**
 * Checks if a stored procedure exists in the database.
 *
 * @param szProcedure The name of the stored procedure to check.
 * @return True if the stored procedure exists, false otherwise.
 */
bool bProcedureExists(const char[] szProcedure)
{
    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='%s'", szProcedure);

    LogSQL("[bProcedureExists] szQuery: %s", szQuery);

    DBResultSet hQueryResult = SQL_Query(g_dbDatabase, szQuery);
    if (hQueryResult == null)
    {
        logErrorSQL(g_dbDatabase, szQuery, "bProcedureExists");
        return false;
    }

    bool bExists = hQueryResult.FetchRow();
    delete hQueryResult;

    return bExists;
}

/**
 * Checks if a trigger exists in the database.
 *
 * @param szTrigger      The name of the trigger to check.
 * @return               True if the trigger exists, false otherwise.
 */
bool bMySQLTriggerExists(const char[] szTrigger)
{
    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_NAME='%s'", szTrigger);

    LogSQL("[bMySQLTriggerExists] szQuery: %s", szQuery)

    DBResultSet hQueryResult = SQL_Query(g_dbDatabase, szQuery);
    if (hQueryResult == null)
    {
        logErrorSQL(g_dbDatabase, szQuery, "bMySQLTriggerExists");
        return false;
    }

    bool bExists = hQueryResult.FetchRow();
    delete hQueryResult;

    return bExists;
}

/**
 * Checks if a specific SQLite trigger exists in the database.
 *
 * @param szTrigger      The name of the trigger to check for existence.
 * @return               True if the trigger exists, false otherwise.
 *
 * This function constructs an SQL query to check for the existence of a trigger
 * in the SQLite database. It logs the query for debugging purposes and handles
 * any SQL errors that may occur. The result of the query determines whether the
 * trigger exists.
 */
bool bSQLiteTriggerExists(const char[] szTrigger)
{
    if (g_dbCache == null)
    {
        LogError("[bSQLiteTriggerExists] Database handle is null.");
        return false;
    }

    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='trigger' AND name='%s'", szTrigger);

    LogSQL("[bSQLiteTriggerExists] Query: %s", szQuery);

    DBResultSet hQueryResult = SQL_Query(g_dbCache, szQuery);
    if (hQueryResult == null)
    {
        logErrorSQL(g_dbCache, szQuery, "bSQLiteTriggerExists");
        return false;
    }

    bool bExists = hQueryResult.FetchRow();
    delete hQueryResult;

    return bExists;
}

/**
 * Creates a database table based on the specified ban type.
 *
 * @param eBan The type of ban for which the table should be created. 
 *             Possible values are:
 *             - kAccess: Creates a table for access bans.
 *             - kComm: Creates a table for communication bans.
 *             - kRegData: Creates a table for registered data access.
 *
 * @return True if the table was successfully created, false otherwise.
 *
 * @remarks
 * - The function dynamically constructs the SQL query to create the table
 *   with the appropriate schema based on the ban type.
 * - The table schema includes fields such as `id`, `steam_id`, `player_name`,
 *   `ip_address`, `ban_length`, `ban_reason`, `banned_by`, `date_expire`, and
 *   `date_reg`, depending on the ban type.
 * - The tables are created with the MyISAM engine and UTF-8 character set.
 * - If the table creation fails, an error is logged, and the function returns false.
 */
bool vDBTable(eTypeBan eBan)
{
	char
        szTableName[64],
        szQuery[1024];

	int iLen = 0;

	switch (eBan)
	{
		case kAccess:
		{
            Format(szTableName, sizeof(szTableName), "%s", g_szTableAccess);
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_szTableAccess);
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`id` int NOT NULL AUTO_INCREMENT, ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` varchar(64) NOT NULL, ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_length` int NOT NULL DEFAULT 0, ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_expire` DATETIME DEFAULT NULL, ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "PRIMARY KEY (`id`), ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "UNIQUE KEY (`steam_id`) ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;");
		}
		case kComm:
		{
            Format(szTableName, sizeof(szTableName), "%s", g_szTableComm);
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` (", g_szTableComm);
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`id` int NOT NULL AUTO_INCREMENT, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` varchar(64) NOT NULL, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0', ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_type` int NOT NULL DEFAULT 3, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_length` int NOT NULL DEFAULT 0, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON', ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_expire` DATETIME DEFAULT NULL, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "PRIMARY KEY (`id`), ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "UNIQUE KEY (`steam_id`) ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;");
		}
		case kRegData:
		{
            Format(szTableName, sizeof(szTableName), "%s", g_szTableDataAccess);
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_szTableDataAccess);
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`id` int NOT NULL AUTO_INCREMENT, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` varchar(64) NOT NULL, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN', ");
            iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0', ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "PRIMARY KEY (`id`) ");
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;");
		}
	}
	
	LogSQL("[vDBTable] Table created: %s", szTableName);
	LogSQL("[vDBTable] szQuery: %s", szQuery);

	if (!SQL_FastQuery(g_dbDatabase, szQuery))
	{
		logErrorSQL(g_dbDatabase, szQuery, "vDBTable");
		return false;
	}

	return true;
}

/**
 * Creates a stored procedure named `CheckAuthId` in the database.
 * 
 * The procedure checks if a given Steam ID (`szAuthId`) is banned and returns
 * the ban status and expiration date. It handles two types of bans:
 * - Access bans (`bans_access`)
 * - Communication bans (`bans_communication`)
 * 
 * Parameters:
 * - `szAuthId` (IN): The Steam ID to check.
 * - `result` (OUT): The result of the check:
 *   - `0`: No ban exists.
 *   - `1`: Active ban exists.
 *   - `-1`: Permanent access ban.
 *   - `-2`, `-3`, etc.: Permanent communication bans (based on ban type).
 * - `out_expire` (OUT): The expiration date of the ban in `YYYY-MM-DD HH:MM:SS` format, or `NULL` if no ban exists.
 * 
 * Behavior:
 * - If the Steam ID exists in the `bans_access` table:
 *   - If the ban length is `0`, it is a permanent ban.
 *   - If the ban has expired, it is removed from the table.
 * - If the Steam ID exists in the `bans_communication` table:
 *   - If the ban length is `0`, it is a permanent communication ban.
 *   - If the ban has expired, it is removed from the table.
 * - If no ban exists, the result is set to `0` and `out_expire` is set to `NULL`.
 * 
 * Error Handling:
 * - If an SQL exception occurs during execution, the result is set to `0` and `out_expire` is set to `NULL`.
 * 
 * Logs:
 * - Logs the generated SQL query for debugging purposes.
 * - Logs success or failure of the stored procedure creation.
 */
void vPLCheckAuthId()
{
    char szQuery[2048];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DROP PROCEDURE IF EXISTS CheckAuthId;");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE PROCEDURE CheckAuthId( ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IN szAuthId VARCHAR(64), ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "OUT result INT, ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "OUT out_expire VARCHAR(64) ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEGIN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE vBanLength INT; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE vExpire DATETIME; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE vBanType INT; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE vNow DATETIME; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET result = 0; SET out_expire = NULL; END; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET vNow = UTC_TIMESTAMP(); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF EXISTS (SELECT 1 FROM `bans_access` WHERE `steam_id` = szAuthId) THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_length`, `date_expire` INTO vBanLength, vExpire FROM `bans_access` WHERE `steam_id` = szAuthId; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF vBanLength = 0 THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = -1; SET out_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF vExpire <= vNow THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bans_access` WHERE `steam_id` = szAuthId; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = 0; SET out_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = 1; SET out_expire = DATE_FORMAT(vExpire, '%%Y-%%m-%%d %%H:%%i:%%s'); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSEIF EXISTS (SELECT 1 FROM `bans_communication` WHERE `steam_id` = szAuthId) THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_type`, `ban_length`, `date_expire` INTO vBanType, vBanLength, vExpire FROM `bans_communication` WHERE `steam_id` = szAuthId; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF vBanLength = 0 THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = (vBanType + 1) * -1; SET out_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF vExpire <= vNow THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bans_communication` WHERE `steam_id` = szAuthId; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = 0; SET out_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = (vBanType + 1); SET out_expire = DATE_FORMAT(vExpire, '%%Y-%%m-%%d %%H:%%i:%%s'); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET result = 0; SET out_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END;");

    LogSQL("[vPLCheckAuthId] szQuery: %s", szQuery);

    if (!SQL_FastQuery(g_dbDatabase, szQuery))
        logErrorSQL(g_dbDatabase, szQuery, "vPLCheckAuthId");
    else
        LogMessage("[vPLCheckAuthId] Stored procedure CheckAuthId created successfully.");
}


/**
 * Creates or replaces the stored procedure `AttemptAccess` in the database.
 * 
 * The stored procedure is designed to handle player access attempts by inserting
 * or updating relevant information in the database. It performs the following steps:
 * 
 * 1. Drops the existing `AttemptAccess` procedure if it exists.
 * 2. Creates a new `AttemptAccess` procedure with the following parameters:
 *    - `szSteamId` (VARCHAR(64)): The Steam ID of the player.
 *    - `szPlayerName` (VARCHAR(64)): The name of the player.
 *    - `szIpAddress` (VARCHAR(64)): The IP address of the player.
 * 3. Within the procedure:
 *    - Declares an exit handler to roll back the transaction in case of an SQL exception.
 *    - Starts a transaction.
 *    - Inserts a new record into the `attempts_access` table with the provided parameters.
 *    - Updates the `bans_access` table with the player's name and IP address where the Steam ID matches.
 *    - Commits the transaction.
 * 
 * Logs the generated SQL query for debugging purposes and executes it using the database connection.
 * If the query fails, logs the error; otherwise, logs a success message.
 */
void vPLAttemptAccess()
{
    char szQuery[1024];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DROP PROCEDURE IF EXISTS AttemptAccess; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE PROCEDURE AttemptAccess( ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IN szSteamId VARCHAR(64), ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IN szPlayerName VARCHAR(64), ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IN szIpAddress VARCHAR(64) ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEGIN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "START TRANSACTION; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO attempts_access (steam_id, player_name, ip_address) VALUES (szSteamId, szPlayerName, szIpAddress); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "UPDATE bans_access SET player_name = szPlayerName, ip_address = szIpAddress WHERE steam_id = szSteamId; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "COMMIT; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END;");

    LogSQL("[vPLAttemptAccess] szQuery: %s", szQuery);

    if (!SQL_FastQuery(g_dbDatabase, szQuery))
        logErrorSQL(g_dbDatabase, szQuery, "vPLAttemptAccess");
    else
        LogMessage("[vPLAttemptAccess] Stored procedure created successfully.");
}

/**
 * @brief Creates a SQL trigger named `trg_bans_access_before_insert` for the `g_szTableAccess` table.
 * 
 * This trigger is executed before any INSERT operation on the specified table.
 * It ensures that the `date_expire` column is set based on the `ban_length` value:
 * - If `ban_length` is greater than 0, `date_expire` is calculated as the current time 
 *   plus the `ban_length` in minutes, converted to UTC.
 * - If `ban_length` is 0 or less, `date_expire` is set to NULL.
 * 
 * The function logs an error if the SQL query fails, or logs a success message if the trigger
 * is created successfully.
 * 
 * @note This function assumes that `g_dbDatabase` is a valid database handle and 
 *       `g_szTableAccess` is a valid table name.
 */
void vTRGAccessExpire()
{
    char szQuery[1024];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER trg_bans_access_before_insert ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE INSERT ON %s ", g_szTableAccess);
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FOR EACH ROW ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEGIN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF NEW.ban_length > 0 THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00'); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.date_expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END;");

    if (!SQL_FastQuery(g_dbDatabase, szQuery))
        logErrorSQL(g_dbDatabase, szQuery, "vTRGAccessExpire");
    else
        LogMessage("[vTRGAccessExpire] Trigger created successfully.");
}

/**
 * @brief Creates a SQL trigger named `trg_bans_access_before_update` for the `g_szTableAccess` table.
 * 
 * This trigger is executed before any update operation on the table. It ensures that the `date_expire` 
 * column is updated based on the `ban_length` value:
 * - If `ban_length` is greater than 0, `date_expire` is set to the current time plus the `ban_length` 
 *   in minutes, converted to UTC.
 * - Otherwise, `date_expire` is set to NULL.
 * 
 * The function constructs the SQL query dynamically and executes it using `SQL_FastQuery`. 
 * If the query fails, an error is logged. Otherwise, a success message is logged.
 * 
 * @note The function assumes that `g_dbDatabase` is a valid database handle and `g_szTableAccess` 
 *       contains the name of the target table.
 */
bool vTRGAccessExpireUpdate()
{
    char szQuery[1024];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER trg_bans_access_before_update ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE UPDATE ON %s ", g_szTableAccess);
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FOR EACH ROW ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEGIN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF NEW.ban_length > 0 THEN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00'); ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.expire = NULL; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END IF; ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END;");

	if (!SQL_FastQuery(g_dbDatabase, szQuery))
	{
		logErrorSQL(g_dbDatabase, szQuery, "vTRGAccessExpireUpdate");
		return false;
	}

    return true;
}

/**
 * Creates a cache table in the database if it does not already exist.
 *
 * The table is named based on the global variable `g_szTableCache` and contains the following columns:
 * - `ban_id` (INT): A non-null integer with a default value of 0.
 * - `steam_id` (VARCHAR(64)): A non-null string representing the Steam ID.
 * - `date_cache` (INTEGER): An optional integer representing the cache date.
 *
 * Logs the SQL query and its execution status for debugging purposes.
 *
 * @return True if the table was created successfully or already exists, false otherwise.
 */
bool vCacheTable()
{
    if (g_dbCache == null)
    {
        LogError("[vCacheTable] Database handle is null.");
        return false;
    }
    
    char szQuery[512];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_szTableCache);
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_id` INT NOT NULL DEFAULT 0, ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` VARCHAR(64) NOT NULL, ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_cache` INTEGER DEFAULT (strftime('%%s', 'now'))");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ");");

	LogSQL("[vCacheTable] Table created: %s", g_szTableCache);
	LogSQL("[vCacheTable] szQuery: %s", szQuery);

	if (!SQL_FastQuery(g_dbCache, szQuery))
	{
		logErrorSQL(g_dbCache, szQuery, "vCacheTable");
		return false;
	}
    else
        LogDebug("[vCacheTable] Table created successfully.");

    return true;
}

/**
 * Creates a SQL trigger named "DeleteOldCache" that automatically deletes 
 * old cache entries from the cache table after a new entry is inserted.
 * 
 * The trigger ensures that any cache entry older than 7 days (604800 seconds) 
 * is removed based on the difference between the current time and the 
 * `date_cache` column.
 * 
 * @return bool
 *         - true: If the trigger was successfully created.
 *         - false: If there was an error executing the SQL query.
 * 
 * The function logs an error if the SQL query fails.
 */
bool vTRGDeleteOldCache()
{
    char szQuery[1024];
    int iLen = 0;

    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER IF NOT EXISTS DeleteOldCache ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "AFTER INSERT ON %s ", g_szTableCache);
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEGIN ");
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM %s ", g_szTableCache);
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE strftime('%%s', 'now') - date_cache > 604800; ");   // 604800 seconds = 7 days
    iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "END;");

	if (!SQL_FastQuery(g_dbCache, szQuery))
	{
		logErrorSQL(g_dbCache, szQuery, "vTRGCacheExpire");
		return false;
	}

    return true;
}