bool bTryResolveAccountIdTarget(int iClient, const char[] szInput, int &iAccountId, char[] szName, int iNameMax, char[] szSteamId64, int iSteamId64Max)
{
	char szTarget[64];
	strcopy(szTarget, sizeof(szTarget), szInput);
	TrimString(szTarget);
	StripQuotes(szTarget);

	SteamIDFormat eFormat = DetectSteamIDFormat(szTarget);
	vAdminSyncDebug("Resolve target begin. input=%s normalized=%s format=%d", szInput, szTarget, view_as<int>(eFormat));

	switch (eFormat)
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szTarget);
			vAdminSyncDebug("Resolve target interpreted as accountid. value=%d", iAccountId);
		}
		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szTarget);
			vAdminSyncDebug("Resolve target interpreted as steam2. accountid=%d", iAccountId);
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			iAccountId = SteamID3ToAccountID(szTarget);
			vAdminSyncDebug("Resolve target interpreted as steam3. accountid=%d", iAccountId);
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			vAdminSyncDebug("Resolve target detected offline steam64. delegating to async path.");
			CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64ConnectedOnly");
			return false;
		}
		default:
		{
			vAdminSyncDebug("Resolve target format unknown. falling back to FindTarget.");
		}
	}

	if (iAccountId > 0)
	{
		int iResolvedClient = FindClientByAccountID(iAccountId);
		vAdminSyncDebug("Resolve target got offline accountid=%d resolved_client=%d", iAccountId, iResolvedClient);
		if (iResolvedClient > 0)
		{
			GetClientName(iResolvedClient, szName, iNameMax);
			if (!GetClientAuthId(iResolvedClient, AuthId_SteamID64, szSteamId64, iSteamId64Max, true))
				szSteamId64[0] = '\0';
		}
		else
		{
			strcopy(szName, iNameMax, szTarget);
			szSteamId64[0] = '\0';
		}
		vAdminSyncDebug("Resolve target success. accountid=%d name=%s steamid64=%s", iAccountId, szName, szSteamId64);
		return true;
	}

	vAdminSyncDebug("Resolve target using FindTarget fallback. query=%s", szTarget);
	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget > 0)
	{
		vAdminSyncDebug("Resolve target FindTarget matched client=%d", iTarget);
		iAccountId = GetClientAccountID(iTarget);
		if (iAccountId <= 0)
		{
			vAdminSyncDebug("Resolve target FindTarget matched but accountid invalid.");
			CReplyToCommand(iClient, "%t", "BSAdminSyncResolveAccountIdFailed");
			return false;
		}

		GetClientName(iTarget, szName, iNameMax);
		if (!GetClientAuthId(iTarget, AuthId_SteamID64, szSteamId64, iSteamId64Max))
			szSteamId64[0] = '\0';
		vAdminSyncDebug("Resolve target FindTarget success. accountid=%d name=%s steamid64=%s", iAccountId, szName, szSteamId64);
		return true;
	}

	vAdminSyncDebug("Resolve target failed. input=%s normalized=%s format=%d", szInput, szTarget, view_as<int>(eFormat));
	CReplyToCommand(iClient, "%t", "BSAdminSyncInvalidTargetIdentity");
	return false;
}

bool bQueueAdminIdentityLookup(int iClient, const char[] szSteamId64, AdminSyncIdentityAction eAction, const char[] szExtra, int iValue, const char[] szExtra2 = "")
{
	SteamIDToolsProvider eProvider;
	if (!bTryGetSteamIdLookupProvider(iClient, eProvider))
		return false;

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		char szProvider[16];
		char szStatus[128];
		vGetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
		if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
		{
			CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64QueueFailed");
			return false;
		}

		CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64QueueFailedStatus", szProvider, szStatus);
		return false;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(view_as<int>(eAction));
	pack.WriteCell(iValue);
	pack.WriteString(szExtra);
	pack.WriteString(szExtra2);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smIdentityRequestContext.SetValue(szRequestId, pack);
	CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64Resolving");
	return true;
}

