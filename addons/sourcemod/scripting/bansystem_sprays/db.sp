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
}
