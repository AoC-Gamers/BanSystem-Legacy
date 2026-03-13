/*****************************************************************
			A U T H   A N D   T R A N S I T I O N
*****************************************************************/

public void OnMapEnd()
{
	g_bMapTransitionActive = true;
}

public void OnMapStart()
{
	g_bMapTransitionActive = true;
}

public void OnClientAuthorized(int iClient, const char[] szAuth)
{
	if(iClient == SERVER_INDEX || !IsClientConnected(iClient) || IsFakeClient(iClient))
		return;

	vResetPlayerPunishmentState(iClient);
	if (g_bMapTransitionActive)
	{
		vQueueClientAuthorizationCheck(iClient);
		return;
	}

	vBeginClientAuthorizationCheck(iClient);
	vHandleClientAuthorization(iClient, szAuth);
}

public void OnClientPutInServer(int iClient)
{
	if (iClient == SERVER_INDEX || IsFakeClient(iClient))
		return;

	vRefreshPlayerCommState(iClient);
}

void vHandleClientAuthorization(int iClient, const char[] szAuth)
{
	int iAccountId;
	iAccountId = GetClientAccountID(iClient);
	if (iAccountId == 0 && !bGetAccountIdFromAuthId(szAuth, iAccountId))
	{
		LogError("[vHandleClientAuthorization] Failed to resolve account id for client %N (%s)", iClient, szAuth);
		vDenyAuthorization(iClient);
		return;
	}

	if (bCanUsePrimaryDatabase() && g_cvLocalCache.BoolValue && bCheckLocalCacheAccountId(iAccountId))
	{
		LogDebug("[vHandleClientAuthorization] Local clean cache hit: %N (%s)", iClient, szAuth);
		vCompleteClientAuthorizationCheck(iClient);
		return;
	}

	if (bCanUsePrimaryDatabase())
	{
		vCheckAuthId(iClient, iAccountId, szAuth);
		return;
	}

	if (bCanUseSQLiteCache())
	{
		vCheckCache(iClient, iAccountId, szAuth);
		return;
	}

	LogDebug("[vHandleClientAuthorization] Queueing auth for %N (%s) because verification backends are not ready yet.", iClient, szAuth);
	g_eAuthState[iClient] = kAuthState_Queued;
}

void vQueueClientAuthorizationCheck(int iClient)
{
	if (!bIsUsableClient(iClient))
		return;

	if (!bIsClientAuthorizationPending(iClient))
		vBeginClientAuthorizationCheck(iClient);

	g_eAuthState[iClient] = kAuthState_Queued;
}

void vProcessQueuedAuthorizationChecks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_eAuthState[i] != kAuthState_Queued)
			continue;

		if (!IsClientConnected(i) || IsFakeClient(i))
		{
			g_eAuthState[i] = kAuthState_Idle;
			continue;
		}

		char szAuthId[MAX_AUTHID_LENGTH];
		if (!GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
			continue;

		int iAccountId = GetClientAccountID(i);
		if (iAccountId == 0 && !bGetAccountIdFromAuthId(szAuthId, iAccountId))
			continue;

		if (g_cvLocalCache.BoolValue && bCheckLocalCacheAccountId(iAccountId))
		{
			LogDebug("[vProcessQueuedAuthorizationChecks] Local clean cache hit while draining queue: %N (%s)", i, szAuthId);
			vCompleteClientAuthorizationCheck(i);
			continue;
		}

		g_eAuthState[i] = kAuthState_Checking;
		vHandleClientAuthorization(i, szAuthId);
	}
}

void vMaybeFinalizeMapTransition()
{
	if (!g_bMapTransitionActive)
		return;

	if (!bCanUsePrimaryDatabase())
		return;

	g_bMapTransitionActive = false;
	LogDebug("[vMaybeFinalizeMapTransition] Map transition complete. Draining auth queue. l4d2_changelevel=%d", g_bHasL4D2ChangeLevel);
	vProcessQueuedAuthorizationChecks();
}

bool bIsClientAuthorizationPending(int iClient)
{
	return (iClient > SERVER_INDEX && iClient <= MaxClients && g_eAuthState[iClient] != kAuthState_Idle);
}

bool bIsClientAuthorizationChecking(int iClient)
{
	return (iClient > SERVER_INDEX && iClient <= MaxClients && g_eAuthState[iClient] == kAuthState_Checking);
}

void vCancelClientAuthorizationTimer(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	if (g_hAuthCheckTimer[iClient] != null)
	{
		delete g_hAuthCheckTimer[iClient];
		g_hAuthCheckTimer[iClient] = null;
	}
}

void vResetClientAuthorizationState(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	vCancelClientAuthorizationTimer(iClient);
	g_eAuthState[iClient] = kAuthState_Idle;
}

