bool bTryResolveAccountIdTarget(int iClient, const char[] szInput, int &iAccountId, char[] szName, int iNameMax, char[] szSteamId64, int iSteamId64Max)
{
	char szTarget[64];
	strcopy(szTarget, sizeof(szTarget), szInput);
	TrimString(szTarget);
	StripQuotes(szTarget);

	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget > 0)
	{
		iAccountId = GetClientAccountID(iTarget);
		if (iAccountId <= 0)
		{
			ReplyToCommand(iClient, "[BS AdminSync] Unable to resolve accountid for target.");
			return false;
		}

		GetClientName(iTarget, szName, iNameMax);
		if (!GetClientAuthId(iTarget, AuthId_SteamID64, szSteamId64, iSteamId64Max))
			szSteamId64[0] = '\0';
		return true;
	}

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szTarget);
		}
		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szTarget);
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			iAccountId = SteamID3ToAccountID(szTarget);
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			ReplyToCommand(iClient, "[BS AdminSync] SteamID64 add requires a connected target for now.");
			return false;
		}
		default:
		{
			ReplyToCommand(iClient, "[BS AdminSync] Invalid target identity.");
			return false;
		}
	}

	if (iAccountId <= 0)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Invalid target identity.");
		return false;
	}

	strcopy(szName, iNameMax, szTarget);
	szSteamId64[0] = '\0';
	return true;
}

bool bQueueAdminIdentityLookup(int iClient, const char[] szSteamId64, AdminSyncIdentityAction eAction, const char[] szExtra, int iValue, const char[] szExtra2 = "")
{
	SteamIDToolsProvider eProvider = eGetSteamIdLookupProvider();
	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		ReplyToCommand(iClient, "[BS AdminSync] SteamID64 resolution is unavailable.");
		return false;
	}

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Failed to queue SteamID64 resolution.");
		return false;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(view_as<int>(eAction));
	pack.WriteCell(iValue);
	pack.WriteString(szExtra);
	pack.WriteString(szExtra2);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smIdentityRequestContext.SetValue(szRequestId, pack);
	ReplyToCommand(iClient, "[BS AdminSync] Resolving SteamID64...");
	return true;
}

void vStartAdminMutationAdd(int iClient, int iAccountId, const char[] szName, const char[] szSteamId64, const char[] szFlags, int iImmunity)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin add. accountid=%d name=%s flags=%s immunity=%d steamid64=%s", iAccountId, szName, szFlags, iImmunity, szSteamId64);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteCell(iImmunity);
	pack.WriteString(szName);
	pack.WriteString(szSteamId64);
	pack.WriteString(szFlags);

	SQL_TConnect(vAdminMutationAddConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationAddConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	int iImmunity = pack.ReadCell();
	char szName[128];
	char szSteamId64[32];
	char szFlags[64];
	pack.ReadString(szName, sizeof(szName));
	pack.ReadString(szSteamId64, sizeof(szSteamId64));
	pack.ReadString(szFlags, sizeof(szFlags));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin add connection failed: %s", szError);
		return;
	}

	char szSafeName[257];
	char szSafeSteamId64[65];
	char szSafeFlags[129];
	db.Escape(szName, szSafeName, sizeof(szSafeName));
	db.Escape(szSteamId64, szSafeSteamId64, sizeof(szSafeSteamId64));
	db.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

	char szQuery[768];
	Format(szQuery, sizeof(szQuery), "INSERT INTO `%s` (`accountid`, `steamid64`, `name`, `flags`, `immunity`, `enabled`) VALUES (%d, '%s', '%s', '%s', %d, 1);",
		MYSQL_TABLE_ADMINS, iAccountId, szSafeSteamId64, szSafeName, szSafeFlags, iImmunity);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_add");
	pQuery.WriteString(szName);
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartAdminMutationDelete(int iClient, int iAccountId)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin delete. accountid=%d", iAccountId);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	SQL_TConnect(vAdminMutationDeleteConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationDeleteConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin delete connection failed: %s", szError);
		return;
	}

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "DELETE ag FROM `%s` ag INNER JOIN `%s` a ON a.`id` = ag.`admin_id` WHERE a.`accountid` = %d;",
		MYSQL_TABLE_ADMINS_GROUPS, MYSQL_TABLE_ADMINS, iAccountId);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteCell(iAccountId);
	SQL_TQuery(db, vAdminDeleteMembershipsCallback, szQuery, pQuery);
}

