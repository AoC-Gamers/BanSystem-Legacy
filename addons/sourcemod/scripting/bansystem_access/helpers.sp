/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSAccess_LogCategory(eBSAccessDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szBSAccessLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSAccess_LogCategoryFormatted(eBSAccessDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szBSAccessLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSAccess_Debug(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(kBSAccessDebug_General)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_General, "Debug", szBuffer);
}

stock void BSAccess_SQL(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(kBSAccessDebug_SQL)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_SQL, "SQL", szBuffer);
}

stock void BSAccess_Menu(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(kBSAccessDebug_Menu)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSAccess_LogCategoryFormatted(kBSAccessDebug_Menu, "Menu", szBuffer);
}

stock void BSAccess_API(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAccessDebugMask, view_as<int>(kBSAccessDebug_API)))
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

stock void BSAccess_PrintAdminConsoleTranslatedLine(int iAdmin, const char[] szFormat, any ...)
{
	static char szBuffer[1024];
	if (iAdmin > 0)
		SetGlobalTransTarget(iAdmin);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	if (iAdmin > 0)
		PrintToConsole(iAdmin, "%s", szBuffer);
	else
		PrintToServer("%s", szBuffer);
}

stock void BSAccess_PrintClientConsoleLine(int iClient, const char[] szFormat, any ...)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	static char szBuffer[512];
	if (iClient > 0)
		SetGlobalTransTarget(iClient);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	PrintToConsole(iClient, "%s", szBuffer);
}

stock void BSAccess_PrintClientConsoleFrameTop(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	PrintToConsole(iClient, "//============= BanSystem =============\\");
}

stock void BSAccess_PrintClientConsoleFrameBottom(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	PrintToConsole(iClient, "//=====================================\\");
}

stock void BSAccess_PrintClientConsoleField(int iClient, const char[] szPhrase, const char[] szValue)
{
	BSAccess_PrintClientConsoleLine(iClient, "%T", szPhrase, iClient, szValue);
}

stock void BSAccess_CReplyToCommandWithSource(int iAdmin, ReplySource eReplySource, const char[] szFormat, any ...)
{
	static char szBuffer[1024];
	if (iAdmin > 0)
		SetGlobalTransTarget(iAdmin);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	BSCReplyToCommandBufferWithSource(iAdmin, eReplySource, szBuffer);
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

	if (IsValidSteamID64(szNormalized))
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
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "module", "module=access action=registered");
	BSAccess_API("Registered access module in bansystem_core.");
}

stock bool BSAccess_HasResolvedAccessModule(int iClient)
{
	return ((view_as<int>(BSCore_GetResolvedModuleMask(iClient)) & view_as<int>(kBSCoreModule_Access)) != 0);
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
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
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

stock void BSAccess_FillResolvedDetailFromRow(int iClient, int iBanId, DBResultSet rsResult)
{
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
}

stock void BSAccess_ReadIdentityLookupContext(DataPack pContext, int &iUserId, eBSAccessIdentityAction &eAction, int &iValue, ReplySource &eReplySource, char[] szReason, int iReasonMaxLength, char[] szContext, int iContextMaxLength)
{
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eAction = view_as<eBSAccessIdentityAction>(pContext.ReadCell());
	iValue = pContext.ReadCell();
	eReplySource = view_as<ReplySource>(pContext.ReadCell());
	pContext.ReadString(szReason, iReasonMaxLength);
	pContext.ReadString(szContext, iContextMaxLength);
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

stock void BSAccess_FormatConsoleExpireDisplay(int iClient, int iExpireTs, char[] szBuffer, int iMaxLength)
{
	if (iExpireTs <= 0)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAccessConsolePermanent", iClient);
		return;
	}

	FormatTime(szBuffer, iMaxLength, "%Y-%m-%d %H:%M:%S", iExpireTs);
}

stock void BSAccess_FormatConsoleDurationDisplay(int iClient, int iDurationMinutes, char[] szBuffer, int iMaxLength)
{
	if (iDurationMinutes <= 0)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAccessConsolePermanent", iClient);
		return;
	}

	FormatEx(szBuffer, iMaxLength, "%T", "BSAccessConsoleDurationMinutesValue", iClient, iDurationMinutes);
}

