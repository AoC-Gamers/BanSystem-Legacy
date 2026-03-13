#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <steamidtools>

#define BANSYSTEM_CORE_VERSION "0.1.0-dev"
#define BANSYSTEM_CORE_DEBUG_LOG "logs/BanSystem_Core.log"

Database g_dbCorePrimary;
Database g_dbCoreCache;
GlobalForward g_gfBSCoreOnAccessDetailRequested;
GlobalForward g_gfBSCoreOnCommDetailRequested;
GlobalForward g_gfBSCoreOnSprayDetailRequested;

ConVar g_cvCoreMysqlConfig;
ConVar g_cvCoreSqliteCache;
ConVar g_cvCoreCacheConfig;
ConVar g_cvCoreLocalCache;
ConVar g_cvCoreAuthTimeout;
ConVar g_cvCoreDebugMask;

ArrayList g_alCoreLocalCleanCache;
StringMap g_smCoreRegisteredModules;

char g_szCoreLogPath[PLATFORM_MAX_PATH];

bool g_bCorePrimaryReady;
bool g_bCoreCacheReady;
bool g_bCoreMapTransitionActive;
bool g_bCoreHasL4D2ChangeLevel;
int g_iCoreRegisteredModuleMask;

Handle g_hCoreAuthTimer[MAXPLAYERS + 1];
eBSCoreAuthState g_eCoreAuthState[MAXPLAYERS + 1];
int g_iCoreResolvedAccountId[MAXPLAYERS + 1];
int g_iCoreResolvedModuleMask[MAXPLAYERS + 1];
eBSCoreCommType g_eCoreResolvedCommType[MAXPLAYERS + 1];
int g_iCoreResolvedAccessBanId[MAXPLAYERS + 1];
int g_iCoreResolvedCommBanId[MAXPLAYERS + 1];
int g_iCoreResolvedSprayBanId[MAXPLAYERS + 1];
int g_iCorePendingDetailMask[MAXPLAYERS + 1];
int g_iCoreResolvedDetailMask[MAXPLAYERS + 1];

#include "bansystem_core/schema.sp"
#include "bansystem_core/helpers.sp"
#include "bansystem_core/api.sp"
#include "bansystem_core/identity.sp"
#include "bansystem_core/db.sp"
#include "bansystem_core/cache.sp"
#include "bansystem_core/summary.sp"
#include "bansystem_core/transition.sp"
#include "bansystem_core/auth.sp"
#include "bansystem_core/modules.sp"

