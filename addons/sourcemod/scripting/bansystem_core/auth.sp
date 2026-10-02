/*****************************************************************
			A U T H
*****************************************************************/

stock void BSCore_ResetResolvedClientState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_iCoreResolvedAccountId[iClient] = 0;
	g_bCoreHasResolvedSummary[iClient] = false;
	g_bCoreSummaryLoaded[iClient] = false;
	g_eCoreResolvedModuleMask[iClient] = kBSCoreModule_None;
	g_eCoreResolvedCommType[iClient] = kBSCoreComm_None;
	g_iCoreResolvedAccessBanId[iClient] = 0;
	g_iCoreResolvedCommBanId[iClient] = 0;
	g_iCoreResolvedSprayBanId[iClient] = 0;
	g_iCoreResolvedCommLength[iClient] = 0;
	g_szCoreResolvedCommReason[iClient][0] = '\0';
	g_szCoreResolvedCommContext[iClient][0] = '\0';
	g_szCoreResolvedCommBannedByName[iClient][0] = '\0';
	g_iCoreResolvedCommExpireTs[iClient] = 0;
	g_iCoreResolvedSprayLength[iClient] = 0;
	g_szCoreResolvedSprayReason[iClient][0] = '\0';
	g_szCoreResolvedSprayContext[iClient][0] = '\0';
	g_szCoreResolvedSprayBannedByName[iClient][0] = '\0';
	g_iCoreResolvedSprayExpireTs[iClient] = 0;
	g_eCorePendingDetailMask[iClient] = kBSCoreModule_None;
	g_eCoreResolvedDetailMask[iClient] = kBSCoreModule_None;
}

stock bool BSCore_HasResolvedSummaryState(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && g_bCoreHasResolvedSummary[iClient]);
}

stock int BSCore_AdvanceClientAuthGeneration(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	if (g_iCoreAuthGeneration[iClient] >= 2147483646)
		g_iCoreAuthGeneration[iClient] = 1;
	else
		g_iCoreAuthGeneration[iClient]++;

	return g_iCoreAuthGeneration[iClient];
}

stock int BSCore_GetClientAuthGeneration(int iClient, int iAccountId)
{
	if (!BSCore_IsUsableClient(iClient) || iAccountId <= 0)
		return 0;

	return (g_iCoreAuthAccountId[iClient] == iAccountId) ? g_iCoreAuthGeneration[iClient] : 0;
}

stock bool BSCore_IsClientAuthGenerationCurrent(int iClient, int iAccountId, int iGeneration)
{
	return (iGeneration > 0 && BSCore_GetClientAuthGeneration(iClient, iAccountId) == iGeneration);
}

stock int BSCore_GetResolvedAccountId(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedAccountId[iClient] : 0;
}

stock eBSCoreModuleBit BSCore_GetResolvedModuleMask(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_eCoreResolvedModuleMask[iClient] : kBSCoreModule_None;
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

stock eBSCoreModuleBit BSCore_GetPendingDetailMask(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients) ? g_eCorePendingDetailMask[iClient] : kBSCoreModule_None;
}

stock bool BSCore_IsClientAuthorizationPending(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && (g_eCoreAuthState[iClient] == kBSCoreAuthState_Queued || g_eCoreAuthState[iClient] == kBSCoreAuthState_Checking));
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

stock void BSCore_CancelClientAuthorizationRetryTimer(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	if (g_hCoreAuthRetryTimer[iClient] != null)
	{
		delete g_hCoreAuthRetryTimer[iClient];
		g_hCoreAuthRetryTimer[iClient] = null;
	}
}

stock void BSCore_ResetClientAuthorizationState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	BSCore_CancelClientAuthorizationTimer(iClient);
	BSCore_CancelClientAuthorizationRetryTimer(iClient);
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Idle;
	g_iCoreAuthAccountId[iClient] = 0;
	BSCore_AdvanceClientAuthGeneration(iClient);
}

