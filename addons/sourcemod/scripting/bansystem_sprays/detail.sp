/*****************************************************************
			D E T A I L
*****************************************************************/

stock void BSSprays_OnPluginStart_Detail()
{
}

stock void BSSprays_ReconcileClientSprayStateFromCore(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
	{
		BSSprays_SQL("Spray reconcile skipped for client %d: client not usable.", iClient);
		return;
	}

	if (!BSSprays_CanUseCoreLibrary() || !BSSprays_CanUseDatabase())
	{
		BSSprays_SQL("Spray reconcile skipped for client %d: core_ready=%d db_ready=%d", iClient, BSSprays_CanUseCoreLibrary() ? 1 : 0, BSSprays_CanUseDatabase() ? 1 : 0);
		return;
	}

	if (!BSCore_HasResolvedSummary(iClient))
	{
		BSSprays_SQL("Spray reconcile skipped for client %d: core has no resolved summary.", iClient);
		return;
	}

	if (!BSSprays_HasResolvedSprayModule(iClient))
	{
		BSSprays_SQL("Spray reconcile skipped for client %d: resolved module mask %d has no sprays bit.", iClient, view_as<int>(BSCore_GetResolvedModuleMask(iClient)));
		return;
	}

	int iAccountId = BSCore_GetResolvedAccountId(iClient);
	int iBanId = BSCore_GetResolvedBanId(iClient, kBSCoreModule_Sprays);
	if (iAccountId <= 0 || iBanId <= 0)
	{
		BSSprays_SQL("Spray reconcile skipped for client %d: invalid core state accountid=%d ban_id=%d", iClient, iAccountId, iBanId);
		return;
	}

	BSSprays_SQL(
		"Reconciling spray state from core for client %d: accountid=%d ban_id=%d",
		iClient,
		iAccountId,
		iBanId
	);

	BSCore_OnSprayDetailRequested(iClient, iAccountId, iBanId);
}

stock void BSSprays_ReconcileAllSprayStatesFromCore()
{
	BSSprays_SQL("Reconciling spray states from core for all clients.");
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		BSSprays_ReconcileClientSprayStateFromCore(iClient);
}

stock void BSSprays_FillResolvedDetailFromRow(int iClient, DBResultSet rsResult)
{
	g_eBSSpraysResolvedDetail[iClient].m_bLoaded = true;
	g_eBSSpraysResolvedDetail[iClient].m_iBanId = rsResult.FetchInt(0);
	g_eBSSpraysResolvedDetail[iClient].m_iAccountId = rsResult.FetchInt(1);
	g_eBSSpraysResolvedDetail[iClient].m_iLength = rsResult.FetchInt(4);
	g_eBSSpraysResolvedDetail[iClient].m_iBannedBy = rsResult.FetchInt(7);
	rsResult.FetchString(2, g_eBSSpraysResolvedDetail[iClient].m_szSteamId64, sizeof(g_eBSSpraysResolvedDetail[].m_szSteamId64));
	rsResult.FetchString(3, g_eBSSpraysResolvedDetail[iClient].m_szPlayerName, sizeof(g_eBSSpraysResolvedDetail[].m_szPlayerName));
	rsResult.FetchString(5, g_eBSSpraysResolvedDetail[iClient].m_szReason, sizeof(g_eBSSpraysResolvedDetail[].m_szReason));
	rsResult.FetchString(6, g_eBSSpraysResolvedDetail[iClient].m_szContext, sizeof(g_eBSSpraysResolvedDetail[].m_szContext));
	rsResult.FetchString(8, g_eBSSpraysResolvedDetail[iClient].m_szBannedByName, sizeof(g_eBSSpraysResolvedDetail[].m_szBannedByName));
	rsResult.FetchString(9, g_eBSSpraysResolvedDetail[iClient].m_szBannedBySteamId64, sizeof(g_eBSSpraysResolvedDetail[].m_szBannedBySteamId64));
	g_eBSSpraysResolvedDetail[iClient].m_iDateExpireTs = rsResult.FetchInt(10);
}

