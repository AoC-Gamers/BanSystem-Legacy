void vStartAdminSync(int iClient = 0)
{
	if (g_bSyncInProgress)
	{
		vAdminSyncDebug("Reload skipped because a sync is already in progress.");
		ReplyToCommand(iClient, "[BS AdminSync] Sync already in progress.");
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

void vRestartVersionCheckTimer()
{
	if (g_hVersionCheckTimer != null)
	{
		delete g_hVersionCheckTimer;
		g_hVersionCheckTimer = null;
	}

	float flInterval = g_cvCheckInterval.FloatValue;
	if (flInterval <= 0.0)
	{
		vAdminSyncDebug("Version polling disabled.");
		return;
	}

	g_hVersionCheckTimer = CreateTimer(flInterval, Timer_AdminSyncVersionCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	vAdminSyncDebug("Version polling timer started with interval %.2f seconds.", flInterval);
}

Action Timer_AdminSyncVersionCheck(Handle hTimer, any data)
{
	if (g_bSyncInProgress || g_bVersionCheckInFlight)
	{
		vAdminSyncDebug("Version check skipped. sync_in_progress=%d version_check_in_flight=%d", g_bSyncInProgress ? 1 : 0, g_bVersionCheckInFlight ? 1 : 0);
		return Plugin_Continue;
	}

	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	g_bVersionCheckInFlight = true;
	vAdminSyncSQL("Running lightweight version check using MySQL config '%s'.", szMysqlConfig);
	SQL_TConnect(vAdminSyncVersionConnectCallback, szMysqlConfig);
	return Plugin_Continue;
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
	Format(szQuery, sizeof(szQuery), "SELECT `meta_value` FROM `adminsync_meta` WHERE `meta_key` = 'snapshot_version';");
	vAdminSyncSQL("Version check connected. Querying snapshot version.");
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
	vAdminSyncDebug("Version check returned snapshot_version=%d (current=%d).", iVersion, g_iLastSnapshotVersion);

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
		ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		g_bSyncInProgress = false;
		return;
	}

	g_iLastAdminCount = 0;
	g_iLastGroupCount = 0;
	g_iLastMembershipCount = 0;
	vAdminSyncSQL("Connected to MySQL for full sync. backend=%d", view_as<int>(GetSnapshotBackend()));

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
		ReplyToCommand(iClient, "[BS AdminSync] Admin query failed.");
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
		ReplyToCommand(iClient, "[BS AdminSync] Group query failed.");
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
		ReplyToCommand(iClient, "[BS AdminSync] Membership query failed.");
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
	ReplyToCommand(iClient, "[BS AdminSync] Snapshot synchronized. admins=%d groups=%d memberships=%d", g_iLastAdminCount, g_iLastGroupCount, g_iLastMembershipCount);
}
