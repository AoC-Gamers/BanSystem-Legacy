/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_SPRAYS_LIBRARY "bansystem_sprays"
#define BANSYSTEM_SPRAYS_MODULE_NAME "sprays"
#define BANSYSTEM_SPRAYS_MODULE_BIT 4
#define BANSYSTEM_SCHEMA_META_TABLE "bansystem_schema_meta"
#define BANSYSTEM_SPRAYS_SCHEMA_COMPONENT "sprays"
#define BANSYSTEM_SPRAYS_SCHEMA_VERSION 1
#define BANSYSTEM_SPRAYS_MYSQL_TABLE_BANS "bansystem_spray_bans"
#define BANSYSTEM_SPRAYS_MYSQL_VIEW_BANS_ACTIVE "view_bansystem_spray_bans_active"

enum eBSSpraysDebugMask
{
	kBSSpraysDebug_None = 0,
	kBSSpraysDebug_General = 1,
	kBSSpraysDebug_SQL = 2,
	kBSSpraysDebug_Menu = 4,
	kBSSpraysDebug_API = 8
}