stock void BSSprays_QueueResolvedDetailRefreshForClient(int iClient, int iAccountId)
{
	if (!BSSprays_CanUseDatabase() || iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || iAccountId <= 0)
		return;

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_length`, `ban_reason`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE `accountid` = %d ", iAccountId);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnResolvedDetailRefreshLoaded, szQuery, pContext, DBPrio_High);
}

public Action BSSprays_OnPlayerDecal(const char[] szName, const int[] iClients, int iCount, float flDelay)
{
	int iClient = TE_ReadNum("m_nPlayer");
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;

	if ((BSSprays_CanUseCoreLibrary() && BSCore_IsClientAuthPending(iClient)) || BSSprays_IsClientSprayBanned(iClient))
	{
		BSSprays_Debug("Blocking spray decal for client=%d accountid=%d pending=%d banned=%d", iClient, GetClientAccountID(iClient), BSSprays_CanUseCoreLibrary() ? (BSCore_IsClientAuthPending(iClient) ? 1 : 0) : 0, BSSprays_IsClientSprayBanned(iClient) ? 1 : 0);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void BSCore_OnSprayDetailRequested(int iClient, int iAccountId, int iBanId)
{
	BSSprays_Debug(
		"Received core spray detail request: client=%d accountid=%d ban_id=%d",
		iClient,
		iAccountId,
		iBanId
	);

	if (!BSSprays_CanUseCoreLibrary())
		return;

	BSSprays_ResetResolvedDetail(iClient);

	if (!BSSprays_CanUseDatabase() || iBanId <= 0)
	{
		BSSprays_SQL("Spray detail request for client %d cannot be resolved because DB is not ready or ban_id is invalid.", iClient);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Sprays);
		return;
	}

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_length`, `ban_reason`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_spray_bans` WHERE `id` = %d ", iBanId);
	iLen += g_dbBSSprays.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(iBanId);

	BSSprays_SQL("Spray detail query: %s", szQuery);
	SQL_TQuery(g_dbBSSprays, BSSprays_OnSprayDetailLoaded, szQuery, pContext, DBPrio_High);
}

public void BSSprays_OnSprayDetailLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iExpectedAccountId = pContext.ReadCell();
	int iBanId = pContext.ReadCell();
	delete pContext;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !BSSprays_CanUseCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_SQL("Spray detail query failed for client %d ban_id %d: %s", iClient, iBanId, szError);
		delete rsResult;
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Sprays);
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (BSSprays_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Sprays);
		BSSprays_SQL("Spray detail query returned no row for client %d ban_id %d.", iClient, iBanId);
		delete rsResult;
		BSSprays_ResetResolvedDetail(iClient);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Sprays);
		return;
	}

	int iResolvedAccountId = rsResult.FetchInt(1);
	if (iResolvedAccountId != iExpectedAccountId)
	{
		BSSprays_SQL(
			"Spray detail accountid mismatch for client %d ban_id %d: expected=%d resolved=%d",
			iClient,
			iBanId,
			iExpectedAccountId,
			iResolvedAccountId
		);
		if (BSSprays_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Sprays);
		delete rsResult;
		BSSprays_ResetResolvedDetail(iClient);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Sprays);
		return;
	}

	BSSprays_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;

	BSSprays_Debug(
		"Resolved spray detail for client %d: accountid=%d ban_id=%d expected_accountid=%d length=%d",
		iClient,
		g_eBSSpraysResolvedDetail[iClient].m_iAccountId,
		g_eBSSpraysResolvedDetail[iClient].m_iBanId,
		iExpectedAccountId,
		g_eBSSpraysResolvedDetail[iClient].m_iLength
	);
	BSCore_SetSpraySummaryDetail(
		iExpectedAccountId,
		g_eBSSpraysResolvedDetail[iClient].m_iBanId,
		g_eBSSpraysResolvedDetail[iClient].m_iLength,
		g_eBSSpraysResolvedDetail[iClient].m_szReason,
		g_eBSSpraysResolvedDetail[iClient].m_szContext,
		g_eBSSpraysResolvedDetail[iClient].m_szBannedByName,
		g_eBSSpraysResolvedDetail[iClient].m_iDateExpireTs
	);

	BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Sprays);
}

public void BSSprays_OnResolvedDetailRefreshLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iUserId = pContext.ReadCell();
	int iExpectedAccountId = pContext.ReadCell();
	delete pContext;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSSprays_SQL("Resolved spray detail refresh failed for client %d accountid %d: %s", iClient, iExpectedAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSSprays_ResetResolvedDetail(iClient);
		delete rsResult;
		if (BSSprays_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Sprays);
		return;
	}

		int iResolvedAccountId = rsResult.FetchInt(1);
		if (iResolvedAccountId != iExpectedAccountId)
		{
			BSSprays_SQL(
				"Resolved spray detail refresh mismatch for client %d: expected=%d resolved=%d",
				iClient,
				iExpectedAccountId,
				iResolvedAccountId
			);
			BSSprays_ResetResolvedDetail(iClient);
			delete rsResult;
			if (BSSprays_CanUseCoreLibrary())
				BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Sprays);
			return;
		}

	BSSprays_ResetResolvedDetail(iClient);
	BSSprays_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;

	if (BSSprays_CanUseCoreLibrary())
	{
		BSCore_SetSpraySummaryDetail(
			iExpectedAccountId,
			g_eBSSpraysResolvedDetail[iClient].m_iBanId,
			g_eBSSpraysResolvedDetail[iClient].m_iLength,
			g_eBSSpraysResolvedDetail[iClient].m_szReason,
			g_eBSSpraysResolvedDetail[iClient].m_szContext,
			g_eBSSpraysResolvedDetail[iClient].m_szBannedByName,
			g_eBSSpraysResolvedDetail[iClient].m_iDateExpireTs
		);
	}
}