stock void BSCore_BeginClientAuthorizationCheck(int iClient, bool bResetRetryAttempt = true)
{
	if (!BSCore_IsUsableClient(iClient))
		return;

	BSCore_CancelClientAuthorizationTimer(iClient);
	BSCore_CancelClientAuthorizationRetryTimer(iClient);
	BSCore_AdvanceClientAuthGeneration(iClient);
	BSCore_ResetResolvedClientState(iClient);
	g_iCoreAuthAccountId[iClient] = GetClientAccountID(iClient);
	if (g_iCoreAuthAccountId[iClient] <= 0)
	{
		char szAuthId[MAX_AUTHID_LENGTH];
		if (GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
			BSCore_GetAccountIdFromSteam2(szAuthId, g_iCoreAuthAccountId[iClient]);
	}
	if (bResetRetryAttempt)
		g_iCoreAuthRetryAttempt[iClient] = 0;
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Checking;

	float flTimeout = (g_cvCoreAuthTimeout != null) ? g_cvCoreAuthTimeout.FloatValue : 0.0;
	if (flTimeout > 0.0)
	{
		DataPack pTimerData;
		g_hCoreAuthTimer[iClient] = CreateDataTimer(flTimeout, Timer_BSCoreAuthTimeout, pTimerData, TIMER_FLAG_NO_MAPCHANGE);
		pTimerData.WriteCell(GetClientUserId(iClient));
		pTimerData.WriteCell(g_iCoreAuthAccountId[iClient]);
		pTimerData.WriteCell(g_iCoreAuthGeneration[iClient]);
	}

	BSCore_Debug("Client %N entered core auth checking state.", iClient);
}

stock void BSCore_QueueClientAuthorizationCheck(int iClient)
{
	if (!BSCore_IsUsableClient(iClient))
		return;

	if (g_eCoreAuthState[iClient] == kBSCoreAuthState_Idle || g_eCoreAuthState[iClient] == kBSCoreAuthState_Unverified)
		BSCore_BeginClientAuthorizationCheck(iClient);

	g_eCoreAuthState[iClient] = kBSCoreAuthState_Queued;
	BSCore_TransitionLog("Queued core auth for client %N.", iClient);
}

stock void BSCore_CompleteClientAuthorizationCheck(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eCorePendingDetailMask[iClient] = kBSCoreModule_None;
	BSCore_CancelClientAuthorizationTimer(iClient);
	BSCore_CancelClientAuthorizationRetryTimer(iClient);
	g_iCoreAuthRetryAttempt[iClient] = 0;
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Idle;
	g_bCoreHasResolvedSummary[iClient] = g_bCoreSummaryLoaded[iClient] && g_iCoreResolvedAccountId[iClient] > 0;
	BSCore_Debug("Client %N completed core auth state.", iClient);
}

stock float BSCore_GetAuthRetryDelay(int iRetryAttempt)
{
	switch (iRetryAttempt)
	{
		case 0: return 1.0;
		case 1: return 2.0;
		case 2: return 4.0;
		case 3: return 8.0;
		case 4: return 16.0;
	}
	return 30.0;
}

stock void BSCore_ScheduleAuthorizationRetry(int iClient, const char[] szReason)
{
	if (!BSCore_IsUsableClient(iClient))
		return;

	BSCore_CancelClientAuthorizationTimer(iClient);
	g_eCoreAuthState[iClient] = kBSCoreAuthState_Unverified;
	g_bCoreHasResolvedSummary[iClient] = false;
	if (g_hCoreAuthRetryTimer[iClient] != null)
		return;

	int iRetryAttempt = g_iCoreAuthRetryAttempt[iClient];
	float flDelay = BSCore_GetAuthRetryDelay(iRetryAttempt);
	if (g_iCoreAuthRetryAttempt[iClient] < 5)
		g_iCoreAuthRetryAttempt[iClient]++;

	DataPack pTimerData;
	g_hCoreAuthRetryTimer[iClient] = CreateDataTimer(flDelay, Timer_BSCoreAuthRetry, pTimerData, TIMER_FLAG_NO_MAPCHANGE);
	pTimerData.WriteCell(GetClientUserId(iClient));
	pTimerData.WriteCell(g_iCoreAuthAccountId[iClient]);
	pTimerData.WriteCell(g_iCoreAuthGeneration[iClient]);
	if (iRetryAttempt < 5)
		BSCore_TransitionLog("Auth unresolved for %N; retry scheduled in %.0f seconds (attempt=%d, reason=%s).", iClient, flDelay, iRetryAttempt + 1, szReason);
	else
		BSCore_Debug("Auth retry backoff capped for %N at %.0f seconds (reason=%s).", iClient, flDelay, szReason);
}

public Action Timer_BSCoreAuthRetry(Handle hTimer, DataPack pTimerData)
{
	pTimerData.Reset();
	int iUserId = pTimerData.ReadCell();
	int iAccountId = pTimerData.ReadCell();
	int iGeneration = pTimerData.ReadCell();
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0)
		return Plugin_Stop;

	if (g_hCoreAuthRetryTimer[iClient] == hTimer)
		g_hCoreAuthRetryTimer[iClient] = null;

	if (g_eCoreAuthState[iClient] != kBSCoreAuthState_Unverified || g_iCoreAuthGeneration[iClient] != iGeneration || (iAccountId > 0 && g_iCoreAuthAccountId[iClient] != iAccountId))
		return Plugin_Stop;

	if (g_bCoreMapTransitionActive)
	{
		BSCore_ScheduleAuthorizationRetry(iClient, "map_transition_active");
		return Plugin_Stop;
	}

	char szAuthId[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
	{
		BSCore_ScheduleAuthorizationRetry(iClient, "identity_unavailable");
		return Plugin_Stop;
	}

	BSCore_BeginClientAuthorizationCheck(iClient, false);
	BSCore_HandleClientAuthorization(iClient, szAuthId);
	return Plugin_Stop;
}

stock void BSCore_DispatchModuleDetailRequests(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	int iAccountId = g_iCoreResolvedAccountId[iClient];
	eBSCoreModuleBit ePendingMask = g_eCorePendingDetailMask[iClient];

	if (ePendingMask == kBSCoreModule_None)
	{
		BSCore_SQL("No pending module detail requests for %N. resolved_module_mask=%d registered_module_mask=%d", iClient, view_as<int>(g_eCoreResolvedModuleMask[iClient]), view_as<int>(g_eCoreRegisteredModuleMask));
		BSCore_CompleteClientAuthorizationCheck(iClient);
		return;
	}

	int iGeneration = g_iCoreAuthGeneration[iClient];
	BSCore_SQL("Dispatching module detail requests for %N: accountid=%d generation=%d pending_mask=%d registered_mask=%d access_fwd=%d comm_fwd=%d spray_fwd=%d", iClient, iAccountId, iGeneration, view_as<int>(ePendingMask), view_as<int>(g_eCoreRegisteredModuleMask), g_gfBSCoreOnAccessDetailRequested != null ? 1 : 0, g_gfBSCoreOnCommDetailRequested != null ? 1 : 0, g_gfBSCoreOnSprayDetailRequested != null ? 1 : 0);

	if (BSCore_HasModule(ePendingMask, kBSCoreModule_Access) && g_gfBSCoreOnAccessDetailRequested != null)
	{
		BSCore_SQL("Forwarding access detail request for %N: accountid=%d ban_id=%d", iClient, iAccountId, g_iCoreResolvedAccessBanId[iClient]);
		Call_StartForward(g_gfBSCoreOnAccessDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedAccessBanId[iClient]);
		Call_PushCell(iGeneration);
		Call_Finish();
	}

	if (BSCore_HasModule(ePendingMask, kBSCoreModule_Communication) && g_gfBSCoreOnCommDetailRequested != null)
	{
		BSCore_SQL("Forwarding communication detail request for %N: accountid=%d ban_id=%d comm_type=%d", iClient, iAccountId, g_iCoreResolvedCommBanId[iClient], view_as<int>(g_eCoreResolvedCommType[iClient]));
		Call_StartForward(g_gfBSCoreOnCommDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedCommBanId[iClient]);
		Call_PushCell(view_as<int>(g_eCoreResolvedCommType[iClient]));
		Call_PushCell(iGeneration);
		Call_Finish();
	}

	if (BSCore_HasModule(ePendingMask, kBSCoreModule_Sprays) && g_gfBSCoreOnSprayDetailRequested != null)
	{
		BSCore_SQL("Forwarding spray detail request for %N: accountid=%d ban_id=%d", iClient, iAccountId, g_iCoreResolvedSprayBanId[iClient]);
		Call_StartForward(g_gfBSCoreOnSprayDetailRequested);
		Call_PushCell(iClient);
		Call_PushCell(iAccountId);
		Call_PushCell(g_iCoreResolvedSprayBanId[iClient]);
		Call_PushCell(iGeneration);
		Call_Finish();
	}
}

stock void BSCore_BeginModuleDetailResolution(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eCoreResolvedDetailMask[iClient] = kBSCoreModule_None;
	g_eCorePendingDetailMask[iClient] = view_as<eBSCoreModuleBit>(view_as<int>(g_eCoreResolvedModuleMask[iClient]) & view_as<int>(g_eCoreRegisteredModuleMask));

	if (g_eCorePendingDetailMask[iClient] == kBSCoreModule_None)
	{
		BSCore_Debug("No registered module detail requests pending for %N.", iClient);
		BSCore_CompleteClientAuthorizationCheck(iClient);
		return;
	}

	BSCore_Debug(
		"Dispatching module detail requests for %N: pending_mask=%d resolved_mask=%d",
		iClient,
		view_as<int>(g_eCorePendingDetailMask[iClient]),
		view_as<int>(g_eCoreResolvedDetailMask[iClient])
	);
	BSCore_DispatchModuleDetailRequests(iClient);
}

stock bool BSCore_MarkModuleDetailResolved(int iClient, eBSCoreModuleBit eModuleBit, int iGeneration)
{
	if (iClient <= 0 || iClient > MaxClients || eModuleBit == kBSCoreModule_None || !BSCore_IsClientAuthGenerationCurrent(iClient, g_iCoreAuthAccountId[iClient], iGeneration))
		return false;

	int iModuleBit = view_as<int>(eModuleBit);
	int iPendingMask = view_as<int>(g_eCorePendingDetailMask[iClient]);
	if ((iPendingMask & iModuleBit) == 0)
		return false;

	g_eCorePendingDetailMask[iClient] = view_as<eBSCoreModuleBit>(iPendingMask & ~iModuleBit);
	g_eCoreResolvedDetailMask[iClient] = view_as<eBSCoreModuleBit>(view_as<int>(g_eCoreResolvedDetailMask[iClient]) | iModuleBit);

	BSCore_Debug(
		"Module detail resolved for %N: bit=%d pending_mask=%d resolved_mask=%d",
		iClient,
		iModuleBit,
		view_as<int>(g_eCorePendingDetailMask[iClient]),
		view_as<int>(g_eCoreResolvedDetailMask[iClient])
	);

	if (g_eCorePendingDetailMask[iClient] == kBSCoreModule_None)
		BSCore_CompleteClientAuthorizationCheck(iClient);

	return true;
}

stock void BSCore_HandleClientAuthorization(int iClient, const char[] szAuthId)
{
	int iAccountId = GetClientAccountID(iClient);
	if (iAccountId <= 0 && !BSCore_GetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		BSCore_Debug("Failed to resolve accountid for %N (%s).", iClient, szAuthId);
		BSCore_ScheduleAuthorizationRetry(iClient, "accountid_unavailable");
		return;
	}

	g_iCoreAuthAccountId[iClient] = iAccountId;
	BSCore_SQL("Auth routing for %N: accountid=%d primary_ready=%d transition=%d", iClient, iAccountId, BSCore_CanUsePrimaryDatabase() ? 1 : 0, g_bCoreMapTransitionActive ? 1 : 0);

	if (BSCore_CanUsePrimaryDatabase())
	{
		BSCore_SQL("Auth routing for %N selected primary MySQL backend.", iClient);
		BSCore_RequestPrimarySummary(iClient, iAccountId);
		return;
	}

	BSCore_ScheduleAuthorizationRetry(iClient, "primary_mysql_unavailable");
}

stock void BSCore_ProcessQueuedAuthorizationChecks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_eCoreAuthState[i] != kBSCoreAuthState_Queued && g_eCoreAuthState[i] != kBSCoreAuthState_Unverified)
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

		if (BSCore_CanUsePrimaryDatabase())
		{
			BSCore_CancelClientAuthorizationRetryTimer(i);
			BSCore_BeginClientAuthorizationCheck(i, false);
			BSCore_HandleClientAuthorization(i, szAuthId);
			continue;
		}

		BSCore_ScheduleAuthorizationRetry(i, "primary_mysql_unavailable");
	}
}

