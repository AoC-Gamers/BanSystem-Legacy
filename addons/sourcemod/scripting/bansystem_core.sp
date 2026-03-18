#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#define REQUIRE_PLUGIN

#define BANSYSTEM_CORE_VERSION "0.1.0-dev"
#define BANSYSTEM_CORE_DEBUG_LOG "logs/bansystem/BanSystem_Core.log"

Database g_dbCorePrimary;
Database g_dbCoreCache;
GlobalForward g_gfBSCoreOnAuthReadyChanged;
GlobalForward g_gfBSCoreOnAccessDetailRequested;
GlobalForward g_gfBSCoreOnCommDetailRequested;
GlobalForward g_gfBSCoreOnSprayDetailRequested;

ConVar g_cvCoreMysqlConfig;
ConVar g_cvCoreSqliteCache;
ConVar g_cvCoreCacheConfig;
ConVar g_cvCoreLocalCache;
ConVar g_cvCoreAuthTimeout;
ConVar g_cvCoreDebugMask;
ConVar g_cvBSLogMode;

ArrayList g_alCoreLocalCleanCache;
StringMap g_smCoreRegisteredModules;

char g_szCoreLogPath[PLATFORM_MAX_PATH];

bool g_bCorePrimaryReady;
bool g_bCoreCacheReady;
bool g_bCoreAuthReady;
bool g_bCoreMapTransitionActive;
bool g_bCoreHasL4D2ChangeLevel;
eBSCoreModuleBit g_eCoreRegisteredModuleMask;

Handle g_hCoreAuthTimer[MAXPLAYERS + 1];
eBSCoreAuthState g_eCoreAuthState[MAXPLAYERS + 1];
int g_iCoreResolvedAccountId[MAXPLAYERS + 1];
eBSCoreModuleBit g_eCoreResolvedModuleMask[MAXPLAYERS + 1];
eBSCoreCommType g_eCoreResolvedCommType[MAXPLAYERS + 1];
int g_iCoreResolvedAccessBanId[MAXPLAYERS + 1];
int g_iCoreResolvedCommBanId[MAXPLAYERS + 1];
int g_iCoreResolvedSprayBanId[MAXPLAYERS + 1];
int g_iCoreResolvedCommLength[MAXPLAYERS + 1];
char g_szCoreResolvedCommReason[MAXPLAYERS + 1][256];
char g_szCoreResolvedCommContext[MAXPLAYERS + 1][512];
char g_szCoreResolvedCommBannedByName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
int g_iCoreResolvedCommExpireTs[MAXPLAYERS + 1];
int g_iCoreResolvedSprayLength[MAXPLAYERS + 1];
char g_szCoreResolvedSprayReason[MAXPLAYERS + 1][256];
char g_szCoreResolvedSprayContext[MAXPLAYERS + 1][512];
char g_szCoreResolvedSprayBannedByName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
int g_iCoreResolvedSprayExpireTs[MAXPLAYERS + 1];
eBSCoreModuleBit g_eCorePendingDetailMask[MAXPLAYERS + 1];
eBSCoreModuleBit g_eCoreResolvedDetailMask[MAXPLAYERS + 1];

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
	author = "lechuga",
	description = "Core scaffold for modular BanSystem.",
	version = BANSYSTEM_CORE_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BSCore_RegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szCoreLogPath, sizeof(g_szCoreLogPath), BANSYSTEM_CORE_DEBUG_LOG);
	LoadTranslations("bansystem_core.phrases");

	g_cvBSLogMode = BSEnsureLogModeConVar();
	g_cvCoreMysqlConfig = CreateConVar("sm_bs_core_mysql_config", "bansystem", "MySQL config used by BanSystem Core.");
	g_cvCoreSqliteCache = CreateConVar("sm_bs_core_sqlitecache", "1", "Enable the BanSystem Core SQLite summary cache.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvCoreCacheConfig = CreateConVar("sm_bs_core_cache_config", "bansystemcache", "SQLite config used by BanSystem Core.");
	g_cvCoreLocalCache = CreateConVar("sm_bs_core_localcache", "1", "Enable the BanSystem Core local clean cache.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvCoreAuthTimeout = CreateConVar("sm_bs_core_auth_timeout", "8.0", "Seconds to keep a core auth request pending before timing it out.", FCVAR_NONE, true, 1.0);
	g_cvCoreDebugMask = CreateConVar("sm_bs_core_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=transition, 8=api (all=15).", FCVAR_NONE, true, 0.0);

	g_alCoreLocalCleanCache = new ArrayList();
	g_smCoreRegisteredModules = new StringMap();
	g_bCoreMapTransitionActive = true;
	g_bCoreHasL4D2ChangeLevel = LibraryExists("l4d2_changelevel");
	g_eCoreRegisteredModuleMask = kBSCoreModule_None;

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_core", BANSYSTEM_AUTOEXEC_FOLDER);
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Core]", "startup", "Plugin started. version=%s changelevel=%d", BANSYSTEM_CORE_VERSION, g_bCoreHasL4D2ChangeLevel ? 1 : 0);

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
