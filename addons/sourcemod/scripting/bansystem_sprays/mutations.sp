/*****************************************************************
			M U T A T I O N S
*****************************************************************/

stock void BSSprays_OnPluginStart_Mutations()
{
}

stock void BSSprays_RefreshCoreSummaryForAccountId(int iAccountId)
{
	if (!BSSprays_CanUseCoreLibrary() || !BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id` FROM `bansystem_spray_bans` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnCoreSummaryRefreshLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSSprays_QueueInfoByAccountId(int iAdmin, int iAccountId)
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[640];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `steamid64`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnInfoLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSSprays_QueueList(int iAdmin, int iLimit)
{
	if (!BSSprays_CanUseDatabase())
		return;

	char szQuery[896];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	SQL_TQuery(g_dbBSSprays, BSSprays_OnListLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSSprays_QueueAddBan(int iAdmin, int iAccountId, int iTargetClient, int iLength, const char[] szReason, const char[] szContext, const char[] szSteamId64Override = "", const char[] szPlayerNameOverride = "UNKNOWN")
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szSteamId64[32];
	char szPlayerName[MAX_NAME_LENGTH];
	char szIpAddress[64];
	char szAdminName[MAX_NAME_LENGTH];
	char szAdminSteamId64[32];
	int iAdminAccountId;

	BSSprays_GetTargetIdentityData(iTargetClient, szSteamId64, sizeof(szSteamId64), szPlayerName, sizeof(szPlayerName));
	if (iTargetClient <= 0 || !IsClientInGame(iTargetClient))
	{
		if (szSteamId64Override[0] != '\0')
			strcopy(szSteamId64, sizeof(szSteamId64), szSteamId64Override);
		if (szPlayerNameOverride[0] != '\0')
			strcopy(szPlayerName, sizeof(szPlayerName), szPlayerNameOverride);
	}

	BSSprays_GetClientIpAddressSafe(iTargetClient, szIpAddress, sizeof(szIpAddress));
	BSSprays_GetAdminAuditData(iAdmin, iAdminAccountId, szAdminName, sizeof(szAdminName), szAdminSteamId64, sizeof(szAdminSteamId64));

	char szQuery[2304];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `bansystem_spray_bans` (`accountid`, `steamid64`, `player_name`, `ip_address`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`) ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, '%s', '%s', '%s', %d, '%s', '%s', %d, '%s', '%s') ", iAccountId, szSteamId64, szPlayerName, szIpAddress, iLength, szReason, szContext, iAdminAccountId, szAdminName, szAdminSteamId64);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `steamid64` = VALUES(`steamid64`), `player_name` = VALUES(`player_name`), `ip_address` = VALUES(`ip_address`), `ban_length` = VALUES(`ban_length`), `ban_reason` = VALUES(`ban_reason`), `ban_context` = VALUES(`ban_context`), `banned_by` = VALUES(`banned_by`), `banned_by_name` = VALUES(`banned_by_name`), `banned_by_steamid64` = VALUES(`banned_by_steamid64`);");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	pContext.WriteString(szReason);

	BSSprays_SQL("Queueing spray add mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnAddBanCompleted, szQuery, pContext, DBPrio_High);
}