public void vAdminDeleteMembershipsCallback(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	delete pack;
	delete rsResult;

	int iClient = GetClientOfUserId(iUserId);
	if (szError[0] != '\0')
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] Failed to delete admin memberships.");
		LogError("[bansystem_adminsync] Admin delete memberships failed: %s", szError);
		delete db;
		return;
	}

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d;", MYSQL_TABLE_ADMINS, iAccountId);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_delete");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartAdminMutationSetFlags(int iClient, int iAccountId, const char[] szFlags)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin flags update. accountid=%d flags=%s", iAccountId, szFlags);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szFlags);
	SQL_TConnect(vAdminMutationSetFlagsConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationSetFlagsConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	char szFlags[64];
	pack.ReadString(szFlags, sizeof(szFlags));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin set flags connection failed: %s", szError);
		return;
	}

	char szSafeFlags[129];
	db.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `%s` SET `flags` = '%s' WHERE `accountid` = %d;", MYSQL_TABLE_ADMINS, szSafeFlags, iAccountId);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_set_flags");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartAdminMutationSetImmunity(int iClient, int iAccountId, int iImmunity)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin immunity update. accountid=%d immunity=%d", iAccountId, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteCell(iImmunity);
	SQL_TConnect(vAdminMutationSetImmunityConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationSetImmunityConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	int iImmunity = pack.ReadCell();
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin set immunity connection failed: %s", szError);
		return;
	}

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `%s` SET `immunity` = %d WHERE `accountid` = %d;", MYSQL_TABLE_ADMINS, iImmunity, iAccountId);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_set_immunity");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartGroupMutationAdd(int iClient, const char[] szName, const char[] szFlags, int iImmunity)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group add. name=%s flags=%s immunity=%d", szName, szFlags, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iImmunity);
	pack.WriteString(szName);
	pack.WriteString(szFlags);
	SQL_TConnect(vGroupMutationAddConnectCallback, szMysqlConfig, pack);
}

public void vGroupMutationAddConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iImmunity = pack.ReadCell();
	char szName[128];
	char szFlags[64];
	pack.ReadString(szName, sizeof(szName));
	pack.ReadString(szFlags, sizeof(szFlags));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Group add connection failed: %s", szError);
		return;
	}

	char szSafeName[257];
	char szSafeFlags[129];
	db.Escape(szName, szSafeName, sizeof(szSafeName));
	db.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

	char szQuery[768];
	Format(szQuery, sizeof(szQuery), "INSERT INTO `%s` (`name`, `flags`, `immunity_level`, `enabled`) VALUES ('%s', '%s', %d, 1);",
		MYSQL_TABLE_GROUPS, szSafeName, szSafeFlags, iImmunity);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("group_add");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartGroupMutationDelete(int iClient, const char[] szName)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group delete. name=%s", szName);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteString(szName);
	SQL_TConnect(vGroupMutationDeleteConnectCallback, szMysqlConfig, pack);
}

public void vGroupMutationDeleteConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	char szName[128];
	pack.ReadString(szName, sizeof(szName));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Group delete connection failed: %s", szError);
		return;
	}

	char szSafeName[257];
	db.Escape(szName, szSafeName, sizeof(szSafeName));

	char szQuery[768];
	Format(szQuery, sizeof(szQuery), "DELETE ag FROM `%s` ag INNER JOIN `%s` g ON g.`id` = ag.`group_id` WHERE g.`name` = '%s';",
		MYSQL_TABLE_ADMINS_GROUPS, MYSQL_TABLE_GROUPS, szSafeName);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString(szName);
	SQL_TQuery(db, vGroupDeleteMembershipsCallback, szQuery, pQuery);
}

