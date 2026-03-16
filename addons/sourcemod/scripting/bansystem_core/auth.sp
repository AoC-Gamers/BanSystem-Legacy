/*****************************************************************
			A U T H
*****************************************************************/

stock void BSCore_ResetResolvedClientState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_iCoreResolvedAccountId[iClient] = 0;
	g_iCoreResolvedModuleMask[iClient] = 0;
	g_eCoreResolvedCommType[iClient] = kBSCoreComm_None;
	g_iCoreResolvedAccessBanId[iClient] = 0;
	g_iCoreResolvedCommBanId[iClient] = 0;
	g_iCoreResolvedSprayBanId[iClient] = 0;
	g_iCorePendingDetailMask[iClient] = 0;
	g_iCoreResolvedDetailMask[iClient] = 0;
}

stock bool BSCore_HasResolvedSummaryState(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && g_iCoreResolvedAccountId[iClient] > 0);
}

stock int BSCore_GetResolvedAccountId(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedAccountId[iClient] : 0;
}

stock int BSCore_GetResolvedModuleMask(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedModuleMask[iClient] : 0;
}

stock eBSCoreCommType BSCore_GetResolvedCommType(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_eCoreResolvedCommType[iClient] : kBSCoreComm_None;
}

stock int BSCore_GetResolvedBanId(int iClient, eBSCoreModuleBit eModuleBit)
{
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	switch (eModuleBit)
	{
		case kBSCoreModule_Access:
			return g_iCoreResolvedAccessBanId[iClient];
		case kBSCoreModule_Communication:
			return g_iCoreResolvedCommBanId[iClient];
		case kBSCoreModule_Sprays:
			return g_iCoreResolvedSprayBanId[iClient];
	}

	return 0;
}

stock int BSCore_GetPendingDetailMask(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_iCorePendingDetailMask[iClient] : 0;
}

stock bool BSCore_IsClientAuthorizationPending(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && g_eCoreAuthState[iClient] != kBSCoreAuthState_Idle);
}

stock bool BSCore_IsClientAuthorizationChecking(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && g_eCoreAuthState[iClient] == kBSCoreAuthState_Checking);
}

stock void BSCore_CancelClientAuthorizationTimer(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	if (g_hCoreAuthTimer[iClient] != null)
	{
		delete g_hCoreAuthTimer[iClient];
		g_hCoreAuthTimer[iClient] = null;
	}
}

stock void BSCore_ResetClientAuthorizationState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	BSCore_CancelClientAuthorizationTimer(iClient);
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Idle;
}

stock void BSCore_BeginClientAuthorizationCheck(int iClient)
{
	if (!BSCore_IsUsableClient(iClient))
		return;

	BSCore_CancelClientAuthorizationTimer(iClient);
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Checking;

	float flTimeout = (g_cvCoreAuthTimeout != null) ? g_cvCoreAuthTimeout.FloatValue : 0.0;
	if (flTimeout > 0.0)
		g_hCoreAuthTimer[iClient] = CreateTimer(flTimeout, Timer_BSCoreAuthTimeout, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);

	BSCore_Debug("Client %N entered core auth checking state.", iClient);
}

stock void BSCore_QueueClientAuthorizationCheck(int iClient)
{
	if (!BSCore_IsUsableClient(iClient))
		return;

	if (!BSCore_IsClientAuthorizationPending(iClient))
		BSCore_BeginClientAuthorizationCheck(iClient);

	g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
	BSCore_TransitionLog("Queued core auth for client %N.", iClient);
}

stock void BSCore_CompleteClientAuthorizationCheck(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_iCorePendingDetailMask[iClient] = 0;
	BSCore_ResetClientAuthorizationState(iClient);
	BSCore_Debug("Client %N completed core auth state.", iClient);
}

stock void BSCore_DispatchModuleDetailRequests(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	int iAccountId = g_iCoreResolvedAccountId[iClient];
	int iPendingMask = g_iCorePendingDetailMask[iClient];

	if (iPendingMask == 0)
	{
		BSCore_CompleteClientAuthorizationCheck(iClient);
		return;
	}

	if (BSCore_HasModule(iPendingMask, kBSCoreModule_Access) && g_gfBSCoreOnAccessDetailRequested != null)
	{
		Call_StartForward(g_gfBSCoreOnAccessDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedAccessBanId[iClient]);
		Call_Finish();
	}

	if (BSCore_HasModule(iPendingMask, kBSCoreModule_Communication) && g_gfBSCoreOnCommDetailRequested != null)
	{
		Call_StartForward(g_gfBSCoreOnCommDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedCommBanId[iClient]);
		Call_PushCell(view_as<int>(g_eCoreResolvedCommType[iClient]));
		Call_Finish();
	}

	if (BSCore_HasModule(iPendingMask, kBSCoreModule_Sprays) && g_gfBSCoreOnSprayDetailRequested != null)
	{
		Call_StartForward(g_gfBSCoreOnSprayDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedSprayBanId[iClient]);
		Call_Finish();
	}
}

