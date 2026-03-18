/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSComm_LogCategory(eBSCommDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvBSCommDebugMask == null)
		return;

	if ((g_cvBSCommDebugMask.IntValue & view_as<int>(eMask)) == 0)
		return;

	BSLogToFileEx(g_szBSCommLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSComm_LogCategoryFormatted(eBSCommDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvBSCommDebugMask == null)
		return;

	if ((g_cvBSCommDebugMask.IntValue & view_as<int>(eMask)) == 0)
		return;

	BSLogToFileEx(g_szBSCommLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSComm_Debug(const char[] szMessage, any ...)
{
	if (g_cvBSCommDebugMask == null || (g_cvBSCommDebugMask.IntValue & view_as<int>(kBSCommDebug_General)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSComm_LogCategoryFormatted(kBSCommDebug_General, "Debug", szBuffer);
}

stock void BSComm_SQL(const char[] szMessage, any ...)
{
	if (g_cvBSCommDebugMask == null || (g_cvBSCommDebugMask.IntValue & view_as<int>(kBSCommDebug_SQL)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSComm_LogCategoryFormatted(kBSCommDebug_SQL, "SQL", szBuffer);
}

stock void BSComm_Menu(const char[] szMessage, any ...)
{
	if (g_cvBSCommDebugMask == null || (g_cvBSCommDebugMask.IntValue & view_as<int>(kBSCommDebug_Menu)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSComm_LogCategoryFormatted(kBSCommDebug_Menu, "Menu", szBuffer);
}

stock void BSComm_API(const char[] szMessage, any ...)
{
	if (g_cvBSCommDebugMask == null || (g_cvBSCommDebugMask.IntValue & view_as<int>(kBSCommDebug_API)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSComm_LogCategoryFormatted(kBSCommDebug_API, "API", szBuffer);
}

stock void BSComm_PrintAdminConsoleLine(int iAdmin, const char[] szMessage, any ...)
{
	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);

	if (iAdmin > 0)
		PrintToConsole(iAdmin, "%s", szBuffer);
	else
		PrintToServer("%s", szBuffer);
}

stock void BSComm_CReplyToCommandWithSource(int iAdmin, ReplySource eReplySource, const char[] szFormat, any ...)
{
	static char szBuffer[1024];
	if (iAdmin > 0)
		SetGlobalTransTarget(iAdmin);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	BSCReplyToCommandBufferWithSource(iAdmin, eReplySource, szBuffer);
}

stock void BSComm_NotifyConsolePrinted(int iAdmin, ReplySource eReplySource, const char[] szPhrase)
{
	BSComm_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", szPhrase);
}

stock bool BSComm_CanUseCoreLibrary()
{
	return g_bBSCommHasCoreLibrary;
}

stock bool BSComm_CanUseDatabase()
{
	return (g_dbBSComm != null && g_bBSCommDatabaseReady);
}

stock bool BSComm_HasResolvedCommunicationModule(int iClient)
{
	return ((BSCore_GetResolvedModuleMask(iClient) & kBSCoreModule_Communication) != kBSCoreModule_None);
}

stock SteamIDToolsProvider BSComm_GetSteamIdLookupProvider()
{
	if (!SteamIDTools_IsLibraryAvailable())
		return SteamIDToolsProvider_Unknown;

	char szProvider[16];
	g_cvBSCommSteamIdProvider.GetString(szProvider, sizeof(szProvider));
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

stock void BSComm_GetSteamIdProviderName(SteamIDToolsProvider eProvider, char[] szBuffer, int iMaxLength)
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

stock bool BSComm_TryGetSteamIdLookupProvider(int iAdmin, SteamIDToolsProvider &eProvider)
{
	eProvider = SteamIDToolsProvider_Unknown;
	BSComm_Debug("SteamID lookup provider selection started. admin=%d library_available=%d", iAdmin, SteamIDTools_IsLibraryAvailable() ? 1 : 0);

	if (!SteamIDTools_IsLibraryAvailable())
	{
		BSComm_Debug("SteamID lookup provider selection failed: SteamIDTools library unavailable.");
		CReplyToCommand(iAdmin, "%t", "BSCommSteam64Unavailable");
		return false;
	}

	char szConfigured[16];
	g_cvBSCommSteamIdProvider.GetString(szConfigured, sizeof(szConfigured));
	TrimString(szConfigured);
	BSComm_Debug("SteamID lookup provider config=%s steamworks_available=%d steamworks_ready=%d system2_available=%d system2_ready=%d",
		szConfigured,
		SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks) ? 1 : 0,
		SteamIDTools_IsProviderReady(SteamIDToolsProvider_SteamWorks) ? 1 : 0,
		SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2) ? 1 : 0,
		SteamIDTools_IsProviderReady(SteamIDToolsProvider_System2) ? 1 : 0);

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
		BSComm_Debug("SteamID lookup provider selection failed: no provider available.");
		CReplyToCommand(iAdmin, "%t", "BSCommSteam64Unavailable");
		return false;
	}

	if (SteamIDTools_IsProviderReady(eProvider))
	{
		BSComm_Debug("SteamID lookup provider selected successfully. provider=%d", view_as<int>(eProvider));
		return true;
	}

	char szProvider[16];
	char szStatus[128];
	BSComm_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
	if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
	{
		strcopy(szStatus, sizeof(szStatus), "backend unavailable");
	}
	BSComm_Debug("SteamID lookup provider selected but not ready. provider=%d status=%s", view_as<int>(eProvider), szStatus);

	CReplyToCommand(iAdmin, "%t", "BSCommSteam64BackendNotReady", szProvider, szStatus);
	return false;
}

stock bool BSComm_TryResolveInputAccountId(int iAdmin, const char[] szInput, int &iAccountId, int &iTargetClient)
{
	iAccountId = 0;
	iTargetClient = 0;

	char szNormalized[64];
	strcopy(szNormalized, sizeof(szNormalized), szInput);
	TrimString(szNormalized);
	StripQuotes(szNormalized);
	BSComm_Debug(
		"TryResolveInputAccountId start admin=%d input=%s normalized=%s is_valid_sid64=%d detected_format=%d",
		iAdmin,
		szInput,
		szNormalized,
		IsValidSteamID64(szNormalized) ? 1 : 0,
		view_as<int>(DetectSteamIDFormat(szNormalized))
	);

	if (IsValidSteamID64(szNormalized))
	{
		BSComm_Debug("TryResolveInputAccountId detected exact SteamID64 input=%s; searching connected clients only", szNormalized);
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
			BSComm_Debug("TryResolveInputAccountId matched connected SteamID64 input=%s client=%d accountid=%d", szNormalized, iTargetClient, iAccountId);
			return (iAccountId > 0);
		}

		BSComm_Debug("TryResolveInputAccountId found no connected match for SteamID64 input=%s", szNormalized);
		return false;
	}

	SteamIDFormat eFormat = DetectSteamIDFormat(szNormalized);
	BSComm_Debug("TryResolveInputAccountId continuing with non-SteamID64 format=%d input=%s", view_as<int>(eFormat), szNormalized);
	switch (eFormat)
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szNormalized);
			BSComm_Debug("TryResolveInputAccountId parsed accountid=%d from input=%s", iAccountId, szNormalized);
		}

		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szNormalized);
			BSComm_Debug("TryResolveInputAccountId converted SteamID2 input=%s to accountid=%d", szNormalized, iAccountId);
		}

		case STEAMID_FORMAT_STEAMID3:
		{
			iAccountId = SteamID3ToAccountID(szNormalized);
			BSComm_Debug("TryResolveInputAccountId converted SteamID3 input=%s to accountid=%d", szNormalized, iAccountId);
		}

		case STEAMID_FORMAT_STEAMID64:
		{
			BSComm_Debug("TryResolveInputAccountId reached SteamID64 format switch path for input=%s; searching connected clients only", szNormalized);
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
				BSComm_Debug("TryResolveInputAccountId matched SteamID64 switch path input=%s client=%d accountid=%d", szNormalized, iTargetClient, iAccountId);
				return (iAccountId > 0);
			}

			BSComm_Debug("TryResolveInputAccountId found no connected match in SteamID64 switch path for input=%s", szNormalized);
			return false;
		}
	}

	if (iAccountId > 0)
	{
		int iResolvedClient = FindClientByAccountID(iAccountId);
		if (iResolvedClient > 0)
			iTargetClient = iResolvedClient;
		BSComm_Debug("TryResolveInputAccountId resolved input=%s to accountid=%d target=%d without FindTarget", szNormalized, iAccountId, iTargetClient);

		return true;
	}

	BSComm_Debug("TryResolveInputAccountId falling back to FindTarget for input=%s admin=%d", szNormalized, iAdmin);
	int iTarget = FindTarget(iAdmin, szNormalized, true, false);
	if (iTarget <= 0)
	{
		BSComm_Debug("TryResolveInputAccountId FindTarget failed for input=%s admin=%d", szNormalized, iAdmin);
		return false;
	}

	iTargetClient = iTarget;
	iAccountId = GetClientAccountID(iTarget);
	BSComm_Debug("TryResolveInputAccountId FindTarget resolved input=%s target=%d accountid=%d", szNormalized, iTargetClient, iAccountId);
	return (iAccountId > 0);
}

