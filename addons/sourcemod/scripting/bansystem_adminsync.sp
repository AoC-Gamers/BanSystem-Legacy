#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#include <steamidtools_helpers>
#define REQUIRE_PLUGIN

#include <bansystem_shared>

#define PLUGIN_VERSION "0.1.0"
#define ADMINSYNC_DEBUG_LOG "logs/BanSystem_AdminSync.log"

#define MYSQL_TABLE_ADMINS "adminsync_admins"
#define MYSQL_TABLE_GROUPS "adminsync_groups"
#define MYSQL_TABLE_ADMINS_GROUPS "adminsync_admins_groups"
#define MYSQL_TABLE_SCHEMA_META "bansystem_schema_meta"
#define ADMINSYNC_SCHEMA_COMPONENT "adminsync"
#define ADMINSYNC_SCHEMA_VERSION 1

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
	url = "https://github.com/AoC-Gamers/BanSystem"
};

Database g_dbLocal;
ConVar g_cvMysqlConfig;
ConVar g_cvBackend;
ConVar g_cvAutoSync;
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
StringMap g_smIdentityRequestContext;

enum AdminSyncIdentityAction
{
	IdentityAction_None = 0,
	IdentityAction_AdminAdd,
	IdentityAction_AdminAddResolveSteam64,
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

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("bansystem_adminsync.phrases");
	g_cvMysqlConfig = CreateConVar("sm_bs_adminsync_mysql_config", "bansystem", "MySQL config name used by BanSystem Admin Sync.");
	g_cvBackend = CreateConVar("sm_bs_adminsync_backend", "sqlite", "Local snapshot backend: sqlite or kv.");
	g_cvAutoSync = CreateConVar("sm_bs_adminsync_autosync", "1", "Synchronize the local snapshot on plugin start.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSteamIdProvider = CreateConVar("sm_bs_adminsync_steamid_provider", "auto", "SteamIDTools provider for SteamID64 resolution: auto, steamworks or system2.");
	g_cvDebug = CreateConVar("sm_bs_adminsync_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api (all=15).", FCVAR_NONE, true, 0.0);

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_adminsync", BANSYSTEM_AUTOEXEC_FOLDER);

	vOnPluginStart_Commands();

	BuildPath(Path_SM, g_szKvSnapshotPath, sizeof(g_szKvSnapshotPath), "data/bansystem_adminsync_snapshot.txt");
	BuildPath(Path_SM, g_szDebugLogPath, sizeof(g_szDebugLogPath), ADMINSYNC_DEBUG_LOG);
	g_smIdentityRequestContext = new StringMap();
	vConnectLocalSnapshot();

	if (g_cvAutoSync.BoolValue)
		vStartAdminSync();
}

public void OnConfigsExecuted()
{
	vRequestSnapshotVersionCheck();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrMax)
{
	vRegisterAdminSyncApi();
	return APLRes_Success;
}
