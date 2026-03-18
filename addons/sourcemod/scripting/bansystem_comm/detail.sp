/*****************************************************************
			D E T A I L
*****************************************************************/

stock void BSComm_OnPluginStart_Detail()
{
}

stock void BSComm_SyncActiveBanIdentityForClient(int iClient, int iAccountId)
{
	if (!BSComm_CanUseDatabase() || iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient) || iAccountId <= 0)
		return;

	char szSteamId64[32];
	char szPlayerName[MAX_NAME_LENGTH];
	char szIpAddress[64];
	char szSafeSteamId64[65];
	char szSafePlayerName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeIpAddress[129];
	BSComm_GetTargetIdentityData(iClient, szSteamId64, sizeof(szSteamId64), szPlayerName, sizeof(szPlayerName));
	BSComm_GetClientIpAddressSafe(iClient, szIpAddress, sizeof(szIpAddress));
	g_dbBSComm.Escape(szSteamId64, szSafeSteamId64, sizeof(szSafeSteamId64));
	g_dbBSComm.Escape(szPlayerName, szSafePlayerName, sizeof(szSafePlayerName));
	g_dbBSComm.Escape(szIpAddress, szSafeIpAddress, sizeof(szSafeIpAddress));

	char szQuery[1024];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "UPDATE `%s` SET `steamid64` = '%s', `player_name` = '%s', `ip_address` = '%s' ", BANSYSTEM_COMM_MYSQL_TABLE_BANS, szSafeSteamId64, szSafePlayerName, szSafeIpAddress);
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ", iAccountId);
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`steamid64` <> '%s' OR `player_name` <> '%s' OR `ip_address` <> '%s');", szSafeSteamId64, szSafePlayerName, szSafeIpAddress);

	SQL_TQuery(g_dbBSComm, BSComm_OnIdentitySyncCompleted, szQuery, iAccountId, DBPrio_Low);
}

public void BSComm_OnIdentitySyncCompleted(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	int iAccountId = pData;
	delete rsResult;

	if (szError[0] != '\0')
		BSComm_SQL("Communication identity sync failed for accountid %d: %s", iAccountId, szError);
}

stock void BSComm_ReconcileClientCommStateFromCore(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return;

	if (!BSComm_CanUseCoreLibrary() || !BSComm_CanUseDatabase())
	{
		BSComm_SQL("Comm reconcile skipped for client %d: core_ready=%d db_ready=%d", iClient, BSComm_CanUseCoreLibrary() ? 1 : 0, BSComm_CanUseDatabase() ? 1 : 0);
		return;
	}

	if (!BSCore_HasResolvedSummary(iClient))
	{
		BSComm_SQL("Comm reconcile skipped for client %d: core has no resolved summary.", iClient);
		return;
	}

	if (!BSComm_HasResolvedCommunicationModule(iClient))
	{
		BSComm_SQL("Comm reconcile skipped for client %d: resolved module mask %d has no communication bit.", iClient, view_as<int>(BSCore_GetResolvedModuleMask(iClient)));
		return;
	}

	int iAccountId = BSCore_GetResolvedAccountId(iClient);
	int iBanId = BSCore_GetResolvedBanId(iClient, kBSCoreModule_Communication);
	eBSCoreCommType eCoreCommType = BSCore_GetResolvedCommType(iClient);
	if (iAccountId <= 0 || iBanId <= 0 || eCoreCommType == kBSCoreComm_None)
	{
		BSComm_SQL("Comm reconcile skipped for client %d: invalid core state accountid=%d ban_id=%d comm_type=%d", iClient, iAccountId, iBanId, view_as<int>(eCoreCommType));
		return;
	}

	BSComm_SQL(
		"Reconciling communication state from core for client %d: accountid=%d ban_id=%d comm_type=%d",
		iClient,
		iAccountId,
		iBanId,
		view_as<int>(eCoreCommType)
	);

	BSCore_OnCommDetailRequested(iClient, iAccountId, iBanId, eCoreCommType);
}

stock void BSComm_ReconcileAllCommStatesFromCore()
{
	BSComm_SQL("Reconciling communication states from core for all clients.");
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		BSComm_ReconcileClientCommStateFromCore(iClient);
}

stock void BSComm_ClearClientCommState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !g_bBSCommHasBaseComm)
		return;

	BaseComm_SetClientMute(iClient, false);
	BaseComm_SetClientGag(iClient, false);
}

