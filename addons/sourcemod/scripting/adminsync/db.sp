void vStartAdminSync(int iClient = 0)
{
	if (g_bSyncInProgress)
	{
		vAdminSyncDebug("Reload skipped because a sync is already in progress.");
		CReplyToCommand(iClient, "%t", "BSAdminSyncSyncInProgress");
		return;
	}

	if (GetSnapshotBackend() == Backend_SQLite && g_dbLocal == null)
		vConnectLocalSnapshot();

	g_bSyncInProgress = true;
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncDebug("Starting snapshot sync using MySQL config '%s'.", szMysqlConfig);
	SQL_TConnect(vAdminSyncConnectCallback, szMysqlConfig, iClient);
}

void vBuildAdminSyncSchemaMetaQuery(char[] szQuery, int iMaxLength)
{
	Format(szQuery, iMaxLength, "SELECT `version_num` FROM `%s` WHERE `component` = '%s' LIMIT 1;", MYSQL_TABLE_SCHEMA_META, ADMINSYNC_SCHEMA_COMPONENT);
}

void vRequestSnapshotVersionCheck()
{
	if (g_bSyncInProgress || g_bVersionCheckInFlight)
	{
		vAdminSyncDebug("Version check skipped. sync_in_progress=%d version_check_in_flight=%d", g_bSyncInProgress ? 1 : 0, g_bVersionCheckInFlight ? 1 : 0);
		return;
	}

	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	g_bVersionCheckInFlight = true;
	vAdminSyncSQL("Running snapshot version check using MySQL config '%s'.", szMysqlConfig);
	SQL_TConnect(vAdminSyncVersionConnectCallback, szMysqlConfig);
}

public void vAdminSyncVersionConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	Database db = view_as<Database>(hndl);
	if (db == null)
	{
		LogError("[bansystem_adminsync] Version check connection failed: %s", szError);
		g_bVersionCheckInFlight = false;
		return;
	}

	char szQuery[160];
	vBuildAdminSyncSchemaMetaQuery(szQuery, sizeof(szQuery));
	vAdminSyncSQL("Version check connected. Validating schema component '%s'.", ADMINSYNC_SCHEMA_COMPONENT);
	SQL_TQuery(db, vAdminSyncVersionSchemaValidationCallback, szQuery);
}

public void vAdminSyncVersionSchemaValidationCallback(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Version check schema validation failed: %s", szError);
		g_bVersionCheckInFlight = false;
		delete rsResult;
		delete db;
		return;
	}

	if (!rsResult.FetchRow())
	{
		LogError("[bansystem_adminsync] Version check schema validation failed: component '%s' not found.", ADMINSYNC_SCHEMA_COMPONENT);
		g_bVersionCheckInFlight = false;
		delete rsResult;
		delete db;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != ADMINSYNC_SCHEMA_VERSION)
	{
		LogError("[bansystem_adminsync] Version check schema validation failed: expected %d but found %d for component '%s'.", ADMINSYNC_SCHEMA_VERSION, iVersion, ADMINSYNC_SCHEMA_COMPONENT);
		g_bVersionCheckInFlight = false;
		delete db;
		return;
	}

	char szQuery[160];
	Format(szQuery, sizeof(szQuery), "SELECT `meta_value` FROM `adminsync_meta` WHERE `meta_key` = 'snapshot_version';");
	vAdminSyncSQL("Schema validated for version check. Querying snapshot version.");
	SQL_TQuery(db, vAdminSyncVersionQueryCallback, szQuery);
}

public void vAdminSyncVersionQueryCallback(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	g_bVersionCheckInFlight = false;

	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Version check query failed: %s", szError);
		delete rsResult;
		delete db;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		delete db;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	delete db;

	if (g_iLastSnapshotVersion == 0)
	{
		g_iLastSnapshotVersion = iVersion;
		vAdminSyncDebug("Initialized local snapshot version to %d.", iVersion);
		return;
	}

	if (iVersion != g_iLastSnapshotVersion)
	{
		LogMessage("[bansystem_adminsync] Detected admin snapshot version change: %d -> %d", g_iLastSnapshotVersion, iVersion);
		vStartAdminSync();
	}
}

public void vAdminSyncConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any iClient)
{
	Database db = view_as<Database>(hndl);
	if (db == null)
	{
		LogError("[bansystem_adminsync] MySQL connection failed: %s", szError);
		CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
		g_bSyncInProgress = false;
		return;
	}

	char szQuery[160];
	vBuildAdminSyncSchemaMetaQuery(szQuery, sizeof(szQuery));
	vAdminSyncSQL("Connected to MySQL for full sync. Validating schema component '%s'.", ADMINSYNC_SCHEMA_COMPONENT);
	SQL_TQuery(db, vAdminSyncSchemaValidationCallback, szQuery, iClient);
}

