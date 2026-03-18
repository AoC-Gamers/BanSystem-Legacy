/*****************************************************************
			D B
*****************************************************************/

stock bool BSCore_CanUsePrimaryDatabase()
{
	return (g_dbCorePrimary != null && g_bCorePrimaryReady);
}

stock bool BSCore_CanUseCacheDatabase()
{
	return (g_dbCoreCache != null && g_bCoreCacheReady);
}

stock void BSCore_ConnectDatabases()
{
	char szMysqlConfig[64];
	g_cvCoreMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	Database.Connect(BSCore_OnPrimaryDatabaseConnected, szMysqlConfig);
	BSCore_SQL("Connecting core primary database using config '%s'.", szMysqlConfig);

	if (!g_cvCoreSqliteCache.BoolValue)
	{
		if (g_dbCoreCache != null)
		{
			delete g_dbCoreCache;
			g_dbCoreCache = null;
		}

		g_bCoreCacheReady = false;
		return;
	}

	char szCacheConfig[64];
	g_cvCoreCacheConfig.GetString(szCacheConfig, sizeof(szCacheConfig));
	Database.Connect(BSCore_OnCacheDatabaseConnected, szCacheConfig);
	BSCore_SQL("Connecting core cache database using config '%s'.", szCacheConfig);
}

public void BSCore_OnPrimaryDatabaseConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary database connection failed: %s", szError);
		g_bCorePrimaryReady = false;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Core]", "database", "target=primary action=connect_failed error=%s", szError);
		return;
	}

	if (g_dbCorePrimary != null)
		delete g_dbCorePrimary;

	g_dbCorePrimary = db;
	BSCore_ValidatePrimarySummarySchema();
}

public void BSCore_OnCacheDatabaseConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		BSCore_SQL("Cache database connection failed: %s", szError);
		g_bCoreCacheReady = false;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Core]", "database", "target=cache action=connect_failed error=%s", szError);
		return;
	}

	if (g_dbCoreCache != null)
		delete g_dbCoreCache;

	g_dbCoreCache = db;
	BSCore_ValidateCacheSummarySchema();
}

stock void BSCore_ValidatePrimarySummarySchema()
{
	if (g_dbCorePrimary == null)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbCorePrimary.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbCorePrimary.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_CORE_SCHEMA_COMPONENT);
	BSCore_SQL("Primary schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySchemaMetaValidated, szQuery);
}

stock void BSCore_ValidateCacheSummarySchema(bool bAllowRepair = true)
{
	if (g_dbCoreCache == null)
		return;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT `comm_reason`, `spray_reason` FROM `%s` LIMIT 0;", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	BSCore_SQL("Cache summary validation query: %s", szQuery);
	SQL_TQuery(g_dbCoreCache, BSCore_OnCacheSummarySchemaValidated, szQuery, bAllowRepair ? 1 : 0);
}

public void BSCore_OnPrimarySchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary schema meta validation failed: %s", szError);
		g_bCorePrimaryReady = false;
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSCore_SQL("Primary schema meta validation failed: component '%s' not found.", BANSYSTEM_CORE_SCHEMA_COMPONENT);
		g_bCorePrimaryReady = false;
		delete rsResult;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_CORE_SCHEMA_VERSION)
	{
		BSCore_SQL("Primary schema meta validation failed: component '%s' expected version %d but found %d.", BANSYSTEM_CORE_SCHEMA_COMPONENT, BANSYSTEM_CORE_SCHEMA_VERSION, iVersion);
		g_bCorePrimaryReady = false;
		return;
	}

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT 1 FROM `%s` LIMIT 0;", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	BSCore_SQL("Primary summary validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySummarySchemaValidated, szQuery);
}

public void BSCore_OnPrimarySummarySchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary summary schema validation failed: %s", szError);
		g_bCorePrimaryReady = false;
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bCorePrimaryReady = true;
	BSCore_SQL("Primary summary schema validated.");
	BSCore_MaybeFinalizeMapTransition();
}

public void BSCore_OnCacheSummarySchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	bool bAllowRepair = (data != 0);

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Cache summary schema validation failed: %s", szError);
		if (bAllowRepair)
		{
			BSCore_SQL("Attempting automatic SQLite cache schema repair.");
			BSCore_DropCacheSchema();
			BSCore_InstallCacheSchema();
			BSCore_ValidateCacheSummarySchema(false);
			delete rsResult;
			return;
		}

		g_bCoreCacheReady = false;
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bCoreCacheReady = true;
	BSCore_SQL("Cache summary schema validated.");
	BSCore_MaybeFinalizeMapTransition();
}
