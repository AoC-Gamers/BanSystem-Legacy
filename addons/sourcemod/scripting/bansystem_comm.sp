#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <steamidtools>
#include <basecomm>

#undef REQUIRE_PLUGIN
#include <bansystem_core>
#define REQUIRE_PLUGIN

#define BANSYSTEM_COMM_VERSION "0.1.0-dev"
#define BANSYSTEM_COMM_DEBUG_LOG "logs/BanSystem_Comm.log"
#define BANSYSTEM_COMM_MAX_REASON_LENGTH 256

Database g_dbBSComm;
StringMap g_smBSCommIdentityRequestContext;

ConVar g_cvBSCommDebugMask;
ConVar g_cvBSCommMysqlConfig;
ConVar g_cvBSCommSteamIdProvider;

char g_szBSCommLogPath[PLATFORM_MAX_PATH];

bool g_bBSCommHasCoreLibrary;
bool g_bBSCommDatabaseReady;

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
	int m_iCommType;
	char m_szPlayerName[MAX_NAME_LENGTH];
	char m_szSteamId64[32];
	char m_szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char m_szContext[512];
	char m_szBannedByName[MAX_NAME_LENGTH];
	char m_szBannedBySteamId64[32];
	int m_iDateExpireTs;
}

eBSCommResolvedDetail g_eBSCommResolvedDetail[MAXPLAYERS + 1];

#include "bansystem_comm/schema.sp"
#include "bansystem_comm/helpers.sp"
#include "bansystem_comm/api.sp"
#include "bansystem_comm/db.sp"
#include "bansystem_comm/commands.sp"
#include "bansystem_comm/panels.sp"
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
	BuildPath(Path_SM, g_szBSCommLogPath, sizeof(g_szBSCommLogPath), BANSYSTEM_COMM_DEBUG_LOG);
	LoadTranslations("bansystem_modular.phrases");
	g_smBSCommIdentityRequestContext = new StringMap();
	g_cvBSCommDebugMask = CreateConVar("sm_bs_comm_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api.", FCVAR_NONE, true, 0.0);
	g_cvBSCommMysqlConfig = CreateConVar("sm_bs_comm_mysql_config", "bansystem", "MySQL config used by BanSystem Comm.", FCVAR_NONE);
	g_cvBSCommSteamIdProvider = CreateConVar("sm_bs_comm_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.", FCVAR_NONE);
	g_bBSCommHasCoreLibrary = LibraryExists("bansystem_core");

	BSComm_OnPluginStart_Api();
	BSComm_OnPluginStart_DB();
	BSComm_OnPluginStart_Commands();
	BSComm_OnPluginStart_Panels();
	BSComm_OnPluginStart_Mutations();
	BSComm_OnPluginStart_Detail();
	BSComm_TryRegisterCoreModule();

	BSComm_Debug("Comm scaffold initialized. core=%d", g_bBSCommHasCoreLibrary ? 1 : 0);
}

public void OnConfigsExecuted()
{
	BSComm_ConnectDatabase();
}

public void OnClientDisconnect(int iClient)
{
	BSComm_ResetResolvedDetail(iClient);
	BSComm_ResetPanelState(iClient);
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	return BSComm_HandlePanelSayCommand(iClient, szCommand, szArgs);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSCommHasCoreLibrary = true;
		BSComm_TryRegisterCoreModule();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
		g_bBSCommHasCoreLibrary = false;
}