bool bQueueAdminAddSteamId64Enrichment(int iClient, const char[] szIdentity, SteamIDFormat eFormat, int iAccountId, const char[] szName, const char[] szFlags, int iImmunity)
{
	SteamIDToolsProvider eProvider;
	if (!bTryGetSteamIdLookupProviderSilent(eProvider))
	{
		return false;
	}

	char szEndpoint[STEAMIDTOOLS_MAX_ENDPOINT_LENGTH];
	szEndpoint[0] = '\0';
	switch (eFormat)
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			szEndpoint = API_SID2toSID64;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			szEndpoint = API_SID3toSID64;
		}
		default:
		{
			return false;
		}
	}

	int iRequestId = SteamIDTools_RequestConversion(eProvider, szEndpoint, szIdentity);
	if (iRequestId <= 0)
	{
		return false;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(view_as<int>(IdentityAction_AdminAddResolveSteam64));
	pack.WriteCell(iAccountId);
	pack.WriteCell(iImmunity);
	pack.WriteString(szName);
	pack.WriteString(szFlags);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smIdentityRequestContext.SetValue(szRequestId, pack);
	vAdminSyncAPI("Queued offline SteamID64 enrichment. request=%d endpoint=%s input=%s accountid=%d", iRequestId, szEndpoint, szIdentity, iAccountId);
	if (iClient > 0)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64Resolving");
	}

	return true;
}

