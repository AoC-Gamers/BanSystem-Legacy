enum eNativeIdentityRequestKind
{
	kNativeIdentityRequest_None = 0,
	kNativeIdentityRequest_AccessBan,
	kNativeIdentityRequest_AccessUnban,
	kNativeIdentityRequest_CommBan,
	kNativeIdentityRequest_CommUnban
}

GlobalForward
	g_gfOnBanAccess,
	g_gfOnUnbanAcess,
	g_gfOnBanMic,
	g_gfOnUnBanMic,
	g_gfOnBanChat,
	g_gfOnUnBanChat;

StringMap g_smNativeIdentityRequestContext;
StringMap g_smNativeIdentityCallbackContext;
int g_iNativeAsyncRequestSerial;

void vRegisterApiLibrary()
{
	CreateNative("bBSBanAccess", iBanAccesNative);
	CreateNative("iBSBanAccessAsync", iBanAccessAsyncNative);
	CreateNative("iBSUnbanAccessAsync", iUnbanAccessAsyncNative);
	CreateNative("iBSBanCommAsync", iBanCommAsyncNative);
	CreateNative("iBSUnbanCommAsync", iUnbanCommAsyncNative);
	CreateNative("bBSBannedComm", iBannedCommNative);

	g_gfOnBanAccess = CreateGlobalForward("vBSOnBanAccess", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_gfOnUnbanAcess = CreateGlobalForward("vBSOnUnbanAccess", ET_Ignore, Param_Cell, Param_String);
	g_gfOnBanMic = CreateGlobalForward("vBSOnBanMic", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_gfOnUnBanMic = CreateGlobalForward("vBSOnUnbanMic", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_gfOnBanChat = CreateGlobalForward("vBSOnBanChat", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_gfOnUnBanChat = CreateGlobalForward("vBSOnUnBanChat", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	RegPluginLibrary("bansystem");
	LogAPI("Registered bansystem API library and natives.");
}

void vOnPluginStart_Api()
{
	g_smNativeIdentityRequestContext = new StringMap();
	g_smNativeIdentityCallbackContext = new StringMap();
}

DataPack pCreateNativeAsyncCallbackContext(Handle hPlugin, Function fnCallback, int iRequestId, bool bAccepted, any data, const char[] szResolvedAuthId, const char[] szError)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(view_as<int>(hPlugin));
	pContext.WriteFunction(fnCallback);
	pContext.WriteCell(iRequestId);
	pContext.WriteCell(bAccepted ? 1 : 0);
	pContext.WriteCell(data);
	pContext.WriteString(szResolvedAuthId);
	pContext.WriteString(szError);
	return pContext;
}

void vReadNativeAsyncCallbackContext(any pData, Handle &hPlugin, Function &fnCallback, int &iRequestId, bool &bAccepted, any &data, char[] szResolvedAuthId, int iResolvedAuthIdMaxLength, char[] szError, int iErrorMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	hPlugin = view_as<Handle>(pContext.ReadCell());
	fnCallback = pContext.ReadFunction();
	iRequestId = pContext.ReadCell();
	bAccepted = view_as<bool>(pContext.ReadCell());
	data = pContext.ReadCell();
	pContext.ReadString(szResolvedAuthId, iResolvedAuthIdMaxLength);
	pContext.ReadString(szError, iErrorMaxLength);
	delete pContext;
}

DataPack pCreateNativeIdentityLookupContext(eNativeIdentityRequestKind eKind, int iAdminUserId, int iArg0, int iArg1, int iNativeRequestId, Handle hPlugin, Function fnCallback, any data, const char[] szExtra)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(view_as<int>(eKind));
	pContext.WriteCell(iAdminUserId);
	pContext.WriteCell(iArg0);
	pContext.WriteCell(iArg1);
	pContext.WriteCell(iNativeRequestId);
	pContext.WriteCell(view_as<int>(hPlugin));
	pContext.WriteFunction(fnCallback);
	pContext.WriteCell(data);
	pContext.WriteString(szExtra);
	return pContext;
}

void vReadNativeIdentityLookupContext(any pData, eNativeIdentityRequestKind &eKind, int &iAdminUserId, int &iArg0, int &iArg1, int &iNativeRequestId, Handle &hPlugin, Function &fnCallback, any &data, char[] szExtra, int iExtraMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	eKind = view_as<eNativeIdentityRequestKind>(pContext.ReadCell());
	iAdminUserId = pContext.ReadCell();
	iArg0 = pContext.ReadCell();
	iArg1 = pContext.ReadCell();
	iNativeRequestId = pContext.ReadCell();
	hPlugin = view_as<Handle>(pContext.ReadCell());
	fnCallback = pContext.ReadFunction();
	data = pContext.ReadCell();
	pContext.ReadString(szExtra, iExtraMaxLength);
	delete pContext;
}

int iGetNextNativeAsyncRequestId()
{
	g_iNativeAsyncRequestSerial++;
	if (g_iNativeAsyncRequestSerial <= 0)
		g_iNativeAsyncRequestSerial = 1;

	return g_iNativeAsyncRequestSerial;
}

void vQueueNativeAsyncCallback(Handle hPlugin, Function fnCallback, int iRequestId, bool bAccepted, const char[] szResolvedAuthId, const char[] szError, any data)
{
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pContext = pCreateNativeAsyncCallbackContext(hPlugin, fnCallback, iRequestId, bAccepted, data, szResolvedAuthId, szError);
	int pContextRef = view_as<int>(pContext);

	g_smNativeIdentityCallbackContext.SetValue(szRequestId, pContextRef);

	RequestFrame(OnFrame_NativeAsyncCallback, iRequestId);
}

public void OnFrame_NativeAsyncCallback(any data)
{
	int iRequestId = data;
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	int pContextRef;
	if (!g_smNativeIdentityCallbackContext.GetValue(szRequestId, pContextRef))
		return;

	g_smNativeIdentityCallbackContext.Remove(szRequestId);

	Handle hPlugin;
	Function fnCallback;
	int iData;
	bool bAccepted;
	char szResolvedAuthId[MAX_AUTHID_LENGTH];
	char szError[MAX_MESSAGE_LENGTH];

	vReadNativeAsyncCallbackContext(pContextRef, hPlugin, fnCallback, iRequestId, bAccepted, iData, szResolvedAuthId, sizeof(szResolvedAuthId), szError, sizeof(szError));

	if (fnCallback == INVALID_FUNCTION || hPlugin == INVALID_HANDLE || !IsValidHandle(hPlugin))
		return;

	if (GetPluginStatus(hPlugin) != Plugin_Running)
		return;

	Call_StartFunction(hPlugin, fnCallback);
	Call_PushCell(iRequestId);
	Call_PushCell(bAccepted);
	Call_PushString(szResolvedAuthId);
	Call_PushString(szError);
	Call_PushCell(iData);
	Call_Finish();
}

bool bQueueNativeIdentityLookupRequest(eNativeIdentityRequestKind eKind, Handle hPlugin, Function fnCallback, int iNativeRequestId, int iAdminUserId, const char[] szInput, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "", any data = 0)
{
	SteamIDToolsProvider eProvider = eGetSteamIdLookupProvider();
	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iNativeRequestId, false, "", "SteamIDTools provider unavailable", data);
		return false;
	}

	char szNormalizedInput[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szInput, szNormalizedInput, sizeof(szNormalizedInput));

	int iLookupRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toSID2, szNormalizedInput);
	if (iLookupRequestId <= 0)
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iNativeRequestId, false, "", "SteamID64 resolution request failed", data);
		return false;
	}

	DataPack pContext = pCreateNativeIdentityLookupContext(eKind, iAdminUserId, iArg0, iArg1, iNativeRequestId, hPlugin, fnCallback, data, szExtra);
	int pContextRef = view_as<int>(pContext);
	char szLookupRequestId[16];
	IntToString(iLookupRequestId, szLookupRequestId, sizeof(szLookupRequestId));
	g_smNativeIdentityRequestContext.SetValue(szLookupRequestId, pContextRef);
	return true;
}

