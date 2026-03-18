/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_ACCESS_LIBRARY "bansystem_access"
#define BANSYSTEM_ACCESS_MODULE_NAME "access"
#define BANSYSTEM_SCHEMA_META_TABLE "bansystem_schema_meta"
#define BANSYSTEM_ACCESS_SCHEMA_COMPONENT "access"
#define BANSYSTEM_ACCESS_SCHEMA_VERSION 1
#define BANSYSTEM_ACCESS_MYSQL_TABLE_BANS "bansystem_access_bans"
#define BANSYSTEM_ACCESS_MYSQL_VIEW_BANS_ACTIVE "view_bansystem_access_bans_active"

enum eBSAccessDebugMask
{
	kBSAccessDebug_None = 0,
	kBSAccessDebug_General = 1,
	kBSAccessDebug_SQL = 2,
	kBSAccessDebug_Menu = 4,
	kBSAccessDebug_API = 8
}