void vStartAdminMutationAdd(int iClient, int iAccountId, const char[] szName, const char[] szSteamId64, const char[] szFlags, int iImmunity)
{
	if (iAccountId <= 0 || iImmunity < 0 || !bAdminSyncHasText(szName) || !bAdminSyncHasText(szFlags))
		return;

	char szMysqlConfig[64];
	char szNormalizedName[128];
	char szNormalizedSteamId64[32];
	char szNormalizedFlags[64];
	vNormalizeAdminSyncText(szName, szNormalizedName, sizeof(szNormalizedName));
	vNormalizeAdminSyncText(szSteamId64, szNormalizedSteamId64, sizeof(szNormalizedSteamId64));
	vNormalizeAdminSyncText(szFlags, szNormalizedFlags, sizeof(szNormalizedFlags));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin add. accountid=%d name=%s flags=%s immunity=%d steamid64=%s", iAccountId, szNormalizedName, szNormalizedFlags, iImmunity, szNormalizedSteamId64);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteCell(iImmunity);
	pack.WriteString(szNormalizedName);
	pack.WriteString(szNormalizedSteamId64);
	pack.WriteString(szNormalizedFlags);

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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iAccountId <= 0)
		return;

	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin delete. accountid=%d", iAccountId);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMutationDeleteAdminMembershipsFailed");
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
	if (iAccountId <= 0 || !bAdminSyncHasText(szFlags))
		return;

	char szMysqlConfig[64];
	char szNormalizedFlags[64];
	vNormalizeAdminSyncText(szFlags, szNormalizedFlags, sizeof(szNormalizedFlags));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin flags update. accountid=%d flags=%s", iAccountId, szNormalizedFlags);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szNormalizedFlags);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iAccountId <= 0 || iImmunity < 0)
		return;

	char szMysqlConfig[64];
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin immunity update. accountid=%d immunity=%d", iAccountId, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iImmunity < 0 || !bAdminSyncHasText(szName) || !bAdminSyncHasText(szFlags))
		return;

	char szMysqlConfig[64];
	char szNormalizedName[128];
	char szNormalizedFlags[64];
	vNormalizeAdminSyncText(szName, szNormalizedName, sizeof(szNormalizedName));
	vNormalizeAdminSyncText(szFlags, szNormalizedFlags, sizeof(szNormalizedFlags));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group add. name=%s flags=%s immunity=%d", szNormalizedName, szNormalizedFlags, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iImmunity);
	pack.WriteString(szNormalizedName);
	pack.WriteString(szNormalizedFlags);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (!bAdminSyncHasText(szName))
		return;

	char szMysqlConfig[64];
	char szNormalizedName[128];
	vNormalizeAdminSyncText(szName, szNormalizedName, sizeof(szNormalizedName));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group delete. name=%s", szNormalizedName);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteString(szNormalizedName);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMutationDeleteGroupMembershipsFailed");
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
	if (!bAdminSyncHasText(szName) || !bAdminSyncHasText(szFlags))
		return;

	char szMysqlConfig[64];
	char szNormalizedName[128];
	char szNormalizedFlags[64];
	vNormalizeAdminSyncText(szName, szNormalizedName, sizeof(szNormalizedName));
	vNormalizeAdminSyncText(szFlags, szNormalizedFlags, sizeof(szNormalizedFlags));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group flags update. name=%s flags=%s", szNormalizedName, szNormalizedFlags);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteString(szNormalizedName);
	pack.WriteString(szNormalizedFlags);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iImmunity < 0 || !bAdminSyncHasText(szName))
		return;

	char szMysqlConfig[64];
	char szNormalizedName[128];
	vNormalizeAdminSyncText(szName, szNormalizedName, sizeof(szNormalizedName));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue group immunity update. name=%s immunity=%d", szNormalizedName, iImmunity);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iImmunity);
	pack.WriteString(szNormalizedName);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iAccountId <= 0 || !bAdminSyncHasText(szGroupName))
		return;

	char szMysqlConfig[64];
	char szNormalizedGroupName[128];
	vNormalizeAdminSyncText(szGroupName, szNormalizedGroupName, sizeof(szNormalizedGroupName));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin add group. accountid=%d group=%s", iAccountId, szNormalizedGroupName);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szNormalizedGroupName);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
	if (iAccountId <= 0 || !bAdminSyncHasText(szGroupName))
		return;

	char szMysqlConfig[64];
	char szNormalizedGroupName[128];
	vNormalizeAdminSyncText(szGroupName, szNormalizedGroupName, sizeof(szNormalizedGroupName));
	g_cvMysqlConfig.GetString(szMysqlConfig, sizeof(szMysqlConfig));
	vAdminSyncSQL("Queue admin remove group. accountid=%d group=%s", iAccountId, szNormalizedGroupName);

	DataPack pack = new DataPack();
	pack.WriteCell(iGetAdminSyncCommandUserId(iClient));
	pack.WriteCell(iAccountId);
	pack.WriteString(szNormalizedGroupName);
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMysqlConnectionFailed");
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
			CReplyToCommand(iClient, "%t", "BSAdminSyncMutationFailed", szError);
		LogError("[bansystem_adminsync] Mutation '%s' failed: %s", szAction, szError);
		return;
	}

	vAdminSyncDebug("Mutation applied successfully: %s", szAction);
	if (iClient > 0)
		CReplyToCommand(iClient, "%t", "BSAdminSyncMutationApplied", szAction);

	if (!g_bSyncInProgress)
		vStartAdminSync();
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch)
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
	int iClient = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iClient <= 0)
	{
		delete pack;
		return;
	}

	if (eAction == IdentityAction_AdminAddResolveSteam64)
	{
		int iAccountId = pack.ReadCell();
		int iImmunity = pack.ReadCell();
		char szName[128];
		char szFlags[64];
		char szResolvedSteamId64[32];
		pack.ReadString(szName, sizeof(szName));
		pack.ReadString(szFlags, sizeof(szFlags));
		delete pack;

		szResolvedSteamId64[0] = '\0';
		if (bSuccess && (StrEqual(szEndpoint, API_SID2toSID64, false) || StrEqual(szEndpoint, API_SID3toSID64, false)) && IsValidSteamID64(szResult))
		{
			strcopy(szResolvedSteamId64, sizeof(szResolvedSteamId64), szResult);
			vAdminSyncAPI("Offline SteamID64 enrichment succeeded. request=%d input=%s accountid=%d steamid64=%s", iRequestId, szInput, iAccountId, szResolvedSteamId64);
		}
		else if (!bSuccess)
		{
			vAdminSyncAPI("Offline SteamID64 enrichment failed. request=%d input=%s", iRequestId, szInput);
		}
		else
		{
			vAdminSyncAPI("Offline SteamID64 enrichment returned invalid result. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		}

		vStartAdminMutationAdd(iClient, iAccountId, szName, szResolvedSteamId64, szFlags, iImmunity);
		return;
	}

	int iValue = pack.ReadCell();
	char szExtra[128];
	char szExtra2[128];
	pack.ReadString(szExtra, sizeof(szExtra));
	pack.ReadString(szExtra2, sizeof(szExtra2));
	delete pack;

	if (!StrEqual(szEndpoint, API_SID64toAID, false))
	{
		vAdminSyncAPI("Ignoring unexpected identity callback. request=%d endpoint=%s action=%d", iRequestId, szEndpoint, view_as<int>(eAction));
		return;
	}

	if (!bSuccess)
	{
		vAdminSyncAPI("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		if (iClient > 0)
			CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64ResolveFailed");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		vAdminSyncAPI("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		if (iClient > 0)
			CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64ResolveInvalid");
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
