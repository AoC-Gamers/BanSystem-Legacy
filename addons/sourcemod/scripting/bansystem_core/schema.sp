/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_CORE_LIBRARY "bansystem_core"

#define BANSYSTEM_SCHEMA_META_TABLE "bansystem_schema_meta"
#define BANSYSTEM_CORE_SCHEMA_COMPONENT "core"
#define BANSYSTEM_CORE_SCHEMA_VERSION 3
#define BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY "bansystem_summary"
#define BANSYSTEM_CORE_MYSQL_VIEW_AUTH_SUMMARY "view_bansystem_auth_summary"
#define BANSYSTEM_CORE_MYSQL_VIEW_ACTIVE_SUMMARY "view_bansystem_active_summary"

#define BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY "bansystem_cache_summary"
#define BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE "view_bansystem_cache_summary_active"
#define BANSYSTEM_CORE_SQLITE_TRIGGER_SUMMARY_UPSERT "trg_bansystem_cache_summary_before_insert"
#define BANSYSTEM_CORE_SQL_OBJECT_TABLE "table"
#define BANSYSTEM_CORE_SQL_OBJECT_TRIGGER "trigger"
#define BANSYSTEM_CORE_SQL_OBJECT_VIEW "view"

#define BANSYSTEM_CORE_STEAMID64_BASE_STRING "76561197960265728"

enum eBSCoreModuleBit
{
	kBSCoreModule_None = 0,
	kBSCoreModule_Access = 1,
	kBSCoreModule_Communication = 2,
	kBSCoreModule_Sprays = 4
}

enum eBSCoreCommType
{
	kBSCoreComm_None = 0,
	kBSCoreComm_Mic = 1,
	kBSCoreComm_Chat = 2,
	kBSCoreComm_All = 3
}

enum eBSCoreIdentityResolution
{
	kBSCoreIdentityResolution_Invalid = 0,
	kBSCoreIdentityResolution_Resolved,
	kBSCoreIdentityResolution_OnlinePending
}

enum eBSCoreAuthState
{
	kBSCoreAuthState_Idle = 0,
	kBSCoreAuthState_Queued,
	kBSCoreAuthState_Checking
}

enum eBSCoreDebugMask
{
	kBSCoreDebug_None = 0,
	kBSCoreDebug_General = 1,
	kBSCoreDebug_SQL = 2,
	kBSCoreDebug_Transition = 4,
	kBSCoreDebug_API = 8
}
