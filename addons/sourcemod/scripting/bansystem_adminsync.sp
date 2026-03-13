#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <steamidtools>

#define PLUGIN_VERSION "0.1.0"
#define ADMINSYNC_DEBUG_LOG "logs/BanSystem_AdminSync.log"

#define MYSQL_TABLE_ADMINS "adminsync_admins"
#define MYSQL_TABLE_GROUPS "adminsync_groups"
#define MYSQL_TABLE_ADMINS_GROUPS "adminsync_admins_groups"

enum SnapshotBackend
{
	Backend_SQLite = 0,
	Backend_KeyValues
}

enum eAdminSyncDebugMask
{
	kASDebug_None    = 0,
	kASDebug_General = 1,
	kASDebug_SQL     = 2,
	kASDebug_Menu    = 4,
	kASDebug_API     = 8
}

public Plugin myinfo =
{
	name = "BanSystem Admin Sync",
	author = "lechuga",
	description = "Synchronizes admins and groups from MySQL to a local snapshot",
	version = PLUGIN_VERSION,
	url = "https://github.com/AoC-Gamers/AoC-L4D2-Competitive"
};

Database g_dbLocal;
ConVar g_cvMysqlConfig;
ConVar g_cvBackend;
ConVar g_cvAutoSync;
ConVar g_cvCheckInterval;
ConVar g_cvSteamIdProvider;
ConVar g_cvDebug;

char g_szKvSnapshotPath[PLATFORM_MAX_PATH];
char g_szDebugLogPath[PLATFORM_MAX_PATH];

bool g_bSyncInProgress;
bool g_bVersionCheckInFlight;
int g_iLastAdminCount;
int g_iLastGroupCount;
int g_iLastMembershipCount;
int g_iLastSyncAt;
int g_iLastSnapshotVersion;
Handle g_hVersionCheckTimer;
StringMap g_smIdentityRequestContext;

enum AdminSyncPromptState
{
	Prompt_None = 0,
	Prompt_AdminAddFlags,
	Prompt_AdminAddImmunity,
	Prompt_AdminEditFlags,
	Prompt_AdminEditImmunity,
	Prompt_GroupAddName,
	Prompt_GroupAddFlags,
	Prompt_GroupAddImmunity,
	Prompt_GroupEditFlags,
	Prompt_GroupEditImmunity
}

AdminSyncPromptState g_ePromptState[MAXPLAYERS + 1];
int g_iPromptAccountId[MAXPLAYERS + 1];
int g_iPromptImmunity[MAXPLAYERS + 1];
int g_iPanelAction[MAXPLAYERS + 1];
char g_szPromptName[MAXPLAYERS + 1][128];
char g_szPromptFlags[MAXPLAYERS + 1][64];
char g_szPromptSteamId64[MAXPLAYERS + 1][32];
char g_szPromptGroupName[MAXPLAYERS + 1][128];

enum AdminSyncIdentityAction
{
	IdentityAction_None = 0,
	IdentityAction_AdminAdd,
	IdentityAction_AdminDelete,
	IdentityAction_AdminSetFlags,
	IdentityAction_AdminSetImmunity,
	IdentityAction_AdminAddGroup,
	IdentityAction_AdminRemoveGroup
}

#include "adminsync/helpers.sp"
#include "adminsync/api.sp"
#include "adminsync/commands.sp"
#include "adminsync/snapshot.sp"
#include "adminsync/admincache.sp"
#include "adminsync/db.sp"
#include "adminsync/mutations.sp"
#include "adminsync/panels.sp"

public void OnPluginStart()
{
	g_cvMysqlConfig = CreateConVar("sm_bs_adminsync_mysql_config", "bansystem", "MySQL config name used by BanSystem Admin Sync.");
	g_cvBackend = CreateConVar("sm_bs_adminsync_backend", "sqlite", "Local snapshot backend: sqlite or kv.");
	g_cvAutoSync = CreateConVar("sm_bs_adminsync_autosync", "1", "Synchronize the local snapshot on plugin start.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvCheckInterval = CreateConVar("sm_bs_adminsync_check_interval", "60.0", "Seconds between lightweight snapshot version checks. 0 disables version polling.", FCVAR_NONE, true, 0.0);
	g_cvSteamIdProvider = CreateConVar("sm_bs_adminsync_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.");
	g_cvDebug = CreateConVar("sm_bs_adminsync_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api.", FCVAR_NONE, true, 0.0);

	vOnPluginStart_Commands();
	vOnPluginStart_Panels();

	BuildPath(Path_SM, g_szKvSnapshotPath, sizeof(g_szKvSnapshotPath), "data/bansystem_adminsync_snapshot.txt");
	BuildPath(Path_SM, g_szDebugLogPath, sizeof(g_szDebugLogPath), ADMINSYNC_DEBUG_LOG);
	g_smIdentityRequestContext = new StringMap();
	vConnectLocalSnapshot();
	vRestartVersionCheckTimer();

	if (g_cvAutoSync.BoolValue)
		vStartAdminSync();
}

public void OnConfigsExecuted()
{
	vRestartVersionCheckTimer();
}

public void OnMapEnd()
{
	g_hVersionCheckTimer = null;
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrMax)
{
	vRegisterAdminSyncApi();
	return APLRes_Success;
}
