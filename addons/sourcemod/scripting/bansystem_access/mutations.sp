/*****************************************************************
			M U T A T I O N S
*****************************************************************/

stock void BSAccess_OnPluginStart_Mutations()
{
	g_smBSAccessAttemptIpCache = new StringMap();
}

stock void BSAccess_BuildAttemptCacheKey(int iAccountId, char[] szBuffer, int iMaxLength)
{
	IntToString(iAccountId, szBuffer, iMaxLength);
}

stock bool BSAccess_RememberAttemptIp(int iAccountId, const char[] szIpAddress)
{
	if (iAccountId <= 0 || szIpAddress[0] == '\0' || g_smBSAccessAttemptIpCache == null)
		return false;

	char szKey[16];
	char szCachedIp[32];
	BSAccess_BuildAttemptCacheKey(iAccountId, szKey, sizeof(szKey));

	if (g_smBSAccessAttemptIpCache.GetString(szKey, szCachedIp, sizeof(szCachedIp)) && StrEqual(szCachedIp, szIpAddress, false))
		return false;

	g_smBSAccessAttemptIpCache.SetString(szKey, szIpAddress);
	return true;
}

stock void BSAccess_ForgetAttemptIpIfMatches(int iAccountId, const char[] szIpAddress)
{
	if (iAccountId <= 0 || szIpAddress[0] == '\0' || g_smBSAccessAttemptIpCache == null)
		return;

	char szKey[16];
	char szCachedIp[32];
	BSAccess_BuildAttemptCacheKey(iAccountId, szKey, sizeof(szKey));

	if (!g_smBSAccessAttemptIpCache.GetString(szKey, szCachedIp, sizeof(szCachedIp)))
		return;

	if (StrEqual(szCachedIp, szIpAddress, false))
		g_smBSAccessAttemptIpCache.Remove(szKey);
}

