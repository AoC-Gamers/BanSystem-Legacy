/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSSprays_LogCategory(eBSSpraysDebugMask eMask, const char[] szTag, const char[] szMessage, int iVFormatArg)
{
	if (g_cvBSSpraysDebugMask == null)
		return;

	if ((g_cvBSSpraysDebugMask.IntValue & view_as<int>(eMask)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, iVFormatArg);
	LogToFileEx(g_szBSSpraysLogPath, "[%s] %s", szTag, szBuffer);
}

stock void BSSprays_Debug(const char[] szMessage, any ...)
{
	BSSprays_LogCategory(kBSSpraysDebug_General, "Debug", szMessage, 2);
}

stock void BSSprays_SQL(const char[] szMessage, any ...)
{
	BSSprays_LogCategory(kBSSpraysDebug_SQL, "SQL", szMessage, 2);
}

stock void BSSprays_Menu(const char[] szMessage, any ...)
{
	BSSprays_LogCategory(kBSSpraysDebug_Menu, "Menu", szMessage, 2);
}

stock void BSSprays_API(const char[] szMessage, any ...)
{
	BSSprays_LogCategory(kBSSpraysDebug_API, "API", szMessage, 2);
}

stock bool BSSprays_CanUseCoreLibrary()
{
	return g_bBSSpraysHasCoreLibrary;
}

stock bool BSSprays_CanUseDatabase()
{
	return (g_dbBSSprays != null && g_bBSSpraysDatabaseReady);
}

stock SteamIDToolsProvider BSSprays_GetSteamIdLookupProvider()
{
	if (!SteamIDTools_IsLibraryAvailable())
		return SteamIDToolsProvider_Unknown;

	char szProvider[16];
	g_cvBSSpraysSteamIdProvider.GetString(szProvider, sizeof(szProvider));
	TrimString(szProvider);

	if (StrEqual(szProvider, "steamworks", false))
	{
		if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks))
			return SteamIDToolsProvider_SteamWorks;
		return SteamIDToolsProvider_Unknown;
	}

	if (StrEqual(szProvider, "system2", false))
	{
		if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
			return SteamIDToolsProvider_System2;
		return SteamIDToolsProvider_Unknown;
	}

	if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks))
		return SteamIDToolsProvider_SteamWorks;

	if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
		return SteamIDToolsProvider_System2;

	return SteamIDToolsProvider_Unknown;
}

stock bool BSSprays_TryResolveInputAccountId(int iAdmin, const char[] szInput, int &iAccountId, int &iTargetClient)
{
	iAccountId = 0;
	iTargetClient = 0;

	SteamIDFormat eFormat = DetectSteamIDFormat(szInput);
	switch (eFormat)
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szInput);
			return (iAccountId > 0);
		}

		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szInput);
			return (iAccountId > 0);
		}

		case STEAMID_FORMAT_STEAMID3:
		{
			iAccountId = SteamID3ToAccountID(szInput);
			return (iAccountId > 0);
		}

		case STEAMID_FORMAT_STEAMID64:
		{
			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || IsFakeClient(iClient))
					continue;

				char szSteamId64[32];
				if (!GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64), true))
					continue;

				if (!StrEqual(szSteamId64, szInput, false))
					continue;

				iTargetClient = iClient;
				iAccountId = GetClientAccountID(iClient);
				return (iAccountId > 0);
			}

			return false;
		}
	}

	int iTarget = FindTarget(iAdmin, szInput, true, false);
	if (iTarget <= 0)
		return false;

	iTargetClient = iTarget;
	iAccountId = GetClientAccountID(iTarget);
	return (iAccountId > 0);
}

stock void BSSprays_GetTargetIdentityData(int iTargetClient, char[] szSteamId64, int iSteamId64MaxLength, char[] szPlayerName, int iPlayerNameMaxLength)
{
	szSteamId64[0] = '\0';
	szPlayerName[0] = '\0';

	if (iTargetClient > 0 && IsClientInGame(iTargetClient))
	{
		GetClientName(iTargetClient, szPlayerName, iPlayerNameMaxLength);
		GetClientAuthId(iTargetClient, AuthId_SteamID64, szSteamId64, iSteamId64MaxLength, true);
		return;
	}

	strcopy(szPlayerName, iPlayerNameMaxLength, "UNKNOWN");
}