void vBeginClientAuthorizationCheck(int iClient)
{
	if (!bIsUsableClient(iClient))
		return;

	float flTimeout = (g_cvAuthCheckTimeout != null) ? g_cvAuthCheckTimeout.FloatValue : 0.0;
	g_eAuthState[iClient] = kAuthState_Checking;
	vCancelClientAuthorizationTimer(iClient);

	if (flTimeout > 0.0)
		g_hAuthCheckTimer[iClient] = CreateTimer(flTimeout, Timer_AuthCheckTimeout, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);

	vRefreshPlayerCommState(iClient);
}

void vCompleteClientAuthorizationCheck(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	vResetClientAuthorizationState(iClient);
	vRefreshPlayerCommState(iClient);
}

Action Timer_AuthCheckTimeout(Handle hTimer, any pData)
{
	int iClient = GetClientOfUserId(view_as<int>(pData));
	if (iClient <= SERVER_INDEX)
		return Plugin_Stop;

	if (g_hAuthCheckTimer[iClient] == hTimer)
		g_hAuthCheckTimer[iClient] = null;

	if (!bIsClientAuthorizationPending(iClient))
		return Plugin_Stop;

	LogError("[Timer_AuthCheckTimeout] Auth check timed out for client %N", iClient);
	vDenyAuthorization(iClient);
	return Plugin_Stop;
}