public void vGroupDeleteMembershipsCallback(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	char szName[128];
	pack.ReadString(szName, sizeof(szName));
	delete pack;
	delete rsResult;

	int iClient = GetClientOfUserId(iUserId);
	if (szError[0] != '\0')
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] Failed to delete group memberships.");
		LogError("[bansystem_adminsync] Group delete memberships failed: %s", szError);
		delete db;
		return;
	}

	char szSafeName[257];
	db.Escape(szName, szSafeName, sizeof(szSafeName));

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `name` = '%s';", MYSQL_TABLE_GROUPS, szSafeName);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("group_delete");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartGroupMutationSetFlags(int iClient, const char[] szName, const char[] szFlags)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group flags update. name=%s flags=%s", szName, szFlags);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteString(szName);
	pack.WriteString(szFlags);
	SQL_TConnect(vGroupMutationSetFlagsConnectCallback, szMysqlConfig, pack);
}

public void vGroupMutationSetFlagsConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	char szName[128];
	char szFlags[64];
	pack.ReadString(szName, sizeof(szName));
	pack.ReadString(szFlags, sizeof(szFlags));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Group set flags connection failed: %s", szError);
		return;
	}

	char szSafeName[257];
	char szSafeFlags[129];
	db.Escape(szName, szSafeName, sizeof(szSafeName));
	db.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `%s` SET `flags` = '%s' WHERE `name` = '%s';", MYSQL_TABLE_GROUPS, szSafeFlags, szSafeName);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("group_set_flags");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartGroupMutationSetImmunity(int iClient, const char[] szName, int iImmunity)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group immunity update. name=%s immunity=%d", szName, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iImmunity);
	pack.WriteString(szName);
	SQL_TConnect(vGroupMutationSetImmunityConnectCallback, szMysqlConfig, pack);
}

public void vGroupMutationSetImmunityConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iImmunity = pack.ReadCell();
	char szName[128];
	pack.ReadString(szName, sizeof(szName));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Group set immunity connection failed: %s", szError);
		return;
	}

	char szSafeName[257];
	db.Escape(szName, szSafeName, sizeof(szSafeName));

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `%s` SET `immunity_level` = %d WHERE `name` = '%s';", MYSQL_TABLE_GROUPS, iImmunity, szSafeName);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("group_set_immunity");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartAdminMutationAddGroup(int iClient, int iAccountId, const char[] szGroupName)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin add group. accountid=%d group=%s", iAccountId, szGroupName);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szGroupName);
	SQL_TConnect(vAdminMutationAddGroupConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationAddGroupConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	char szGroupName[128];
	pack.ReadString(szGroupName, sizeof(szGroupName));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin add group connection failed: %s", szError);
		return;
	}

	char szSafeGroupName[257];
	db.Escape(szGroupName, szSafeGroupName, sizeof(szSafeGroupName));

	char szQuery[768];
	Format(szQuery, sizeof(szQuery),
		"INSERT INTO `%s` (`admin_id`, `group_id`, `inherit_order`) SELECT a.`id`, g.`id`, 0 FROM `%s` a INNER JOIN `%s` g ON g.`name` = '%s' WHERE a.`accountid` = %d;",
		MYSQL_TABLE_ADMINS_GROUPS, MYSQL_TABLE_ADMINS, MYSQL_TABLE_GROUPS, szSafeGroupName, iAccountId);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_add_group");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

void vStartAdminMutationRemoveGroup(int iClient, int iAccountId, const char[] szGroupName)
{
	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin remove group. accountid=%d group=%s", iAccountId, szGroupName);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szGroupName);
	SQL_TConnect(vAdminMutationRemoveGroupConnectCallback, szMysqlConfig, pack);
}

