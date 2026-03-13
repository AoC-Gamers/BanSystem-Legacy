/*****************************************************************
			S C H E M A
*****************************************************************/

#define SQL_OBJECT_TABLE		 "TABLE"
#define SQL_OBJECT_TRIGGER		 "TRIGGER"
#define SQL_OBJECT_VIEW			 "VIEW"

#define TABLE_ACCESS			 "bans_access"
#define TABLE_COMM				 "bans_communication"
#define TABLE_DATA_ACCESS		 "attempts_access"
#define TABLE_SCHEMA_VERSION	 "bansystem_schema_version"
#define TABLE_CACHE				 "BanCache"

#define MYSQL_SCHEMA_VERSION	 6
#define TRIGGER_DELETE_OLD_CACHE "DeleteOldCacheForAccountID"
#define VIEW_CACHE_VALID		 "BanCache_Valid"

ConVar
	g_cvRegAttemptAccess;
bool g_bSQLiteCacheReady;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

void vOnPluginStart_Schema()
{
	// MySQL schema is managed externally. SQLite cache objects are installed manually and validated at runtime.
	g_cvRegAttemptAccess = CreateConVar("sm_bansystem_Attempt", "1", "Enables a table with additional information that is collected on access attempts.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bSQLiteCacheReady = false;

	RegAdminCmd("sm_bs_cache_install", aInstallCacheCmd, ADMFLAG_ROOT, "Installs the tables in the SQLite database.");
	RegAdminCmd("sm_bs_cache_reinstall", aReinstallCacheCmd, ADMFLAG_ROOT, "Deletes and reinstalls the tables in the SQLite database.");
}

Action aInstallCacheCmd(int iClient, int iArgs)
{
	if (!g_cvSQLCache.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "CacheSQLDisabled");
		return Plugin_Handled;
	}

	vInstallSQLiteTable();
	return Plugin_Handled;
}

Action aReinstallCacheCmd(int iClient, int iArgs)
{
	if (!g_cvSQLCache.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "CacheSQLDisabled");
		return Plugin_Handled;
	}

	vDropAllSqlCacheObjects();
	vInstallSQLiteTable();
	return Plugin_Handled;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void vInstallSQLiteTable()
{
	bDropSQLiteObject(TRIGGER_DELETE_OLD_CACHE, SQL_OBJECT_TRIGGER);
	bDropSQLiteObject(VIEW_CACHE_VALID, SQL_OBJECT_VIEW);

	if (bCacheTableExists(TABLE_CACHE) && !bCacheColumnExists(TABLE_CACHE, "account_id"))
		bDropSQLiteObject(TABLE_CACHE, SQL_OBJECT_TABLE);

	vEnsureCacheTableExists();

	bCreateSQLiteTrigger(TRIGGER_DELETE_OLD_CACHE);
	bCreateSQLiteView(VIEW_CACHE_VALID);
	g_bSQLiteCacheReady = bValidateSQLiteCacheSchema(true);
}

void vDropAllSqlCacheObjects()
{
	g_bSQLiteCacheReady = false;
	bDropSQLiteObject(VIEW_CACHE_VALID, SQL_OBJECT_VIEW);
	bDropSQLiteObject(TRIGGER_DELETE_OLD_CACHE, SQL_OBJECT_TRIGGER);
	bDropSQLiteObject(TABLE_CACHE, SQL_OBJECT_TABLE);
}

bool bCanUseSQLiteCache()
{
	return (g_cvSQLCache != null && g_cvSQLCache.BoolValue && g_dbCache != null && g_bSQLiteCacheReady);
}

bool bValidateSQLiteCacheSchema(bool bLogSuccess = false)
{
	if (g_dbCache == null)
	{
		LogError("[bValidateSQLiteCacheSchema] SQLite cache handle is null.");
		g_bSQLiteCacheReady = false;
		return false;
	}

	if (!bCacheTableExists(TABLE_CACHE))
	{
		LogError("[bValidateSQLiteCacheSchema] Missing SQLite cache table '%s'. Run sm_bs_cache_install.", TABLE_CACHE);
		g_bSQLiteCacheReady = false;
		return false;
	}

	if (!bCacheColumnExists(TABLE_CACHE, "account_id"))
	{
		LogError("[bValidateSQLiteCacheSchema] SQLite cache table '%s' is incompatible. Run sm_bs_cache_reinstall.", TABLE_CACHE);
		g_bSQLiteCacheReady = false;
		return false;
	}

	if (!bSQLiteObjectExists(SQL_OBJECT_TRIGGER, TRIGGER_DELETE_OLD_CACHE))
	{
		LogError("[bValidateSQLiteCacheSchema] Missing SQLite cache trigger '%s'. Run sm_bs_cache_install.", TRIGGER_DELETE_OLD_CACHE);
		g_bSQLiteCacheReady = false;
		return false;
	}

	if (!bSQLiteObjectExists(SQL_OBJECT_VIEW, VIEW_CACHE_VALID))
	{
		LogError("[bValidateSQLiteCacheSchema] Missing SQLite cache view '%s'. Run sm_bs_cache_install.", VIEW_CACHE_VALID);
		g_bSQLiteCacheReady = false;
		return false;
	}

	g_bSQLiteCacheReady = true;
	if (bLogSuccess)
		LogDebug("[bValidateSQLiteCacheSchema] SQLite cache schema validated.");
	return true;
}

