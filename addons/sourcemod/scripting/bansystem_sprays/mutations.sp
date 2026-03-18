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

stock void BSSprays_QueueInfoByAccountId(int iAdmin, int iAccountId, ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[640];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `ban_length`, `ban_reason`, `ban_context`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`banned_by`, `banned_by_name`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnInfoLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSSprays_QueueList(int iAdmin, int iLimit, ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	if (!BSSprays_CanUseDatabase())
		return;

	char szQuery[896];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_length`, `ban_reason`, `ban_context`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`banned_by`, `banned_by_name`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eReplySource));
	SQL_TQuery(g_dbBSSprays, BSSprays_OnListLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSSprays_QueueAddBan(int iAdmin, int iAccountId, int iTargetClient, int iLength, const char[] szReason, const char[] szContext, const char[] szSteamId64Override = "", const char[] szPlayerNameOverride = "UNKNOWN", ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0 || iLength < 0)
		return;

	char szSteamId64[32];
	char szPlayerName[MAX_NAME_LENGTH];
	char szIpAddress[64];
	char szAdminName[MAX_NAME_LENGTH];
	char szAdminSteamId64[32];
	char szSafeSteamId64[65];
	char szSafePlayerName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeIpAddress[129];
	char szSafeReason[(BANSYSTEM_SPRAYS_MAX_REASON_LENGTH * 2) + 1];
	char szSafeContext[(sizeof(g_eBSSpraysResolvedDetail[].m_szContext) * 2) + 1];
	char szSafeAdminName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeAdminSteamId64[65];
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
	g_dbBSSprays.Escape(szSteamId64, szSafeSteamId64, sizeof(szSafeSteamId64));
	g_dbBSSprays.Escape(szPlayerName, szSafePlayerName, sizeof(szSafePlayerName));
	g_dbBSSprays.Escape(szIpAddress, szSafeIpAddress, sizeof(szSafeIpAddress));
	g_dbBSSprays.Escape(szReason, szSafeReason, sizeof(szSafeReason));
	g_dbBSSprays.Escape(szContext, szSafeContext, sizeof(szSafeContext));
	g_dbBSSprays.Escape(szAdminName, szSafeAdminName, sizeof(szSafeAdminName));
	g_dbBSSprays.Escape(szAdminSteamId64, szSafeAdminSteamId64, sizeof(szSafeAdminSteamId64));

	char szQuery[2304];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `bansystem_spray_bans` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `steamid64`, `player_name`, `ip_address`, `ban_length`, `ban_reason`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`) ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, '%s', '%s', '%s', %d, '%s', '%s', %d, '%s', '%s') ", iAccountId, szSafeSteamId64, szSafePlayerName, szSafeIpAddress, iLength, szSafeReason, szSafeContext, iAdminAccountId, szSafeAdminName, szSafeAdminSteamId64);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `steamid64` = VALUES(`steamid64`), `player_name` = VALUES(`player_name`), ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ip_address` = VALUES(`ip_address`), `ban_length` = VALUES(`ban_length`), `ban_reason` = VALUES(`ban_reason`), ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_context` = VALUES(`ban_context`), `banned_by` = VALUES(`banned_by`), `banned_by_name` = VALUES(`banned_by_name`), `banned_by_steamid64` = VALUES(`banned_by_steamid64`);");

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iTargetClient);
	pContext.WriteCell(iLength);
	pContext.WriteString(szReason);

	BSSprays_SQL("Queueing spray add mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnAddBanCompleted, szQuery, pContext, DBPrio_High);
}

