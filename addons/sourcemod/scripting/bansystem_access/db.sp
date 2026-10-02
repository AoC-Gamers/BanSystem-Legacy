/*****************************************************************
			D B
*****************************************************************/

#define BANSYSTEM_ACCESS_CONNECT_TIMEOUT 30.0
#define BANSYSTEM_ACCESS_SCHEMA_TIMEOUT 15.0

stock void BSAccess_OnPluginStart_DB()
{
}

stock void BSAccess_ConnectDatabase()
{
	if (g_bBSAccessDatabaseReady && g_dbBSAccess != null)
		return;

	if (g_bBSAccessDatabaseConnectPending || g_bBSAccessSchemaValidationPending || g_hBSAccessDatabaseRetryTimer != null)
		return;

	if (g_dbBSAccess != null)
	{
		BSAccess_ValidateSchema();
		return;
	}

	char szConfig[64];
	g_cvBSAccessMysqlConfig.GetString(szConfig, sizeof(szConfig));

	int iGeneration = BSAccess_AdvanceDatabaseGeneration();
	g_bBSAccessDatabaseReady = false;
	g_bBSAccessDatabaseConnectPending = true;
	g_hBSAccessDatabaseConnectWatchdog = CreateTimer(BANSYSTEM_ACCESS_CONNECT_TIMEOUT, BSAccess_OnConnectWatchdog, iGeneration);
	Database.Connect(BSAccess_OnDatabaseConnected, szConfig, iGeneration);
	BSAccess_SQL("Connecting access database using config '%s'.", szConfig);
}

stock int BSAccess_AdvanceDatabaseGeneration()
{
	g_iBSAccessDatabaseGeneration++;
	if (g_iBSAccessDatabaseGeneration <= 0)
		g_iBSAccessDatabaseGeneration = 1;

	return g_iBSAccessDatabaseGeneration;
}

stock void BSAccess_CancelDatabaseTimers()
{
	delete g_hBSAccessDatabaseConnectWatchdog;
	g_hBSAccessDatabaseConnectWatchdog = null;
	delete g_hBSAccessSchemaWatchdog;
	g_hBSAccessSchemaWatchdog = null;
	delete g_hBSAccessDatabaseRetryTimer;
	g_hBSAccessDatabaseRetryTimer = null;
}

stock void BSAccess_CancelConnectWatchdog()
{
	delete g_hBSAccessDatabaseConnectWatchdog;
	g_hBSAccessDatabaseConnectWatchdog = null;
}

stock void BSAccess_CancelSchemaWatchdog()
{
	delete g_hBSAccessSchemaWatchdog;
	g_hBSAccessSchemaWatchdog = null;
}

stock void BSAccess_StartSchemaWatchdog(int iGeneration)
{
	BSAccess_CancelSchemaWatchdog();
	g_hBSAccessSchemaWatchdog = CreateTimer(BANSYSTEM_ACCESS_SCHEMA_TIMEOUT, BSAccess_OnSchemaWatchdog, iGeneration);
}

stock void BSAccess_ScheduleDatabaseRetry(const char[] szReason)
{
	if (g_hBSAccessDatabaseRetryTimer != null)
		return;

	static const float flRetryDelays[] = {1.0, 2.0, 4.0, 8.0, 16.0, 30.0};
	int iDelayIndex = g_iBSAccessDatabaseRetryAttempt;
	if (iDelayIndex >= sizeof(flRetryDelays))
		iDelayIndex = sizeof(flRetryDelays) - 1;

	float flDelay = flRetryDelays[iDelayIndex];
	g_iBSAccessDatabaseRetryAttempt++;
	if (g_iBSAccessDatabaseRetryAttempt >= sizeof(flRetryDelays))
		g_iBSAccessDatabaseRetryAttempt = sizeof(flRetryDelays) - 1;

	g_hBSAccessDatabaseRetryTimer = CreateTimer(flDelay, BSAccess_OnDatabaseRetry, g_iBSAccessDatabaseGeneration);
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=retry_scheduled reason=%s delay_seconds=%.0f attempt=%d", szReason, flDelay, g_iBSAccessDatabaseRetryAttempt);
}

public Action BSAccess_OnConnectWatchdog(Handle hTimer, any data)
{
	if (hTimer != g_hBSAccessDatabaseConnectWatchdog)
		return Plugin_Stop;

	g_hBSAccessDatabaseConnectWatchdog = null;

	if (data != g_iBSAccessDatabaseGeneration || !g_bBSAccessDatabaseConnectPending)
		return Plugin_Stop;

	g_bBSAccessDatabaseConnectPending = false;
	g_bBSAccessDatabaseReady = false;
	BSAccess_AdvanceDatabaseGeneration();
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=connect_timeout retry=true");
	BSAccess_ScheduleDatabaseRetry("connect_timeout");
	return Plugin_Stop;
}

public Action BSAccess_OnSchemaWatchdog(Handle hTimer, any data)
{
	if (hTimer != g_hBSAccessSchemaWatchdog)
		return Plugin_Stop;

	g_hBSAccessSchemaWatchdog = null;

	if (data != g_iBSAccessDatabaseGeneration || !g_bBSAccessSchemaValidationPending)
		return Plugin_Stop;

	g_bBSAccessSchemaValidationPending = false;
	g_bBSAccessDatabaseReady = false;
	BSAccess_AdvanceDatabaseGeneration();
	bool bHadDatabaseHandle = g_dbBSAccess != null;
	Database db = g_dbBSAccess;
	g_dbBSAccess = null;
	delete db;
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=schema_timeout retry=true handle_discarded=%d", bHadDatabaseHandle ? 1 : 0);
	BSAccess_ScheduleDatabaseRetry("schema_timeout");
	return Plugin_Stop;
}