public Plugin myinfo =
{
	name = "BanSystem Core",
	author = "Israel L.",
	description = "Core scaffold for modular BanSystem.",
	version = BANSYSTEM_CORE_VERSION,
	url = "https://github.com/IsraelL/BanSystem"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BSCore_RegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_szCoreLogPath, sizeof(g_szCoreLogPath), BANSYSTEM_CORE_DEBUG_LOG);
	LoadTranslations("bansystem_modular.phrases");

	g_cvCoreMysqlConfig = CreateConVar("sm_bs_core_mysql_config", "bansystem", "MySQL config used by BanSystem Core.");
	g_cvCoreSqliteCache = CreateConVar("sm_bs_core_sqlitecache", "1", "Enable the BanSystem Core SQLite summary cache.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvCoreCacheConfig = CreateConVar("sm_bs_core_cache_config", "bansystemcache", "SQLite config used by BanSystem Core.");
	g_cvCoreLocalCache = CreateConVar("sm_bs_core_localcache", "1", "Enable the BanSystem Core local clean cache.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvCoreAuthTimeout = CreateConVar("sm_bs_core_auth_timeout", "8.0", "Seconds to keep a core auth request pending before timing it out.", FCVAR_NONE, true, 1.0);
	g_cvCoreDebugMask = CreateConVar("sm_bs_core_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=transition, 8=api.", FCVAR_NONE, true, 0.0);

	g_alCoreLocalCleanCache = new ArrayList();
	g_smCoreRegisteredModules = new StringMap();
	g_bCoreMapTransitionActive = true;
	g_bCoreHasL4D2ChangeLevel = LibraryExists("l4d2_changelevel");
	g_iCoreRegisteredModuleMask = 0;

	RegAdminCmd("sm_bs_core_status", Command_BSCoreStatus, ADMFLAG_ROOT, "Show BanSystem Core runtime status.");
	RegAdminCmd("sm_bs_core_cache_install", Command_BSCoreCacheInstall, ADMFLAG_ROOT, "Install the BanSystem Core SQLite summary cache schema.");
	RegAdminCmd("sm_bs_core_cache_reinstall", Command_BSCoreCacheReinstall, ADMFLAG_ROOT, "Reinstall the BanSystem Core SQLite summary cache schema.");
	BSCore_Debug("Core bootstrap initialized. l4d2_changelevel=%d", g_bCoreHasL4D2ChangeLevel);
}

public void OnConfigsExecuted()
{
	g_bCorePrimaryReady = false;
	g_bCoreCacheReady = false;
	BSCore_ConnectDatabases();
}

public void OnMapStart()
{
	BSCore_BeginMapTransition();
}

public void OnMapEnd()
{
	BSCore_BeginMapTransition();
}

public void OnLibraryAdded(const char[] szName)
{
	BSCore_OnLibraryAdded(szName);
}

public void OnLibraryRemoved(const char[] szName)
{
	BSCore_OnLibraryRemoved(szName);
}

public void OnClientDisconnect(int iClient)
{
	BSCore_ResetClientAuthorizationState(iClient);
	BSCore_ResetResolvedClientState(iClient);
}

public void OnClientAuthorized(int iClient, const char[] szAuth)
{
	if (iClient <= 0 || !IsClientConnected(iClient) || IsFakeClient(iClient))
		return;

	BSCore_ResetResolvedClientState(iClient);
	if (g_bCoreMapTransitionActive)
	{
		BSCore_QueueClientAuthorizationCheck(iClient);
		return;
	}

	BSCore_BeginClientAuthorizationCheck(iClient);
	BSCore_HandleClientAuthorization(iClient, szAuth);
}

Action Command_BSCoreStatus(int iClient, int iArgs)
{
	char szModules[128];
	BSCore_BuildRegisteredModulesString(szModules, sizeof(szModules));

	CReplyToCommand(
		iClient,
		"%t",
		"BSCoreStatus",
		g_bCoreMapTransitionActive ? 1 : 0,
		BSCore_CanUseLocalCleanCache() ? 1 : 0,
		BSCore_GetLocalCleanCacheSize(),
		g_iCoreRegisteredModuleMask,
		szModules,
		g_bCoreHasL4D2ChangeLevel ? 1 : 0,
		g_bCorePrimaryReady ? 1 : 0,
		g_bCoreCacheReady ? 1 : 0
	);

	return Plugin_Handled;
}

Action Command_BSCoreCacheInstall(int iClient, int iArgs)
{
	if (g_dbCoreCache == null)
	{
		CReplyToCommand(iClient, "%t", "BSCoreCacheHandleNotConnected");
		return Plugin_Handled;
	}

	BSCore_InstallCacheSchema();
	CReplyToCommand(iClient, "%t", "BSCoreCacheInstallRequested");
	return Plugin_Handled;
}

Action Command_BSCoreCacheReinstall(int iClient, int iArgs)
{
	if (g_dbCoreCache == null)
	{
		CReplyToCommand(iClient, "%t", "BSCoreCacheHandleNotConnected");
		return Plugin_Handled;
	}

	BSCore_DropCacheSchema();
	BSCore_InstallCacheSchema();
	CReplyToCommand(iClient, "%t", "BSCoreCacheReinstallRequested");
	return Plugin_Handled;
}
