#if defined _bansystem_shared_included
	#endinput
#endif
#define _bansystem_shared_included

#define BANSYSTEM_AUTOEXEC_FOLDER "sourcemod/bansystem"
#define BANSYSTEM_AUTOEXEC_FOLDER_PATH "../../cfg/sourcemod/bansystem"

stock void BSEnsureAutoExecFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	char szFolderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFolderPath, sizeof(szFolderPath), BANSYSTEM_AUTOEXEC_FOLDER_PATH);
	if (!DirExists(szFolderPath))
		CreateDirectory(szFolderPath);

	s_bEnsured = true;
}