void vSubmitNativeBanAccessRequest(Handle hPlugin, Function fnCallback, int iRequestId, int iAdminUserId, const char[] szResolvedSteamId2, int iLength, const char[] szReason, any data)
{
	if (!bCanUsePrimaryDatabase())
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Primary database is not ready", data);
		return;
	}

	vSubmitAccessRegistrationByIdentity(iResolveReplyClient(iAdminUserId, true), szResolvedSteamId2, iLength, szReason, SM_REPLY_TO_CONSOLE);
	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, true, szResolvedSteamId2, "", data);
}

void vSubmitNativeAccessUnbanRequest(Handle hPlugin, Function fnCallback, int iRequestId, int iAdminUserId, const char[] szResolvedSteamId2, any data)
{
	if (!bCanUsePrimaryDatabase())
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Primary database is not ready", data);
		return;
	}

	vSubmitRemoveAccessByIdentity(iResolveReplyClient(iAdminUserId, true), szResolvedSteamId2, SM_REPLY_TO_CONSOLE);
	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, true, szResolvedSteamId2, "", data);
}

void vSubmitNativeCommBanRequest(Handle hPlugin, Function fnCallback, int iRequestId, int iAdminUserId, const char[] szResolvedSteamId2, eTypeComms eCommType, int iLength, const char[] szReason, any data)
{
	if (!bCanUsePrimaryDatabase())
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Primary database is not ready", data);
		return;
	}

	vSubmitCommRegistrationByIdentity(iResolveReplyClient(iAdminUserId, true), szResolvedSteamId2, iLength, szReason, eCommType, SM_REPLY_TO_CONSOLE);
	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, true, szResolvedSteamId2, "", data);
}