stock void BSComm_GetTargetIdentityData(int iTargetClient, char[] szSteamId64, int iSteamId64MaxLength, char[] szPlayerName, int iPlayerNameMaxLength)
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

stock void BSComm_GetAdminAuditData(int iAdmin, int &iAdminAccountId, char[] szAdminName, int iAdminNameMaxLength, char[] szAdminSteamId64, int iAdminSteamId64MaxLength)
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

stock void BSComm_GetClientIpAddressSafe(int iClient, char[] szIpAddress, int iMaxLength)
{
	strcopy(szIpAddress, iMaxLength, "0.0.0.0");

	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient))
		return;

	GetClientIP(iClient, szIpAddress, iMaxLength, true);
}

stock bool BSComm_IsSupportedCommType(eBSCommType eCommType)
{
	return (eCommType == kBSCommType_Mic || eCommType == kBSCommType_Chat || eCommType == kBSCommType_All);
}

stock bool BSComm_ParseCommTypeString(const char[] szInput, eBSCommType &eCommType)
{
	if (StrEqual(szInput, "mic", false))
	{
		eCommType = kBSCommType_Mic;
		return true;
	}

	if (StrEqual(szInput, "chat", false))
	{
		eCommType = kBSCommType_Chat;
		return true;
	}

	if (StrEqual(szInput, "all", false))
	{
		eCommType = kBSCommType_All;
		return true;
	}

	eCommType = kBSCommType_None;
	return false;
}