stock void BSSprays_QueueRemoveBan(int iAdmin, int iAccountId, ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bansystem_spray_bans` WHERE `accountid` = %d;", iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteCell(iAccountId);

	BSSprays_SQL("Queueing spray remove mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnRemoveBanCompleted, szQuery, pContext, DBPrio_High);
}

public void BSSprays_OnAddBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	ReplySource eReplySource = view_as<ReplySource>(pContext.ReadCell());
	int iAccountId = pContext.ReadCell();
	int iTargetClient = pContext.ReadCell();
	int iLength = pContext.ReadCell();
	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	pContext.ReadString(szReason, sizeof(szReason));
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	bool bCanReply = (iAdminUserId == 0 || iAdmin > 0);
	if (szError[0] != '\0')
	{
		BSSprays_SQL("Spray add mutation failed for accountid=%d: %s", iAccountId, szError);
		if (bCanReply)
			BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysPersistFailed", iAccountId);
		return;
	}

	if (BSSprays_CanUseCoreLibrary())
	{
		BSCore_RemoveLocalCleanCache(iAccountId);
		BSSprays_RefreshCoreSummaryForAccountId(iAccountId);
	}

	int iLiveTarget = iTargetClient;
	if (iLiveTarget <= 0 || !IsClientInGame(iLiveTarget) || GetClientAccountID(iLiveTarget) != iAccountId)
		iLiveTarget = FindClientByAccountID(iAccountId);

	if (iLiveTarget > 0 && IsClientInGame(iLiveTarget))
	{
		BSSprays_QueueResolvedDetailRefreshForClient(iLiveTarget, iAccountId);
		CPrintToChat(iLiveTarget, "%t", "BSSpraysPlayerBanned");
	}

	if (bCanReply)
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysStored", iAccountId, szReason);

	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Sprays]", "enforcement", "action=ban_added accountid=%d length=%d live_target=%d", iAccountId, iLength, (iLiveTarget > 0 && IsClientInGame(iLiveTarget)) ? 1 : 0);
}

public void BSSprays_OnRemoveBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	ReplySource eReplySource = view_as<ReplySource>(pContext.ReadCell());
	int iAccountId = pContext.ReadCell();
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	bool bCanReply = (iAdminUserId == 0 || iAdmin > 0);
	if (szError[0] != '\0')
	{
		BSSprays_SQL("Spray remove mutation failed for accountid=%d: %s", iAccountId, szError);
		if (bCanReply)
			BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysRemoveFailed", iAccountId);
		return;
	}

	if (BSSprays_CanUseCoreLibrary())
		BSCore_ClearSummaryModule(iAccountId, kBSCoreModule_Sprays);

	int iTarget = FindClientByAccountID(iAccountId);
	if (iTarget > 0 && IsClientInGame(iTarget))
	{
		BSSprays_ResetResolvedDetail(iTarget);
		CPrintToChat(iTarget, "%t", "BSSpraysPlayerUnbanned");
	}

	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Sprays]", "enforcement", "action=ban_removed accountid=%d live_target=%d", iAccountId, (iTarget > 0 && IsClientInGame(iTarget)) ? 1 : 0);

	if (bCanReply)
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysRemoved", iAccountId);
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
		BSCore_ClearSummaryModule(iAccountId, kBSCoreModule_Sprays);
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

	int iUserId;
	eBSSpraysIdentityAction eAction;
	int iValue;
	ReplySource eReplySource;
	char szExtra[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	BSSprays_ReadIdentityLookupContext(pContext, iUserId, eAction, iValue, eReplySource, szExtra, sizeof(szExtra), szContext, sizeof(szContext));
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
		return;

	if (!bSuccess)
	{
		BSSprays_API("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysSteam64ResolveFailed");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		BSSprays_API("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysSteam64ResolveInvalid");
		return;
	}

	BSSprays_API("SteamID64 resolution succeeded. request=%d input=%s accountid=%d action=%d", iRequestId, szInput, iAccountId, view_as<int>(eAction));
	switch (eAction)
	{
		case kBSSpraysIdentityAction_Add:
		{
			BSSprays_QueueAddBan(iAdmin, iAccountId, 0, iValue, szExtra, szContext, szInput, "UNKNOWN", eReplySource);
		}

		case kBSSpraysIdentityAction_Remove:
		{
			BSSprays_QueueRemoveBan(iAdmin, iAccountId, eReplySource);
		}

		case kBSSpraysIdentityAction_Info:
		{
			BSSprays_QueueInfoByAccountId(iAdmin, iAccountId, eReplySource);
		}
	}
}

public void BSSprays_OnInfoLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	ReplySource eReplySource = view_as<ReplySource>(pContext.ReadCell());
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
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysInfoLoadFailed");
		BSSprays_SQL("Spray info query failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysNoActiveBan", iAccountId);
		delete rsResult;
		return;
	}

	char szPlayerName[MAX_NAME_LENGTH];
	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	char szBannedByName[MAX_NAME_LENGTH];
	char szDateExpire[64];
	char szSteam2[32];
	char szBannedBySteam2[32];
	int iLength = rsResult.FetchInt(1);
	int iBannedBy = rsResult.FetchInt(4);
	int iDateExpireTs = rsResult.FetchInt(6);
	rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(2, szReason, sizeof(szReason));
	rsResult.FetchString(3, szContext, sizeof(szContext));
	rsResult.FetchString(5, szBannedByName, sizeof(szBannedByName));
	delete rsResult;
	BSSprays_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

	if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	if (!AccountIDToSteamID2(iBannedBy, szBannedBySteam2, sizeof(szBannedBySteam2)))
		strcopy(szBannedBySteam2, sizeof(szBannedBySteam2), "UNKNOWN");

	BSSprays_PrintAdminInfoConsoleCard(iAdmin, iAccountId, szPlayerName, szSteam2, iLength, szReason, szContext, szBannedByName, szDateExpire);
	BSSprays_NotifyConsolePrinted(iAdmin, eReplySource, "BSSpraysInfoPrinted");
}

public void BSSprays_OnListLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	ReplySource eReplySource = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysListLoadFailed");
		BSSprays_SQL("Spray list query failed: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSSpraysNoActiveBans");
		delete rsResult;
		return;
	}

	do
	{
		char szPlayerName[MAX_NAME_LENGTH];
		char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
		char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
		char szBannedByName[MAX_NAME_LENGTH];
		char szDateExpire[64];
		char szSteam2[32];
		char szBannedBySteam2[32];
		int iAccountId = rsResult.FetchInt(1);
		int iLength = rsResult.FetchInt(2);
		int iBannedBy = rsResult.FetchInt(5);
		int iDateExpireTs = rsResult.FetchInt(7);
		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		rsResult.FetchString(3, szReason, sizeof(szReason));
		rsResult.FetchString(4, szContext, sizeof(szContext));
		rsResult.FetchString(6, szBannedByName, sizeof(szBannedByName));
		if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
			strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");
		if (!AccountIDToSteamID2(iBannedBy, szBannedBySteam2, sizeof(szBannedBySteam2)))
			strcopy(szBannedBySteam2, sizeof(szBannedBySteam2), "UNKNOWN");
		BSSprays_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

		BSSprays_PrintAdminListConsoleCard(iAdmin, iAccountId, szPlayerName, szSteam2, iLength, szReason, szContext, szBannedByName, szDateExpire);
	} while (rsResult.FetchRow());

	delete rsResult;
	BSSprays_NotifyConsolePrinted(iAdmin, eReplySource, "BSSpraysListPrinted");
}