stock void BSComm_ApplyCommStateToClientByType(int iClient, eBSCommType eCommType, bool bEnabled)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !g_bBSCommHasBaseComm)
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

	BSComm_SQL("Applying resolved communication state to client %d: comm_type=%d basecomm=%d", iClient, view_as<int>(g_eBSCommResolvedDetail[iClient].m_eCommType), g_bBSCommHasBaseComm ? 1 : 0);

	BSComm_ClearClientCommState(iClient);
	BSComm_ApplyCommStateToClientByType(iClient, g_eBSCommResolvedDetail[iClient].m_eCommType, true);
}

stock void BSComm_ReapplyResolvedCommStateToAllClients()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || !g_eBSCommResolvedDetail[iClient].m_bLoaded)
			continue;

		BSComm_ApplyResolvedCommState(iClient);
	}
}

stock void BSComm_PrintResolvedDetailToClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !g_eBSCommResolvedDetail[iClient].m_bLoaded)
		return;

	char szType[16];
	BSComm_GetCommTypeLabel(g_eBSCommResolvedDetail[iClient].m_eCommType, szType, sizeof(szType));
	BSComm_PrintClientResolvedDetailConsoleCard(
		iClient,
		szType,
		g_eBSCommResolvedDetail[iClient].m_iLength,
		g_eBSCommResolvedDetail[iClient].m_szReason,
		g_eBSCommResolvedDetail[iClient].m_szContext,
		g_eBSCommResolvedDetail[iClient].m_szBannedByName,
		g_eBSCommResolvedDetail[iClient].m_iDateExpireTs
	);
}

stock void BSComm_FillResolvedDetailFromRow(int iClient, DBResultSet rsResult)
{
	g_eBSCommResolvedDetail[iClient].m_bLoaded = true;
	g_eBSCommResolvedDetail[iClient].m_iBanId = rsResult.FetchInt(0);
	g_eBSCommResolvedDetail[iClient].m_iAccountId = rsResult.FetchInt(1);
	g_eBSCommResolvedDetail[iClient].m_eCommType = view_as<eBSCommType>(rsResult.FetchInt(4));
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
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_type`, `ban_length`, ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` WHERE `accountid` = %d LIMIT 1;", BANSYSTEM_COMM_MYSQL_VIEW_BANS_ACTIVE, iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(bApplyState ? 1 : 0);
	SQL_TQuery(g_dbBSComm, BSComm_OnResolvedDetailRefreshLoaded, szQuery, pContext, DBPrio_High);
}

