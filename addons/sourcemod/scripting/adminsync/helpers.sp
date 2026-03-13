SnapshotBackend GetSnapshotBackend()
{
	char szBackend[16];
	g_cvBackend.GetString(szBackend, sizeof(szBackend));
	return StrEqual(szBackend, "kv", false) ? Backend_KeyValues : Backend_SQLite;
}

SteamIDToolsProvider eGetSteamIdLookupProvider()
{
	if (!SteamIDTools_IsLibraryAvailable())
		return SteamIDToolsProvider_Unknown;

	char szProvider[16];
	g_cvSteamIdProvider.GetString(szProvider, sizeof(szProvider));
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

void vResetPromptState(int iClient)
{
	g_ePromptState[iClient] = Prompt_None;
	g_iPromptAccountId[iClient] = 0;
	g_iPromptImmunity[iClient] = 0;
	g_iPanelAction[iClient] = 0;
	g_szPromptName[iClient][0] = '\0';
	g_szPromptFlags[iClient][0] = '\0';
	g_szPromptSteamId64[iClient][0] = '\0';
	g_szPromptGroupName[iClient][0] = '\0';
}

bool bIsClientUsable(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

void vAdminSyncDebug(const char[] szFormat, any ...)
{
	vAdminSyncLog(kASDebug_General, "Debug", szFormat, 2);
}

void vAdminSyncSQL(const char[] szFormat, any ...)
{
	vAdminSyncLog(kASDebug_SQL, "SQL", szFormat, 2);
}

void vAdminSyncMenu(const char[] szFormat, any ...)
{
	vAdminSyncLog(kASDebug_Menu, "Menu", szFormat, 2);
}

void vAdminSyncAPI(const char[] szFormat, any ...)
{
	vAdminSyncLog(kASDebug_API, "API", szFormat, 2);
}

void vAdminSyncLog(eAdminSyncDebugMask eMask, const char[] szTag, const char[] szFormat, int iVFormatArg)
{
	if (g_cvDebug == null)
		return;

	if (!(g_cvDebug.IntValue & view_as<int>(eMask)))
		return;

	char szMessage[512];
	VFormat(szMessage, sizeof(szMessage), szFormat, iVFormatArg);
	LogToFileEx(g_szDebugLogPath, "[%s] %s", szTag, szMessage);
}

bool bAccountIdToSteam2(int iAccountId, char[] szBuffer, int iMaxLength)
{
	if (iAccountId <= 0)
		return false;

	Format(szBuffer, iMaxLength, "STEAM_1:%d:%d", iAccountId % 2, iAccountId / 2);
	return true;
}

void vApplyFlagsToAdmin(AdminId idAdmin, const char[] szFlags)
{
	int iLength = strlen(szFlags);
	for (int i = 0; i < iLength; i++)
	{
		AdminFlag eFlag;
		if (FindFlagByChar(szFlags[i], eFlag))
			idAdmin.SetFlag(eFlag, true);
	}
}

void vApplyFlagsToGroup(GroupId idGroup, const char[] szFlags)
{
	int iLength = strlen(szFlags);
	for (int i = 0; i < iLength; i++)
	{
		AdminFlag eFlag;
		if (FindFlagByChar(szFlags[i], eFlag))
			idGroup.SetFlag(eFlag, true);
	}
}
