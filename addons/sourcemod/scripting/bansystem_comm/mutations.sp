/*****************************************************************
			M U T A T I O N S
*****************************************************************/

stock void BSComm_OnPluginStart_Mutations()
{
}

stock void BSComm_RefreshCoreSummaryForAccountId(int iAccountId)
{
	if (!BSComm_CanUseCoreLibrary() || !BSComm_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `ban_type` FROM `bansystem_comm_bans` ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSComm, BSComm_OnCoreSummaryRefreshLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSComm_QueueInfoByAccountId(int iAdmin, int iAccountId)
{
	if (!BSComm_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[640];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `steamid64`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_comm_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSComm, BSComm_OnInfoLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSComm_QueueList(int iAdmin, int iLimit)
{
	if (!BSComm_CanUseDatabase())
		return;

	char szQuery[896];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_comm_bans` WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	SQL_TQuery(g_dbBSComm, BSComm_OnListLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSComm_QueueAddBan(int iAdmin, int iAccountId, int iTargetClient, eBSCommType eCommType, int iLength, const char[] szReason, const char[] szContext, const char[] szSteamId64Override = "", const char[] szPlayerNameOverride = "UNKNOWN")
{
	if (!BSComm_CanUseDatabase() || iAccountId <= 0 || eCommType == kBSCommType_None)
		return;

	char szSteamId64[32];
	char szPlayerName[MAX_NAME_LENGTH];
	char szIpAddress[64];
	char szAdminName[MAX_NAME_LENGTH];
	char szAdminSteamId64[32];
	int iAdminAccountId;

	BSComm_GetTargetIdentityData(iTargetClient, szSteamId64, sizeof(szSteamId64), szPlayerName, sizeof(szPlayerName));
	if (iTargetClient <= 0 || !IsClientInGame(iTargetClient))
	{
		if (szSteamId64Override[0] != '\0')
			strcopy(szSteamId64, sizeof(szSteamId64), szSteamId64Override);
		if (szPlayerNameOverride[0] != '\0')
			strcopy(szPlayerName, sizeof(szPlayerName), szPlayerNameOverride);
	}

	BSComm_GetClientIpAddressSafe(iTargetClient, szIpAddress, sizeof(szIpAddress));
	BSComm_GetAdminAuditData(iAdmin, iAdminAccountId, szAdminName, sizeof(szAdminName), szAdminSteamId64, sizeof(szAdminSteamId64));

	char szQuery[2304];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `bansystem_comm_bans` (`accountid`, `steamid64`, `player_name`, `ip_address`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`) ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, '%s', '%s', '%s', %d, %d, '%s', '%s', %d, '%s', '%s') ", iAccountId, szSteamId64, szPlayerName, szIpAddress, view_as<int>(eCommType), iLength, szReason, szContext, iAdminAccountId, szAdminName, szAdminSteamId64);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `steamid64` = VALUES(`steamid64`), `player_name` = VALUES(`player_name`), `ip_address` = VALUES(`ip_address`), `ban_type` = VALUES(`ban_type`), `ban_length` = VALUES(`ban_length`), `ban_reason` = VALUES(`ban_reason`), `ban_context` = VALUES(`ban_context`), `banned_by` = VALUES(`banned_by`), `banned_by_name` = VALUES(`banned_by_name`), `banned_by_steamid64` = VALUES(`banned_by_steamid64`);");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iTargetClient);
	pContext.WriteCell(view_as<int>(eCommType));
	pContext.WriteCell(iLength);
	pContext.WriteString(szReason);

	BSComm_SQL("Queueing communication add mutation for accountid=%d type=%d query=%s", iAccountId, view_as<int>(eCommType), szQuery);
	SQL_TQuery(g_dbBSComm, BSComm_OnAddBanCompleted, szQuery, pContext, DBPrio_High);
}