public void BSCore_OnCommDetailRequested(int client, int accountid, int banId, eBSCoreCommType commType)
{
	BSComm_SQL(
		"Received core communication detail request: client=%d accountid=%d ban_id=%d comm_type=%d",
		client,
		accountid,
		banId,
		commType
	);

	if (!BSComm_CanUseCoreLibrary())
		return;

	BSComm_ResetResolvedDetail(client);

	if (!BSComm_CanUseDatabase() || banId <= 0)
	{
		BSComm_SQL("Communication detail request for client %d cannot be resolved because DB is not ready or ban_id is invalid.", client);
		BSCore_MarkModuleDetailResolved(client, kBSCoreModule_Communication);
		return;
	}

	char szQuery[512];
	int iLen = 0;
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `id`, `accountid`, `steamid64`, `player_name`, `ban_type`, `ban_length`, ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, ");
	iLen += g_dbBSComm.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts` ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` WHERE `id` = %d LIMIT 1;", BANSYSTEM_COMM_MYSQL_VIEW_BANS_ACTIVE, banId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(client));
	pContext.WriteCell(accountid);
	pContext.WriteCell(banId);
	pContext.WriteCell(view_as<int>(commType));

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
	eBSCoreCommType eExpectedCommType = view_as<eBSCoreCommType>(pContext.ReadCell());
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
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Communication);
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (BSComm_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Communication);
		BSComm_SQL("Communication detail query returned no row for client %d ban_id %d.", iClient, iBanId);
		delete rsResult;
		BSComm_ClearClientCommState(iClient);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Communication);
		return;
	}

	int iResolvedBanId = rsResult.FetchInt(0);
	int iResolvedAccountId = rsResult.FetchInt(1);
	eBSCommType eResolvedCommType = view_as<eBSCommType>(rsResult.FetchInt(4));
	if (iResolvedAccountId != iExpectedAccountId || !BSComm_IsSupportedCommType(eResolvedCommType) || view_as<eBSCoreCommType>(eResolvedCommType) != eExpectedCommType)
	{
		BSComm_SQL(
			"Communication detail query returned mismatched state for client %d: expected_accountid=%d actual_accountid=%d expected_type=%d actual_type=%d ban_id=%d",
			iClient,
			iExpectedAccountId,
			iResolvedAccountId,
			view_as<int>(eExpectedCommType),
			view_as<int>(eResolvedCommType),
			iResolvedBanId
		);
		delete rsResult;
		BSComm_ClearClientCommState(iClient);
		BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Communication);
		BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Communication);
		return;
	}

	BSComm_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;

	BSComm_SQL(
		"Resolved communication detail for client %d: accountid=%d ban_id=%d expected_accountid=%d comm_type=%d expected_comm_type=%d length=%d basecomm=%d",
		iClient,
		g_eBSCommResolvedDetail[iClient].m_iAccountId,
		g_eBSCommResolvedDetail[iClient].m_iBanId,
		iExpectedAccountId,
		view_as<int>(g_eBSCommResolvedDetail[iClient].m_eCommType),
		view_as<int>(eExpectedCommType),
		g_eBSCommResolvedDetail[iClient].m_iLength,
		g_bBSCommHasBaseComm ? 1 : 0
	);
	BSComm_SyncActiveBanIdentityForClient(iClient, iExpectedAccountId);

	BSComm_ApplyResolvedCommState(iClient);
	BSComm_PrintResolvedDetailToClient(iClient);
	BSCore_SetCommSummaryDetail(
		iExpectedAccountId,
		g_eBSCommResolvedDetail[iClient].m_iBanId,
		view_as<eBSCoreCommType>(g_eBSCommResolvedDetail[iClient].m_eCommType),
		g_eBSCommResolvedDetail[iClient].m_iLength,
		g_eBSCommResolvedDetail[iClient].m_szReason,
		g_eBSCommResolvedDetail[iClient].m_szContext,
		g_eBSCommResolvedDetail[iClient].m_szBannedByName,
		g_eBSCommResolvedDetail[iClient].m_iDateExpireTs
	);
	BSCore_MarkModuleDetailResolved(iClient, kBSCoreModule_Communication);
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
		BSComm_SQL("Resolved communication detail refresh returned no row for client %d accountid %d. Clearing state.", iClient, iExpectedAccountId);
		BSComm_ResetResolvedDetail(iClient);
		BSComm_ClearClientCommState(iClient);
		delete rsResult;
		if (BSComm_CanUseCoreLibrary())
			BSCore_ClearSummaryModule(iExpectedAccountId, kBSCoreModule_Communication);
		return;
	}

	BSComm_ResetResolvedDetail(iClient);
	BSComm_FillResolvedDetailFromRow(iClient, rsResult);
	delete rsResult;
	BSComm_SQL("Resolved communication detail refresh loaded for client %d: accountid=%d ban_id=%d comm_type=%d apply_state=%d basecomm=%d", iClient, g_eBSCommResolvedDetail[iClient].m_iAccountId, g_eBSCommResolvedDetail[iClient].m_iBanId, view_as<int>(g_eBSCommResolvedDetail[iClient].m_eCommType), bApplyState ? 1 : 0, g_bBSCommHasBaseComm ? 1 : 0);
	BSComm_SyncActiveBanIdentityForClient(iClient, iExpectedAccountId);

	if (bApplyState)
	{
		BSComm_ApplyResolvedCommState(iClient);
		BSComm_PrintResolvedDetailToClient(iClient);
	}

	if (BSComm_CanUseCoreLibrary())
	{
		BSCore_SetCommSummaryDetail(
			iExpectedAccountId,
			g_eBSCommResolvedDetail[iClient].m_iBanId,
			view_as<eBSCoreCommType>(g_eBSCommResolvedDetail[iClient].m_eCommType),
			g_eBSCommResolvedDetail[iClient].m_iLength,
			g_eBSCommResolvedDetail[iClient].m_szReason,
			g_eBSCommResolvedDetail[iClient].m_szContext,
			g_eBSCommResolvedDetail[iClient].m_szBannedByName,
			g_eBSCommResolvedDetail[iClient].m_iDateExpireTs
		);
	}
}
