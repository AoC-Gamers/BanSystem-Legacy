/*****************************************************************
			A P I
*****************************************************************/

bool g_bBSCommApiRegistered;

stock void BSComm_RegisterApiLibrary()
{
	if (g_bBSCommApiRegistered)
		return;

	CreateNative("BSComm_AddBanByAccountId", Native_BSCommAddBanByAccountId);
	CreateNative("BSComm_RemoveBanByAccountId", Native_BSCommRemoveBanByAccountId);
	CreateNative("BSComm_HasResolvedDetail", Native_BSCommHasResolvedDetail);
	CreateNative("BSComm_IsClientBanned", Native_BSCommIsClientBanned);
	CreateNative("BSComm_GetResolvedCommType", Native_BSCommGetResolvedCommType);
	RegPluginLibrary(BANSYSTEM_COMM_LIBRARY);
	g_bBSCommApiRegistered = true;
	BSComm_API("Registered bansystem_comm API library.");
}

stock void BSComm_OnPluginStart_Api()
{
}

public int Native_BSCommAddBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	eBSCommType eCommType = view_as<eBSCommType>(GetNativeCell(3));
	int iLength = GetNativeCell(4);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSComm_CanUseDatabase() || iAccountId <= 0 || iLength < 0 || !BSComm_IsSupportedCommType(eCommType))
		return false;

	char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char szContext[512];
	GetNativeString(5, szReason, sizeof(szReason));
	GetNativeString(6, szContext, sizeof(szContext));

	int iTargetClient = FindClientByAccountID(iAccountId);
	BSComm_QueueAddBan(iAdmin, iAccountId, iTargetClient, eCommType, iLength, szReason, szContext, "", "UNKNOWN", eReplySource);
	return true;
}

public int Native_BSCommRemoveBanByAccountId(Handle hPlugin, int iNumParams)
{
	int iAdmin = GetNativeCell(1);
	int iAccountId = GetNativeCell(2);
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSComm_CanUseDatabase() || iAccountId <= 0)
		return false;

	BSComm_QueueRemoveBan(iAdmin, iAccountId, eReplySource);
	return true;
}

public int Native_BSCommHasResolvedDetail(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSCommResolvedDetail[iClient].m_bLoaded;
}

public int Native_BSCommIsClientBanned(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return false;

	return g_eBSCommResolvedDetail[iClient].m_bLoaded && g_eBSCommResolvedDetail[iClient].m_eCommType != kBSCommType_None;
}

public int Native_BSCommGetResolvedCommType(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	return view_as<int>(g_eBSCommResolvedDetail[iClient].m_eCommType);
}
