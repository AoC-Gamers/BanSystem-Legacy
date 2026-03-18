/*****************************************************************
			D B
*****************************************************************/

stock void BSSprays_OnPluginStart_DB()
{
}

stock void BSSprays_ConnectDatabase()
{
	g_bBSSpraysDatabaseReady = false;

	char szConfig[64];
	g_cvBSSpraysMysqlConfig.GetString(szConfig, sizeof(szConfig));
	Database.Connect(BSSprays_OnDatabaseConnected, szConfig);
	BSSprays_SQL("Connecting sprays database using config '%s'.", szConfig);
}

public void BSSprays_OnDatabaseConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		BSSprays_SQL("Sprays database connection failed: %s", szError);
		g_bBSSpraysDatabaseReady = false;
		BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Sprays]", "database", "action=connect_failed error=%s", szError);
		return;
	}

	if (g_dbBSSprays != null)
		delete g_dbBSSprays;

	g_dbBSSprays = db;
	BSSprays_ValidateSchema();
}

stock void BSSprays_ValidateSchema()
{
	if (g_dbBSSprays == null)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_SPRAYS_SCHEMA_COMPONENT);
	BSSprays_SQL("Sprays schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnSchemaMetaValidated, szQuery);
}

public void BSSprays_OnSchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_SQL("Sprays schema meta validation failed: %s", szError);
		g_bBSSpraysDatabaseReady = false;
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSSprays_SQL("Sprays schema meta validation failed: component '%s' not found.", BANSYSTEM_SPRAYS_SCHEMA_COMPONENT);
		g_bBSSpraysDatabaseReady = false;
		delete rsResult;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_SPRAYS_SCHEMA_VERSION)
	{
		BSSprays_SQL("Sprays schema meta validation failed: component '%s' expected version %d but found %d.", BANSYSTEM_SPRAYS_SCHEMA_COMPONENT, BANSYSTEM_SPRAYS_SCHEMA_VERSION, iVersion);
		g_bBSSpraysDatabaseReady = false;
		return;
	}

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT 1 FROM `bansystem_spray_bans` LIMIT 0;");
	BSSprays_SQL("Sprays schema validation query: %s", szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnSchemaValidated, szQuery);
}

public void BSSprays_OnSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_SQL("Sprays schema validation failed: %s", szError);
		g_bBSSpraysDatabaseReady = false;
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bBSSpraysDatabaseReady = true;
	BSSprays_SQL("Sprays schema validated.");
	if (BSSprays_CanUseCoreLibrary() && BSCore_IsAuthReady())
		BSSprays_ReconcileAllSprayStatesFromCore();
}