stock void BSSprays_GetAdminAuditData(int iAdmin, int &iAdminAccountId, char[] szAdminName, int iAdminNameMaxLength, char[] szAdminSteamId64, int iAdminSteamId64MaxLength)
{
	iAdminAccountId = 0;
	strcopy(szAdminName, iAdminNameMaxLength, "Console");
	szAdminSteamId64[0] = '\0';

	if (iAdmin <= 0 || iAdmin > MaxClients || !IsClientInGame(iAdmin))
		return;

	iAdminAccountId = GetClientAccountID(iAdmin);
	GetClientName(iAdmin, szAdminName, iAdminNameMaxLength);
	GetClientAuthId(iAdmin, AuthId_SteamID64, szAdminSteamId64, iAdminSteamId64MaxLength, true);
}

stock void BSSprays_GetClientIpAddressSafe(int iClient, char[] szIpAddress, int iMaxLength)
{
	strcopy(szIpAddress, iMaxLength, "0.0.0.0");

	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient))
		return;

	GetClientIP(iClient, szIpAddress, iMaxLength, true);
}

stock void BSSprays_TryRegisterCoreModule()
{
	if (!BSSprays_CanUseCoreLibrary())
		return;

	BSCore_RegisterModule(BANSYSTEM_SPRAYS_MODULE_NAME, BANSYSTEM_SPRAYS_MODULE_BIT);
	BSSprays_API("Registered sprays module in bansystem_core.");
}

stock bool BSSprays_QueueIdentityLookup(int iAdmin, const char[] szSteamId64, eBSSpraysIdentityAction eAction, int iValue, const char[] szExtra = "", const char[] szContext = "")
{
	SteamIDToolsProvider eProvider = BSSprays_GetSteamIdLookupProvider();
	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64Unavailable");
		return false;
	}

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64QueueFailed");
		return false;
	}

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eAction));
	pContext.WriteCell(iValue);
	pContext.WriteString(szExtra);
	pContext.WriteString(szContext);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smBSSpraysIdentityRequestContext.SetValue(szRequestId, pContext);
	BSSprays_API("Queued SteamID64 identity lookup. request=%d input=%s action=%d value=%d", iRequestId, szSteamId64, view_as<int>(eAction), iValue);
	CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64Resolving");
	return true;
}

stock void BSSprays_ResetResolvedDetail(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eBSSpraysResolvedDetail[iClient].m_bLoaded = false;
	g_eBSSpraysResolvedDetail[iClient].m_iBanId = 0;
	g_eBSSpraysResolvedDetail[iClient].m_iAccountId = 0;
	g_eBSSpraysResolvedDetail[iClient].m_iLength = 0;
	g_eBSSpraysResolvedDetail[iClient].m_iBannedBy = 0;
	g_eBSSpraysResolvedDetail[iClient].m_szPlayerName[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_szSteamId64[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_szReason[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_szContext[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_szBannedByName[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_szBannedBySteamId64[0] = '\0';
	g_eBSSpraysResolvedDetail[iClient].m_iDateExpireTs = 0;
}

stock void BSSprays_FormatExpireDisplay(int iExpireTs, char[] szBuffer, int iMaxLength)
{
	if (iExpireTs <= 0)
	{
		strcopy(szBuffer, iMaxLength, "<permanent>");
		return;
	}

	FormatTime(szBuffer, iMaxLength, "%Y-%m-%d %H:%M:%S", iExpireTs);
}

stock bool BSSprays_IsClientSprayBanned(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSSpraysResolvedDetail[iClient].m_bLoaded && g_eBSSpraysResolvedDetail[iClient].m_iBanId > 0;
}
