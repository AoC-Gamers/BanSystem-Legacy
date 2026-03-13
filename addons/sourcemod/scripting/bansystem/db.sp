/*****************************************************************
			D B
*****************************************************************/

void vConnectDB(char[] szConfigName, bool bCache = false)
{
	if (!SQL_CheckConfig(szConfigName))
	{
        LogError("[vConnectDB] SQL config not found: %s", szConfigName);
		if (!bCache)
			SetFailState("Missing BanSystem MySQL database configuration: %s", szConfigName);
		return;
	}

	Database.Connect(vConnectCallback, szConfigName, bCache);
}

void vConnectCallback(Database dbDatabase, const char[] szError, any pData)
{
	bool bCache = view_as<bool>(pData);

	if (dbDatabase == null)
	{
        LogError("[vConnectCallback] Database connection failed.");
		if (!bCache)
			SetFailState("Primary MySQL connection failed. Check the BanSystem database configuration.");
		return;
	}

	if (szError[0] != '\0')
	{
        LogError("[vConnectCallback] %s", szError);
		delete dbDatabase;
		if (!bCache)
			SetFailState("Primary MySQL connection failed. Check the BanSystem database configuration.");
		return;
	}

	if (bCache)
	{
		g_dbCache = dbDatabase;
		bValidateSQLiteCacheSchema(true);
		vProcessQueuedAuthorizationChecks();
	}
	else
	{
		g_bPrimaryDatabaseReady = false;
		g_dbDatabase = dbDatabase;
		vValidateMySQLSchema();
	}
}

void vValidateMySQLSchema()
{
	if (g_dbDatabase == null)
		return;

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT `version_num` FROM `%s` ORDER BY `version_num` DESC LIMIT 1;", TABLE_SCHEMA_VERSION);

	LogSQL("[vValidateMySQLSchema] Query: %s", szQuery);
	SQL_TQuery(g_dbDatabase, vValidateMySQLSchemaCallback, szQuery);
}

void vValidateMySQLSchemaCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vValidateMySQLSchemaCallback");
		delete rsResult;
		SetFailState("MySQL schema validation failed. Import ScriptsSQL/mysql/schema.sql (schema version %d).", MYSQL_SCHEMA_VERSION);
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		SetFailState("MySQL schema version table is empty. Import ScriptsSQL/mysql/schema.sql (schema version %d).", MYSQL_SCHEMA_VERSION);
		return;
	}

	int iSchemaVersion = rsResult.FetchInt(0);
	delete rsResult;

	if (iSchemaVersion != MYSQL_SCHEMA_VERSION)
	{
		SetFailState("MySQL schema version mismatch. Expected %d but found %d. Reinstall ScriptsSQL/mysql/schema.sql.", MYSQL_SCHEMA_VERSION, iSchemaVersion);
		return;
	}

	g_bPrimaryDatabaseReady = true;
	LogDebug("[vValidateMySQLSchemaCallback] MySQL schema version validated: %d", iSchemaVersion);
	vCleanupExpiredMySQLBans();
	vMaybeFinalizeMapTransition();
	vProcessQueuedAuthorizationChecks();
}

void vCleanupExpiredMySQLBans()
{
	if (!bCanUsePrimaryDatabase())
		return;

	char szQuery[256];

	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `ban_length` != 0 AND `date_expire` IS NOT NULL AND `date_expire` <= UTC_TIMESTAMP();", TABLE_ACCESS);
	SQL_TQuery(g_dbDatabase, vCleanupExpiredAccessCallback, szQuery);

	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `ban_length` != 0 AND `date_expire` IS NOT NULL AND `date_expire` <= UTC_TIMESTAMP();", TABLE_COMM);
	SQL_TQuery(g_dbDatabase, vCleanupExpiredCommCallback, szQuery);
}

void vCleanupExpiredAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vCleanupExpiredAccessCallback");
		delete rsResult;
		return;
	}

	LogDebug("[vCleanupExpiredAccessCallback] Cleanup completed. Affected rows: %d", SQL_GetAffectedRows(dbDataBase));
	delete rsResult;
}

void vCleanupExpiredCommCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vCleanupExpiredCommCallback");
		delete rsResult;
		return;
	}

	LogDebug("[vCleanupExpiredCommCallback] Cleanup completed. Affected rows: %d", SQL_GetAffectedRows(dbDataBase));
	delete rsResult;
}