stock void BSCore_QueueConnectedClientsForMapTransition()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!BSCore_IsUsableClient(iClient) || IsFakeClient(iClient))
			continue;

		BSCore_ResetClientAuthorizationState(iClient);
		BSCore_ResetResolvedClientState(iClient);
		BSCore_QueueClientAuthorizationCheck(iClient);
	}
}

stock void BSCore_RequestPrimarySummary(int iClient, int iAccountId)
{
	if (!BSCore_CanUsePrimaryDatabase())
		return;

	char szQuery[512];
	BSCore_GetSummarySelectQueryByAccountId(iAccountId, szQuery, sizeof(szQuery));
	BSCore_SQL("Primary summary query for %N: %s", iClient, szQuery);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(g_iCoreAuthGeneration[iClient]);
	pContext.WriteCell(g_iCorePrimaryDatabaseGeneration);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimarySummaryResolved, szQuery, pContext, DBPrio_High);
}

stock void BSCore_RequestPrimaryActiveSummary(int iClient, int iAccountId)
{
	if (!BSCore_CanUsePrimaryDatabase())
		return;

	char szQuery[768];
	BSCore_GetActiveSummarySelectQueryByAccountId(iAccountId, szQuery, sizeof(szQuery));
	BSCore_SQL("Primary active summary fallback query for %N: %s", iClient, szQuery);

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteCell(g_iCoreAuthGeneration[iClient]);
	pContext.WriteCell(g_iCorePrimaryDatabaseGeneration);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnPrimaryActiveSummaryResolved, szQuery, pContext, DBPrio_High);
}