public void vAdminMutationRemoveGroupConnectCallback(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	int iAccountId = pack.ReadCell();
	char szGroupName[128];
	pack.ReadString(szGroupName, sizeof(szGroupName));
	delete pack;

	Database db = view_as<Database>(hndl);
	int iClient = GetClientOfUserId(iUserId);
	if (db == null)
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] MySQL connection failed.");
		LogError("[bansystem_adminsync] Admin remove group connection failed: %s", szError);
		return;
	}

	char szSafeGroupName[257];
	db.Escape(szGroupName, szSafeGroupName, sizeof(szSafeGroupName));

	char szQuery[768];
	Format(szQuery, sizeof(szQuery),
		"DELETE ag FROM `%s` ag INNER JOIN `%s` a ON a.`id` = ag.`admin_id` INNER JOIN `%s` g ON g.`id` = ag.`group_id` WHERE a.`accountid` = %d AND g.`name` = '%s';",
		MYSQL_TABLE_ADMINS_GROUPS, MYSQL_TABLE_ADMINS, MYSQL_TABLE_GROUPS, iAccountId, szSafeGroupName);

	DataPack pQuery = new DataPack();
	pQuery.WriteCell(iUserId);
	pQuery.WriteString("admin_remove_group");
	SQL_TQuery(db, vMutationSimpleCallback, szQuery, pQuery);
}

public void vMutationSimpleCallback(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int iUserId = pack.ReadCell();
	char szAction[64];
	pack.ReadString(szAction, sizeof(szAction));
	delete pack;
	delete rsResult;
	delete db;

	int iClient = GetClientOfUserId(iUserId);
	if (szError[0] != '\0')
	{
		if (iClient > 0)
			ReplyToCommand(iClient, "[BS AdminSync] Mutation failed: %s", szError);
		LogError("[bansystem_adminsync] Mutation '%s' failed: %s", szAction, szError);
		return;
	}

	vAdminSyncDebug("Mutation applied successfully: %s", szAction);
	if (iClient > 0)
		ReplyToCommand(iClient, "[BS AdminSync] Mutation applied: %s. Refreshing snapshot...", szAction);

	if (!g_bSyncInProgress)
		vStartAdminSync();
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch || !StrEqual(szEndpoint, API_SID64toAID, false))
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pack;
	if (!g_smIdentityRequestContext.GetValue(szRequestId, pack))
		return;

	g_smIdentityRequestContext.Remove(szRequestId);
	pack.Reset();

	int iUserId = pack.ReadCell();
	AdminSyncIdentityAction eAction = view_as<AdminSyncIdentityAction>(pack.ReadCell());
	int iValue = pack.ReadCell();
	char szExtra[128];
	char szExtra2[128];
	pack.ReadString(szExtra, sizeof(szExtra));
	pack.ReadString(szExtra2, sizeof(szExtra2));
	delete pack;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0)
		return;

	if (!bSuccess)
	{
		vAdminSyncAPI("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		ReplyToCommand(iClient, "[BS AdminSync] SteamID64 resolution failed.");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		vAdminSyncAPI("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		ReplyToCommand(iClient, "[BS AdminSync] SteamID64 resolution returned an invalid accountid.");
		return;
	}

	vAdminSyncAPI("SteamID64 resolution succeeded. request=%d input=%s accountid=%d action=%d", iRequestId, szInput, iAccountId, view_as<int>(eAction));
	switch (eAction)
	{
		case IdentityAction_AdminAdd:
		{
			vStartAdminMutationAdd(iClient, iAccountId, szExtra2, szInput, szExtra, iValue);
		}
		case IdentityAction_AdminDelete:
		{
			vStartAdminMutationDelete(iClient, iAccountId);
		}
		case IdentityAction_AdminSetFlags:
		{
			vStartAdminMutationSetFlags(iClient, iAccountId, szExtra);
		}
		case IdentityAction_AdminSetImmunity:
		{
			vStartAdminMutationSetImmunity(iClient, iAccountId, iValue);
		}
		case IdentityAction_AdminAddGroup:
		{
			vStartAdminMutationAddGroup(iClient, iAccountId, szExtra);
		}
		case IdentityAction_AdminRemoveGroup:
		{
			vStartAdminMutationRemoveGroup(iClient, iAccountId, szExtra);
		}
	}
}