stock void BSCore_BeginModuleDetailResolution(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_iCoreResolvedDetailMask[iClient] = 0;
	g_iCorePendingDetailMask[iClient] = (g_iCoreResolvedModuleMask[iClient] & g_iCoreRegisteredModuleMask);

	if (g_iCorePendingDetailMask[iClient] == 0)
	{
		BSCore_Debug("No registered module detail requests pending for %N.", iClient);
		BSCore_CompleteClientAuthorizationCheck(iClient);
		return;
	}

	BSCore_Debug(
		"Dispatching module detail requests for %N: pending_mask=%d resolved_mask=%d",
		iClient,
		g_iCorePendingDetailMask[iClient],
		g_iCoreResolvedDetailMask[iClient]
	);
	BSCore_DispatchModuleDetailRequests(iClient);
}

stock bool BSCore_MarkModuleDetailResolved(int iClient, eBSCoreModuleBit eModuleBit)
{
	if (iClient <= 0 || iClient > MaxClients || eModuleBit == kBSCoreModule_None)
		return false;

	int iModuleBit = view_as<int>(eModuleBit);
	if ((g_iCorePendingDetailMask[iClient] & iModuleBit) == 0)
		return false;

	g_iCorePendingDetailMask[iClient] &= ~iModuleBit;
	g_iCoreResolvedDetailMask[iClient] |= iModuleBit;

	BSCore_Debug(
		"Module detail resolved for %N: bit=%d pending_mask=%d resolved_mask=%d",
		iClient,
		iModuleBit,
		g_iCorePendingDetailMask[iClient],
		g_iCoreResolvedDetailMask[iClient]
	);

	if (g_iCorePendingDetailMask[iClient] == 0)
		BSCore_CompleteClientAuthorizationCheck(iClient);

	return true;
}

stock void BSCore_HandleClientAuthorization(int iClient, const char[] szAuthId)
{
	int iAccountId = GetClientAccountID(iClient);
	if (iAccountId <= 0 && !BSCore_GetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		BSCore_Debug("Failed to resolve accountid for %N (%s).", iClient, szAuthId);
		BSCore_ResetClientAuthorizationState(iClient);
		return;
	}

	g_iCoreResolvedAccountId[iClient] = iAccountId;

	if (BSCore_HasLocalCleanCacheAccountId(iAccountId))
	{
		BSCore_Debug("Local clean cache hit for %N (%d).", iClient, iAccountId);
		BSCore_CompleteClientAuthorizationCheck(iClient);
		return;
	}

	if (BSCore_CanUseCacheDatabase())
	{
		BSCore_RequestCacheSummary(iClient, iAccountId);
		return;
	}

	if (BSCore_CanUsePrimaryDatabase())
	{
		BSCore_RequestPrimarySummary(iClient, iAccountId);
		return;
	}

	g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
	BSCore_TransitionLog("Queued core auth for %N because no summary backend is ready.", iClient);
}

stock void BSCore_ProcessQueuedAuthorizationChecks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_eCoreAuthState[i] != kBSCoreAuthState_Queued)
			continue;

		if (!BSCore_IsUsableClient(i) || IsFakeClient(i))
		{
			BSCore_ResetClientAuthorizationState(i);
			continue;
		}

		char szAuthId[MAX_AUTHID_LENGTH];
		if (!GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
			continue;

		int iAccountId = GetClientAccountID(i);
		if (iAccountId <= 0 && !BSCore_GetAccountIdFromSteam2(szAuthId, iAccountId))
			continue;

		if (BSCore_HasLocalCleanCacheAccountId(iAccountId))
		{
			BSCore_TransitionLog("Local clean cache hit while draining core auth queue for %N.", i);
			BSCore_CompleteClientAuthorizationCheck(i);
			continue;
		}

		if (BSCore_CanUseCacheDatabase() || BSCore_CanUsePrimaryDatabase())
		{
			g_eCoreAuthState[i] = kBSCoreAuthState_Checking;
			BSCore_HandleClientAuthorization(i, szAuthId);
			continue;
		}

		BSCore_Debug("Queued core auth for %N remains unresolved because no summary backend is ready.", i);
	}
}

stock void BSCore_RequestPrimarySummary(int iClient, int iAccountId)
{
	if (!BSCore_CanUsePrimaryDatabase())
		return;

	char szQuery[256];
	BSCore_GetSummarySelectQueryByAccountId(iAccountId, szQuery, sizeof(szQuery));
	BSCore_SQL("Primary summary query for %N: %s", iClient, szQuery);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySummaryResolved, szQuery, pContext, DBPrio_High);
}