public void BSCore_OnPrimarySummaryResolved(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	int iAccountId;
	int iGeneration;
	int iDatabaseGeneration;
	BSCore_ReadSummaryContext(pData, iUserId, iAccountId, iGeneration, iDatabaseGeneration);
	int iClient = GetClientOfUserId(iUserId);
	BSCore_SQL(
		"Primary summary callback entered: userid=%d client=%d accountid=%d auth_state=%d rs_null=%d err=%d",
		iUserId,
		iClient,
		iAccountId,
		(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCoreAuthState[iClient]) : -1,
		rsResult == null ? 1 : 0,
		szError[0] != '\0' ? 1 : 0
	);

	if (!BSCore_IsCurrentAuthorizationCallback(db, iClient, iUserId, iAccountId, iGeneration, iDatabaseGeneration))
	{
		BSCore_SQL(
			"Primary summary callback ignored: userid=%d client=%d accountid=%d auth_state=%d",
			iUserId,
			iClient,
			iAccountId,
			(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCoreAuthState[iClient]) : -1
		);
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary summary query failed for accountid %d: %s", iAccountId, szError);
		delete rsResult;
		if (BSCore_IsPrimaryConnectionError(szError))
		{
			BSCore_MarkPrimaryDatabaseUnavailable(szError);
			BSCore_ScheduleAuthorizationRetry(iClient, "primary_mysql_disconnected");
			return;
		}
		BSCore_RequestPrimaryActiveSummary(iClient, iAccountId);
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSCore_SQL("Primary summary query returned no row for accountid %d. Falling back to active bans query.", iAccountId);
		delete rsResult;
		BSCore_RequestPrimaryActiveSummary(iClient, iAccountId);
		return;
	}

	eBSCoreModuleBit eModuleMask = view_as<eBSCoreModuleBit>(rsResult.FetchInt(0));
	int iAccessBanId = rsResult.FetchInt(1);
	int iCommBanId = rsResult.FetchInt(2);
	int iSprayBanId = rsResult.FetchInt(3);
	eBSCoreCommType eCommType = view_as<eBSCoreCommType>(rsResult.FetchInt(4));
	BSCore_SQL("Primary summary resolved for %N: accountid=%d module_mask=%d access_ban_id=%d comm_ban_id=%d spray_ban_id=%d comm_type=%d", iClient, iAccountId, view_as<int>(eModuleMask), iAccessBanId, iCommBanId, iSprayBanId, view_as<int>(eCommType));
	if (BSCore_CanUseCacheDatabase())
		BSCore_UpsertCacheSummary(iAccountId, eModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType);

	BSCore_ApplyFetchedSummaryResult(
		iClient,
		iAccountId,
		eModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		eCommType
	);
	delete rsResult;
}

