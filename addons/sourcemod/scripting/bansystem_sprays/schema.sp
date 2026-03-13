/*****************************************************************
			S C H E M A
*****************************************************************/

#define BANSYSTEM_SPRAYS_LIBRARY "bansystem_sprays"
#define BANSYSTEM_SPRAYS_MODULE_NAME "sprays"
#define BANSYSTEM_SPRAYS_MODULE_BIT 4

enum eBSSpraysDebugMask
{
	kBSSpraysDebug_None = 0,
	kBSSpraysDebug_General = 1,
	kBSSpraysDebug_SQL = 2,
	kBSSpraysDebug_Menu = 4,
	kBSSpraysDebug_API = 8
}
