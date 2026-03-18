/*****************************************************************
			A P I
*****************************************************************/

bool g_bBSAccessApiRegistered;

stock void BSAccess_RegisterApiLibrary()
{
	if (g_bBSAccessApiRegistered)
		return;

	CreateNative("BSAccess_AddBanByAccountId", Native_BSAccessAddBanByAccountId);
	CreateNative("BSAccess_RemoveBanByAccountId", Native_BSAccessRemoveBanByAccountId);
	CreateNative("BSAccess_HasResolvedDetail", Native_BSAccessHasResolvedDetail);
	CreateNative("BSAccess_IsClientBanned", Native_BSAccessIsClientBanned);
	CreateNative("BSAccess_GetResolvedAccountId", Native_BSAccessGetResolvedAccountId);
	g_gfBSAccessOnClientDenied = CreateGlobalForward("BSAccess_OnClientDenied", ET_Ignore, Param_Cell, Param_Cell);
	RegPluginLibrary(BANSYSTEM_ACCESS_LIBRARY);
	g_bBSAccessApiRegistered = true;
	BSAccess_API("Registered bansystem_access API library.");
}

stock void BSAccess_OnPluginStart_Api()
{
}

public int Native_BSAccessAddBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	int iLength = GetNativeCell(3);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSAccess_CanUseDatabase() || iAccountId <= 0)
		return false;

	char szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
	char szContext[512];
	GetNativeString(4, szReason, sizeof(szReason));
	GetNativeString(5, szContext, sizeof(szContext));

	int iTargetClient = FindClientByAccountID(iAccountId);
	BSAccess_QueueAddBan(iAdmin, iAccountId, iTargetClient, iLength, szReason, szContext, "", "UNKNOWN", eReplySource);
	return true;
}

public int Native_BSAccessRemoveBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSAccess_CanUseDatabase() || iAccountId <= 0)
		return false;

	BSAccess_QueueRemoveBan(iAdmin, iAccountId, eReplySource);
	return true;
}

public int Native_BSAccessHasResolvedDetail(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSAccessResolvedDetail[iClient].m_bLoaded;
}

public int Native_BSAccessIsClientBanned(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSAccessResolvedDetail[iClient].m_bLoaded && g_eBSAccessResolvedDetail[iClient].m_iBanId > 0;
}

public int Native_BSAccessGetResolvedAccountId(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	return g_eBSAccessResolvedDetail[iClient].m_iAccountId;
}
