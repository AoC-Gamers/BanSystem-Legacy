/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_COMM_LIBRARY "bansystem_comm"
#define BANSYSTEM_COMM_MODULE_NAME "communication"
#define BANSYSTEM_COMM_MODULE_BIT 2
#define BANSYSTEM_SCHEMA_META_TABLE "bansystem_schema_meta"
#define BANSYSTEM_COMM_SCHEMA_COMPONENT "comm"
#define BANSYSTEM_COMM_SCHEMA_VERSION 1

enum eBSCommType
{
	kBSCommType_None = 0,
	kBSCommType_Mic = 1,
	kBSCommType_Chat = 2,
	kBSCommType_All = 3
}

enum eBSCommDebugMask
{
	kBSCommDebug_None = 0,
	kBSCommDebug_General = 1,
	kBSCommDebug_SQL = 2,
	kBSCommDebug_Menu = 4,
	kBSCommDebug_API = 8
}