public Action BSAccess_OnDatabaseRetry(Handle hTimer, any data)
{
	if (hTimer != g_hBSAccessDatabaseRetryTimer)
		return Plugin_Stop;

	g_hBSAccessDatabaseRetryTimer = null;

	if (data != g_iBSAccessDatabaseGeneration)
		return Plugin_Stop;

	BSAccess_ConnectDatabase();
	return Plugin_Stop;
}

public void BSAccess_OnDatabaseConnected(Database db, const char[] szError, any data)
{
	if (data != g_iBSAccessDatabaseGeneration || !g_bBSAccessDatabaseConnectPending)
	{
		delete db;
		return;
	}

	BSAccess_CancelConnectWatchdog();
	g_bBSAccessDatabaseConnectPending = false;
	if (db == null || szError[0] != '\0')
	{
		delete db;
		g_bBSAccessDatabaseReady = false;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=connect_failed retry=true");
		BSAccess_ScheduleDatabaseRetry("connect_failed");
		return;
	}

	if (g_dbBSAccess != null && g_dbBSAccess != db)
	{
		delete db;
		BSAccess_ValidateSchema();
		return;
	}

	g_dbBSAccess = db;
	g_bBSAccessDatabaseReady = false;
	BSAccess_ValidateSchema();
}

stock void BSAccess_ValidateSchema()
{
	if (g_dbBSAccess == null || g_bBSAccessSchemaValidationPending)
		return;

	int iGeneration = BSAccess_AdvanceDatabaseGeneration();
	g_bBSAccessSchemaValidationPending = true;
	g_bBSAccessDatabaseReady = false;
	BSAccess_StartSchemaWatchdog(iGeneration);

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_ACCESS_SCHEMA_COMPONENT);
	BSAccess_SQL("Access schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnSchemaMetaValidated, szQuery, iGeneration);
}

stock bool BSAccess_IsCurrentSchemaCallback(Database db, int iGeneration, DBResultSet rsResult)
{
	if (iGeneration == g_iBSAccessDatabaseGeneration
		&& g_bBSAccessSchemaValidationPending
		&& db != null
		&& g_dbBSAccess != null
		&& SQL_IsSameConnection(db, g_dbBSAccess))
		return true;

	delete rsResult;
	return false;
}

stock void BSAccess_FailSchemaValidation(const char[] szReason, bool bQueryError)
{
	g_bBSAccessSchemaValidationPending = false;
	BSAccess_CancelSchemaWatchdog();
	g_bBSAccessDatabaseReady = false;
	if (bQueryError)
		g_iBSAccessSchemaQueryFailureCount++;
	else
		g_iBSAccessSchemaQueryFailureCount = 0;

	if (bQueryError && g_iBSAccessSchemaQueryFailureCount >= 2)
	{
		Database db = g_dbBSAccess;
		g_dbBSAccess = null;
		BSAccess_AdvanceDatabaseGeneration();
		delete db;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=schema_validation_failed reason=%s retry=reconnect handle_retained=0 consecutive_query_errors=%d", szReason, g_iBSAccessSchemaQueryFailureCount);
	}
	else
	{
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "database", "action=schema_validation_failed reason=%s retry=true handle_retained=%d consecutive_query_errors=%d", szReason, g_dbBSAccess != null ? 1 : 0, g_iBSAccessSchemaQueryFailureCount);
	}

	BSAccess_ScheduleDatabaseRetry(szReason);
}

public void BSAccess_OnSchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (!BSAccess_IsCurrentSchemaCallback(db, data, rsResult))
		return;

	if (rsResult == null || szError[0] != '\0')
	{
		delete rsResult;
		BSAccess_FailSchemaValidation("meta_query_failed", true);
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSAccess_FailSchemaValidation("meta_component_missing", false);
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_ACCESS_SCHEMA_VERSION)
	{
		BSAccess_FailSchemaValidation("meta_version_mismatch", false);
		return;
	}

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT 1 FROM `bansystem_access_bans` LIMIT 0;");
	BSAccess_SQL("Access schema validation query: %s", szQuery);
	BSAccess_StartSchemaWatchdog(data);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnSchemaValidated, szQuery, data);
}

public void BSAccess_OnSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (!BSAccess_IsCurrentSchemaCallback(db, data, rsResult))
		return;

	if (rsResult == null || szError[0] != '\0')
	{
		delete rsResult;
		BSAccess_FailSchemaValidation("table_query_failed", true);
		return;
	}

	delete rsResult;
	BSAccess_CancelSchemaWatchdog();
	g_bBSAccessSchemaValidationPending = false;
	g_bBSAccessDatabaseReady = true;
	g_iBSAccessDatabaseRetryAttempt = 0;
	g_iBSAccessSchemaQueryFailureCount = 0;
	delete g_hBSAccessDatabaseRetryTimer;
	g_hBSAccessDatabaseRetryTimer = null;
	BSAccess_SQL("Access schema validated.");
	if (BSAccess_CanUseCoreLibrary() && BSCore_IsAuthReady())
		BSAccess_ReconcileAllAccessStatesFromCore();
}
