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

stock bool BSCore_IsPrimaryConnectionError(const char[] szError)
{
	return (StrContains(szError, "server has gone away", false) != -1
		|| StrContains(szError, "lost connection", false) != -1
		|| StrContains(szError, "connection refused", false) != -1
		|| StrContains(szError, "connection is closed", false) != -1
		|| StrContains(szError, "broken pipe", false) != -1
		|| StrContains(szError, "2006", false) != -1
		|| StrContains(szError, "2013", false) != -1);
}

stock void BSCore_AdvancePrimaryDatabaseGeneration()
{
	if (g_iCorePrimaryDatabaseGeneration >= 2147483646)
		g_iCorePrimaryDatabaseGeneration = 1;
	else
		g_iCorePrimaryDatabaseGeneration++;
}

stock void BSCore_MarkPrimaryDatabaseUnavailable(const char[] szError)
{
	g_bCorePrimaryReady = false;
	BSCore_UpdateAuthReadyState();
	if (!BSCore_IsPrimaryConnectionError(szError))
		return;

	BSCore_SQL("Discarding primary database handle after connection error; next retry will reconnect.");
	g_bCorePrimaryValidationPending = false;
	BSCore_AdvancePrimaryDatabaseGeneration();
	if (g_dbCorePrimary != null)
	{
		delete g_dbCorePrimary;
		g_dbCorePrimary = null;
	}
}

stock void BSCore_ConnectDatabases()
{
	BSCore_ConnectPrimaryDatabase();
	BSCore_EnsureDatabaseRetryTimer();

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

	BSCore_ConnectCacheDatabase();
}

stock void BSCore_ConnectPrimaryDatabase()
{
	if (g_dbCorePrimary != null)
	{
		if (!g_bCorePrimaryReady)
			BSCore_ValidatePrimarySummarySchema();
		return;
	}
	if (g_bCorePrimaryConnectPending)
		return;

	char szMysqlConfig[64];
	g_cvCoreMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	g_bCorePrimaryConnectPending = true;
	Database.Connect(BSCore_OnPrimaryDatabaseConnected, szMysqlConfig);
	BSCore_SQL("Connecting core primary database using config '%s'.", szMysqlConfig);
}

stock void BSCore_ConnectCacheDatabase()
{
	if (g_dbCoreCache != null)
	{
		if (!g_bCoreCacheReady)
			BSCore_ValidateCacheSummarySchema(false);
		return;
	}
	if (g_bCoreCacheConnectPending || !g_cvCoreSqliteCache.BoolValue)
		return;

	char szCacheConfig[64];
	g_cvCoreCacheConfig.GetString(szCacheConfig, sizeof(szCacheConfig));
	g_bCoreCacheConnectPending = true;
	Database.Connect(BSCore_OnCacheDatabaseConnected, szCacheConfig);
	BSCore_SQL("Connecting core cache database using config '%s'.", szCacheConfig);
}

stock void BSCore_EnsureDatabaseRetryTimer()
{
	if (g_hCoreDatabaseRetryTimer == null)
		g_hCoreDatabaseRetryTimer = CreateTimer(BANSYSTEM_CORE_DB_RETRY_INTERVAL, Timer_BSCoreDatabaseRetry, _, TIMER_REPEAT);
}

public Action Timer_BSCoreDatabaseRetry(Handle hTimer, any data)
{
	if (!g_bCorePrimaryReady && !g_bCorePrimaryConnectPending && !g_bCorePrimaryValidationPending)
	{
		if (g_dbCorePrimary == null)
			BSCore_ConnectPrimaryDatabase();
		else
			BSCore_ValidatePrimarySummarySchema();
	}

	if (g_cvCoreSqliteCache.BoolValue && !g_bCoreCacheReady && !g_bCoreCacheConnectPending && !g_bCoreCacheValidationPending)
	{
		if (g_dbCoreCache == null)
			BSCore_ConnectCacheDatabase();
		else
			BSCore_ValidateCacheSummarySchema(false);
	}

	return Plugin_Continue;
}

public void BSCore_OnPrimaryDatabaseConnected(Database db, const char[] szError, any data)
{
	g_bCorePrimaryConnectPending = false;
	if (db == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary database connection failed: %s", szError);
		g_bCorePrimaryReady = false;
		BSCore_UpdateAuthReadyState();
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Core]", "database", "target=primary action=connect_failed error=%s", szError);
		return;
	}

	if (g_dbCorePrimary != null)
		delete g_dbCorePrimary;

	g_dbCorePrimary = db;
	BSCore_AdvancePrimaryDatabaseGeneration();
	BSCore_ValidatePrimarySummarySchema();
}

public void BSCore_OnCacheDatabaseConnected(Database db, const char[] szError, any data)
{
	g_bCoreCacheConnectPending = false;
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
	if (g_dbCorePrimary == null || g_bCorePrimaryValidationPending)
		return;

	g_bCorePrimaryValidationPending = true;
	char szQuery[256];
	int iLen = 0;
	iLen += g_dbCorePrimary.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbCorePrimary.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_CORE_SCHEMA_COMPONENT);
	BSCore_SQL("Primary schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySchemaMetaValidated, szQuery, g_iCorePrimaryDatabaseGeneration);
}