stock void BSComm_QueueRemoveBan(int iAdmin, int iAccountId)
{
	if (!BSComm_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bansystem_comm_bans` WHERE `accountid` = %d;", iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);

	BSComm_SQL("Queueing communication remove mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSComm, BSComm_OnRemoveBanCompleted, szQuery, pContext, DBPrio_High);
}

public void BSComm_OnAddBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	int iTargetClient = pContext.ReadCell();
	eBSCommType eCommType = view_as<eBSCommType>(pContext.ReadCell());
	int iLength = pContext.ReadCell();
	char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	pContext.ReadString(szReason, sizeof(szReason));
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	if (szError[0] != '\0')
	{
		BSComm_SQL("Communication add mutation failed for accountid=%d: %s", iAccountId, szError);
		CReplyToCommand(iAdmin, "%t", "BSCommPersistFailed", iAccountId);
		return;
	}

	if (BSComm_CanUseCoreLibrary())
	{
		BSCore_RemoveLocalCleanCache(iAccountId);
		BSComm_RefreshCoreSummaryForAccountId(iAccountId);
	}

	int iLiveTarget = iTargetClient;
	if (iLiveTarget <= 0 || !IsClientInGame(iLiveTarget) || GetClientAccountID(iLiveTarget) != iAccountId)
		iLiveTarget = FindClientByAccountID(iAccountId);

	if (iLiveTarget > 0 && IsClientInGame(iLiveTarget))
		BSComm_QueueResolvedDetailRefreshForClient(iLiveTarget, iAccountId, true);

	char szType[16];
	BSComm_GetCommTypeLabel(eCommType, szType, sizeof(szType));

	if (iLiveTarget > 0 && IsClientInGame(iLiveTarget))
		CReplyToCommand(iAdmin, "%t", "BSCommStoredTarget", szType, iLiveTarget, iLength, szReason);
	else
		CReplyToCommand(iAdmin, "%t", "BSCommStoredAccount", szType, iAccountId, iLength, szReason);
}

public void BSComm_OnRemoveBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
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
		BSComm_SQL("Communication remove mutation failed for accountid=%d: %s", iAccountId, szError);
		CReplyToCommand(iAdmin, "%t", "BSCommRemoveFailed", iAccountId);
		return;
	}

	if (BSComm_CanUseCoreLibrary())
		BSCore_ClearSummaryModule(iAccountId, BANSYSTEM_COMM_MODULE_BIT);

	int iTarget = FindClientByAccountID(iAccountId);
	if (iTarget > 0 && IsClientInGame(iTarget))
	{
		BSComm_ClearClientCommState(iTarget);
		BSComm_ResetResolvedDetail(iTarget);
	}

	CReplyToCommand(iAdmin, "%t", "BSCommRemoved", iAccountId);
}

public void BSComm_OnCoreSummaryRefreshLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	if (!BSComm_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSComm_SQL("Communication summary refresh lookup failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSCore_ClearSummaryModule(iAccountId, BANSYSTEM_COMM_MODULE_BIT);
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	eBSCommType eCommType = view_as<eBSCommType>(rsResult.FetchInt(1));
	delete rsResult;
	BSCore_SetCommSummary(iAccountId, iBanId, view_as<int>(eCommType));
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch || !StrEqual(szEndpoint, API_SID64toAID, false))
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pContext;
	if (!g_smBSCommIdentityRequestContext.GetValue(szRequestId, pContext))
		return;

	g_smBSCommIdentityRequestContext.Remove(szRequestId);
	pContext.Reset();

	int iUserId = pContext.ReadCell();
	eBSCommIdentityAction eAction = view_as<eBSCommIdentityAction>(pContext.ReadCell());
	int iValue = pContext.ReadCell();
	int iExtraValue = pContext.ReadCell();
	char szExtra[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSCommResolvedDetail[].m_szContext)];
	pContext.ReadString(szExtra, sizeof(szExtra));
	pContext.ReadString(szContext, sizeof(szContext));
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
		return;

	if (!bSuccess)
	{
		BSComm_API("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		CReplyToCommand(iAdmin, "%t", "BSCommSteam64ResolveFailed");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		BSComm_API("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		CReplyToCommand(iAdmin, "%t", "BSCommSteam64ResolveInvalid");
		return;
	}

	BSComm_API("SteamID64 resolution succeeded. request=%d input=%s accountid=%d action=%d", iRequestId, szInput, iAccountId, view_as<int>(eAction));
	switch (eAction)
	{
		case kBSCommIdentityAction_Add:
		{
			eBSCommType eCommType = view_as<eBSCommType>(iExtraValue);
			BSComm_QueueAddBan(iAdmin, iAccountId, 0, eCommType, iValue, szExtra, szContext, szInput, "UNKNOWN");
		}

		case kBSCommIdentityAction_Remove:
		{
			BSComm_QueueRemoveBan(iAdmin, iAccountId);
		}

		case kBSCommIdentityAction_Info:
		{
			BSComm_QueueInfoByAccountId(iAdmin, iAccountId);
		}
	}
}

public void BSComm_OnInfoLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
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
		CReplyToCommand(iAdmin, "%t", "BSCommInfoLoadFailed");
		BSComm_SQL("Communication info query failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSCommNoActiveBan", iAccountId);
		delete rsResult;
		return;
	}

	char szPlayerName[MAX_NAME_LENGTH];
	char szSteamId64[32];
	char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSCommResolvedDetail[].m_szContext)];
	char szBannedByName[MAX_NAME_LENGTH];
	char szBannedBySteamId64[32];
	char szDateExpire[64];
	char szSteam2[32];
	char szType[16];
	eBSCommType eCommType = view_as<eBSCommType>(rsResult.FetchInt(2));
	int iLength = rsResult.FetchInt(3);
	int iBannedBy = rsResult.FetchInt(6);
	int iDateExpireTs = rsResult.FetchInt(9);
	rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(1, szSteamId64, sizeof(szSteamId64));
	rsResult.FetchString(4, szReason, sizeof(szReason));
	rsResult.FetchString(5, szContext, sizeof(szContext));
	rsResult.FetchString(7, szBannedByName, sizeof(szBannedByName));
	rsResult.FetchString(8, szBannedBySteamId64, sizeof(szBannedBySteamId64));
	delete rsResult;
	BSComm_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

	if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	BSComm_GetCommTypeLabel(eCommType, szType, sizeof(szType));
	PrintToConsole(iAdmin, "== BanSystem Comm Info ==");
	PrintToConsole(iAdmin, "Player: %s", szPlayerName);
	PrintToConsole(iAdmin, "AccountId: %d", iAccountId);
	PrintToConsole(iAdmin, "Steam2: %s", szSteam2);
	PrintToConsole(iAdmin, "SteamID64: %s", szSteamId64[0] != '\0' ? szSteamId64 : "<none>");
	PrintToConsole(iAdmin, "Type: %s", szType);
	PrintToConsole(iAdmin, "Length: %s", iLength > 0 ? "Temporary" : "Permanent");
	if (iLength > 0)
		PrintToConsole(iAdmin, "Minutes: %d", iLength);
	PrintToConsole(iAdmin, "Reason: %s", szReason);
	if (szContext[0] != '\0')
		PrintToConsole(iAdmin, "Context: %s", szContext);
	PrintToConsole(iAdmin, "Banned by: %d (%s / %s)", iBannedBy, szBannedByName, szBannedBySteamId64[0] != '\0' ? szBannedBySteamId64 : "<none>");
	PrintToConsole(iAdmin, "Expire: %s", szDateExpire);
	CReplyToCommand(iAdmin, "%t", "BSCommInfoPrinted");
}

public void BSComm_OnListLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
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
		CReplyToCommand(iAdmin, "%t", "BSCommListLoadFailed");
		BSComm_SQL("Communication list query failed: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSCommNoActiveBans");
		delete rsResult;
		return;
	}

	PrintToConsole(iAdmin, "== BanSystem Comm Active Bans ==");
	do
	{
		char szPlayerName[MAX_NAME_LENGTH];
		char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
		char szContext[sizeof(g_eBSCommResolvedDetail[].m_szContext)];
		char szBannedByName[MAX_NAME_LENGTH];
		char szBannedBySteamId64[32];
		char szDateExpire[64];
		char szSteam2[32];
		char szType[16];
		int iAccountId = rsResult.FetchInt(1);
		eBSCommType eCommType = view_as<eBSCommType>(rsResult.FetchInt(2));
		int iLength = rsResult.FetchInt(3);
		int iBannedBy = rsResult.FetchInt(6);
		int iDateExpireTs = rsResult.FetchInt(9);
		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		rsResult.FetchString(4, szReason, sizeof(szReason));
		rsResult.FetchString(5, szContext, sizeof(szContext));
		rsResult.FetchString(7, szBannedByName, sizeof(szBannedByName));
		rsResult.FetchString(8, szBannedBySteamId64, sizeof(szBannedBySteamId64));
		if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
			strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

		BSComm_GetCommTypeLabel(eCommType, szType, sizeof(szType));
		BSComm_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));
		PrintToConsole(iAdmin, "> %s | %s | type=%s | %s | by=%d (%s)", szPlayerName, szSteam2, szType, iLength > 0 ? szDateExpire : "Permanent", iBannedBy, szBannedByName);
		PrintToConsole(iAdmin, "  reason=%s", szReason);
		if (szContext[0] != '\0')
			PrintToConsole(iAdmin, "  context=%s", szContext);
		if (szBannedBySteamId64[0] != '\0')
			PrintToConsole(iAdmin, "  banned_by_steamid64=%s", szBannedBySteamId64);
	} while (rsResult.FetchRow());

	delete rsResult;
	CReplyToCommand(iAdmin, "%t", "BSCommListPrinted");
}