public void BSCore_OnPrimaryActiveSummaryResolved(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	int iAccountId;
	int iGeneration;
	int iDatabaseGeneration;
	BSCore_ReadSummaryContext(pData, iUserId, iAccountId, iGeneration, iDatabaseGeneration);
	int iClient = GetClientOfUserId(iUserId);
	BSCore_SQL(
		"Primary active summary callback entered: userid=%d client=%d accountid=%d auth_state=%d rs_null=%d err=%d",
		iUserId,
		iClient,
		iAccountId,
		(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCoreAuthState[iClient]) : -1,
		rsResult == null ? 1 : 0,
		szError[0] != '\0' ? 1 : 0
	);

	if (!BSCore_IsCurrentAuthorizationCallback(db, iClient, iUserId, iAccountId, iGeneration, iDatabaseGeneration))
	{
		BSCore_SQL(
			"Primary active summary callback ignored: userid=%d client=%d accountid=%d auth_state=%d",
			iUserId,
			iClient,
			iAccountId,
			(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCoreAuthState[iClient]) : -1
		);
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Primary active summary fallback query failed for accountid %d: %s", iAccountId, szError);
		delete rsResult;
		BSCore_MarkPrimaryDatabaseUnavailable(szError);
		BSCore_ScheduleAuthorizationRetry(iClient, "primary_summary_query_failed");
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSCore_SQL("Primary active summary fallback returned no row for accountid %d. Marking clean.", iAccountId);
		delete rsResult;
		BSCore_MarkAccountIdClean(iClient, iAccountId);
		return;
	}

	eBSCoreModuleBit eModuleMask = view_as<eBSCoreModuleBit>(rsResult.FetchInt(0));
	int iAccessBanId = rsResult.FetchInt(1);
	int iCommBanId = rsResult.FetchInt(2);
	int iSprayBanId = rsResult.FetchInt(3);
	eBSCoreCommType eCommType = view_as<eBSCoreCommType>(rsResult.FetchInt(4));
	delete rsResult;

	BSCore_SQL("Primary active summary fallback resolved for %N: accountid=%d module_mask=%d access_ban_id=%d comm_ban_id=%d spray_ban_id=%d comm_type=%d", iClient, iAccountId, view_as<int>(eModuleMask), iAccessBanId, iCommBanId, iSprayBanId, view_as<int>(eCommType));
	BSCore_UpsertPrimarySummary(iAccountId, eModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType, 0, "", "", "", 0, 0, "", "", "", 0, true);
	if (BSCore_CanUseCacheDatabase())
		BSCore_UpsertCacheSummary(iAccountId, eModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType);

	BSCore_ApplyFetchedSummaryResult(
		iClient,
		iAccountId,
		eModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		eCommType
	);
}

