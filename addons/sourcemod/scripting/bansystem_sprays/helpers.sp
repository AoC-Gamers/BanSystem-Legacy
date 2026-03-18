/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSSprays_LogCategory(eBSSpraysDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szBSSpraysLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSSprays_LogCategoryFormatted(eBSSpraysDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szBSSpraysLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSSprays_Debug(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(kBSSpraysDebug_General)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSSprays_LogCategoryFormatted(kBSSpraysDebug_General, "Debug", szBuffer);
}

stock void BSSprays_SQL(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(kBSSpraysDebug_SQL)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSSprays_LogCategoryFormatted(kBSSpraysDebug_SQL, "SQL", szBuffer);
}

stock void BSSprays_Menu(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(kBSSpraysDebug_Menu)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSSprays_LogCategoryFormatted(kBSSpraysDebug_Menu, "Menu", szBuffer);
}

stock void BSSprays_API(const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysDebugMask, view_as<int>(kBSSpraysDebug_API)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSSprays_LogCategoryFormatted(kBSSpraysDebug_API, "API", szBuffer);
}

stock void BSSprays_PrintAdminConsoleLine(int iAdmin, const char[] szMessage, any ...)
{
	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);

	if (iAdmin > 0)
		PrintToConsole(iAdmin, "%s", szBuffer);
	else
		PrintToServer("%s", szBuffer);
}

stock void BSSprays_PrintAdminConsoleTranslatedLine(int iAdmin, const char[] szFormat, any ...)
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

stock void BSSprays_CReplyToCommandWithSource(int iAdmin, ReplySource eReplySource, const char[] szFormat, any ...)
{
	static char szBuffer[1024];
	if (iAdmin > 0)
		SetGlobalTransTarget(iAdmin);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	BSCReplyToCommandBufferWithSource(iAdmin, eReplySource, szBuffer);
}

stock void BSSprays_NotifyConsolePrinted(int iAdmin, ReplySource eReplySource, const char[] szPhrase)
{
	BSSprays_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", szPhrase);
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

stock void BSSprays_GetSteamIdProviderName(SteamIDToolsProvider eProvider, char[] szBuffer, int iMaxLength)
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

stock bool BSSprays_TryGetSteamIdLookupProvider(int iAdmin, SteamIDToolsProvider &eProvider)
{
	eProvider = SteamIDToolsProvider_Unknown;

	if (!SteamIDTools_IsLibraryAvailable())
	{
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64Unavailable");
		return false;
	}

	char szConfigured[16];
	g_cvBSSpraysSteamIdProvider.GetString(szConfigured, sizeof(szConfigured));
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
		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64Unavailable");
		return false;
	}

	if (SteamIDTools_IsProviderReady(eProvider))
	{
		return true;
	}

	char szProvider[16];
	char szStatus[128];
	BSSprays_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
	if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
	{
		strcopy(szStatus, sizeof(szStatus), "backend unavailable");
	}

	CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64BackendNotReady", szProvider, szStatus);
	return false;
}

stock bool BSSprays_TryResolveInputAccountId(int iAdmin, const char[] szInput, int &iAccountId, int &iTargetClient)
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

	BSCore_RegisterModule(BANSYSTEM_SPRAYS_MODULE_NAME, kBSCoreModule_Sprays);
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Sprays]", "module", "module=sprays action=registered");
	BSSprays_API("Registered sprays module in bansystem_core.");
}

stock bool BSSprays_HasResolvedSprayModule(int iClient)
{
	return ((view_as<int>(BSCore_GetResolvedModuleMask(iClient)) & view_as<int>(kBSCoreModule_Sprays)) != 0);
}

stock bool BSSprays_QueueIdentityLookup(int iAdmin, const char[] szSteamId64, eBSSpraysIdentityAction eAction, int iValue, const char[] szExtra = "", const char[] szContext = "", ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	SteamIDToolsProvider eProvider;
	if (!BSSprays_TryGetSteamIdLookupProvider(iAdmin, eProvider))
		return false;

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		char szProvider[16];
		char szStatus[128];
		BSSprays_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
		if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
		{
			CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64QueueFailed");
			return false;
		}

		CReplyToCommand(iAdmin, "%t", "BSSpraysSteam64QueueFailedStatus", szProvider, szStatus);
		return false;
	}

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eAction));
	pContext.WriteCell(iValue);
	pContext.WriteCell(view_as<int>(eReplySource));
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

