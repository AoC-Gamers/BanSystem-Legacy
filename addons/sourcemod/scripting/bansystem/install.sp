/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define SQL_OBJECT_TABLE		 "TABLE"
#define SQL_OBJECT_PROCEDURE	 "PROCEDURE"
#define SQL_OBJECT_TRIGGER		 "TRIGGER"
#define SQL_OBJECT_VIEW			 "VIEW"

#define TABLE_ACCESS			 "bans_access"
#define TABLE_COMM				 "bans_communication"
#define TABLE_DATA_ACCESS		 "attempts_access"
#define TABLE_CACHE				 "BanCache"

#define PROCEDURE_CHECKAUTHID	 "CheckAuthId"
#define PROCEDURE_ATTEMPTACCESS	 "AttemptAccess"

#define TRIGGER_ACCESS_INSERT	 "trg_bans_access_before_insert"
#define TRIGGER_ACCESS_UPDATE	 "trg_bans_access_before_update"
#define TRIGGER_DELETE_OLD_CACHE "DeleteOldCacheForSteamID"

#define VIEW_CACHE_VALID		 "BanCache_Valid"

ConVar
	g_cvRegAttemptAccess;

enum eTypeBan
{
	kNoBan	 = 0,
	kAccess	 = 1,
	kComm	 = 2,
	kRegData = 3
}

enum SQLEngine
{
	m_Mysql	 = 0,
	m_SQLite = 1
}

enum struct eSqlObject
{
	char szName[64];
	char szType[16];
}

eSqlObject g_arrSqlDB[] = {
	{TABLE_ACCESS, SQL_OBJECT_TABLE},
	{TABLE_COMM, SQL_OBJECT_TABLE},
	{TABLE_DATA_ACCESS, SQL_OBJECT_TABLE},

	{PROCEDURE_CHECKAUTHID, SQL_OBJECT_PROCEDURE},
	{PROCEDURE_ATTEMPTACCESS, SQL_OBJECT_PROCEDURE},

	{TRIGGER_ACCESS_INSERT, SQL_OBJECT_TRIGGER},
	{TRIGGER_ACCESS_UPDATE, SQL_OBJECT_TRIGGER}
};

