/*****************************************************************
			D E T A I L
*****************************************************************/

stock void BSComm_OnPluginStart_Detail()
{
}

stock void BSComm_ClearClientCommState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	BaseComm_SetClientMute(iClient, false);
	BaseComm_SetClientGag(iClient, false);
}

stock void BSComm_ApplyCommStateToClientByType(int iClient, eBSCommType eCommType, bool bEnabled)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	switch (eCommType)
	{
		case kBSCommType_Mic:
		{
			BaseComm_SetClientMute(iClient, bEnabled);
		}

		case kBSCommType_Chat:
		{
			BaseComm_SetClientGag(iClient, bEnabled);
		}

		case kBSCommType_All:
		{
			BaseComm_SetClientMute(iClient, bEnabled);
			BaseComm_SetClientGag(iClient, bEnabled);
		}
	}
}

stock void BSComm_ApplyResolvedCommState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !g_eBSCommResolvedDetail[iClient].m_bLoaded)
		return;

	BSComm_ClearClientCommState(iClient);
	BSComm_ApplyCommStateToClientByType(iClient, view_as<eBSCommType>(g_eBSCommResolvedDetail[iClient].m_iCommType), true);
}

stock void BSComm_PrintResolvedDetailToClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !g_eBSCommResolvedDetail[iClient].m_bLoaded)
		return;

	char szType[16];
	BSComm_GetCommTypeLabel(view_as<eBSCommType>(g_eBSCommResolvedDetail[iClient].m_iCommType), szType, sizeof(szType));

	PrintToConsole(iClient, "// -------------------------------- \\\\");
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "%T", "BSCommConsoleReceived", iClient);
	PrintToConsole(iClient, "%T", "BSCommConsoleExecutedBy", iClient, g_eBSCommResolvedDetail[iClient].m_szBannedByName[0] != '\0' ? g_eBSCommResolvedDetail[iClient].m_szBannedByName : "Console");
	if (g_eBSCommResolvedDetail[iClient].m_iLength > 0)
		PrintToConsole(iClient, "%T", "BSCommConsoleDurationMinutes", iClient, g_eBSCommResolvedDetail[iClient].m_iLength);
	else
		PrintToConsole(iClient, "%T", "BSCommConsoleDurationPermanent", iClient);
	PrintToConsole(iClient, "%T", "BSCommConsoleType", iClient, szType);
	PrintToConsole(iClient, "%T", "BSCommConsoleReason", iClient, g_eBSCommResolvedDetail[iClient].m_szReason);
	if (g_eBSCommResolvedDetail[iClient].m_szContext[0] != '\0')
		PrintToConsole(iClient, "%T", "BSCommConsoleContext", iClient, g_eBSCommResolvedDetail[iClient].m_szContext);
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "// -------------------------------- \\\\");
}

stock void BSComm_FillResolvedDetailFromRow(int iClient, DBResultSet rsResult)
{
	g_eBSCommResolvedDetail[iClient].m_bLoaded = true;
	g_eBSCommResolvedDetail[iClient].m_iBanId = rsResult.FetchInt(0);
	g_eBSCommResolvedDetail[iClient].m_iAccountId = rsResult.FetchInt(1);
	g_eBSCommResolvedDetail[iClient].m_iCommType = rsResult.FetchInt(4);
	g_eBSCommResolvedDetail[iClient].m_iLength = rsResult.FetchInt(5);
	g_eBSCommResolvedDetail[iClient].m_iBannedBy = rsResult.FetchInt(8);
	rsResult.FetchString(2, g_eBSCommResolvedDetail[iClient].m_szSteamId64, sizeof(g_eBSCommResolvedDetail[].m_szSteamId64));
	rsResult.FetchString(3, g_eBSCommResolvedDetail[iClient].m_szPlayerName, sizeof(g_eBSCommResolvedDetail[].m_szPlayerName));
	rsResult.FetchString(6, g_eBSCommResolvedDetail[iClient].m_szReason, sizeof(g_eBSCommResolvedDetail[].m_szReason));
	rsResult.FetchString(7, g_eBSCommResolvedDetail[iClient].m_szContext, sizeof(g_eBSCommResolvedDetail[].m_szContext));
	rsResult.FetchString(9, g_eBSCommResolvedDetail[iClient].m_szBannedByName, sizeof(g_eBSCommResolvedDetail[].m_szBannedByName));
	rsResult.FetchString(10, g_eBSCommResolvedDetail[iClient].m_szBannedBySteamId64, sizeof(g_eBSCommResolvedDetail[].m_szBannedBySteamId64));
	g_eBSCommResolvedDetail[iClient].m_iDateExpireTs = rsResult.FetchInt(11);
}

