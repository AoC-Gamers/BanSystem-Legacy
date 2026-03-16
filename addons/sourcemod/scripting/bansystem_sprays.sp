#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#include <steamidtools_helpers>
#define REQUIRE_PLUGIN

#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <bansystem_core>
#define REQUIRE_PLUGIN

#define BANSYSTEM_SPRAYS_VERSION "0.1.0-dev"
#define BANSYSTEM_SPRAYS_DEBUG_LOG "logs/bansystem/BanSystem_Sprays.log"
#define BANSYSTEM_SPRAYS_MAX_REASON_LENGTH 256

Database g_dbBSSprays;
StringMap g_smBSSpraysIdentityRequestContext;

ConVar g_cvBSSpraysDebugMask;
ConVar g_cvBSSpraysMysqlConfig;
ConVar g_cvBSSpraysSteamIdProvider;

char g_szBSSpraysLogPath[PLATFORM_MAX_PATH];

bool g_bBSSpraysHasCoreLibrary;
bool g_bBSSpraysDatabaseReady;

enum eBSSpraysIdentityAction
{
	kBSSpraysIdentityAction_None = 0,
	kBSSpraysIdentityAction_Add,
	kBSSpraysIdentityAction_Remove,
	kBSSpraysIdentityAction_Info
}

enum struct eBSSpraysResolvedDetail
{
	bool m_bLoaded;
	int m_iBanId;
	int m_iAccountId;
	int m_iLength;
	int m_iBannedBy;
	char m_szPlayerName[MAX_NAME_LENGTH];
	char m_szSteamId64[32];
	char m_szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char m_szContext[512];
	char m_szBannedByName[MAX_NAME_LENGTH];
	char m_szBannedBySteamId64[32];
	int m_iDateExpireTs;
}

eBSSpraysResolvedDetail g_eBSSpraysResolvedDetail[MAXPLAYERS + 1];

#include "bansystem_sprays/schema.sp"
#include "bansystem_sprays/helpers.sp"
#include "bansystem_sprays/api.sp"
#include "bansystem_sprays/db.sp"
#include "bansystem_sprays/commands.sp"
#include "bansystem_sprays/mutations.sp"
#include "bansystem_sprays/detail.sp"

public Plugin myinfo =
{
	name = "BanSystem Sprays",
	author = "lechuga",
	description = "Sprays module scaffold for BanSystem Core.",
	version = BANSYSTEM_SPRAYS_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BSSprays_RegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szBSSpraysLogPath, sizeof(g_szBSSpraysLogPath), BANSYSTEM_SPRAYS_DEBUG_LOG);
	LoadTranslations("bansystem_sprays.phrases");
	g_smBSSpraysIdentityRequestContext = new StringMap();
	g_cvBSSpraysDebugMask = CreateConVar("sm_bs_sprays_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api (all=15).", FCVAR_NONE, true, 0.0);
	g_cvBSSpraysMysqlConfig = CreateConVar("sm_bs_sprays_mysql_config", "bansystem", "MySQL config used by BanSystem Sprays.", FCVAR_NONE);
	g_cvBSSpraysSteamIdProvider = CreateConVar("sm_bs_sprays_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.", FCVAR_NONE);
	g_bBSSpraysHasCoreLibrary = LibraryExists("bansystem_core");

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_sprays", BANSYSTEM_AUTOEXEC_FOLDER);

	BSSprays_OnPluginStart_Api();
	BSSprays_OnPluginStart_DB();
	BSSprays_OnPluginStart_Commands();
	BSSprays_OnPluginStart_Mutations();
	BSSprays_OnPluginStart_Detail();
	BSSprays_TryRegisterCoreModule();
	AddTempEntHook("Player Decal", BSSprays_OnPlayerDecal);

	BSSprays_Debug("Sprays scaffold initialized. core=%d", g_bBSSpraysHasCoreLibrary ? 1 : 0);
}

public void OnConfigsExecuted()
{
	BSSprays_ConnectDatabase();
}

public void OnClientDisconnect(int iClient)
{
	BSSprays_ResetResolvedDetail(iClient);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSSpraysHasCoreLibrary = true;
		BSSprays_TryRegisterCoreModule();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
		g_bBSSpraysHasCoreLibrary = false;
}
