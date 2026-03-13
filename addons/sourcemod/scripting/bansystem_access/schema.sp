/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_ACCESS_LIBRARY "bansystem_access"
#define BANSYSTEM_ACCESS_MODULE_NAME "access"

enum eBSAccessDebugMask
{
	kBSAccessDebug_None = 0,
	kBSAccessDebug_General = 1,
	kBSAccessDebug_SQL = 2,
	kBSAccessDebug_Menu = 4,
	kBSAccessDebug_API = 8
}