stock void BSSprays_QueueRemoveBan(int iAdmin, int iAccountId)
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bansystem_spray_bans` WHERE `accountid` = %d;", iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);

	BSSprays_SQL("Queueing spray remove mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnRemoveBanCompleted, szQuery, pContext, DBPrio_High);
}

public void BSSprays_OnAddBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	pContext.ReadString(szReason, sizeof(szReason));
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	if (szError[0] != '\0')
	{
		BSSprays_SQL("Spray add mutation failed for accountid=%d: %s", iAccountId, szError);
		CReplyToCommand(iAdmin, "%t", "BSSpraysPersistFailed", iAccountId);
		return;
	}

	if (BSSprays_CanUseCoreLibrary())
	{
		BSCore_RemoveLocalCleanCache(iAccountId);
		BSSprays_RefreshCoreSummaryForAccountId(iAccountId);
	}

	int iTarget = FindClientByAccountID(iAccountId);
	if (iTarget > 0 && IsClientInGame(iTarget))
		CPrintToChat(iTarget, "%t", "BSSpraysPlayerBanned");

	CReplyToCommand(iAdmin, "%t", "BSSpraysStored", iAccountId, szReason);
}

public void BSSprays_OnRemoveBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	if (szError[0] != '\0')
	{
		BSSprays_SQL("Spray remove mutation failed for accountid=%d: %s", iAccountId, szError);
		CReplyToCommand(iAdmin, "%t", "BSSpraysRemoveFailed", iAccountId);
		return;
	}

	if (BSSprays_CanUseCoreLibrary())
		BSCore_ClearSummaryModule(iAccountId, BANSYSTEM_SPRAYS_MODULE_BIT);

	int iTarget = FindClientByAccountID(iAccountId);
	if (iTarget > 0 && IsClientInGame(iTarget))
	{
		BSSprays_ResetResolvedDetail(iTarget);
		CPrintToChat(iTarget, "%t", "BSSpraysPlayerUnbanned");
	}

	CReplyToCommand(iAdmin, "%t", "BSSpraysRemoved", iAccountId);
}

public void BSSprays_OnCoreSummaryRefreshLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	if (!BSSprays_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_SQL("Spray summary refresh lookup failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSCore_ClearSummaryModule(iAccountId, BANSYSTEM_SPRAYS_MODULE_BIT);
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	delete rsResult;
	BSCore_SetSpraySummary(iAccountId, iBanId);
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch || !StrEqual(szEndpoint, API_SID64toAID, false))
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pContext;
	if (!g_smBSSpraysIdentityRequestContext.GetValue(szRequestId, pContext))
		return;

	g_smBSSpraysIdentityRequestContext.Remove(szRequestId);
	pContext.Reset();

	int iUserId = pContext.ReadCell();
	eBSSpraysIdentityAction eAction = view_as<eBSSpraysIdentityAction>(pContext.ReadCell());
	int iValue = pContext.ReadCell();
	char szExtra[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	pContext.ReadString(szExtra, sizeof(szExtra));
	pContext.ReadString(szContext, sizeof(szContext));
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
		return;

	if (!bSuccess)
	{
		BSSprays_API("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64ResolveFailed");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		BSSprays_API("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64ResolveInvalid");
		return;
	}

	BSSprays_API("SteamID64 resolution succeeded. request=%d input=%s accountid=%d action=%d", iRequestId, szInput, iAccountId, view_as<int>(eAction));
	switch (eAction)
	{
		case kBSSpraysIdentityAction_Add:
		{
			BSSprays_QueueAddBan(iAdmin, iAccountId, 0, iValue, szExtra, szContext, szInput, "UNKNOWN");
		}

		case kBSSpraysIdentityAction_Remove:
		{
			BSSprays_QueueRemoveBan(iAdmin, iAccountId);
		}

		case kBSSpraysIdentityAction_Info:
		{
			BSSprays_QueueInfoByAccountId(iAdmin, iAccountId);
		}
	}
}

public void BSSprays_OnInfoLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysInfoLoadFailed");
		BSSprays_SQL("Spray info query failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysNoActiveBan", iAccountId);
		delete rsResult;
		return;
	}

	char szPlayerName[MAX_NAME_LENGTH];
	char szSteamId64[32];
	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	char szBannedByName[MAX_NAME_LENGTH];
	char szBannedBySteamId64[32];
	char szDateExpire[64];
	char szSteam2[32];
	int iLength = rsResult.FetchInt(2);
	int iBannedBy = rsResult.FetchInt(5);
	int iDateExpireTs = rsResult.FetchInt(8);
	rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(1, szSteamId64, sizeof(szSteamId64));
	rsResult.FetchString(3, szReason, sizeof(szReason));
	rsResult.FetchString(4, szContext, sizeof(szContext));
	rsResult.FetchString(6, szBannedByName, sizeof(szBannedByName));
	rsResult.FetchString(7, szBannedBySteamId64, sizeof(szBannedBySteamId64));
	delete rsResult;
	BSSprays_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

	if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	PrintToConsole(iAdmin, "== BanSystem Sprays Info ==");
	PrintToConsole(iAdmin, "Player: %s", szPlayerName);
	PrintToConsole(iAdmin, "AccountId: %d", iAccountId);
	PrintToConsole(iAdmin, "Steam2: %s", szSteam2);
	PrintToConsole(iAdmin, "SteamID64: %s", szSteamId64[0] != '\0' ? szSteamId64 : "<none>");
	PrintToConsole(iAdmin, "Length: %s", iLength > 0 ? "Temporary" : "Permanent");
	if (iLength > 0)
		PrintToConsole(iAdmin, "Minutes: %d", iLength);
	PrintToConsole(iAdmin, "Reason: %s", szReason);
	if (szContext[0] != '\0')
		PrintToConsole(iAdmin, "Context: %s", szContext);
	PrintToConsole(iAdmin, "Banned by: %d (%s / %s)", iBannedBy, szBannedByName, szBannedBySteamId64[0] != '\0' ? szBannedBySteamId64 : "<none>");
	PrintToConsole(iAdmin, "Expire: %s", szDateExpire);
	CReplyToCommand(iAdmin, "%t", "BSSpraysInfoPrinted");
}

public void BSSprays_OnListLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysListLoadFailed");
		BSSprays_SQL("Spray list query failed: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysNoActiveBans");
		delete rsResult;
		return;
	}

	PrintToConsole(iAdmin, "== BanSystem Sprays Active Bans ==");
	do
	{
		char szPlayerName[MAX_NAME_LENGTH];
		char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
		char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
		char szBannedByName[MAX_NAME_LENGTH];
		char szBannedBySteamId64[32];
		char szDateExpire[64];
		char szSteam2[32];
		int iAccountId = rsResult.FetchInt(1);
		int iLength = rsResult.FetchInt(2);
		int iBannedBy = rsResult.FetchInt(5);
		int iDateExpireTs = rsResult.FetchInt(8);
		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		rsResult.FetchString(3, szReason, sizeof(szReason));
		rsResult.FetchString(4, szContext, sizeof(szContext));
		rsResult.FetchString(6, szBannedByName, sizeof(szBannedByName));
		rsResult.FetchString(7, szBannedBySteamId64, sizeof(szBannedBySteamId64));
		if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
			strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");
		BSSprays_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

		PrintToConsole(iAdmin, "> %s | %s | %s | by=%d (%s)", szPlayerName, szSteam2, iLength > 0 ? szDateExpire : "Permanent", iBannedBy, szBannedByName);
		PrintToConsole(iAdmin, "  reason=%s", szReason);
		if (szContext[0] != '\0')
			PrintToConsole(iAdmin, "  context=%s", szContext);
		if (szBannedBySteamId64[0] != '\0')
			PrintToConsole(iAdmin, "  banned_by_steamid64=%s", szBannedBySteamId64);
	} while (rsResult.FetchRow());

	delete rsResult;
	CReplyToCommand(iAdmin, "%t", "BSSpraysListPrinted");
}
