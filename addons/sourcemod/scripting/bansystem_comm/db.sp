/*****************************************************************
			D B
*****************************************************************/

stock void BSComm_OnPluginStart_DB()
{
}

stock void BSComm_ConnectDatabase()
{
	g_bBSCommDatabaseReady = false;

	char szConfig[64];
	g_cvBSCommMysqlConfig.GetString(szConfig, sizeof(szConfig));
	Database.Connect(BSComm_OnDatabaseConnected, szConfig);
	BSComm_SQL("Connecting communication database using config '%s'.", szConfig);
}

public void BSComm_OnDatabaseConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		BSComm_SQL("Communication database connection failed: %s", szError);
		g_bBSCommDatabaseReady = false;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Comm]", "database", "action=connect_failed error=%s", szError);
		return;
	}

	if (g_dbBSComm != null)
		delete g_dbBSComm;

	g_dbBSComm = db;
	BSComm_ValidateSchema();
}

stock void BSComm_ValidateSchema()
{
	if (g_dbBSComm == null)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_COMM_SCHEMA_COMPONENT);
	BSComm_SQL("Communication schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbBSComm, BSComm_OnSchemaMetaValidated, szQuery);
}

public void BSComm_OnSchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSComm_SQL("Communication schema meta validation failed: %s", szError);
		g_bBSCommDatabaseReady = false;
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSComm_SQL("Communication schema meta validation failed: component '%s' not found.", BANSYSTEM_COMM_SCHEMA_COMPONENT);
		g_bBSCommDatabaseReady = false;
		delete rsResult;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_COMM_SCHEMA_VERSION)
	{
		BSComm_SQL("Communication schema meta validation failed: component '%s' expected version %d but found %d.", BANSYSTEM_COMM_SCHEMA_COMPONENT, BANSYSTEM_COMM_SCHEMA_VERSION, iVersion);
		g_bBSCommDatabaseReady = false;
		return;
	}

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT 1 FROM `bansystem_comm_bans` LIMIT 0;");
	BSComm_SQL("Communication schema validation query: %s", szQuery);
	SQL_TQuery(g_dbBSComm, BSComm_OnSchemaValidated, szQuery);
}

public void BSComm_OnSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSComm_SQL("Communication schema validation failed: %s", szError);
		g_bBSCommDatabaseReady = false;
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bBSCommDatabaseReady = true;
	BSComm_SQL("Communication schema validated.");
	if (BSComm_CanUseCoreLibrary() && BSCore_IsAuthReady())
		BSComm_ReconcileAllCommStatesFromCore();
}
