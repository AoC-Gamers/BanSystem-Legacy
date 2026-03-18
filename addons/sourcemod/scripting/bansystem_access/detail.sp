/*****************************************************************
			D E T A I L
*****************************************************************/

stock void BSAccess_OnPluginStart_Detail()
{
}

stock void BSAccess_ReconcileClientAccessStateFromCore(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
	{
		BSAccess_SQL("Access reconcile skipped for client %d: client not usable.", iClient);
		return;
	}

	if (!BSAccess_CanUseCoreLibrary() || !BSAccess_CanUseDatabase())
	{
		BSAccess_SQL("Access reconcile skipped for client %d: core_ready=%d db_ready=%d", iClient, BSAccess_CanUseCoreLibrary() ? 1 : 0, BSAccess_CanUseDatabase() ? 1 : 0);
		return;
	}

	if (!BSCore_HasResolvedSummary(iClient))
	{
		BSAccess_SQL("Access reconcile skipped for client %d: core has no resolved summary.", iClient);
		return;
	}

	if (!BSAccess_HasResolvedAccessModule(iClient))
	{
		BSAccess_SQL("Access reconcile skipped for client %d: resolved module mask %d has no access bit.", iClient, view_as<int>(BSCore_GetResolvedModuleMask(iClient)));
		return;
	}

	int iAccountId = BSCore_GetResolvedAccountId(iClient);
	int iBanId = BSCore_GetResolvedBanId(iClient, kBSCoreModule_Access);
	if (iAccountId <= 0 || iBanId <= 0)
	{
		BSAccess_SQL("Access reconcile skipped for client %d: invalid core state accountid=%d ban_id=%d", iClient, iAccountId, iBanId);
		return;
	}

	BSAccess_SQL(
		"Reconciling access state from core for client %d: accountid=%d ban_id=%d",
		iClient,
		iAccountId,
		iBanId
	);

	BSCore_OnAccessDetailRequested(iClient, iAccountId, iBanId);
}

stock void BSAccess_ReconcileAllAccessStatesFromCore()
{
	BSAccess_SQL("Reconciling access states from core for all clients.");
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		BSAccess_ReconcileClientAccessStateFromCore(iClient);
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
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Access);
		return;
	}

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `accountid`, `steamid64`, `player_name`, `ban_length`, `ban_reason`, ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `bansystem_access_bans` WHERE `id` = %d ", iBanId);
	iLen += g_dbBSAccess.Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) LIMIT 1;");

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
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Access);
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (BSAccess_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Access);
		BSAccess_SQL("Access detail query returned no row for client %d ban_id %d.", iClient, iBanId);
		delete rsResult;
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Access);
		return;
	}

	int iResolvedAccountId = rsResult.FetchInt(0);
	if (iResolvedAccountId != iExpectedAccountId)
	{
		BSAccess_SQL("Access detail query returned mismatched accountid for client %d ban_id %d: expected=%d actual=%d", iClient, iBanId, iExpectedAccountId, iResolvedAccountId);
		delete rsResult;
		BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Access);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Access);
		return;
	}

	BSAccess_FillResolvedDetailFromRow(iClient, iBanId, rsResult);
	delete rsResult;

	BSAccess_Debug(
		"Resolved access detail for client %d: accountid=%d ban_id=%d expected_accountid=%d length=%d",
		iClient,
		g_eBSAccessResolvedDetail[iClient].m_iAccountId,
		g_eBSAccessResolvedDetail[iClient].m_iBanId,
		iExpectedAccountId,
		g_eBSAccessResolvedDetail[iClient].m_iLength
	);

	BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Access);
	BSAccess_ApplyResolvedBanToClient(iClient);
}