stock void BSAccess_PrintClientBanConsoleCard(int iClient, int iDurationMinutes, const char[] szReason, const char[] szContext, const char[] szAdminName, int iExpireTs)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	char szDuration[64];
	char szExpire[64];
	BSAccess_FormatConsoleDurationDisplay(iClient, iDurationMinutes, szDuration, sizeof(szDuration));
	BSAccess_FormatConsoleExpireDisplay(iClient, iExpireTs, szExpire, sizeof(szExpire));

	BSAccess_PrintClientConsoleFrameTop(iClient);
	BSAccess_PrintClientConsoleLine(iClient, "%T", "BSAccessConsoleTitle", iClient);
	PrintToConsole(iClient, "|");
	BSAccess_PrintClientConsoleLine(iClient, "%T", "BSAccessConsoleSection", iClient);
	BSAccess_PrintClientConsoleField(iClient, "BSAccessConsoleFieldDuration", szDuration);
	BSAccess_PrintClientConsoleField(iClient, "BSAccessConsoleFieldReason", szReason[0] != '\0' ? szReason : "-");
	BSAccess_PrintClientConsoleField(iClient, "BSAccessConsoleFieldContext", szContext[0] != '\0' ? szContext : "-");
	BSAccess_PrintClientConsoleField(iClient, "BSAccessConsoleFieldAdmin", szAdminName[0] != '\0' ? szAdminName : "Console");
	BSAccess_PrintClientConsoleField(iClient, "BSAccessConsoleFieldExpire", szExpire);
	BSAccess_PrintClientConsoleFrameBottom(iClient);
}

stock void BSAccess_PrintAdminInfoConsoleCard(int iAdmin, int iAccountId, const char[] szPlayerName, const char[] szSteam2, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, const char[] szExpire)
{
	char szDuration[64];
	BSAccess_FormatConsoleDurationDisplay(iAdmin, iLength, szDuration, sizeof(szDuration));

	BSAccess_PrintAdminConsoleLine(iAdmin, "//============= BanSystem =============\\");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoConsoleTitle", iAdmin);
	BSAccess_PrintAdminConsoleLine(iAdmin, "|");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoConsoleSection", iAdmin);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldPlayer", iAdmin, szPlayerName);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldAccountId", iAdmin, iAccountId);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldSteam2", iAdmin, szSteam2);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldDuration", iAdmin, szDuration);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldReason", iAdmin, szReason[0] != '\0' ? szReason : "-");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldContext", iAdmin, szContext[0] != '\0' ? szContext : "-");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldAdmin", iAdmin, szBannedByName[0] != '\0' ? szBannedByName : "Console");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldExpire", iAdmin, szExpire);
	BSAccess_PrintAdminConsoleLine(iAdmin, "//=====================================\\");
}

stock void BSAccess_PrintAdminListConsoleCard(int iAdmin, int iAccountId, const char[] szPlayerName, const char[] szSteam2, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, const char[] szExpire)
{
	char szDuration[64];
	BSAccess_FormatConsoleDurationDisplay(iAdmin, iLength, szDuration, sizeof(szDuration));

	BSAccess_PrintAdminConsoleLine(iAdmin, "//============= BanSystem =============\\");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessListConsoleTitle", iAdmin);
	BSAccess_PrintAdminConsoleLine(iAdmin, "|");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoConsoleSection", iAdmin);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldPlayer", iAdmin, szPlayerName);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldAccountId", iAdmin, iAccountId);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessInfoFieldSteam2", iAdmin, szSteam2);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldDuration", iAdmin, szDuration);
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldReason", iAdmin, szReason[0] != '\0' ? szReason : "-");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldContext", iAdmin, szContext[0] != '\0' ? szContext : "-");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldAdmin", iAdmin, szBannedByName[0] != '\0' ? szBannedByName : "Console");
	BSAccess_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSAccessConsoleFieldExpire", iAdmin, szExpire);
	BSAccess_PrintAdminConsoleLine(iAdmin, "//=====================================\\");
}
