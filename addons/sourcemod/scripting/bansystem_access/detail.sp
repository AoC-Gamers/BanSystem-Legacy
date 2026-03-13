/*****************************************************************
			D E T A I L
*****************************************************************/

stock void BSAccess_OnPluginStart_Detail()
{
}

public void BSCore_OnAccessDetailRequested(int iClient, int iAccountId, int iBanId)
{
	BSAccess_Debug(
		"Received core access detail request: client=%d accountid=%d ban_id=%d",
		iClient,
		iAccountId,
		iBanId
	);

	if (!BSAccess_CanUseCoreLibrary())
		return;

	BSAccess_ResetResolvedDetail(iClient);

	if (!BSAccess_CanUseDatabase() || iBanId <= 0)
	{
		BSAccess_SQL("Access detail request for client %d cannot be resolved because DB is not ready or ban_id is invalid.", iClient);
		BSCore_MarkModuleDetailResolved(iClient, 1);
		return;
	}

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `accountid`, `steamid64`, `player_name`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_access_bans` WHERE `id` = %d LIMIT 1;", iBanId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iBanId);

	BSAccess_SQL("Access detail query: %s", szQuery);
	SQL_TQuery(g_dbBSAccess, BSAccess_OnAccessDetailLoaded, szQuery, pContext, DBPrio_High);
}

public void BSAccess_OnAccessDetailLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iExpectedAccountId = pContext.ReadCell();
	int iBanId = pContext.ReadCell();
	delete pContext;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !BSAccess_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSAccess_SQL("Access detail query failed for client %d ban_id %d: %s", iClient, iBanId, szError);
		delete rsResult;
		BSCore_MarkModuleDetailResolved(iClient, 1);
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (BSAccess_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, 1);
		BSAccess_SQL("Access detail query returned no row for client %d ban_id %d.", iClient, iBanId);
		delete rsResult;
		BSCore_MarkModuleDetailResolved(iClient, 1);
		return;
	}

	g_eBSAccessResolvedDetail[iClient].m_bLoaded = true;
	g_eBSAccessResolvedDetail[iClient].m_iBanId = iBanId;
	g_eBSAccessResolvedDetail[iClient].m_iAccountId = rsResult.FetchInt(0);
	g_eBSAccessResolvedDetail[iClient].m_iLength = rsResult.FetchInt(3);
	g_eBSAccessResolvedDetail[iClient].m_iBannedBy = rsResult.FetchInt(6);
	rsResult.FetchString(1, g_eBSAccessResolvedDetail[iClient].m_szSteamId64, sizeof(g_eBSAccessResolvedDetail[].m_szSteamId64));
	rsResult.FetchString(2, g_eBSAccessResolvedDetail[iClient].m_szPlayerName, sizeof(g_eBSAccessResolvedDetail[].m_szPlayerName));
	rsResult.FetchString(4, g_eBSAccessResolvedDetail[iClient].m_szReason, sizeof(g_eBSAccessResolvedDetail[].m_szReason));
	rsResult.FetchString(5, g_eBSAccessResolvedDetail[iClient].m_szContext, sizeof(g_eBSAccessResolvedDetail[].m_szContext));
	rsResult.FetchString(7, g_eBSAccessResolvedDetail[iClient].m_szBannedByName, sizeof(g_eBSAccessResolvedDetail[].m_szBannedByName));
	rsResult.FetchString(8, g_eBSAccessResolvedDetail[iClient].m_szBannedBySteamId64, sizeof(g_eBSAccessResolvedDetail[].m_szBannedBySteamId64));
	g_eBSAccessResolvedDetail[iClient].m_iDateExpireTs = rsResult.FetchInt(9);
	delete rsResult;

	BSAccess_Debug(
		"Resolved access detail for client %d: accountid=%d ban_id=%d expected_accountid=%d length=%d",
		iClient,
		g_eBSAccessResolvedDetail[iClient].m_iAccountId,
		g_eBSAccessResolvedDetail[iClient].m_iBanId,
		iExpectedAccountId,
		g_eBSAccessResolvedDetail[iClient].m_iLength
	);

	BSCore_MarkModuleDetailResolved(iClient, 1);
	BSAccess_ApplyResolvedBanToClient(iClient);
}