stock void BSComm_QueueResolvedDetailRefreshForClient(int iClient, int iAccountId, bool bApplyState)
{
	if (!BSComm_CanUseDatabase() || iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || iAccountId <= 0)
		return;

	char szQuery[640];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_comm_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(bApplyState ? 1 : 0);
	SQL_TQuery(g_dbBSComm, BSComm_OnResolvedDetailRefreshLoaded, szQuery, pContext, DBPrio_High);
}

public void BSCore_OnCommDetailRequested(int iClient, int iAccountId, int iBanId, int iCommType)
{
	BSComm_Debug(
		"Received core communication detail request: client=%d accountid=%d ban_id=%d comm_type=%d",
		iClient,
		iAccountId,
		iBanId,
		iCommType
	);

	if (!BSComm_CanUseCoreLibrary())
		return;

	BSComm_ResetResolvedDetail(iClient);

	if (!BSComm_CanUseDatabase() || iBanId <= 0)
	{
		BSComm_SQL("Communication detail request for client %d cannot be resolved because DB is not ready or ban_id is invalid.", iClient);
		BSCore_MarkModuleDetailResolved(iClient, 2);
		return;
	}

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_comm_bans` WHERE `id` = %d ", iBanId);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iBanId);
	pContext.WriteCell(iCommType);

	BSComm_SQL("Communication detail query: %s", szQuery);
	SQL_TQuery(g_dbBSComm, BSComm_OnCommDetailLoaded, szQuery, pContext, DBPrio_High);
}

public void BSComm_OnCommDetailLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iExpectedAccountId = pContext.ReadCell();
	int iBanId = pContext.ReadCell();
	int iExpectedCommType = pContext.ReadCell();
	delete pContext;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !BSComm_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSComm_SQL("Communication detail query failed for client %d ban_id %d: %s", iClient, iBanId, szError);
		delete rsResult;
		BSComm_ClearClientCommState(iClient);
		BSCore_MarkModuleDetailResolved(iClient, 2);
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (BSComm_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, BANSYSTEM_COMM_MODULE_BIT);
		BSComm_SQL("Communication detail query returned no row for client %d ban_id %d.", iClient, iBanId);
		delete rsResult;
		BSComm_ClearClientCommState(iClient);
		BSCore_MarkModuleDetailResolved(iClient, 2);
		return;
	}

	BSComm_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;

	BSComm_Debug(
		"Resolved communication detail for client %d: accountid=%d ban_id=%d expected_accountid=%d comm_type=%d expected_comm_type=%d length=%d",
		iClient,
		g_eBSCommResolvedDetail[iClient].m_iAccountId,
		g_eBSCommResolvedDetail[iClient].m_iBanId,
		iExpectedAccountId,
		g_eBSCommResolvedDetail[iClient].m_iCommType,
		iExpectedCommType,
		g_eBSCommResolvedDetail[iClient].m_iLength
	);

	BSComm_ApplyResolvedCommState(iClient);
	BSComm_PrintResolvedDetailToClient(iClient);
	BSCore_MarkModuleDetailResolved(iClient, 2);
}

public void BSComm_OnResolvedDetailRefreshLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iExpectedAccountId = pContext.ReadCell();
	bool bApplyState = view_as<bool>(pContext.ReadCell());
	delete pContext;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSComm_SQL("Resolved communication detail refresh failed for client %d accountid %d: %s", iClient, iExpectedAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSComm_ResetResolvedDetail(iClient);
		BSComm_ClearClientCommState(iClient);
		delete rsResult;
		if (BSComm_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, BANSYSTEM_COMM_MODULE_BIT);
		return;
	}

	BSComm_ResetResolvedDetail(iClient);
	BSComm_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;

	if (bApplyState)
	{
		BSComm_ApplyResolvedCommState(iClient);
		BSComm_PrintResolvedDetailToClient(iClient);
	}
}