stock void BSCore_RequestCacheSummary(int iClient, int iAccountId)
{
	if (!BSCore_CanUseCacheDatabase())
		return;

	char szQuery[256];
	BSCore_GetSummaryCacheSelectQueryByAccountId(iAccountId, szQuery, sizeof(szQuery));
	BSCore_SQL("Cache summary query for %N: %s", iClient, szQuery);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbCoreCache, BSCore_OnCacheSummaryResolved, szQuery, pContext, DBPrio_High);
}

public void BSCore_OnPrimarySummaryResolved(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	int iAccountId;
	BSCore_ReadSummaryContext(pData, iUserId, iAccountId);
	int iClient = GetClientOfUserId(iUserId);

	if (iClient <= 0 || !BSCore_IsClientAuthorizationChecking(iClient))
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary summary query failed for accountid %d: %s", iAccountId, szError);
		delete rsResult;

		g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSCore_MarkAccountIdClean(iClient, iAccountId);
		return;
	}

	int iModuleMask = rsResult.FetchInt(0);
	int iAccessBanId = rsResult.FetchInt(1);
	int iCommBanId = rsResult.FetchInt(2);
	int iSprayBanId = rsResult.FetchInt(3);
	eBSCoreCommType eCommType = view_as<eBSCoreCommType>(rsResult.FetchInt(4));
	if (BSCore_CanUseCacheDatabase())
		BSCore_UpsertCacheSummary(iAccountId, iModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType);

	BSCore_ApplyFetchedSummaryResult(
		iClient,
		iAccountId,
		iModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		eCommType
	);
	delete rsResult;
}

public void BSCore_OnCacheSummaryResolved(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	int iAccountId;
	BSCore_ReadSummaryContext(pData, iUserId, iAccountId);
	int iClient = GetClientOfUserId(iUserId);

	if (iClient <= 0 || !BSCore_IsClientAuthorizationChecking(iClient))
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Cache summary query failed for accountid %d: %s", iAccountId, szError);
		delete rsResult;
		if (BSCore_CanUsePrimaryDatabase())
		{
			BSCore_RequestPrimarySummary(iClient, iAccountId);
			return;
		}

		g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		if (BSCore_CanUsePrimaryDatabase())
		{
			BSCore_RequestPrimarySummary(iClient, iAccountId);
			return;
		}

		g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
		return;
	}

	BSCore_ApplyFetchedSummaryResult(
		iClient,
		iAccountId,
		rsResult.FetchInt(0),
		rsResult.FetchInt(1),
		rsResult.FetchInt(2),
		rsResult.FetchInt(3),
		view_as<eBSCoreCommType>(rsResult.FetchInt(4))
	);
	delete rsResult;
}

stock void BSCore_MarkAccountIdClean(int iClient, int iAccountId)
{
	BSCore_AddLocalCleanCacheAccountId(iAccountId);
	BSCore_ResetResolvedClientState(iClient);
	g_iCoreResolvedAccountId[iClient] = iAccountId;
	BSCore_Debug("No active summary state for %N (%d). Registered as clean.", iClient, iAccountId);
	BSCore_CompleteClientAuthorizationCheck(iClient);
}

stock void BSCore_ApplyFetchedSummaryResult(int iClient, int iAccountId, int iModuleMask, int iAccessBanId, int iCommBanId, int iSprayBanId, eBSCoreCommType eCommType)
{
	if (iModuleMask == 0)
	{
		BSCore_MarkAccountIdClean(iClient, iAccountId);
		return;
	}

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	g_iCoreResolvedAccountId[iClient] = iAccountId;
	g_iCoreResolvedModuleMask[iClient] = iModuleMask;
	g_iCoreResolvedAccessBanId[iClient] = iAccessBanId;
	g_iCoreResolvedCommBanId[iClient] = iCommBanId;
	g_iCoreResolvedSprayBanId[iClient] = iSprayBanId;
	g_eCoreResolvedCommType[iClient] = eCommType;

	BSCore_Debug(
		"Resolved summary for %N: accountid=%d module_mask=%d access_ban_id=%d comm_ban_id=%d spray_ban_id=%d comm_type=%d",
		iClient,
		iAccountId,
		iModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		eCommType
	);

	BSCore_BeginModuleDetailResolution(iClient);
}

stock void BSCore_ReadSummaryContext(any pData, int &iUserId, int &iAccountId)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	iAccountId = pContext.ReadCell();
	delete pContext;
}

public Action Timer_BSCoreAuthTimeout(Handle hTimer, any pData)
{
	int iClient = GetClientOfUserId(view_as<int>(pData));
	if (iClient <= 0)
		return Plugin_Stop;

	if (g_hCoreAuthTimer[iClient] == hTimer)
		g_hCoreAuthTimer[iClient] = null;

	if (!BSCore_IsClientAuthorizationPending(iClient))
		return Plugin_Stop;

	BSCore_Debug("Core auth timeout reached for client %N; resetting pending state.", iClient);
	BSCore_ResetClientAuthorizationState(iClient);
	return Plugin_Stop;
}