void vSubmitNativeCommUnbanRequest(Handle hPlugin, Function fnCallback, int iRequestId, int iAdminUserId, const char[] szResolvedSteamId2, any data)
{
	if (!bCanUsePrimaryDatabase())
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Primary database is not ready", data);
		return;
	}

	vSubmitRemoveCommByIdentity(iResolveReplyClient(iAdminUserId, true), szResolvedSteamId2, SM_REPLY_TO_CONSOLE);
	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, true, szResolvedSteamId2, "", data);
}

bool bHandleNativeIdentityLookupRequestResult(int iRequestId, bool bSuccess, const char[] szResult)
{
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	int pContextRef;
	if (!g_smNativeIdentityRequestContext.GetValue(szRequestId, pContextRef))
		return false;

	g_smNativeIdentityRequestContext.Remove(szRequestId);

	eNativeIdentityRequestKind eKind;
	int iAdminUserId;
	int iArg0;
	int iArg1;
	int iNativeRequestId;
	Handle hPlugin;
	Function fnCallback;
	any iData;
	char szExtra[MAX_MESSAGE_LENGTH];
	vReadNativeIdentityLookupContext(pContextRef, eKind, iAdminUserId, iArg0, iArg1, iNativeRequestId, hPlugin, fnCallback, iData, szExtra, sizeof(szExtra));

	if (!bSuccess)
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iNativeRequestId, false, "", szResult, iData);
		return true;
	}

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szResult, szResolvedSteamId2, sizeof(szResolvedSteamId2));
	if (!IsValidSteamID2(szResolvedSteamId2))
	{
		vQueueNativeAsyncCallback(hPlugin, fnCallback, iNativeRequestId, false, "", "Invalid SteamIDTools response", iData);
		return true;
	}

	switch (eKind)
	{
		case kNativeIdentityRequest_AccessBan:
		{
			vSubmitNativeBanAccessRequest(hPlugin, fnCallback, iNativeRequestId, iAdminUserId, szResolvedSteamId2, iArg0, szExtra, iData);
		}
		case kNativeIdentityRequest_AccessUnban:
		{
			vSubmitNativeAccessUnbanRequest(hPlugin, fnCallback, iNativeRequestId, iAdminUserId, szResolvedSteamId2, iData);
		}
		case kNativeIdentityRequest_CommBan:
		{
			vSubmitNativeCommBanRequest(hPlugin, fnCallback, iNativeRequestId, iAdminUserId, szResolvedSteamId2, view_as<eTypeComms>(iArg0), iArg1, szExtra, iData);
		}
		case kNativeIdentityRequest_CommUnban:
		{
			vSubmitNativeCommUnbanRequest(hPlugin, fnCallback, iNativeRequestId, iAdminUserId, szResolvedSteamId2, iData);
		}
		default:
		{
			vQueueNativeAsyncCallback(hPlugin, fnCallback, iNativeRequestId, false, "", "Invalid native async request kind", iData);
		}
	}

	return true;
}

