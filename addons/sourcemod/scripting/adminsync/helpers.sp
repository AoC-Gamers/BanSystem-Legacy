SnapshotBackend GetSnapshotBackend()
{
	char szBackend[16];
	g_cvBackend.GetString(szBackend, sizeof(szBackend));
	return StrEqual(szBackend, "kv", false) ? Backend_KeyValues : Backend_SQLite;
}

bool bUseSQLiteSnapshotBackend()
{
	return (GetSnapshotBackend() == Backend_SQLite);
}

void vGetSteamIdProviderName(SteamIDToolsProvider eProvider, char[] szBuffer, int iMaxLength)
{
	switch (eProvider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			strcopy(szBuffer, iMaxLength, "steamworks");
		}
		case SteamIDToolsProvider_System2:
		{
			strcopy(szBuffer, iMaxLength, "system2");
		}
		default:
		{
			strcopy(szBuffer, iMaxLength, "unknown");
		}
	}
}

void vAdminSyncCReplyToCommandWithSource(int iClient, ReplySource eReplySource, const char[] szFormat, any ...)
{
	ReplySource eOldSource = SetCmdReplySource(eReplySource);

	static char szBuffer[1024];
	if (iClient > 0)
		SetGlobalTransTarget(iClient);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	CReplyToCommand(iClient, "%s", szBuffer);
	SetCmdReplySource(eOldSource);
}

bool bTryGetSteamIdLookupProvider(int iClient, SteamIDToolsProvider &eProvider)
{
	eProvider = SteamIDToolsProvider_Unknown;

	if (!SteamIDTools_IsLibraryAvailable())
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64Unavailable");
		return false;
	}

	char szConfigured[16];
	g_cvSteamIdProvider.GetString(szConfigured, sizeof(szConfigured));
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
		{
			eProvider = SteamIDToolsProvider_SteamWorks;
		}
		else if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
		{
			eProvider = SteamIDToolsProvider_System2;
		}
	}

	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64Unavailable");
		return false;
	}

	if (SteamIDTools_IsProviderReady(eProvider))
	{
		return true;
	}

	char szProvider[16];
	char szStatus[128];
	vGetSteamIdProviderName(eProvider, szProvider, sizeof(szProvider));
	if (!SteamIDTools_GetBackendStatusMessage(eProvider, szStatus, sizeof(szStatus)) || szStatus[0] == '\0')
	{
		strcopy(szStatus, sizeof(szStatus), "backend unavailable");
	}

	CReplyToCommand(iClient, "%t", "BSAdminSyncSteam64BackendNotReady", szProvider, szStatus);
	return false;
}

bool bTryGetSteamIdLookupProviderSilent(SteamIDToolsProvider &eProvider)
{
	eProvider = SteamIDToolsProvider_Unknown;

	if (!SteamIDTools_IsLibraryAvailable())
	{
		return false;
	}

	char szConfigured[16];
	g_cvSteamIdProvider.GetString(szConfigured, sizeof(szConfigured));
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

		return false;
	}

	return SteamIDTools_IsProviderReady(eProvider);
}

void vNormalizeAdminSyncText(const char[] szInput, char[] szOutput, int iMaxLength)
{
	strcopy(szOutput, iMaxLength, szInput);
	TrimString(szOutput);
	StripQuotes(szOutput);
}

bool bAdminSyncHasText(const char[] szInput)
{
	char szNormalized[256];
	vNormalizeAdminSyncText(szInput, szNormalized, sizeof(szNormalized));
	return (szNormalized[0] != '\0');
}

bool bTryParseAdminSyncNonNegativeInt(const char[] szInput, int &iValue)
{
	char szNormalized[32];
	vNormalizeAdminSyncText(szInput, szNormalized, sizeof(szNormalized));
	if (!SteamIDTools_IsNumericString(szNormalized))
		return false;

	iValue = StringToInt(szNormalized);
	return (iValue >= 0);
}

int iGetAdminSyncCommandUserId(int iClient)
{
	return BSGetCommandIssuerUserId(iClient);
}

void vAdminSyncReadUserReplyContext(DataPack pack, int &iUserId, ReplySource &eReplySource)
{
	pack.Reset();
	iUserId = pack.ReadCell();
	eReplySource = view_as<ReplySource>(pack.ReadCell());
}

void vAdminSyncReadIdentityLookupContext(DataPack pack, int &iUserId, AdminSyncIdentityAction &eAction, int &iValue, ReplySource &eReplySource, char[] szExtra, int iExtraMaxLength, char[] szExtra2, int iExtra2MaxLength)
{
	pack.Reset();
	iUserId = pack.ReadCell();
	eAction = view_as<AdminSyncIdentityAction>(pack.ReadCell());
	iValue = pack.ReadCell();
	eReplySource = view_as<ReplySource>(pack.ReadCell());
	pack.ReadString(szExtra, iExtraMaxLength);
	pack.ReadString(szExtra2, iExtra2MaxLength);
}

void vAdminSyncReadAdminAddSteamId64EnrichmentContext(DataPack pack, int &iUserId, int &iAccountId, int &iImmunity, ReplySource &eReplySource, char[] szName, int iNameMaxLength, char[] szFlags, int iFlagsMaxLength)
{
	pack.Reset();
	iUserId = pack.ReadCell();
	pack.ReadCell();
	iAccountId = pack.ReadCell();
	iImmunity = pack.ReadCell();
	eReplySource = view_as<ReplySource>(pack.ReadCell());
	pack.ReadString(szName, iNameMaxLength);
	pack.ReadString(szFlags, iFlagsMaxLength);
}

void vAdminSyncDebug(const char[] szFormat, any ...)
{
	char szMessage[512];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	vAdminSyncLog(kASDebug_General, "Debug", szMessage);
}

void vAdminSyncSQL(const char[] szFormat, any ...)
{
	char szMessage[512];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	vAdminSyncLog(kASDebug_SQL, "SQL", szMessage);
}

void vAdminSyncAPI(const char[] szFormat, any ...)
{
	char szMessage[512];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	vAdminSyncLog(kASDebug_API, "API", szMessage);
}

void vAdminSyncLog(eAdminSyncDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvDebug == null)
		return;

	if (!(g_cvDebug.IntValue & view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szDebugLogPath, "[%s] %s", szTag, szMessage);
}

bool bAccountIdToSteam2(int iAccountId, char[] szBuffer, int iMaxLength)
{
	return AccountIDToSteamID2(iAccountId, szBuffer, iMaxLength);
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

void vAdminSyncStoreAdminRef(StringMap smAdminMap, const char[] szKey, AdminId idAdmin)
{
	smAdminMap.SetValue(szKey, view_as<int>(idAdmin));
}

bool bAdminSyncTryGetAdminRef(StringMap smAdminMap, const char[] szKey, AdminId &idAdmin)
{
	int iAdminRef;
	if (!smAdminMap.GetValue(szKey, iAdminRef))
		return false;

	idAdmin = view_as<AdminId>(iAdminRef);
	return true;
}
