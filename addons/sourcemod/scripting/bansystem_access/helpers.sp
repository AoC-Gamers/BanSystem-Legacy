/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSAccess_LogCategory(eBSAccessDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvBSAccessDebugMask == null)
		return;

	if ((g_cvBSAccessDebugMask.IntValue & view_as<int>(eMask)) == 0)
		return;

	LogToFileEx(g_szBSAccessLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSAccess_LogCategoryFormatted(eBSAccessDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvBSAccessDebugMask == null)
		return;

	if ((g_cvBSAccessDebugMask.IntValue & view_as<int>(eMask)) == 0)
		return;

	LogToFileEx(g_szBSAccessLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSAccess_Debug(const char[] szMessage, any ...)
{
	if (g_cvBSAccessDebugMask == null || (g_cvBSAccessDebugMask.IntValue & view_as<int>(kBSAccessDebug_General)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_General, "Debug", szBuffer);
}

stock void BSAccess_SQL(const char[] szMessage, any ...)
{
	if (g_cvBSAccessDebugMask == null || (g_cvBSAccessDebugMask.IntValue & view_as<int>(kBSAccessDebug_SQL)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_SQL, "SQL", szBuffer);
}

stock void BSAccess_Menu(const char[] szMessage, any ...)
{
	if (g_cvBSAccessDebugMask == null || (g_cvBSAccessDebugMask.IntValue & view_as<int>(kBSAccessDebug_Menu)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_Menu, "Menu", szBuffer);
}

stock void BSAccess_API(const char[] szMessage, any ...)
{
	if (g_cvBSAccessDebugMask == null || (g_cvBSAccessDebugMask.IntValue & view_as<int>(kBSAccessDebug_API)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_API, "API", szBuffer);
}

stock void BSAccess_PrintAdminConsoleLine(int iAdmin, const char[] szMessage, any ...)
{
	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);

	if (iAdmin > 0)
		PrintToConsole(iAdmin, "%s", szBuffer);
	else
		PrintToServer("%s", szBuffer);
}

stock void BSAccess_CReplyToCommandWithSource(int iAdmin, ReplySource eReplySource, const char[] szFormat, any ...)
{
	ReplySource eOldSource = SetCmdReplySource(eReplySource);

	static char szBuffer[1024];
	if (iAdmin > 0)
		SetGlobalTransTarget(iAdmin);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	CReplyToCommand(iAdmin, "%s", szBuffer);
	SetCmdReplySource(eOldSource);
}

stock void BSAccess_NotifyConsolePrinted(int iAdmin, ReplySource eReplySource, const char[] szPhrase)
{
	BSAccess_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", szPhrase);
}

stock bool BSAccess_CanUseCoreLibrary()
{
	return g_bBSAccessHasCoreLibrary;
}

stock bool BSAccess_CanUseDatabase()
{
	return (g_dbBSAccess != null && g_bBSAccessDatabaseReady);
}

stock SteamIDToolsProvider BSAccess_GetSteamIdLookupProvider()
{
	if (!SteamIDTools_IsLibraryAvailable())
		return SteamIDToolsProvider_Unknown;

	char szProvider[16];
	g_cvBSAccessSteamIdProvider.GetString(szProvider, sizeof(szProvider));
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

stock void BSAccess_GetSteamIdProviderName(SteamIDToolsProvider eProvider, char[] szBuffer, int iMaxLength)
{
	switch (eProvider)
	{
		case SteamIDToolsProvider_SteamWorks:
			strcopy(szBuffer, iMaxLength, "steamworks");
		case SteamIDToolsProvider_System2:
			strcopy(szBuffer, iMaxLength, "system2");
		default:
			strcopy(szBuffer, iMaxLength, "unknown");
	}
}

stock bool BSAccess_TryGetSteamIdLookupProvider(int iAdmin, SteamIDToolsProvider &eProvider)
{
	eProvider = SteamIDToolsProvider_Unknown;

	if (!SteamIDTools_IsLibraryAvailable())
	{
		CReplyToCommand(iAdmin, "%t", "BSAccessSteam64Unavailable");
		return false;
	}

	char szConfigured[16];
	g_cvBSAccessSteamIdProvider.GetString(szConfigured, sizeof(szConfigured));
	TrimString(szConfigured);

	if (StrEqual(szConfigured, "steamworks", false))
	{
		eProvider = SteamIDToolsProvider_SteamWorks;
	}
	else if (StrEqual(szConfigured, "system2", false))
	{
		eProvider = SteamIDToolsProvider_System2;
	}
	else
	{
		if (SteamIDTools_IsProviderReady(SteamIDToolsProvider_SteamWorks))
		{
			eProvider = SteamIDToolsProvider_SteamWorks;
			return true;
		}

		if (SteamIDTools_IsProviderReady(SteamIDToolsProvider_System2))
		{
			eProvider = SteamIDToolsProvider_System2;
			return true;
		}

		if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks))
			eProvider = SteamIDToolsProvider_SteamWorks;
		else if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
			eProvider = SteamIDToolsProvider_System2;
	}

	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		CReplyToCommand(iAdmin, "%t", "BSAccessSteam64Unavailable");
		return false;
	}

	if (SteamIDTools_IsProviderReady(eProvider))
	{
		return true;
	}

	char szProvider[16];
	char szStatus[128];
	BSAccess_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
	if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
	{
		strcopy(szStatus, sizeof(szStatus), "backend unavailable");
	}

	CReplyToCommand(iAdmin, "%t", "BSAccessSteam64BackendNotReady", szProvider, szStatus);
	return false;
}

stock bool BSAccess_TryResolveInputAccountId(int iAdmin, const char[] szInput, int &iAccountId, int &iTargetClient)
{
	iAccountId = 0;
	iTargetClient = 0;

	char szNormalized[64];
	strcopy(szNormalized, sizeof(szNormalized), szInput);
	TrimString(szNormalized);
	StripQuotes(szNormalized);

	SteamIDFormat eFormat = DetectSteamIDFormat(szNormalized);
	switch (eFormat)
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szNormalized);
		}

		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szNormalized);
		}

		case STEAMID_FORMAT_STEAMID3:
		{
			iAccountId = SteamID3ToAccountID(szNormalized);
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

				if (!StrEqual(szSteamId64, szNormalized, false))
					continue;

				iTargetClient = iClient;
				iAccountId = GetClientAccountID(iClient);
				return (iAccountId > 0);
			}

			return false;
		}
	}

	if (iAccountId > 0)
	{
		int iResolvedClient = FindClientByAccountID(iAccountId);
		if (iResolvedClient > 0)
			iTargetClient = iResolvedClient;

		return true;
	}

	int iTarget = FindTarget(iAdmin, szNormalized, true, false);
	if (iTarget <= 0)
		return false;

	iTargetClient = iTarget;
	iAccountId = GetClientAccountID(iTarget);
	return (iAccountId > 0);
}