stock void BSCore_MarkAccountIdClean(int iClient, int iAccountId)
{
	BSCore_ResetResolvedClientState(iClient);
	g_iCoreResolvedAccountId[iClient] = iAccountId;
	g_bCoreSummaryLoaded[iClient] = true;
	BSCore_Debug("No active summary state for %N (%d). Registered as clean.", iClient, iAccountId);
	BSCore_CompleteClientAuthorizationCheck(iClient);
}

stock void BSCore_ApplyFetchedSummaryResult(int iClient, int iAccountId, eBSCoreModuleBit eModuleMask, int iAccessBanId, int iCommBanId, int iSprayBanId, eBSCoreCommType eCommType)
{
	if (eModuleMask == kBSCoreModule_None)
	{
		BSCore_MarkAccountIdClean(iClient, iAccountId);
		return;
	}

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	g_iCoreResolvedAccountId[iClient] = iAccountId;
	g_bCoreSummaryLoaded[iClient] = true;
	g_eCoreResolvedModuleMask[iClient] = eModuleMask;
	g_iCoreResolvedAccessBanId[iClient] = iAccessBanId;
	g_iCoreResolvedCommBanId[iClient] = iCommBanId;
	g_iCoreResolvedSprayBanId[iClient] = iSprayBanId;
	g_eCoreResolvedCommType[iClient] = eCommType;

	BSCore_Debug(
		"Resolved summary for %N: accountid=%d module_mask=%d access_ban_id=%d comm_ban_id=%d spray_ban_id=%d comm_type=%d",
		iClient,
		iAccountId,
		view_as<int>(eModuleMask),
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType)
	);

	BSCore_BeginModuleDetailResolution(iClient);
}

