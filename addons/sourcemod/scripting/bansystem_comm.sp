#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#include <steamidtools_helpers>
#include <basecomm>
#include <bansystem_core>
#define REQUIRE_PLUGIN

#define BANSYSTEM_COMM_VERSION "1.1.0"
#define BANSYSTEM_COMM_DEBUG_LOG "logs/bansystem/BanSystem_Comm.log"
#define BANSYSTEM_COMM_MAX_REASON_LENGTH 256

Database g_dbBSComm;
StringMap g_smBSCommIdentityRequestContext;

ConVar g_cvBSCommDebugMask;
ConVar g_cvBSCommMysqlConfig;
ConVar g_cvBSCommSteamIdProvider;
ConVar g_cvBSLogMode;

char g_szBSCommLogPath[PLATFORM_MAX_PATH];

bool g_bBSCommHasCoreLibrary;
bool g_bBSCommHasBaseComm;
bool g_bBSCommDatabaseReady;

#include "bansystem_comm/schema.sp"

enum eBSCommIdentityAction
{
	kBSCommIdentityAction_None = 0,
	kBSCommIdentityAction_Add,
	kBSCommIdentityAction_Remove,
	kBSCommIdentityAction_Info
}

enum struct eBSCommResolvedDetail
{
	bool m_bLoaded;
	int m_iBanId;
	int m_iAccountId;
	int m_iLength;
	int m_iBannedBy;
	eBSCommType m_eCommType;
	char m_szPlayerName[MAX_NAME_LENGTH];
	char m_szSteamId64[32];
	char m_szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char m_szContext[512];
	char m_szBannedByName[MAX_NAME_LENGTH];
	char m_szBannedBySteamId64[32];
	int m_iDateExpireTs;
}

eBSCommResolvedDetail g_eBSCommResolvedDetail[MAXPLAYERS + 1];

#include "bansystem_comm/helpers.sp"
#include "bansystem_comm/api.sp"
#include "bansystem_comm/db.sp"
#include "bansystem_comm/commands.sp"
#include "bansystem_comm/mutations.sp"
#include "bansystem_comm/detail.sp"

public Plugin myinfo =
{
	name = "BanSystem Comm",
	author = "lechuga",
	description = "Communication module scaffold for BanSystem Core.",
	version = BANSYSTEM_COMM_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BSComm_RegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szBSCommLogPath, sizeof(g_szBSCommLogPath), BANSYSTEM_COMM_DEBUG_LOG);
	LoadTranslations("common.phrases");
	LoadTranslations("bansystem_comm.phrases");
	g_smBSCommIdentityRequestContext = new StringMap();
	g_cvBSLogMode = BSEnsureLogModeConVar();
	g_cvBSCommDebugMask = CreateConVar("sm_bs_comm_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api (all=15).", FCVAR_NONE, true, 0.0);
	g_cvBSCommMysqlConfig = CreateConVar("sm_bs_comm_mysql_config", "bansystem", "MySQL config used by BanSystem Comm.", FCVAR_NONE);
	g_cvBSCommSteamIdProvider = CreateConVar("sm_bs_comm_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.", FCVAR_NONE);
	g_bBSCommHasCoreLibrary = LibraryExists("bansystem_core");
	g_bBSCommHasBaseComm = LibraryExists("basecomm");

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_comm", BANSYSTEM_AUTOEXEC_FOLDER);

	BSComm_OnPluginStart_Api();
	BSComm_OnPluginStart_DB();
	BSComm_OnPluginStart_Commands();
	BSComm_OnPluginStart_Mutations();
	BSComm_OnPluginStart_Detail();
	BSComm_TryRegisterCoreModule();
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Comm]", "startup", "Plugin started. version=%s core=%d basecomm=%d", BANSYSTEM_COMM_VERSION, g_bBSCommHasCoreLibrary ? 1 : 0, g_bBSCommHasBaseComm ? 1 : 0);

	BSComm_Debug("Comm scaffold initialized. core=%d basecomm=%d", g_bBSCommHasCoreLibrary ? 1 : 0, g_bBSCommHasBaseComm ? 1 : 0);
}

public void OnConfigsExecuted()
{
	BSComm_ConnectDatabase();
}

public void OnClientDisconnect(int iClient)
{
	BSComm_ResetResolvedDetail(iClient);
}

public void OnClientPutInServer(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || IsFakeClient(iClient))
		return;

	if (g_eBSCommResolvedDetail[iClient].m_bLoaded)
	{
		BSComm_ApplyResolvedCommState(iClient);
		return;
	}

	if (!BSComm_CanUseCoreLibrary() || !BSComm_CanUseDatabase() || !BSCore_HasResolvedSummary(iClient))
		return;

	BSComm_ReconcileClientCommStateFromCore(iClient);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSCommHasCoreLibrary = true;
		BSComm_TryRegisterCoreModule();
		if (BSCore_IsAuthReady())
			BSComm_ReconcileAllCommStatesFromCore();
		return;
	}

	if (StrEqual(szName, "basecomm", false))
	{
		g_bBSCommHasBaseComm = true;
		BSComm_ReapplyResolvedCommStateToAllClients();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSCommHasCoreLibrary = false;
		return;
	}

	if (StrEqual(szName, "basecomm", false))
	{
		g_bBSCommHasBaseComm = false;
	}
}

public void BSCore_OnAuthReadyChanged(bool bReady)
{
	BSComm_SQL("Received core auth ready changed event: ready=%d core_ready=%d db_ready=%d", bReady ? 1 : 0, BSComm_CanUseCoreLibrary() ? 1 : 0, BSComm_CanUseDatabase() ? 1 : 0);
	if (!bReady || !BSComm_CanUseCoreLibrary() || !BSComm_CanUseDatabase())
		return;

	BSComm_ReconcileAllCommStatesFromCore();
}
