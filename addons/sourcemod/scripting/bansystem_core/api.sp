/*****************************************************************
			A P I
*****************************************************************/

stock void BSCore_RegisterApiLibrary()
{
	CreateNative("BSCore_IsMapTransitionActive", Native_BSCoreIsMapTransitionActive);
	CreateNative("BSCore_IsAuthReady", Native_BSCoreIsAuthReady);
	CreateNative("BSCore_IsClientAuthPending", Native_BSCoreIsClientAuthPending);
	CreateNative("BSCore_IsLocalCleanCached", Native_BSCoreIsLocalCleanCached);
	CreateNative("BSCore_AddLocalCleanCache", Native_BSCoreAddLocalCleanCache);
	CreateNative("BSCore_RemoveLocalCleanCache", Native_BSCoreRemoveLocalCleanCache);
	CreateNative("BSCore_ClearLocalCleanCache", Native_BSCoreClearLocalCleanCache);
	CreateNative("BSCore_GetLocalCleanCacheSize", Native_BSCoreGetLocalCleanCacheSize);
	CreateNative("BSCore_RegisterModule", Native_BSCoreRegisterModule);
	CreateNative("BSCore_IsModuleRegistered", Native_BSCoreIsModuleRegistered);
	CreateNative("BSCore_GetRegisteredModuleMask", Native_BSCoreGetRegisteredModuleMask);
	CreateNative("BSCore_HasResolvedSummary", Native_BSCoreHasResolvedSummary);
	CreateNative("BSCore_GetResolvedAccountId", Native_BSCoreGetResolvedAccountId);
	CreateNative("BSCore_GetResolvedModuleMask", Native_BSCoreGetResolvedModuleMask);
	CreateNative("BSCore_GetResolvedCommType", Native_BSCoreGetResolvedCommType);
	CreateNative("BSCore_GetResolvedBanId", Native_BSCoreGetResolvedBanId);
	CreateNative("BSCore_GetResolvedCommLength", Native_BSCoreGetResolvedCommLength);
	CreateNative("BSCore_GetResolvedCommReason", Native_BSCoreGetResolvedCommReason);
	CreateNative("BSCore_GetResolvedCommContext", Native_BSCoreGetResolvedCommContext);
	CreateNative("BSCore_GetResolvedCommBannedByName", Native_BSCoreGetResolvedCommBannedByName);
	CreateNative("BSCore_GetResolvedCommExpireTs", Native_BSCoreGetResolvedCommExpireTs);
	CreateNative("BSCore_GetResolvedSprayLength", Native_BSCoreGetResolvedSprayLength);
	CreateNative("BSCore_GetResolvedSprayReason", Native_BSCoreGetResolvedSprayReason);
	CreateNative("BSCore_GetResolvedSprayContext", Native_BSCoreGetResolvedSprayContext);
	CreateNative("BSCore_GetResolvedSprayBannedByName", Native_BSCoreGetResolvedSprayBannedByName);
	CreateNative("BSCore_GetResolvedSprayExpireTs", Native_BSCoreGetResolvedSprayExpireTs);
	CreateNative("BSCore_GetPendingDetailMask", Native_BSCoreGetPendingDetailMask);
	CreateNative("BSCore_SetAccessSummary", Native_BSCoreSetAccessSummary);
	CreateNative("BSCore_SetCommSummary", Native_BSCoreSetCommSummary);
	CreateNative("BSCore_SetCommSummaryDetail", Native_BSCoreSetCommSummaryDetail);
	CreateNative("BSCore_SetSpraySummary", Native_BSCoreSetSpraySummary);
	CreateNative("BSCore_SetSpraySummaryDetail", Native_BSCoreSetSpraySummaryDetail);
	CreateNative("BSCore_ClearSummaryModule", Native_BSCoreClearSummaryModule);
	CreateNative("BSCore_ClearSummary", Native_BSCoreClearSummary);
	CreateNative("BSCore_MarkModuleDetailResolved", Native_BSCoreMarkModuleDetailResolved);

	g_gfBSCoreOnAuthReadyChanged = CreateGlobalForward("BSCore_OnAuthReadyChanged", ET_Ignore, Param_Cell);
	g_gfBSCoreOnAccessDetailRequested = CreateGlobalForward("BSCore_OnAccessDetailRequested", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_gfBSCoreOnCommDetailRequested = CreateGlobalForward("BSCore_OnCommDetailRequested", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_gfBSCoreOnSprayDetailRequested = CreateGlobalForward("BSCore_OnSprayDetailRequested", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	RegPluginLibrary(BANSYSTEM_CORE_LIBRARY);
	BSCore_API("Registered bansystem_core API library and natives.");
}

public int Native_BSCoreIsMapTransitionActive(Handle hPlugin, int iNumParams)
{
	return g_bCoreMapTransitionActive;
}

public int Native_BSCoreIsAuthReady(Handle hPlugin, int iNumParams)
{
	return g_bCoreAuthReady;
}

public int Native_BSCoreIsClientAuthPending(Handle hPlugin, int iNumParams)
{
	return BSCore_IsClientAuthorizationPending(GetNativeCell(1));
}

public int Native_BSCoreIsLocalCleanCached(Handle hPlugin, int iNumParams)
{
	return BSCore_HasLocalCleanCacheAccountId(GetNativeCell(1));
}

public int Native_BSCoreAddLocalCleanCache(Handle hPlugin, int iNumParams)
{
	return BSCore_AddLocalCleanCacheAccountId(GetNativeCell(1));
}

public int Native_BSCoreRemoveLocalCleanCache(Handle hPlugin, int iNumParams)
{
	return BSCore_RemoveLocalCleanCacheAccountId(GetNativeCell(1));
}

public int Native_BSCoreClearLocalCleanCache(Handle hPlugin, int iNumParams)
{
	BSCore_ClearLocalCleanCache();
	return 0;
}

public int Native_BSCoreGetLocalCleanCacheSize(Handle hPlugin, int iNumParams)
{
	return BSCore_GetLocalCleanCacheSize();
}

public int Native_BSCoreRegisterModule(Handle hPlugin, int iNumParams)
{
	char szName[64];
	GetNativeString(1, szName, sizeof(szName));
	return BSCore_RegisterModule(szName, view_as<eBSCoreModuleBit>(GetNativeCell(2)));
}

public int Native_BSCoreIsModuleRegistered(Handle hPlugin, int iNumParams)
{
	char szName[64];
	GetNativeString(1, szName, sizeof(szName));
	return BSCore_IsModuleRegistered(szName);
}

public int Native_BSCoreGetRegisteredModuleMask(Handle hPlugin, int iNumParams)
{
	return view_as<int>(g_eCoreRegisteredModuleMask);
}

public int Native_BSCoreHasResolvedSummary(Handle hPlugin, int iNumParams)
{
	return BSCore_HasResolvedSummaryState(GetNativeCell(1));
}

public int Native_BSCoreGetResolvedAccountId(Handle hPlugin, int iNumParams)
{
	return BSCore_GetResolvedAccountId(GetNativeCell(1));
}

public int Native_BSCoreGetResolvedModuleMask(Handle hPlugin, int iNumParams)
{
	return BSCore_GetResolvedModuleMask(GetNativeCell(1));
}

public int Native_BSCoreGetResolvedCommType(Handle hPlugin, int iNumParams)
{
	return view_as<int>(BSCore_GetResolvedCommType(GetNativeCell(1)));
}

public int Native_BSCoreGetResolvedBanId(Handle hPlugin, int iNumParams)
{
	return BSCore_GetResolvedBanId(GetNativeCell(1), view_as<eBSCoreModuleBit>(GetNativeCell(2)));
}

public int Native_BSCoreGetResolvedCommLength(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedCommLength[iClient] : 0;
}

public int Native_BSCoreGetResolvedCommReason(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedCommReason[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedCommContext(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedCommContext[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedCommBannedByName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedCommBannedByName[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedCommExpireTs(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedCommExpireTs[iClient] : 0;
}

public int Native_BSCoreGetResolvedSprayLength(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedSprayLength[iClient] : 0;
}

public int Native_BSCoreGetResolvedSprayReason(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedSprayReason[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedSprayContext(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedSprayContext[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedSprayBannedByName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	SetNativeString(2, (iClient > 0 && iClient <= MaxClients) ? g_szCoreResolvedSprayBannedByName[iClient] : "", GetNativeCell(3), true);
	return 0;
}

public int Native_BSCoreGetResolvedSprayExpireTs(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return (iClient > 0 && iClient <= MaxClients) ? g_iCoreResolvedSprayExpireTs[iClient] : 0;
}

public int Native_BSCoreGetPendingDetailMask(Handle hPlugin, int iNumParams)
{
	return BSCore_GetPendingDetailMask(GetNativeCell(1));
}

public int Native_BSCoreSetAccessSummary(Handle hPlugin, int iNumParams)
{
	return BSCore_SetAccessSummary(GetNativeCell(1), GetNativeCell(2));
}

public int Native_BSCoreSetCommSummary(Handle hPlugin, int iNumParams)
{
	return BSCore_SetCommSummary(GetNativeCell(1), GetNativeCell(2), view_as<eBSCoreCommType>(GetNativeCell(3)));
}

public int Native_BSCoreSetCommSummaryDetail(Handle hPlugin, int iNumParams)
{
	char szReason[256];
	char szContext[512];
	char szBannedByName[MAX_NAME_LENGTH];
	GetNativeString(5, szReason, sizeof(szReason));
	GetNativeString(6, szContext, sizeof(szContext));
	GetNativeString(7, szBannedByName, sizeof(szBannedByName));
	return BSCore_SetCommSummaryDetail(GetNativeCell(1), GetNativeCell(2), view_as<eBSCoreCommType>(GetNativeCell(3)), GetNativeCell(4), szReason, szContext, szBannedByName, GetNativeCell(8));
}

public int Native_BSCoreSetSpraySummary(Handle hPlugin, int iNumParams)
{
	return BSCore_SetSpraySummary(GetNativeCell(1), GetNativeCell(2));
}

public int Native_BSCoreSetSpraySummaryDetail(Handle hPlugin, int iNumParams)
{
	char szReason[256];
	char szContext[512];
	char szBannedByName[MAX_NAME_LENGTH];
	GetNativeString(4, szReason, sizeof(szReason));
	GetNativeString(5, szContext, sizeof(szContext));
	GetNativeString(6, szBannedByName, sizeof(szBannedByName));
	return BSCore_SetSpraySummaryDetail(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), szReason, szContext, szBannedByName, GetNativeCell(7));
}

public int Native_BSCoreClearSummaryModule(Handle hPlugin, int iNumParams)
{
	return BSCore_ClearSummaryModule(GetNativeCell(1), view_as<eBSCoreModuleBit>(GetNativeCell(2)));
}

public int Native_BSCoreClearSummary(Handle hPlugin, int iNumParams)
{
	return BSCore_ClearSummary(GetNativeCell(1));
}

public int Native_BSCoreMarkModuleDetailResolved(Handle hPlugin, int iNumParams)
{
	return BSCore_MarkModuleDetailResolved(GetNativeCell(1), view_as<eBSCoreModuleBit>(GetNativeCell(2)));
}