stock void BSSprays_FormatConsoleDurationDisplay(int iAdmin, int iDurationMinutes, char[] szBuffer, int iMaxLength)
{
	if (iDurationMinutes <= 0)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSSpraysInfoPermanent", iAdmin);
		return;
	}

	FormatEx(szBuffer, iMaxLength, "%T", "BSSpraysInfoMinutesValue", iAdmin, iDurationMinutes);
}

stock void BSSprays_PrintAdminInfoConsoleCard(int iAdmin, int iAccountId, const char[] szPlayerName, const char[] szSteam2, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, const char[] szExpire)
{
	char szDuration[64];
	BSSprays_FormatConsoleDurationDisplay(iAdmin, iLength, szDuration, sizeof(szDuration));

	BSSprays_PrintAdminConsoleLine(iAdmin, "//============= BanSystem =============\\");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoConsoleTitle", iAdmin);
	BSSprays_PrintAdminConsoleLine(iAdmin, "|");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoConsoleSection", iAdmin);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldPlayer", iAdmin, szPlayerName);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldAccountId", iAdmin, iAccountId);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldSteam2", iAdmin, szSteam2);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldDuration", iAdmin, szDuration);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldReason", iAdmin, szReason[0] != '\0' ? szReason : "-");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldContext", iAdmin, szContext[0] != '\0' ? szContext : "-");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldIssuedBy", iAdmin, szBannedByName[0] != '\0' ? szBannedByName : "Console");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldExpire", iAdmin, szExpire);
	BSSprays_PrintAdminConsoleLine(iAdmin, "//=====================================\\");
}

stock void BSSprays_PrintAdminListConsoleCard(int iAdmin, int iAccountId, const char[] szPlayerName, const char[] szSteam2, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, const char[] szExpire)
{
	char szDuration[64];
	BSSprays_FormatConsoleDurationDisplay(iAdmin, iLength, szDuration, sizeof(szDuration));

	BSSprays_PrintAdminConsoleLine(iAdmin, "//============= BanSystem =============\\");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysListConsoleTitle", iAdmin);
	BSSprays_PrintAdminConsoleLine(iAdmin, "|");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoConsoleSection", iAdmin);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldPlayer", iAdmin, szPlayerName);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldAccountId", iAdmin, iAccountId);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldSteam2", iAdmin, szSteam2);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldDuration", iAdmin, szDuration);
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldReason", iAdmin, szReason[0] != '\0' ? szReason : "-");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldContext", iAdmin, szContext[0] != '\0' ? szContext : "-");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldIssuedBy", iAdmin, szBannedByName[0] != '\0' ? szBannedByName : "Console");
	BSSprays_PrintAdminConsoleTranslatedLine(iAdmin, "%T", "BSSpraysInfoFieldExpire", iAdmin, szExpire);
	BSSprays_PrintAdminConsoleLine(iAdmin, "//=====================================\\");
}

stock bool BSSprays_IsClientSprayBanned(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSSpraysResolvedDetail[iClient].m_bLoaded && g_eBSSpraysResolvedDetail[iClient].m_iBanId > 0;
}

stock void BSSprays_ReadIdentityLookupContext(DataPack pContext, int &iUserId, eBSSpraysIdentityAction &eAction, int &iValue, ReplySource &eReplySource, char[] szExtra, int iExtraMaxLength, char[] szContext, int iContextMaxLength)
{
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eAction = view_as<eBSSpraysIdentityAction>(pContext.ReadCell());
	iValue = pContext.ReadCell();
	eReplySource = view_as<ReplySource>(pContext.ReadCell());
	pContext.ReadString(szExtra, iExtraMaxLength);
	pContext.ReadString(szContext, iContextMaxLength);
}