stock void BSAccess_GetTargetIdentityData(int iTargetClient, char[] szSteamId64, int iSteamId64MaxLength, char[] szPlayerName, int iPlayerNameMaxLength)
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

stock void BSAccess_GetAdminAuditData(int iAdmin, int &iAdminAccountId, char[] szAdminName, int iAdminNameMaxLength, char[] szAdminSteamId64, int iAdminSteamId64MaxLength)
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

stock void BSAccess_GetClientIpAddressSafe(int iClient, char[] szIpAddress, int iMaxLength)
{
	strcopy(szIpAddress, iMaxLength, "0.0.0.0");

	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient))
		return;

	GetClientIP(iClient, szIpAddress, iMaxLength, true);
}

stock void BSAccess_TryRegisterCoreModule()
{
	if (!BSAccess_CanUseCoreLibrary())
		return;

	BSCore_RegisterModule(BANSYSTEM_ACCESS_MODULE_NAME, kBSCoreModule_Access);
	BSAccess_API("Registered access module in bansystem_core.");
}

stock bool BSAccess_QueueIdentityLookup(int iAdmin, const char[] szSteamId64, eBSAccessIdentityAction eAction, int iValue, const char[] szReason = "", const char[] szContext = "", ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	SteamIDToolsProvider eProvider;
	if (!BSAccess_TryGetSteamIdLookupProvider(iAdmin, eProvider))
		return false;

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		char szProvider[16];
		char szStatus[128];
		BSAccess_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
		if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
		{
			BSAccess_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSAccessSteam64QueueFailed");
			return false;
		}

		BSAccess_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSAccessSteam64QueueFailedStatus", szProvider, szStatus);
		return false;
	}

	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eAction));
	pContext.WriteCell(iValue);
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteString(szReason);
	pContext.WriteString(szContext);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smBSAccessIdentityRequestContext.SetValue(szRequestId, pContext);
	BSAccess_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSAccessSteam64Resolving");
	return true;
}

stock void BSAccess_ResetResolvedDetail(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eBSAccessResolvedDetail[iClient].m_bLoaded = false;
	g_eBSAccessResolvedDetail[iClient].m_iBanId = 0;
	g_eBSAccessResolvedDetail[iClient].m_iAccountId = 0;
	g_eBSAccessResolvedDetail[iClient].m_iLength = 0;
	g_eBSAccessResolvedDetail[iClient].m_iBannedBy = 0;
	g_eBSAccessResolvedDetail[iClient].m_szPlayerName[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_szSteamId64[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_szReason[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_szContext[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_szBannedByName[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_szBannedBySteamId64[0] = '\0';
	g_eBSAccessResolvedDetail[iClient].m_iDateExpireTs = 0;
}

stock void BSAccess_FormatExpireDisplay(int iExpireTs, char[] szBuffer, int iMaxLength)
{
	if (iExpireTs <= 0)
	{
		strcopy(szBuffer, iMaxLength, "<permanent>");
		return;
	}

	FormatTime(szBuffer, iMaxLength, "%Y-%m-%d %H:%M:%S", iExpireTs);
}