stock void BSAccess_RefreshCoreSummaryForAccountId(int iAccountId)
{
	if (!BSAccess_CanUseCoreLibrary() || !BSAccess_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id` FROM `bansystem_access_bans` ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d LIMIT 1;", iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnCoreSummaryRefreshLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSAccess_QueueInfoByAccountId(int iAdmin, int iAccountId)
{
	if (!BSAccess_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `steamid64`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_access_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnInfoLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSAccess_QueueList(int iAdmin, int iLimit)
{
	if (!BSAccess_CanUseDatabase())
		return;

	char szQuery[768];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_access_bans` WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	SQL_TQuery(g_dbBSAccess, BSAccess_OnListLoaded, szQuery, pContext, DBPrio_Normal);
}

stock void BSAccess_QueueAddBan(int iAdmin, int iAccountId, int iTargetClient, int iLength, const char[] szReason, const char[] szContext, const char[] szSteamId64Override = "", const char[] szPlayerNameOverride = "UNKNOWN")
{
	if (!BSAccess_CanUseDatabase() || iAccountId <= 0 || iLength < 0)
		return;

	char szSteamId64[32];
	char szPlayerName[MAX_NAME_LENGTH];
	char szIpAddress[64];
	char szAdminName[MAX_NAME_LENGTH];
	char szAdminSteamId64[32];
	char szSafeSteamId64[65];
	char szSafePlayerName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeIpAddress[129];
	char szSafeReason[(BANSYSTEM_ACCESS_MAX_REASON_LENGTH * 2) + 1];
	char szSafeContext[1025];
	char szSafeAdminName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeAdminSteamId64[65];
	int iAdminAccountId;

	BSAccess_GetTargetIdentityData(iTargetClient, szSteamId64, sizeof(szSteamId64), szPlayerName, sizeof(szPlayerName));
	if (iTargetClient <= 0 || !IsClientInGame(iTargetClient))
	{
		if (szSteamId64Override[0] != '\0')
			strcopy(szSteamId64, sizeof(szSteamId64), szSteamId64Override);
		if (szPlayerNameOverride[0] != '\0')
			strcopy(szPlayerName, sizeof(szPlayerName), szPlayerNameOverride);
	}
	BSAccess_GetClientIpAddressSafe(iTargetClient, szIpAddress, sizeof(szIpAddress));
	BSAccess_GetAdminAuditData(iAdmin, iAdminAccountId, szAdminName, sizeof(szAdminName), szAdminSteamId64, sizeof(szAdminSteamId64));
	g_dbBSAccess.Escape(szSteamId64, szSafeSteamId64, sizeof(szSafeSteamId64));
	g_dbBSAccess.Escape(szPlayerName, szSafePlayerName, sizeof(szSafePlayerName));
	g_dbBSAccess.Escape(szIpAddress, szSafeIpAddress, sizeof(szSafeIpAddress));
	g_dbBSAccess.Escape(szReason, szSafeReason, sizeof(szSafeReason));
	g_dbBSAccess.Escape(szContext, szSafeContext, sizeof(szSafeContext));
	g_dbBSAccess.Escape(szAdminName, szSafeAdminName, sizeof(szSafeAdminName));
	g_dbBSAccess.Escape(szAdminSteamId64, szSafeAdminSteamId64, sizeof(szSafeAdminSteamId64));

	char szQuery[2048];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `bansystem_access_bans` (`accountid`, `steamid64`, `player_name`, `ip_address`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`) ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, '%s', '%s', '%s', %d, '%s', '%s', %d, '%s', '%s') ", iAccountId, szSafeSteamId64, szSafePlayerName, szSafeIpAddress, iLength, szSafeReason, szSafeContext, iAdminAccountId, szSafeAdminName, szSafeAdminSteamId64);
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `steamid64` = VALUES(`steamid64`), `player_name` = VALUES(`player_name`), `ip_address` = VALUES(`ip_address`), `ban_length` = VALUES(`ban_length`), `ban_reason` = VALUES(`ban_reason`), `ban_context` = VALUES(`ban_context`), `banned_by` = VALUES(`banned_by`), `banned_by_name` = VALUES(`banned_by_name`), `banned_by_steamid64` = VALUES(`banned_by_steamid64`);");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iTargetClient);
	pContext.WriteCell(iLength);
	pContext.WriteString(szReason);

	BSAccess_SQL("Queueing access add mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnAddBanCompleted, szQuery, pContext, DBPrio_High);
}

stock void BSAccess_QueueRemoveBan(int iAdmin, int iAccountId)
{
	if (!BSAccess_CanUseDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "DELETE FROM `bansystem_access_bans` WHERE `accountid` = %d;", iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(iAccountId);

	BSAccess_SQL("Queueing access remove mutation for accountid=%d query=%s", iAccountId, szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnRemoveBanCompleted, szQuery, pContext, DBPrio_High);
}

public void BSAccess_OnAddBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	int iTargetClient = pContext.ReadCell();
	int iLength = pContext.ReadCell();
	char szReason[sizeof(g_eBSAccessResolvedDetail[].m_szReason)];
	pContext.ReadString(szReason, sizeof(szReason));
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	bool bCanReply = (iAdminUserId == 0 || iAdmin > 0);
	if (szError[0] != '\0')
	{
		BSAccess_SQL("Access add mutation failed for accountid=%d: %s", iAccountId, szError);
		if (bCanReply)
			CReplyToCommand(iAdmin, "%t", "BSAccessPersistFailed", iAccountId);
		return;
	}

	if (BSAccess_CanUseCoreLibrary())
	{
		BSCore_RemoveLocalCleanCache(iAccountId);
		BSAccess_RefreshCoreSummaryForAccountId(iAccountId);
	}

	int iLiveTarget = iTargetClient;
	if (iLiveTarget <= 0 || !IsClientInGame(iLiveTarget) || GetClientAccountID(iLiveTarget) != iAccountId)
		iLiveTarget = FindClientByAccountID(iAccountId);

	if (iLiveTarget > 0 && IsClientInGame(iLiveTarget))
	{
		PrintToConsole(iLiveTarget, "// -------------------------------- \\\\");
		PrintToConsole(iLiveTarget, "|");
		PrintToConsole(iLiveTarget, "%T", "BSAccessConsoleReceived", iLiveTarget);
		if (iLength > 0)
			PrintToConsole(iLiveTarget, "%T", "BSAccessConsoleDurationMinutes", iLiveTarget, iLength);
		else
			PrintToConsole(iLiveTarget, "%T", "BSAccessConsoleDurationPermanent", iLiveTarget);
		PrintToConsole(iLiveTarget, "%T", "BSAccessConsoleReason", iLiveTarget, szReason);
		PrintToConsole(iLiveTarget, "|");
		PrintToConsole(iLiveTarget, "// -------------------------------- \\\\");
		char szKickMessage[192];
		Format(szKickMessage, sizeof(szKickMessage), "%T", "BSAccessKickMessage", iLiveTarget);
		KickClient(iLiveTarget, "%s", szKickMessage);
	}

	if (bCanReply)
	{
		if (iLiveTarget > 0 && IsClientInGame(iLiveTarget))
			CReplyToCommand(iAdmin, "%t", "BSAccessStoredTarget", iLiveTarget, iLength, szReason);
		else
			CReplyToCommand(iAdmin, "%t", "BSAccessStoredAccount", iAccountId, iLength, szReason);
	}
}

public void BSAccess_OnRemoveBanCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAdminUserId = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	delete pContext;
	delete rsResult;

	int iAdmin = GetClientOfUserId(iAdminUserId);
	bool bCanReply = (iAdminUserId == 0 || iAdmin > 0);
	if (szError[0] != '\0')
	{
		BSAccess_SQL("Access remove mutation failed for accountid=%d: %s", iAccountId, szError);
		if (bCanReply)
			CReplyToCommand(iAdmin, "%t", "BSAccessRemoveFailed", iAccountId);
		return;
	}

	if (BSAccess_CanUseCoreLibrary())
		BSCore_ClearSummaryModule(iAccountId, kBSCoreModule_Access);

	if (bCanReply)
		CReplyToCommand(iAdmin, "%t", "BSAccessRemoved", iAccountId);
}

public void BSAccess_OnCoreSummaryRefreshLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	if (!BSAccess_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSAccess_SQL("Access summary refresh lookup failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSCore_ClearSummaryModule(iAccountId, kBSCoreModule_Access);
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	delete rsResult;
	BSCore_SetAccessSummary(iAccountId, iBanId);
}

stock void BSAccess_RecordAttempt(int iClient)
{
	if (!BSAccess_CanUseDatabase() || iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient))
		return;

	int iAccountId = g_eBSAccessResolvedDetail[iClient].m_iAccountId;
	if (iAccountId <= 0)
		return;

	char szIpAddress[64];
	char szPlayerName[MAX_NAME_LENGTH];
	char szSteamId64[32];
	char szSafeIpAddress[129];
	char szSafePlayerName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeSteamId64[65];
	BSAccess_GetClientIpAddressSafe(iClient, szIpAddress, sizeof(szIpAddress));

	if (!BSAccess_RememberAttemptIp(iAccountId, szIpAddress))
	{
		BSAccess_Debug("Skipping duplicate access attempt record for client=%d accountid=%d ip=%s", iClient, iAccountId, szIpAddress);
		return;
	}

	GetClientName(iClient, szPlayerName, sizeof(szPlayerName));
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64), true);
	g_dbBSAccess.Escape(szIpAddress, szSafeIpAddress, sizeof(szSafeIpAddress));
	g_dbBSAccess.Escape(szPlayerName, szSafePlayerName, sizeof(szSafePlayerName));
	g_dbBSAccess.Escape(szSteamId64, szSafeSteamId64, sizeof(szSafeSteamId64));

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "CALL `bansystem_access_attempt_record`(%d, '%s', '%s', '%s');", iAccountId, szSafeSteamId64, szSafePlayerName, szSafeIpAddress);

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	pContext.WriteString(szIpAddress);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnAttemptRecorded, szQuery, pContext, DBPrio_Normal);
}

stock void BSAccess_ApplyResolvedBanToClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient) || !g_eBSAccessResolvedDetail[iClient].m_bLoaded)
		return;

	PrintToConsole(iClient, "// -------------------------------- \\\\");
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "%T", "BSAccessConsoleReceived", iClient);
	PrintToConsole(iClient, "%T", "BSAccessConsoleExecutedBy", iClient, g_eBSAccessResolvedDetail[iClient].m_szBannedByName[0] != '\0' ? g_eBSAccessResolvedDetail[iClient].m_szBannedByName : "Console");
	if (g_eBSAccessResolvedDetail[iClient].m_iLength > 0)
		PrintToConsole(iClient, "%T", "BSAccessConsoleDurationMinutes", iClient, g_eBSAccessResolvedDetail[iClient].m_iLength);
	else
		PrintToConsole(iClient, "%T", "BSAccessConsoleDurationPermanent", iClient);
	PrintToConsole(iClient, "%T", "BSAccessConsoleReason", iClient, g_eBSAccessResolvedDetail[iClient].m_szReason);
	if (g_eBSAccessResolvedDetail[iClient].m_szContext[0] != '\0')
		PrintToConsole(iClient, "%T", "BSAccessConsoleContext", iClient, g_eBSAccessResolvedDetail[iClient].m_szContext);
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "// -------------------------------- \\\\");

	BSAccess_RecordAttempt(iClient);
	char szKickMessage[192];
	Format(szKickMessage, sizeof(szKickMessage), "%T", "BSAccessKickMessage", iClient);
	KickClient(iClient, "%s", szKickMessage);
}

public void BSAccess_OnAttemptRecorded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	char szIpAddress[64];
	pContext.ReadString(szIpAddress, sizeof(szIpAddress));
	delete pContext;
	delete rsResult;

	if (szError[0] != '\0')
	{
		BSAccess_ForgetAttemptIpIfMatches(iAccountId, szIpAddress);
		BSAccess_SQL("Access attempt record failed for accountid=%d: %s", iAccountId, szError);
		return;
	}

	BSAccess_Debug("Recorded access attempt for accountid=%d ip=%s", iAccountId, szIpAddress);
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch || !StrEqual(szEndpoint, API_SID64toAID, false))
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pContext;
	if (!g_smBSAccessIdentityRequestContext.GetValue(szRequestId, pContext))
		return;

	g_smBSAccessIdentityRequestContext.Remove(szRequestId);
	pContext.Reset();

	int iUserId = pContext.ReadCell();
	eBSAccessIdentityAction eAction = view_as<eBSAccessIdentityAction>(pContext.ReadCell());
	int iValue = pContext.ReadCell();
	char szReason[sizeof(g_eBSAccessResolvedDetail[].m_szReason)];
	char szContext[sizeof(g_eBSAccessResolvedDetail[].m_szContext)];
	pContext.ReadString(szReason, sizeof(szReason));
	pContext.ReadString(szContext, sizeof(szContext));
	delete pContext;

	int iAdmin = GetClientOfUserId(iUserId);
	if (iUserId != 0 && iAdmin <= 0)
		return;

	if (!bSuccess)
	{
		BSAccess_API("SteamID64 resolution failed. request=%d input=%s", iRequestId, szInput);
		CReplyToCommand(iAdmin, "%t", "BSAccessSteam64ResolveFailed");
		return;
	}

	int iAccountId = StringToInt(szResult);
	if (iAccountId <= 0)
	{
		BSAccess_API("SteamID64 resolution returned invalid accountid. request=%d input=%s result=%s", iRequestId, szInput, szResult);
		CReplyToCommand(iAdmin, "%t", "BSAccessSteam64ResolveInvalid");
		return;
	}

	BSAccess_API("SteamID64 resolution succeeded. request=%d input=%s accountid=%d action=%d", iRequestId, szInput, iAccountId, view_as<int>(eAction));
	switch (eAction)
	{
		case kBSAccessIdentityAction_Add:
		{
			BSAccess_QueueAddBan(iAdmin, iAccountId, 0, iValue, szReason, szContext, szInput, "UNKNOWN");
		}
		case kBSAccessIdentityAction_Remove:
		{
			BSAccess_QueueRemoveBan(iAdmin, iAccountId);
		}
		case kBSAccessIdentityAction_Info:
		{
			BSAccess_QueueInfoByAccountId(iAdmin, iAccountId);
		}
	}
}

public void BSAccess_OnInfoLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
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
		CReplyToCommand(iAdmin, "%t", "BSAccessInfoLoadFailed");
		BSAccess_SQL("Access info query failed for accountid=%d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSAccessNoActiveBan", iAccountId);
		delete rsResult;
		return;
	}

	char szPlayerName[MAX_NAME_LENGTH];
	char szSteamId64[32];
	char szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
	char szContext[512];
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
	BSAccess_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

	if (!AccountIDToSteamID2(iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	BSAccess_PrintAdminConsoleLine(iAdmin, "== BanSystem Access Info ==");
	BSAccess_PrintAdminConsoleLine(iAdmin, "Player: %s", szPlayerName);
	BSAccess_PrintAdminConsoleLine(iAdmin, "AccountId: %d", iAccountId);
	BSAccess_PrintAdminConsoleLine(iAdmin, "Steam2: %s", szSteam2);
	BSAccess_PrintAdminConsoleLine(iAdmin, "SteamID64: %s", szSteamId64[0] != '\0' ? szSteamId64 : "<none>");
	BSAccess_PrintAdminConsoleLine(iAdmin, "Length: %s", iLength > 0 ? "Temporary" : "Permanent");
	if (iLength > 0)
		BSAccess_PrintAdminConsoleLine(iAdmin, "Minutes: %d", iLength);
	BSAccess_PrintAdminConsoleLine(iAdmin, "Reason: %s", szReason);
	if (szContext[0] != '\0')
		BSAccess_PrintAdminConsoleLine(iAdmin, "Context: %s", szContext);
	BSAccess_PrintAdminConsoleLine(iAdmin, "Banned by: %d (%s / %s)", iBannedBy, szBannedByName, szBannedBySteamId64[0] != '\0' ? szBannedBySteamId64 : "<none>");
	BSAccess_PrintAdminConsoleLine(iAdmin, "Expire: %s", szDateExpire);
	CReplyToCommand(iAdmin, "%t", "BSAccessInfoPrinted");
}

public void BSAccess_OnListLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
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
		CReplyToCommand(iAdmin, "%t", "BSAccessListLoadFailed");
		BSAccess_SQL("Access list query failed: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iAdmin, "%t", "BSAccessNoActiveBans");
		delete rsResult;
		return;
	}

	BSAccess_PrintAdminConsoleLine(iAdmin, "== BanSystem Access Active Bans ==");
	do
	{
		char szPlayerName[MAX_NAME_LENGTH];
		char szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
		char szContext[512];
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
		BSAccess_FormatExpireDisplay(iDateExpireTs, szDateExpire, sizeof(szDateExpire));

		BSAccess_PrintAdminConsoleLine(iAdmin, "> %s | %s | %s | by=%d (%s)", szPlayerName, szSteam2, iLength > 0 ? szDateExpire : "Permanent", iBannedBy, szBannedByName);
		BSAccess_PrintAdminConsoleLine(iAdmin, "  reason=%s", szReason);
		if (szContext[0] != '\0')
			BSAccess_PrintAdminConsoleLine(iAdmin, "  context=%s", szContext);
		if (szBannedBySteamId64[0] != '\0')
			BSAccess_PrintAdminConsoleLine(iAdmin, "  banned_by_steamid64=%s", szBannedBySteamId64);
	} while (rsResult.FetchRow());

	delete rsResult;
	CReplyToCommand(iAdmin, "%t", "BSAccessListPrinted");
}
