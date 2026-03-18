#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#include <steamidtools_helpers>
#include <bansystem_core>
#define REQUIRE_PLUGIN

#define BANSYSTEM_ACCESS_VERSION "0.1.0-dev"
#define BANSYSTEM_ACCESS_DEBUG_LOG "logs/bansystem/BanSystem_Access.log"
#define BANSYSTEM_ACCESS_MAX_REASON_LENGTH 256
#define BANSYSTEM_ACCESS_APPLY_RETRY_INTERVAL 0.1
#define BANSYSTEM_ACCESS_APPLY_MAX_RETRIES 20

Database g_dbBSAccess;
StringMap g_smBSAccessIdentityRequestContext;
StringMap g_smBSAccessAttemptIpCache;
GlobalForward g_gfBSAccessOnClientDenied;
Handle g_hBSAccessPendingApplyTimer[MAXPLAYERS + 1];

ConVar g_cvBSAccessDebugMask;
ConVar g_cvBSAccessMysqlConfig;
ConVar g_cvBSAccessSteamIdProvider;
ConVar g_cvBSLogMode;

char g_szBSAccessLogPath[PLATFORM_MAX_PATH];

bool g_bBSAccessHasCoreLibrary;
bool g_bBSAccessDatabaseReady;

enum eBSAccessIdentityAction
{
	kBSAccessIdentityAction_None = 0,
	kBSAccessIdentityAction_Add,
	kBSAccessIdentityAction_Remove,
	kBSAccessIdentityAction_Info
}

enum struct eBSAccessResolvedDetail
{
	bool m_bLoaded;
	int m_iBanId;
	int m_iAccountId;
	int m_iLength;
	int m_iBannedBy;
	char m_szPlayerName[MAX_NAME_LENGTH];
	char m_szSteamId64[32];
	char m_szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
	char m_szContext[512];
	char m_szBannedByName[MAX_NAME_LENGTH];
	char m_szBannedBySteamId64[32];
	int m_iDateExpireTs;
}

eBSAccessResolvedDetail g_eBSAccessResolvedDetail[MAXPLAYERS + 1];

void BSAccess_CancelPendingApplyTimer(int iClient);
void BSAccess_ScheduleResolvedBanApplyRetry(int iClient, int iAttempt);
void BSAccess_FinalizeResolvedBanToClient(int iClient, bool bPrintConsole);

#include "bansystem_access/schema.sp"
#include "bansystem_access/helpers.sp"
#include "bansystem_access/api.sp"
#include "bansystem_access/db.sp"
#include "bansystem_access/commands.sp"
#include "bansystem_access/mutations.sp"
#include "bansystem_access/detail.sp"

public Plugin myinfo =
{
	name = "BanSystem Access",
	author = "lechuga",
	description = "Access module scaffold for BanSystem Core.",
	version = BANSYSTEM_ACCESS_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BSAccess_RegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szBSAccessLogPath, sizeof(g_szBSAccessLogPath), BANSYSTEM_ACCESS_DEBUG_LOG);
	LoadTranslations("common.phrases");
	LoadTranslations("bansystem_access.phrases");
	g_smBSAccessIdentityRequestContext = new StringMap();
	g_cvBSLogMode = BSEnsureLogModeConVar();
	g_cvBSAccessDebugMask = CreateConVar("sm_bs_access_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api (all=15).", FCVAR_NONE, true, 0.0);
	g_cvBSAccessMysqlConfig = CreateConVar("sm_bs_access_mysql_config", "bansystem", "MySQL config used by BanSystem Access.", FCVAR_NONE);
	g_cvBSAccessSteamIdProvider = CreateConVar("sm_bs_access_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.", FCVAR_NONE);
	g_bBSAccessHasCoreLibrary = LibraryExists("bansystem_core");

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_access", BANSYSTEM_AUTOEXEC_FOLDER);

	BSAccess_OnPluginStart_Api();
	BSAccess_OnPluginStart_DB();
	BSAccess_OnPluginStart_Commands();
	BSAccess_OnPluginStart_Mutations();
	BSAccess_OnPluginStart_Detail();
	BSAccess_TryRegisterCoreModule();
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Access]", "startup", "Plugin started. version=%s core=%d", BANSYSTEM_ACCESS_VERSION, g_bBSAccessHasCoreLibrary ? 1 : 0);

	BSAccess_Debug("Access scaffold initialized. core=%d", g_bBSAccessHasCoreLibrary ? 1 : 0);
}

public void OnConfigsExecuted()
{
	BSAccess_ConnectDatabase();
}

public void OnClientDisconnect(int iClient)
{
	delete g_hBSAccessPendingApplyTimer[iClient];
	BSAccess_ResetResolvedDetail(iClient);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSAccessHasCoreLibrary = true;
		BSAccess_TryRegisterCoreModule();
		if (BSCore_IsAuthReady())
			BSAccess_ReconcileAllAccessStatesFromCore();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSAccessHasCoreLibrary = false;
	}
}

public void BSCore_OnAuthReadyChanged(bool bReady)
{
	BSAccess_SQL("Received core auth ready changed event: ready=%d db_ready=%d", bReady ? 1 : 0, BSAccess_CanUseDatabase() ? 1 : 0);
	if (bReady)
		BSAccess_ReconcileAllAccessStatesFromCore();
}