void vCheckCache(int iClient, int iAccountId, const char[] szAuthId)
{
	if (!bCanUseSQLiteCache())
	{
		vDenyAuthorization(iClient);
		return;
	}

	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_id` FROM `BanCache_Valid` ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE account_id = %d;", iAccountId);

	LogSQL("[vCheckCache] Query: %s", szQuery);

	DataPack pCheckAuthId = pCreateAuthCheckContext(iClient, iAccountId, szAuthId);

	SQL_TQuery(g_dbCache, vCheckCacheCallback, szQuery, pCheckAuthId);
}

void vCheckCacheCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int iClient;
	int iAccountId;
    char szAuthId[MAX_AUTHID_LENGTH];

	int iUserId;
	vReadAuthCheckContext(pData, iUserId, iAccountId, szAuthId, sizeof(szAuthId));

    iClient = GetClientOfUserId(iUserId);

	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}

	if (!bIsClientAuthorizationChecking(iClient))
	{
		LogDebug("[vCheckCacheCallback] Ignoring stale cache callback for %N (%s)", iClient, szAuthId);
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0])
	{
        logErrorSQL(dbDataBase, szError, "vCheckCacheCallback");
		vDisableSQLiteCache("vCheckCacheCallback");
		delete rsResult;
		if (bCanUsePrimaryDatabase())
			vDenyAuthorization(iClient);
		else
			LogDebug("[vCheckCacheCallback] Keeping auth queued for %N (%s) after SQLite error because MySQL is not ready yet.", iClient, szAuthId);
        return;
    }

    if (!SQL_FetchRow(rsResult))
    {
        LogDebug("[vCheckCacheCallback] SQLite auth cache miss for client: %N (%s)", iClient, szAuthId);
        vResetPlayerPunishmentState(iClient);
		delete rsResult;
		if (bCanUsePrimaryDatabase())
			vDenyAuthorization(iClient);
		else
			LogDebug("[vCheckCacheCallback] Keeping auth queued for %N (%s) after SQLite miss while MySQL is still unavailable.", iClient, szAuthId);
        return;
    }

	int iResult = SQL_FetchInt(rsResult, 0);
	int iCacheResult = IntAbs(iResult);
	LogSQL("[vCheckCacheCallback] Cache result for client %N (%s): raw=%d normalized=%d", iClient, szAuthId, iResult, iCacheResult);

	switch (iCacheResult)
	{
		case 1:
		{
			vCompleteClientAuthorizationCheck(iClient);
			vAttemptAccess(iClient, iAccountId, szAuthId);
			KickClient(iClient, "%t", "BlockAccessPerm");
		}
		case 2,3,4:
		{
			eTypeComms eComms = view_as<eTypeComms>(iCacheResult - 1);

			char szComms[64];
			char szDate[128] = "[SQL Error: Field is Null]";
			vFormatCommTypeDisplay(iClient, eComms, szComms, sizeof(szComms));

			vSetPlayerCommPunishmentState(iClient, eComms, true);
			vCompleteClientAuthorizationCheck(iClient);
			Format(szDate, sizeof(szDate), "%T", "Permanent", iClient);

			DataPack pAnnouncer = pCreateCommAnnouncementContext(iUserId, szComms, szDate);
			CreateDataTimer(10.0, AnnouncerCommTimer, pAnnouncer, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		}
		default:
		{
			vResetPlayerPunishmentState(iClient);
			LogDebug("[vCheckCacheCallback] Invalid SQLite auth cache result for client: %N (%s)", iClient, szAuthId);
			if (bCanUsePrimaryDatabase())
				vDenyAuthorization(iClient);
			else
				LogDebug("[vCheckCacheCallback] Keeping auth queued for %N (%s) after invalid SQLite cache result while MySQL is still unavailable.", iClient, szAuthId);
		}
	}

	delete rsResult;
}

void vCheckAuthId(int iClient, int iAccountId, const char[] szAuthId)
{
	if (!bCanUsePrimaryDatabase())
	{
		LogDebug("[vCheckAuthId] MySQL not ready for %N (%s); using queued auth flow.", iClient, szAuthId);
		if (bCanUseSQLiteCache())
			vCheckCache(iClient, iAccountId, szAuthId);
		else
			vDenyAuthorization(iClient);
		return;
	}

	DataPack pCheckAuthId = pCreateAuthCheckContext(iClient, iAccountId, szAuthId);

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "CALL GetCheckAuthId(%d);", iAccountId);

	LogSQL("[vCheckAuthId] Query: %s", szQuery);

	SQL_TQuery(g_dbDatabase, vCheckAuthIdCallback, szQuery, pCheckAuthId);
}

void vCheckAuthIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];

	int
		iUserId,
		iClient,
		iAccountId;

	vReadAuthCheckContext(pData, iUserId, iAccountId, szAuthId, sizeof(szAuthId));
	iClient = GetClientOfUserId(iUserId);

	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}

	if (!bIsClientAuthorizationChecking(iClient))
	{
		LogDebug("[vCheckAuthIdCallback] Ignoring stale auth callback for %N (%s)", iClient, szAuthId);
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vCheckAuthIdCallback");
		delete rsResult;
		if (bCanUseSQLiteCache())
			vCheckCache(iClient, iAccountId, szAuthId);
		else
			vDenyAuthorization(iClient);
		return;
	}

	if (!SQL_FetchRow(rsResult))
	{
		LogError("[vCheckAuthIdCallback] Empty result for auth id %s", szAuthId);
		delete rsResult;
		if (bCanUseSQLiteCache())
			vCheckCache(iClient, iAccountId, szAuthId);
		else
			vDenyAuthorization(iClient);
		return;
	}

	int iResult = SQL_FetchInt(rsResult, 0);
	bool bPerm = (iResult < 0);

	LogSQL("[vCheckAuthIdCallback] iResult: %d", iResult);

	if (!bIsValidAuthCheckResult(iResult))
	{
		LogError("[vCheckAuthIdCallback] Invalid auth result %d for %s", iResult, szAuthId);
		delete rsResult;
		if (bCanUseSQLiteCache())
			vCheckCache(iClient, iAccountId, szAuthId);
		else
			vDenyAuthorization(iClient);
		return;
	}
	
	if (iResult == 0)
	{
		vResetPlayerPunishmentState(iClient);
		bRegLocalCacheAccountId(iAccountId);
		vCompleteClientAuthorizationCheck(iClient);
	}
	else if (iResult == -1 || iResult == 1)
	{
		vCompleteClientAuthorizationCheck(iClient);
		vAttemptAccess(iClient, iAccountId, szAuthId);
		
		if (bPerm)
		{
			KickClient(iClient, "%t", "BlockAccessPerm");
			bRegisterCacheAccountId(iAccountId, IntAbs(iResult));
		}
		else
		{
			char szDate[64];
			if (SQL_IsFieldNull(rsResult, 1))
				KickClient(iClient, "%t", "BlockAccessTempNoDate");
			else
			{
				SQL_FetchString(rsResult, 1, szDate, sizeof(szDate));
				KickClient(iClient, "%t", "BlockAccessTemp", szDate);
			}
		}
	}
	else
	{
		eTypeComms eComms = view_as<eTypeComms>(IntAbs(iResult) - 1);
		char szComms[64];
		char szDate[128] = "[SQL Error: Field is Null]";
		vFormatCommTypeDisplay(iClient, eComms, szComms, sizeof(szComms));
		
		vSetPlayerCommPunishmentState(iClient, eComms, bPerm);
		vCompleteClientAuthorizationCheck(iClient);
		if (!bPerm)
		{
			if (SQL_IsFieldNull(rsResult, 1))
				logErrorSQL(dbDataBase, szError, "vCheckAuthIdCallback");
			else
			{
				SQL_FetchString(rsResult, 1, szDate, sizeof(szDate));
				vScheduleCommExpireByDate(iClient, szDate);
			}
		}
		else
		{
			Format(szDate, sizeof(szDate), "%T", "Permanent", iClient);
			bRegisterCacheAccountId(iAccountId, IntAbs(iResult));
		}
		
		DataPack pAnnouncer = pCreateCommAnnouncementContext(iUserId, szComms, szDate);
		CreateDataTimer(10.0, AnnouncerCommTimer, pAnnouncer, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
	}

	delete rsResult;
}