stock void BSCore_ValidateCacheSummarySchema(bool bAllowRepair = true)
{
	if (g_dbCoreCache == null || g_bCoreCacheValidationPending)
		return;

	g_bCoreCacheValidationPending = true;
	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT `comm_reason`, `spray_reason` FROM `%s` LIMIT 0;", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	BSCore_SQL("Cache summary validation query: %s", szQuery);
	SQL_TQuery(g_dbCoreCache, BSCore_OnCacheSummarySchemaValidated, szQuery, bAllowRepair ? 1 : 0);
}

stock void BSCore_RequestPrimaryAuthViewSchemaValidation()
{
	if (g_dbCorePrimary == null)
		return;

	char szQuery[768];
	Format(szQuery, sizeof(szQuery), "SELECT `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, `comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, `spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts` FROM `%s` LIMIT 0;", BANSYSTEM_CORE_MYSQL_VIEW_AUTH_SUMMARY);
	BSCore_SQL("Primary auth view schema validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimaryAuthViewSchemaValidated, szQuery, g_iCorePrimaryDatabaseGeneration);
}

stock void BSCore_RequestPrimaryActiveViewSchemaValidation()
{
	if (g_dbCorePrimary == null)
		return;

	char szQuery[768];
	Format(szQuery, sizeof(szQuery), "SELECT `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, `comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, `spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts` FROM `%s` LIMIT 0;", BANSYSTEM_CORE_MYSQL_VIEW_ACTIVE_SUMMARY);
	BSCore_SQL("Primary active view schema validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimaryActiveViewSchemaValidated, szQuery, g_iCorePrimaryDatabaseGeneration);
}

public void BSCore_OnPrimarySchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (db == null || g_dbCorePrimary == null || !SQL_IsSameConnection(db, g_dbCorePrimary) || data != g_iCorePrimaryDatabaseGeneration)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		g_bCorePrimaryValidationPending = false;
		BSCore_SQL("Primary schema meta validation failed: %s", szError);
		BSCore_MarkPrimaryDatabaseUnavailable(szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		g_bCorePrimaryValidationPending = false;
		BSCore_SQL("Primary schema meta validation failed: component '%s' not found.", BANSYSTEM_CORE_SCHEMA_COMPONENT);
		g_bCorePrimaryReady = false;
		BSCore_UpdateAuthReadyState();
		delete rsResult;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_CORE_SCHEMA_VERSION)
	{
		g_bCorePrimaryValidationPending = false;
		BSCore_SQL("Primary schema meta validation failed: component '%s' expected version %d but found %d.", BANSYSTEM_CORE_SCHEMA_COMPONENT, BANSYSTEM_CORE_SCHEMA_VERSION, iVersion);
		g_bCorePrimaryReady = false;
		BSCore_UpdateAuthReadyState();
		return;
	}

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT 1 FROM `%s` LIMIT 0;", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	BSCore_SQL("Primary summary validation query: %s", szQuery);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySummarySchemaValidated, szQuery, g_iCorePrimaryDatabaseGeneration);
}

public void BSCore_OnPrimarySummarySchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (db == null || g_dbCorePrimary == null || !SQL_IsSameConnection(db, g_dbCorePrimary) || data != g_iCorePrimaryDatabaseGeneration)
	{
		delete rsResult;
		return;
	}
	if (rsResult == null || szError[0] != '\0')
	{
		g_bCorePrimaryValidationPending = false;
		BSCore_SQL("Primary summary schema validation failed: %s", szError);
		BSCore_MarkPrimaryDatabaseUnavailable(szError);
		delete rsResult;
		return;
	}

	delete rsResult;
	BSCore_RequestPrimaryAuthViewSchemaValidation();
}

public void BSCore_OnPrimaryAuthViewSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (db == null || g_dbCorePrimary == null || !SQL_IsSameConnection(db, g_dbCorePrimary) || data != g_iCorePrimaryDatabaseGeneration)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		g_bCorePrimaryValidationPending = false;
		BSCore_SQL("Primary auth view schema validation failed: %s", szError);
		BSCore_MarkPrimaryDatabaseUnavailable(szError);
		delete rsResult;
		return;
	}

	delete rsResult;
	BSCore_RequestPrimaryActiveViewSchemaValidation();
}

public void BSCore_OnPrimaryActiveViewSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (db == null || g_dbCorePrimary == null || !SQL_IsSameConnection(db, g_dbCorePrimary) || data != g_iCorePrimaryDatabaseGeneration)
	{
		delete rsResult;
		return;
	}

	g_bCorePrimaryValidationPending = false;
	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary active view schema validation failed: %s", szError);
		BSCore_MarkPrimaryDatabaseUnavailable(szError);
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bCorePrimaryReady = true;
	BSCore_SQL("Primary summary table and auth/active views validated.");
	BSCore_MaybeFinalizeMapTransition();
	BSCore_UpdateAuthReadyState();
}

public void BSCore_OnCacheSummarySchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (db == null || g_dbCoreCache == null || !SQL_IsSameConnection(db, g_dbCoreCache))
	{
		delete rsResult;
		return;
	}
	g_bCoreCacheValidationPending = false;
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
