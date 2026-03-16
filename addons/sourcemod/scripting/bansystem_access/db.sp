/*****************************************************************
			D B
*****************************************************************/

stock void BSAccess_OnPluginStart_DB()
{
}

stock void BSAccess_ConnectDatabase()
{
	g_bBSAccessDatabaseReady = false;

	char szConfig[64];
	g_cvBSAccessMysqlConfig.GetString(szConfig, sizeof(szConfig));
	Database.Connect(BSAccess_OnDatabaseConnected, szConfig);
	BSAccess_SQL("Connecting access database using config '%s'.", szConfig);
}

public void BSAccess_OnDatabaseConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		BSAccess_SQL("Access database connection failed: %s", szError);
		g_bBSAccessDatabaseReady = false;
		return;
	}

	if (g_dbBSAccess != null)
		delete g_dbBSAccess;

	g_dbBSAccess = db;
	BSAccess_ValidateSchema();
}

stock void BSAccess_ValidateSchema()
{
	if (g_dbBSAccess == null)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `version_num` FROM `%s` ", BANSYSTEM_SCHEMA_META_TABLE);
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `component` = '%s' LIMIT 1;", BANSYSTEM_ACCESS_SCHEMA_COMPONENT);
	BSAccess_SQL("Access schema meta validation query: %s", szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnSchemaMetaValidated, szQuery);
}

public void BSAccess_OnSchemaMetaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSAccess_SQL("Access schema meta validation failed: %s", szError);
		g_bBSAccessDatabaseReady = false;
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSAccess_SQL("Access schema meta validation failed: component '%s' not found.", BANSYSTEM_ACCESS_SCHEMA_COMPONENT);
		g_bBSAccessDatabaseReady = false;
		delete rsResult;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != BANSYSTEM_ACCESS_SCHEMA_VERSION)
	{
		BSAccess_SQL("Access schema meta validation failed: component '%s' expected version %d but found %d.", BANSYSTEM_ACCESS_SCHEMA_COMPONENT, BANSYSTEM_ACCESS_SCHEMA_VERSION, iVersion);
		g_bBSAccessDatabaseReady = false;
		return;
	}

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT 1 FROM `bansystem_access_bans` LIMIT 0;");
	BSAccess_SQL("Access schema validation query: %s", szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnSchemaValidated, szQuery);
}

public void BSAccess_OnSchemaValidated(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		BSAccess_SQL("Access schema validation failed: %s", szError);
		g_bBSAccessDatabaseReady = false;
		delete rsResult;
		return;
	}

	delete rsResult;
	g_bBSAccessDatabaseReady = true;
	BSAccess_SQL("Access schema validated.");
}