stock void BSComm_GetCommTypeLabel(eBSCommType eCommType, char[] szBuffer, int iMaxLength)
{
	switch (eCommType)
	{
		case kBSCommType_Mic:
			strcopy(szBuffer, iMaxLength, "mic");
		case kBSCommType_Chat:
			strcopy(szBuffer, iMaxLength, "chat");
		case kBSCommType_All:
			strcopy(szBuffer, iMaxLength, "all");
		default:
			strcopy(szBuffer, iMaxLength, "none");
	}
}

stock void BSComm_TryRegisterCoreModule()
{
	if (!BSComm_CanUseCoreLibrary())
		return;

	BSCore_RegisterModule(BANSYSTEM_COMM_MODULE_NAME, kBSCoreModule_Communication);
	BSComm_ReconcileAllCommStatesFromCore();
	BSComm_API("Registered communication module in bansystem_core.");
}

stock bool BSComm_QueueIdentityLookup(int iAdmin, const char[] szSteamId64, eBSCommIdentityAction eAction, int iValue, eBSCommType eCommType = kBSCommType_None, const char[] szExtra = "", const char[] szContext = "", ReplySource eReplySource = SM_REPLY_TO_CONSOLE)
{
	SteamIDToolsProvider eProvider;
	if (!BSComm_TryGetSteamIdLookupProvider(iAdmin, eProvider))
	{
		BSComm_Debug("QueueIdentityLookup aborted for input=%s action=%d because provider selection failed", szSteamId64, view_as<int>(eAction));
		return false;
	}

	BSComm_Debug("QueueIdentityLookup requesting conversion input=%s action=%d provider=%d value=%d comm_type=%d", szSteamId64, view_as<int>(eAction), view_as<int>(eProvider), iValue, view_as<int>(eCommType));
	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toAID, szSteamId64);
	if (iRequestId <= 0)
	{
		char szProvider[16];
		char szStatus[128];
		BSComm_GetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
		if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
		{
			BSComm_Debug("QueueIdentityLookup request creation failed for input=%s provider=%d without backend status", szSteamId64, view_as<int>(eProvider));
			BSComm_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSCommSteam64QueueFailed");
			return false;
		}

		BSComm_Debug("QueueIdentityLookup request creation failed for input=%s provider=%d status=%s", szSteamId64, view_as<int>(eProvider), szStatus);
		BSComm_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSCommSteam64QueueFailedStatus", szProvider, szStatus);
		return false;
	}

	DataPack pContext = new DataPack();
	pContext.WriteCell(BSGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(view_as<int>(eAction));
	pContext.WriteCell(iValue);
	pContext.WriteCell(view_as<int>(eCommType));
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteString(szExtra);
	pContext.WriteString(szContext);

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smBSCommIdentityRequestContext.SetValue(szRequestId, pContext);
	BSComm_Debug("QueueIdentityLookup stored request context request=%d input=%s action=%d admin_userid=%d", iRequestId, szSteamId64, view_as<int>(eAction), BSGetCommandIssuerUserId(iAdmin));
	BSComm_API("Queued SteamID64 identity lookup. request=%d input=%s action=%d value=%d comm_type=%d", iRequestId, szSteamId64, view_as<int>(eAction), iValue, view_as<int>(eCommType));
	BSComm_CReplyToCommandWithSource(iAdmin, eReplySource, "%t", "BSCommSteam64Resolving");
	return true;
}

stock void BSComm_ResetResolvedDetail(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eBSCommResolvedDetail[iClient].m_bLoaded = false;
	g_eBSCommResolvedDetail[iClient].m_iBanId = 0;
	g_eBSCommResolvedDetail[iClient].m_iAccountId = 0;
	g_eBSCommResolvedDetail[iClient].m_iLength = 0;
	g_eBSCommResolvedDetail[iClient].m_iBannedBy = 0;
	g_eBSCommResolvedDetail[iClient].m_eCommType = kBSCommType_None;
	g_eBSCommResolvedDetail[iClient].m_szPlayerName[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_szSteamId64[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_szReason[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_szContext[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_szBannedByName[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_szBannedBySteamId64[0] = '\0';
	g_eBSCommResolvedDetail[iClient].m_iDateExpireTs = 0;
}

stock void BSComm_FormatExpireDisplay(int iExpireTs, char[] szBuffer, int iMaxLength)
{
	if (iExpireTs <= 0)
	{
		strcopy(szBuffer, iMaxLength, "<permanent>");
		return;
	}

	FormatTime(szBuffer, iMaxLength, "%Y-%m-%d %H:%M:%S", iExpireTs);
}