eSqlObject g_arrSqlCache[] = {
	{TABLE_CACHE, SQL_OBJECT_TABLE},

	{TRIGGER_DELETE_OLD_CACHE, SQL_OBJECT_TRIGGER},

	{VIEW_CACHE_VALID, SQL_OBJECT_VIEW}
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

vOnPluginStart_Install()
{
	g_cvRegAttemptAccess = CreateConVar("sm_bansystem_Attempt", "1", "Enables a table with additional information that is collected on access attempts.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegAdminCmd("sm_bs_install_db", aInstallDBCmd, ADMFLAG_ROOT, "Install the tables in the Mysql database.");
	RegAdminCmd("sm_bs_reinstall_db", aReinstallDBCmd, ADMFLAG_ROOT, "Deletes and unstalls the tables in the Mysql database.");

	RegAdminCmd("sm_bs_install_cache", aInstallCacheCmd, ADMFLAG_ROOT, "Installs the tables in the SQLite database.");
	RegAdminCmd("sm_bs_reinstall_cache", aReinstallCacheCmd, ADMFLAG_ROOT, "Deletes and unstalls the tables in the SQLite database.");
}

Action aInstallDBCmd(int iClient, int iArgs)
{
	vInstallMySQLTable();
	return Plugin_Handled;
}

Action aReinstallDBCmd(int iClient, int iArgs)
{
	vDropAllSqlDBObjects();
	vInstallMySQLTable();
	return Plugin_Handled;
}

Action aInstallCacheCmd(int iClient, int iArgs)
{
	if (!g_cvLocalCache.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "CacheLocalDisabled");
		return Plugin_Handled;
	}

	vDropAllSqlCacheObjects();
	vInstallSQLiteTable();
	return Plugin_Handled;
}

Action aReinstallCacheCmd(int iClient, int iArgs)
{
	if (!g_cvLocalCache.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "CacheLocalDisabled");
		return Plugin_Handled;
	}

	vDeleteDBTable(TABLE_CACHE, m_SQLite);
	vInstallSQLiteTable();
	return Plugin_Handled;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * @brief Installs the necessary MySQL tables, procedures, and triggers for the ban system.
 *
 * This function ensures that the required database tables, stored procedures, and triggers
 * are created and exist in the MySQL database. It performs the following actions:
 */
void vInstallMySQLTable()
{
	vEnsureTableExists(TABLE_ACCESS, m_Mysql, kAccess);
	vEnsureTableExists(TABLE_COMM, m_Mysql, kComm);

	if (g_cvRegAttemptAccess.BoolValue)
		vEnsureTableExists(TABLE_DATA_ACCESS, m_Mysql, kRegData);

    vEnsureProcedureExists(PROCEDURE_CHECKAUTHID);
    vEnsureProcedureExists(PROCEDURE_ATTEMPTACCESS);

    vEnsureTriggerExists(TRIGGER_ACCESS_INSERT, m_Mysql);
    vEnsureTriggerExists(TRIGGER_ACCESS_UPDATE, m_Mysql);
}

/**
 * @brief Installs the necessary SQLite table, trigger, and view for the ban system.
 *
 * This function ensures that the required database table, trigger, and view
 * are created if they do not already exist.
 */
void vInstallSQLiteTable()
{
	vEnsureTableExists(TABLE_CACHE, m_SQLite);
    vEnsureTriggerExists(TRIGGER_DELETE_OLD_CACHE, m_SQLite);
    vEnsureViewExists(VIEW_CACHE_VALID, m_SQLite);
}

/**
 * Drops all SQL database objects defined in the global array `g_arrSqlDB`.
 *
 * This function iterates through the `g_arrSqlDB` array and calls the `bDropSQLObject` 
 * function for each entry, passing the object's name, type, and the MySQL connection handle.
 */
void vDropAllSqlDBObjects()
{
	for (int iIndex = 0; iIndex < sizeof(g_arrSqlDB); iIndex++)
	{
		bDropSQLObject(g_arrSqlDB[iIndex].szName, g_arrSqlDB[iIndex].szType, m_Mysql);
	}
}

/**
 * Drops all SQL cache objects stored in the global array `g_arrSqlCache`.
 * Iterates through the array and removes each SQL object by calling `bDropSQLObject`.
 *
 * This function is useful for cleaning up SQL cache objects to free resources
 * or reset the state of the database cache.
 */
void vDropAllSqlCacheObjects()
{
	for (int iIndex = 0; iIndex < sizeof(g_arrSqlCache); iIndex++)
	{
		bDropSQLObject(g_arrSqlCache[iIndex].szName, g_arrSqlCache[iIndex].szType, m_SQLite);
	}
}

/**
 * Drops a SQL object (e.g., table, view, etc.) if it exists in the database.
 *
 * @param szName    The name of the SQL object to drop.
 * @param szType    The type of the SQL object (e.g., "TABLE", "VIEW").
 * @param eEngine   The SQL engine to use (e.g., m_Mysql, m_SQLite).
 * @return          True if the query executed successfully, false otherwise.
 */
bool bDropSQLObject(const char[] szName, const char[] szType, SQLEngine eEngine)
{
	bool bResult;
	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DROP %s IF EXISTS `%s`;", szType, szName);

	switch (eEngine)
	{
		case m_Mysql:
			bResult = bExecuteQuery(g_dbDatabase, szQuery, szName);
		case m_SQLite:
			bResult = bExecuteQuery(g_dbCache, szQuery, szName);
	}
	return bResult;
}

/**
 * Ensures that a database table exists for the specified SQL engine.
 * If the table does not exist, it creates the table based on the engine type.
 *
 * @param szTable   The name of the table to check or create.
 * @param eEngine   The SQL engine type (e.g., MySQL or SQLite).
 * @param eBan      (Optional) The type of ban to apply when creating the table. Defaults to kNoBan.
 */
void vEnsureTableExists(const char[] szTable, SQLEngine eEngine, eTypeBan eBan = kNoBan)
{
	if (bTableExists(szTable, eEngine))
		return;

	bCreateTable(szTable, eEngine, eBan);
}

/**
 * Ensures that a stored procedure exists in the MySQL database.
 * If it does not exist, it creates it using the appropriate creation function.
 *
 * @param szProcedureName The name of the stored procedure to ensure exists.
 */
void vEnsureProcedureExists(const char[] szProcedureName)
{
	if (!bProcedureExists(szProcedureName))
		bCreateProcedure(szProcedureName);
}

/**
 * Ensures that a trigger exists in the database for the specified engine.
 * If it doesn't, it will be created.
 *
 * @param szTriggerName The name of the trigger to ensure exists.
 * @param eEngine       The SQL engine type.
 */
void vEnsureTriggerExists(const char[] szTriggerName, SQLEngine eEngine)
{
	if (bTriggerExists(szTriggerName, eEngine))
		return;

	bCreateTrigger(szTriggerName);
}

/**
 * Ensures that a SQL view exists in the database.
 * If the view does not exist, it will be created.
 *
 * @param szViewName The name of the view.
 * @param eEngine    The SQL engine (e.g., m_SQLite or m_Mysql).
 */
void vEnsureViewExists(const char[] szViewName, SQLEngine eEngine)
{
	if (bViewExists(szViewName, eEngine))
		return;

	bCreateView(szViewName);
}

/**
 * Executes a SQL query on the given database handle and logs the result.
 *
 * @param dbDataBase    The database handle to execute the query on. Must not be null.
 * @param szQuery       The SQL query string to execute.
 * @param szContext     A context string used for logging purposes to identify the source of the query.
 *
 * @return              True if the query was executed successfully, false otherwise.
 */
bool bExecuteQuery(Database dbDataBase, const char[] szQuery, const char[] szContext)
{
	if (dbDataBase == null)
	{
		LogError("[%s] Database handle is null.", szContext);
		return false;
	}

	if (!SQL_FastQuery(dbDataBase, szQuery))
	{
		logErrorSQL(dbDataBase, szQuery, szContext);
		return false;
	}
	LogDebug("[%s] Query executed successfully: %s", szContext, szQuery);
	return true;
}

/**
 * Checks if a specific table exists in the database.
 *
 * @param szTable   The name of the table to check for existence.
 * @param eEngine   The SQL engine being used (either SQLite or MySQL).
 *
 * @return          True if the table exists, false otherwise.
 */
stock bool bTableExists(const char[] szTable, SQLEngine eEngine)
{
	char		szQuery[255];
	DBResultSet hQueryTableExists = null;
	bool		bExists			  = false;

	if ((eEngine == m_SQLite && g_dbCache == null) || (eEngine == m_Mysql && g_dbDatabase == null))
	{
		LogError("[bTableExists] Database handle is null.");
		return false;
	}

	switch (eEngine)
	{
		case m_SQLite:
		{
			Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='table' AND name='%s'", szTable);
			hQueryTableExists = SQL_Query(g_dbCache, szQuery);
		}
		case m_Mysql:
		{
			Format(szQuery, sizeof(szQuery), "SHOW TABLES LIKE '%s'", szTable);
			hQueryTableExists = SQL_Query(g_dbDatabase, szQuery);
		}
	}

	if (hQueryTableExists == null)
	{
		logErrorSQL((eEngine == m_SQLite) ? g_dbCache : g_dbDatabase, szQuery, "bTableExists");
		return false;
	}

	bExists = hQueryTableExists.FetchRow();
	delete hQueryTableExists;

	return bExists;
}

/**
 * Checks if a stored procedure exists in the database.
 *
 * @param szProcedure    The name of the stored procedure to check.
 * @return               True if the procedure exists, false otherwise.
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
 * Checks if a database trigger exists in the specified SQL engine.
 *
 * @param szTrigger  The name of the trigger to check for existence.
 * @param eEngine    The SQL engine to use for the query (m_SQLite or m_Mysql).
 *
 * @return           True if the trigger exists, false otherwise.
 */
bool bTriggerExists(const char[] szTrigger, SQLEngine eEngine)
{
	char		szQuery[256];
	DBResultSet hQueryResult = null;
	bool		bExists		 = false;

	if ((eEngine == m_SQLite && g_dbCache == null) || (eEngine == m_Mysql && g_dbDatabase == null))
	{
		LogError("[bTriggerExists] Database handle is null.");
		return false;
	}

	switch (eEngine)
	{
		case m_SQLite:
		{
			Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='trigger' AND name='%s'", szTrigger);
			hQueryResult = SQL_Query(g_dbCache, szQuery);
		}
		case m_Mysql:
		{
			Format(szQuery, sizeof(szQuery), "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_NAME='%s'", szTrigger);
			hQueryResult = SQL_Query(g_dbDatabase, szQuery);
		}
	}

	if (hQueryResult == null)
	{
		logErrorSQL((eEngine == m_SQLite) ? g_dbCache : g_dbDatabase, szQuery, "bTriggerExists");
		return false;
	}

	bExists = hQueryResult.FetchRow();
	delete hQueryResult;

	return bExists;
}

/**
 * Checks if a specific database view exists in the connected database.
 *
 * @param szView    The name of the view to check for existence.
 * @param eEngine   The database engine being used (SQLite or MySQL).
 *
 * @return          True if the view exists, false otherwise.
 */
bool bViewExists(const char[] szView, SQLEngine eEngine)
{
	char		szQuery[256];
	DBResultSet hQueryResult = null;
	bool		bExists		 = false;

	if ((eEngine == m_SQLite && g_dbCache == null) || (eEngine == m_Mysql && g_dbDatabase == null))
	{
		LogError("[bViewExists] Database handle is null.");
		return false;
	}

	switch (eEngine)
	{
		case m_SQLite:
		{
			Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='view' AND name='%s'", szView);
			LogSQL("[bViewExists] Query (SQLite): %s", szQuery);
			hQueryResult = SQL_Query(g_dbCache, szQuery);
		}
		case m_Mysql:
		{
			Format(szQuery, sizeof(szQuery), "SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_NAME='%s'", szView);
			LogSQL("[bViewExists] Query (MySQL): %s", szQuery);
			hQueryResult = SQL_Query(g_dbDatabase, szQuery);
		}
	}

	if (hQueryResult == null)
	{
		logErrorSQL((eEngine == m_SQLite) ? g_dbCache : g_dbDatabase, szQuery, "bViewExists");
		return false;
	}

	bExists = hQueryResult.FetchRow();
	delete hQueryResult;

	return bExists;
}

/**
 * Crea una tabla en la base de datos según su nombre y motor.
 *
 * @param szTable  Nombre de la tabla.
 * @param eEngine  Motor SQL (MySQL o SQLite).
 * @param eBan     Tipo de ban (solo aplica en MySQL). Opcional.
 * @return         true si se ejecutó correctamente, false en caso contrario.
 */
bool bCreateTable(const char[] szTable, SQLEngine eEngine, eTypeBan eBan = kNoBan)
{
    bool bResult;
	char szQuery[1024];
	int iLen = 0;

    if(eEngine == m_SQLite)
    {
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", szTable);
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_id` INT NOT NULL DEFAULT 0, ");
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` VARCHAR(64) NOT NULL, ");
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_cache` INTEGER DEFAULT (strftime('%%s', 'now'))");
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ");");

        return bExecuteQuery(g_dbCache, szQuery, "bCreateCacheTable");
    }
    else if(eEngine == m_Mysql)
    {
        switch (eBan)
        {
            case kAccess:
            {
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", szTable);
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
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` (", szTable);
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
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", szTable);
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`id` int NOT NULL AUTO_INCREMENT, ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id` varchar(64) NOT NULL, ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN', ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0', ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "PRIMARY KEY (`id`) ");
                iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;");
            }
        }
        bResult = bExecuteQuery(g_dbDatabase, szQuery, "bCreateTable");
    }

	return bResult;
}

/**
 * Creates a stored procedure in the database based on its name.
 *
 * @param szProcedureName The name of the procedure to create.
 * @return                True if the procedure was created successfully, false otherwise.
 */
bool bCreateProcedure(const char[] szProcedureName)
{
	char szQuery[2048];
	int  iLen = 0;

	if (StrEqual(szProcedureName, PROCEDURE_CHECKAUTHID))
	{
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
	}
	else if (StrEqual(szProcedureName, PROCEDURE_ATTEMPTACCESS))
	{
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
	}
	else
	{
		LogError("[bCreateProcedure] Unknown procedure: %s", szProcedureName);
		return false;
	}

	return bExecuteQuery(g_dbDatabase, szQuery, "bCreateProcedure");
}

/**
 * Creates a trigger in the database based on its name.
 *
 * @param szTriggerName The name of the trigger to create.
 * @return              True if the trigger was created successfully, false otherwise.
 */
bool bCreateTrigger(const char[] szTriggerName)
{
	char szQuery[1024];
	int iLen = 0;

	if (StrEqual(szTriggerName, TRIGGER_ACCESS_INSERT))
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER %s ", TRIGGER_ACCESS_INSERT);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE INSERT ON %s FOR EACH ROW BEGIN ", TABLE_ACCESS);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF NEW.ban_length > 0 THEN ");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00'); ");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE SET NEW.date_expire = NULL; END IF; END;");
		return bExecuteQuery(g_dbDatabase, szQuery, "bCreateTrigger");
	}
	else if (StrEqual(szTriggerName, TRIGGER_ACCESS_UPDATE))
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER %s ", TRIGGER_ACCESS_UPDATE);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE UPDATE ON %s FOR EACH ROW BEGIN ", TABLE_ACCESS);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "IF NEW.ban_length > 0 THEN ");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00'); ");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ELSE SET NEW.expire = NULL; END IF; END;");
		return bExecuteQuery(g_dbDatabase, szQuery, "bCreateTrigger");
	}
	else if (StrEqual(szTriggerName, TRIGGER_DELETE_OLD_CACHE))
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER %s ", TRIGGER_DELETE_OLD_CACHE);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE INSERT ON %s BEGIN ", TABLE_CACHE);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM %s WHERE steam_id = NEW.steam_id; END;", TABLE_CACHE);
		return bExecuteQuery(g_dbCache, szQuery, "bCreateTrigger");
	}
	else
	{
		LogError("[bCreateTrigger] Unknown trigger: %s", szTriggerName);
		return false;
	}
}

/**
 * Deletes a database table if it exists.
 *
 * @param szTable   The name of the table to delete.
 * @param eEngine   The database engine to use (SQLite or MySQL).
 * @return          True if the query executed successfully, false otherwise.
 */
bool vDeleteDBTable(const char[] szTable, SQLEngine eEngine)
{
	bool bResult;
	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DROP TABLE IF EXISTS `%s`;", szTable);

	switch (eEngine)
	{
		case m_SQLite:
			bResult = bExecuteQuery(g_dbCache, szQuery, "vDeleteDBTable");

		case m_Mysql:
			bResult = bExecuteQuery(g_dbDatabase, szQuery, "vDeleteDBTable");
	}
	return bResult;
}

/**
 * Creates a SQL view in the database based on its name.
 *
 * @param szViewName The name of the view to create.
 * @return           True if the view was created successfully, false otherwise.
 */
bool bCreateView(const char[] szViewName)
{
	char szQuery[512];
	int iLen = 0;

	if (StrEqual(szViewName, VIEW_CACHE_VALID))
	{
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE VIEW IF NOT EXISTS BanCache_Valid AS ");
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_id` ");
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM %s ", TABLE_CACHE);
        iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE date_cache >= strftime('%%s', 'now') - 604800;");	  // 604800 segundos = 7 días

		return bExecuteQuery(g_dbCache, szQuery, "bCreateView");
	}
	else
	{
		LogError("[bCreateView] Unknown view: %s", szViewName);
		return false;
	}
}