bool bDropSQLiteObject(const char[] szName, const char[] szType)
{
	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DROP %s IF EXISTS `%s`;", szType, szName);
	return bExecuteSQLiteQuery(szQuery, szName);
}

bool bSQLiteObjectExists(const char[] szType, const char[] szName)
{
	if (g_dbCache == null)
	{
		LogError("[bSQLiteObjectExists] Database handle is null.");
		return false;
	}

	char szSQLiteType[16];
	if (StrEqual(szType, SQL_OBJECT_TABLE, false))
		strcopy(szSQLiteType, sizeof(szSQLiteType), "table");
	else if (StrEqual(szType, SQL_OBJECT_TRIGGER, false))
		strcopy(szSQLiteType, sizeof(szSQLiteType), "trigger");
	else if (StrEqual(szType, SQL_OBJECT_VIEW, false))
		strcopy(szSQLiteType, sizeof(szSQLiteType), "view");
	else
	{
		LogError("[bSQLiteObjectExists] Unknown sqlite object type: %s", szType);
		return false;
	}

	char szQuery[255];
	Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='%s' AND name='%s';", szSQLiteType, szName);

	DBResultSet rsObjectExists = SQL_Query(g_dbCache, szQuery);
	if (rsObjectExists == null)
	{
		logErrorSQL(g_dbCache, szQuery, "bSQLiteObjectExists");
		return false;
	}

	bool bExists = rsObjectExists.FetchRow();
	delete rsObjectExists;
	return bExists;
}

void vEnsureCacheTableExists()
{
	if (bCacheTableExists(TABLE_CACHE))
		return;

	bCreateCacheTable(TABLE_CACHE);
}

bool bExecuteSQLiteQuery(const char[] szQuery, const char[] szContext)
{
	if (g_dbCache == null)
	{
		LogError("[%s] Database handle is null.", szContext);
		return false;
	}

	if (!SQL_FastQuery(g_dbCache, szQuery))
	{
		logErrorSQL(g_dbCache, szQuery, szContext);
		return false;
	}

	LogDebug("[%s] Query executed successfully: %s", szContext, szQuery);
	return true;
}

bool bCacheTableExists(const char[] szTable)
{
	if (g_dbCache == null)
	{
		LogError("[bCacheTableExists] Database handle is null.");
		return false;
	}

	char szQuery[255];
	Format(szQuery, sizeof(szQuery), "SELECT name FROM sqlite_master WHERE type='table' AND name='%s'", szTable);

	DBResultSet hQueryTableExists = SQL_Query(g_dbCache, szQuery);
	if (hQueryTableExists == null)
	{
		logErrorSQL(g_dbCache, szQuery, "bCacheTableExists");
		return false;
	}

	bool bExists = hQueryTableExists.FetchRow();
	delete hQueryTableExists;
	return bExists;
}

bool bCreateCacheTable(const char[] szTable)
{
	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", szTable);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_id` INT NOT NULL DEFAULT 0, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`account_id` INTEGER NOT NULL, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`date_cache` INTEGER DEFAULT (strftime('%%s', 'now'))");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ");");

	return bExecuteSQLiteQuery(szQuery, "bCreateCacheTable");
}

bool bCreateSQLiteTrigger(const char[] szTriggerName)
{
	if (!StrEqual(szTriggerName, TRIGGER_DELETE_OLD_CACHE))
	{
		LogError("[bCreateSQLiteTrigger] Unknown trigger: %s", szTriggerName);
		return false;
	}

	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TRIGGER %s ", TRIGGER_DELETE_OLD_CACHE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "BEFORE INSERT ON %s BEGIN ", TABLE_CACHE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM %s WHERE account_id = NEW.account_id; END;", TABLE_CACHE);

	return bExecuteSQLiteQuery(szQuery, "bCreateSQLiteTrigger");
}

bool bCreateSQLiteView(const char[] szViewName)
{
	if (!StrEqual(szViewName, VIEW_CACHE_VALID))
	{
		LogError("[bCreateSQLiteView] Unknown view: %s", szViewName);
		return false;
	}

	char szQuery[512];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE VIEW IF NOT EXISTS BanCache_Valid AS ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_id`, `account_id`, `date_cache` ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM %s ", TABLE_CACHE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE date_cache >= strftime('%%s', 'now') - 604800;");

	return bExecuteSQLiteQuery(szQuery, "bCreateSQLiteView");
}

bool bCacheColumnExists(const char[] szTable, const char[] szColumn)
{
	if (g_dbCache == null)
	{
		LogError("[bCacheColumnExists] Database handle is null.");
		return false;
	}

	char szQuery[255];
	Format(szQuery, sizeof(szQuery), "PRAGMA table_info(`%s`);", szTable);

	DBResultSet rsTableInfo = SQL_Query(g_dbCache, szQuery);
	if (rsTableInfo == null)
	{
		logErrorSQL(g_dbCache, szQuery, "bCacheColumnExists");
		return false;
	}

	bool bExists = false;
	while (rsTableInfo.FetchRow())
	{
		char szColumnName[64];
		rsTableInfo.FetchString(1, szColumnName, sizeof(szColumnName));
		if (!StrEqual(szColumnName, szColumn))
			continue;

		bExists = true;
		break;
	}

	delete rsTableInfo;
	return bExists;
}
