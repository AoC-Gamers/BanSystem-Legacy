/*****************************************************************
			A P I
*****************************************************************/

bool g_bBSSpraysApiRegistered;

stock void BSSprays_RegisterApiLibrary()
{
	if (g_bBSSpraysApiRegistered)
		return;

	CreateNative("BSSprays_AddBanByAccountId", Native_BSSpraysAddBanByAccountId);
	CreateNative("BSSprays_RemoveBanByAccountId", Native_BSSpraysRemoveBanByAccountId);
	CreateNative("BSSprays_HasResolvedDetail", Native_BSSpraysHasResolvedDetail);
	CreateNative("BSSprays_IsClientBanned", Native_BSSpraysIsClientBanned);
	RegPluginLibrary(BANSYSTEM_SPRAYS_LIBRARY);
	g_bBSSpraysApiRegistered = true;
	BSSprays_API("Registered bansystem_sprays API library.");
}

stock void BSSprays_OnPluginStart_Api()
{
}

public int Native_BSSpraysAddBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	int iLength = GetNativeCell(3);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSSprays_CanUseDatabase() || iAccountId <= 0 || iLength < 0)
		return false;

	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	GetNativeString(4, szReason, sizeof(szReason));
	GetNativeString(5, szContext, sizeof(szContext));

	int iTargetClient = FindClientByAccountID(iAccountId);
	BSSprays_QueueAddBan(iAdmin, iAccountId, iTargetClient, iLength, szReason, szContext, "", "UNKNOWN", eReplySource);
	return true;
}

public int Native_BSSpraysRemoveBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSSprays_CanUseDatabase() || iAccountId <= 0)
		return false;

	BSSprays_QueueRemoveBan(iAdmin, iAccountId, eReplySource);
	return true;
}

public int Native_BSSpraysHasResolvedDetail(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSSpraysResolvedDetail[iClient].m_bLoaded;
}

public int Native_BSSpraysIsClientBanned(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return BSSprays_IsClientSprayBanned(iClient);
}