public void vAdminSyncSchemaValidationCallback(Database db, DBResultSet rsResult, const char[] szError, any iClient)
{
	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Schema validation failed: %s", szError);
		CReplyToCommand(iClient, "%t", "BSAdminSyncSchemaValidationFailed");
		delete rsResult;
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	if (!rsResult.FetchRow())
	{
		LogError("[bansystem_adminsync] Schema validation failed: component '%s' not found.", ADMINSYNC_SCHEMA_COMPONENT);
		CReplyToCommand(iClient, "%t", "BSAdminSyncSchemaComponentMissing");
		delete rsResult;
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	int iVersion = rsResult.FetchInt(0);
	delete rsResult;
	if (iVersion != ADMINSYNC_SCHEMA_VERSION)
	{
		LogError("[bansystem_adminsync] Schema validation failed: expected %d but found %d for component '%s'.", ADMINSYNC_SCHEMA_VERSION, iVersion, ADMINSYNC_SCHEMA_COMPONENT);
		CReplyToCommand(iClient, "%t", "BSAdminSyncSchemaVersionMismatch");
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	g_iLastAdminCount = 0;
	g_iLastGroupCount = 0;
	g_iLastMembershipCount = 0;
	vAdminSyncSQL("Schema validated for full sync. backend=%d", view_as<int>(GetSnapshotBackend()));

	if (GetSnapshotBackend() == Backend_SQLite)
		vClearLocalSQLiteSnapshot();
	else
		vWriteEmptyKvSnapshot();

	char szVersionQuery[160];
	Format(szVersionQuery, sizeof(szVersionQuery), "SELECT `meta_value` FROM `adminsync_meta` WHERE `meta_key` = 'snapshot_version';");
	DBResultSet rsVersion = SQL_Query(db, szVersionQuery);
	if (rsVersion != null && rsVersion.FetchRow())
		g_iLastSnapshotVersion = rsVersion.FetchInt(0);
	delete rsVersion;
	vAdminSyncSQL("Full sync latched snapshot version %d.", g_iLastSnapshotVersion);

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT `id`, `accountid`, `name`, `flags`, `immunity`, `enabled` FROM `%s` WHERE `enabled` = 1 ORDER BY `id` ASC;", MYSQL_TABLE_ADMINS);
	SQL_TQuery(db, vAdminSyncAdminsCallback, szQuery, iClient);
}

public void vAdminSyncAdminsCallback(Database db, DBResultSet rsResult, const char[] szError, any iClient)
{
	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Admin snapshot query failed: %s", szError);
		CReplyToCommand(iClient, "%t", "BSAdminSyncAdminQueryFailed");
		delete rsResult;
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	if (GetSnapshotBackend() == Backend_SQLite)
		vPersistAdminsToSQLite(rsResult);
	else
		vPersistAdminsToKeyValues(rsResult);
	vAdminSyncDebug("Admin rows persisted: %d.", g_iLastAdminCount);

	delete rsResult;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT `id`, `name`, `flags`, `immunity_level`, `enabled` FROM `%s` WHERE `enabled` = 1 ORDER BY `id` ASC;", MYSQL_TABLE_GROUPS);
	SQL_TQuery(db, vAdminSyncGroupsCallback, szQuery, iClient);
}

public void vAdminSyncGroupsCallback(Database db, DBResultSet rsResult, const char[] szError, any iClient)
{
	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Group snapshot query failed: %s", szError);
		CReplyToCommand(iClient, "%t", "BSAdminSyncGroupQueryFailed");
		delete rsResult;
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	if (GetSnapshotBackend() == Backend_SQLite)
		vPersistGroupsToSQLite(rsResult);
	else
		vPersistGroupsToKeyValues(rsResult);
	vAdminSyncDebug("Group rows persisted: %d.", g_iLastGroupCount);

	delete rsResult;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT `admin_id`, `group_id`, `inherit_order` FROM `%s` ORDER BY `admin_id` ASC, `inherit_order` ASC;", MYSQL_TABLE_ADMINS_GROUPS);
	SQL_TQuery(db, vAdminSyncMembershipsCallback, szQuery, iClient);
}

public void vAdminSyncMembershipsCallback(Database db, DBResultSet rsResult, const char[] szError, any iClient)
{
	if (rsResult == null || szError[0] != '\0')
	{
		LogError("[bansystem_adminsync] Membership snapshot query failed: %s", szError);
		CReplyToCommand(iClient, "%t", "BSAdminSyncMembershipQueryFailed");
		delete rsResult;
		delete db;
		g_bSyncInProgress = false;
		return;
	}

	if (GetSnapshotBackend() == Backend_SQLite)
		vPersistMembershipsToSQLite(rsResult);
	else
		vPersistMembershipsToKeyValues(rsResult);
	vAdminSyncDebug("Membership rows persisted: %d.", g_iLastMembershipCount);

	delete rsResult;
	delete db;

	g_iLastSyncAt = GetTime();
	g_bSyncInProgress = false;
	vAdminSyncDebug("Snapshot sync finished. admins=%d groups=%d memberships=%d version=%d", g_iLastAdminCount, g_iLastGroupCount, g_iLastMembershipCount, g_iLastSnapshotVersion);
	vApplySnapshotToAdminCache();
	CReplyToCommand(iClient, "%t", "BSAdminSyncSnapshotSynchronized", g_iLastAdminCount, g_iLastGroupCount, g_iLastMembershipCount);
}