stock bool BSCore_IsCurrentAuthorizationCallback(Database db, int iClient, int iUserId, int iAccountId, int iGeneration, int iDatabaseGeneration)
{
	return (db != null
		&& g_dbCorePrimary != null
		&& SQL_IsSameConnection(db, g_dbCorePrimary)
		&& iDatabaseGeneration == g_iCorePrimaryDatabaseGeneration
		&& iClient > 0
		&& iClient <= MaxClients
		&& GetClientUserId(iClient) == iUserId
		&& (g_eCoreAuthState[iClient] == kBSCoreAuthState_Checking || g_eCoreAuthState[iClient] == kBSCoreAuthState_Unverified)
		&& BSCore_IsClientAuthGenerationCurrent(iClient, iAccountId, iGeneration));
}

stock void BSCore_ReadSummaryContext(any pData, int &iUserId, int &iAccountId, int &iGeneration, int &iDatabaseGeneration)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	iAccountId = pContext.ReadCell();
	iGeneration = pContext.ReadCell();
	iDatabaseGeneration = pContext.ReadCell();
	delete pContext;
}

public Action Timer_BSCoreAuthTimeout(Handle hTimer, DataPack pTimerData)
{
	pTimerData.Reset();
	int iUserId = pTimerData.ReadCell();
	int iAccountId = pTimerData.ReadCell();
	int iGeneration = pTimerData.ReadCell();
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0)
		return Plugin_Stop;

	if (g_hCoreAuthTimer[iClient] == hTimer)
		g_hCoreAuthTimer[iClient] = null;

	if ((g_eCoreAuthState[iClient] != kBSCoreAuthState_Checking && g_eCoreAuthState[iClient] != kBSCoreAuthState_Queued)
		|| g_iCoreAuthGeneration[iClient] != iGeneration
		|| (iAccountId > 0 && g_iCoreAuthAccountId[iClient] != iAccountId))
		return Plugin_Stop;

	BSCore_SQL("Core auth timeout reached for %N; allowing join while retrying. accountid=%d generation=%d module_mask=%d pending_mask=%d", iClient, iAccountId, iGeneration, view_as<int>(g_eCoreResolvedModuleMask[iClient]), view_as<int>(g_eCorePendingDetailMask[iClient]));
	BSCore_ScheduleAuthorizationRetry(iClient, "auth_timeout");
	return Plugin_Stop;
}