int iBanAccesNative(Handle hPlugin, int iNumParams)
{
	if (!bCanUsePrimaryDatabase())
	{
		LogError("[iBanAccesNative] Primary database is not ready.");
		return 0;
	}

	int iClient = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	if (!bIsUsableClient(iClient))
		iClient = SERVER_INDEX;

	if (iTarget == NO_INDEX)
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
	else if (bIsUsableClient(iTarget) && GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
	{
		// Auth ID resolved from target client.
	}
	else
	{
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
		iTarget = NO_INDEX;
	}

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	switch (eResolveIdentityToSteam2Offline(szTargetAuthId, szResolvedSteamId2, sizeof(szResolvedSteamId2), true))
	{
		case kIdentityResolution_Resolved:
		{
			strcopy(szTargetAuthId, sizeof(szTargetAuthId), szResolvedSteamId2);
		}
		case kIdentityResolution_OnlinePending:
		{
			LogError("[iBanAccesNative] SteamID64 input requires async resolution and is not supported by this native: %s", szTargetAuthId);
			return 0;
		}
		default:
		{
			LogError("[iBanAccesNative] Invalid auth id received from native call: %s", szTargetAuthId);
			return 0;
		}
	}

	int iLength = GetNativeCell(4);
	char szReason[MAX_MESSAGE_LENGTH];
	GetNativeString(5, szReason, sizeof(szReason));

	vRegAccess(iClient, iTarget, szTargetAuthId, iLength, szReason);
	return 1;
}

int iBanAccessAsyncNative(Handle hPlugin, int iNumParams)
{
	Function fnCallback = GetNativeFunction(6);

	int iRequestId = iGetNextNativeAsyncRequestId();
	int iAdmin = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	if (!bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget == NO_INDEX)
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
	else if (bIsUsableClient(iTarget) && GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
	{
		// Auth ID resolved from target client.
	}
	else
	{
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
		iTarget = NO_INDEX;
	}

	int iLength = GetNativeCell(4);
	char szReason[MAX_MESSAGE_LENGTH];
	GetNativeString(5, szReason, sizeof(szReason));
	any iData = GetNativeCell(7);
	int iAdminUserId = iGetCommandIssuerUserId(iAdmin);

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	switch (eResolveIdentityToSteam2Offline(szTargetAuthId, szResolvedSteamId2, sizeof(szResolvedSteamId2), true))
	{
		case kIdentityResolution_Resolved:
		{
			vSubmitNativeBanAccessRequest(hPlugin, fnCallback, iRequestId, iAdminUserId, szResolvedSteamId2, iLength, szReason, iData);
			return iRequestId;
		}
		case kIdentityResolution_OnlinePending:
		{
			bQueueNativeIdentityLookupRequest(kNativeIdentityRequest_AccessBan, hPlugin, fnCallback, iRequestId, iAdminUserId, szTargetAuthId, iLength, 0, szReason, iData);
			return iRequestId;
		}
	}

	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Invalid auth id", iData);
	return iRequestId;
}

int iUnbanAccessAsyncNative(Handle hPlugin, int iNumParams)
{
	Function fnCallback = GetNativeFunction(3);

	int iRequestId = iGetNextNativeAsyncRequestId();
	int iAdmin = GetNativeCell(1);
	char szTargetAuthId[MAX_AUTHID_LENGTH];
	GetNativeString(2, szTargetAuthId, sizeof(szTargetAuthId));
	any iData = GetNativeCell(4);

	if (!bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	int iAdminUserId = iGetCommandIssuerUserId(iAdmin);
	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	switch (eResolveIdentityToSteam2Offline(szTargetAuthId, szResolvedSteamId2, sizeof(szResolvedSteamId2), true))
	{
		case kIdentityResolution_Resolved:
		{
			vSubmitNativeAccessUnbanRequest(hPlugin, fnCallback, iRequestId, iAdminUserId, szResolvedSteamId2, iData);
			return iRequestId;
		}
		case kIdentityResolution_OnlinePending:
		{
			bQueueNativeIdentityLookupRequest(kNativeIdentityRequest_AccessUnban, hPlugin, fnCallback, iRequestId, iAdminUserId, szTargetAuthId, 0, 0, "", iData);
			return iRequestId;
		}
	}

	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Invalid auth id", iData);
	return iRequestId;
}

int iBanCommAsyncNative(Handle hPlugin, int iNumParams)
{
	Function fnCallback = GetNativeFunction(7);

	int iRequestId = iGetNextNativeAsyncRequestId();
	int iAdmin = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	if (!bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget == NO_INDEX)
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
	else if (bIsUsableClient(iTarget) && GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
	{
		// Auth ID resolved from target client.
	}
	else
	{
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
		iTarget = NO_INDEX;
	}

	eTypeComms eCommType = view_as<eTypeComms>(GetNativeCell(4));
	int iLength = GetNativeCell(5);
	char szReason[MAX_MESSAGE_LENGTH];
	GetNativeString(6, szReason, sizeof(szReason));
	any iData = GetNativeCell(8);
	int iAdminUserId = iGetCommandIssuerUserId(iAdmin);
	char szResolvedSteamId2[MAX_AUTHID_LENGTH];

	switch (eResolveIdentityToSteam2Offline(szTargetAuthId, szResolvedSteamId2, sizeof(szResolvedSteamId2), true))
	{
		case kIdentityResolution_Resolved:
		{
			vSubmitNativeCommBanRequest(hPlugin, fnCallback, iRequestId, iAdminUserId, szResolvedSteamId2, eCommType, iLength, szReason, iData);
			return iRequestId;
		}
		case kIdentityResolution_OnlinePending:
		{
			bQueueNativeIdentityLookupRequest(kNativeIdentityRequest_CommBan, hPlugin, fnCallback, iRequestId, iAdminUserId, szTargetAuthId, view_as<int>(eCommType), iLength, szReason, iData);
			return iRequestId;
		}
	}

	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Invalid auth id", iData);
	return iRequestId;
}

int iUnbanCommAsyncNative(Handle hPlugin, int iNumParams)
{
	Function fnCallback = GetNativeFunction(4);

	int iRequestId = iGetNextNativeAsyncRequestId();
	int iAdmin = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	if (!bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget == NO_INDEX)
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
	else if (bIsUsableClient(iTarget) && GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
	{
		// Auth ID resolved from target client.
	}
	else
	{
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
		iTarget = NO_INDEX;
	}

	any iData = GetNativeCell(5);
	int iAdminUserId = iGetCommandIssuerUserId(iAdmin);
	char szResolvedSteamId2[MAX_AUTHID_LENGTH];

	switch (eResolveIdentityToSteam2Offline(szTargetAuthId, szResolvedSteamId2, sizeof(szResolvedSteamId2), true))
	{
		case kIdentityResolution_Resolved:
		{
			vSubmitNativeCommUnbanRequest(hPlugin, fnCallback, iRequestId, iAdminUserId, szResolvedSteamId2, iData);
			return iRequestId;
		}
		case kIdentityResolution_OnlinePending:
		{
			bQueueNativeIdentityLookupRequest(kNativeIdentityRequest_CommUnban, hPlugin, fnCallback, iRequestId, iAdminUserId, szTargetAuthId, 0, 0, "", iData);
			return iRequestId;
		}
	}

	vQueueNativeAsyncCallback(hPlugin, fnCallback, iRequestId, false, "", "Invalid auth id", iData);
	return iRequestId;
}

int iBannedCommNative(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	eTypeComms eComms = view_as<eTypeComms>(GetNativeCell(2));

	if (!bIsUsableClient(iClient))
		return 0;

	switch (eComms)
	{
		case kAll:
		{
			if (g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
		case kMic:
		{
			if (g_ePunished[iClient].m_eComms == kMic || g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
		case kChat:
		{
			if (g_ePunished[iClient].m_eComms == kChat || g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
	}

	return 0;
}
