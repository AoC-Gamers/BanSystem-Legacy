#if defined _bansystem_shared_included
	#endinput
#endif
#define _bansystem_shared_included

#define BANSYSTEM_AUTOEXEC_FOLDER "sourcemod/bansystem"
#define BANSYSTEM_AUTOEXEC_FOLDER_PATH "../../cfg/sourcemod/bansystem"
#define BANSYSTEM_SM_LOGS_FOLDER "logs"
#define BANSYSTEM_LOG_FOLDER "logs/bansystem"
#define BANSYSTEM_LOG_FOLDER_PATH BANSYSTEM_LOG_FOLDER
#define BANSYSTEM_NORMAL_LOG_FILE "logs/bansystem.log"

enum BSLogMode
{
	kBSLogMode_Off = 0,
	kBSLogMode_Normal,
	kBSLogMode_Debug
}

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

stock ConVar BSEnsureLogModeConVar()
{
	ConVar cvLogMode = CreateConVar("sm_bs_log_mode", "0", "BanSystem log mode. 0=off, 1=normal, 2=debug.", FCVAR_NONE, true, 0.0, true, 2.0);
	if (cvLogMode != null)
		return cvLogMode;

	return FindConVar("sm_bs_log_mode");
}

stock bool BSIsNormalLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(kBSLogMode_Normal));
}

stock bool BSIsDebugLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(kBSLogMode_Debug));
}

stock bool BSDebugMaskEnabled(ConVar cvLogMode, ConVar cvDebugMask, int iMask)
{
	if (!BSIsDebugLogMode(cvLogMode) || cvDebugMask == null)
		return false;

	return ((cvDebugMask.IntValue & iMask) != 0);
}

stock void BSEnsureSMLogsFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	char szLogsPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szLogsPath, sizeof(szLogsPath), BANSYSTEM_SM_LOGS_FOLDER);
	if (!DirExists(szLogsPath))
		CreateDirectory(szLogsPath, 511);

	s_bEnsured = DirExists(szLogsPath);
}

stock void BSEnsureLogFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	BSEnsureSMLogsFolder();

	ConVar cvLogMode = FindConVar("sm_bs_log_mode");
	if (!BSIsDebugLogMode(cvLogMode))
		return;

	char szFolderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFolderPath, sizeof(szFolderPath), BANSYSTEM_LOG_FOLDER_PATH);
	if (!DirExists(szFolderPath))
		CreateDirectory(szFolderPath, 511);

	s_bEnsured = DirExists(szFolderPath);
}

stock void BSBuildNormalLogPath(char[] szLogPath, int iMaxLength)
{
	BSEnsureSMLogsFolder();
	BuildPath(Path_SM, szLogPath, iMaxLength, BANSYSTEM_NORMAL_LOG_FILE);
}

stock void BSLogToFileEx(const char[] szLogPath, const char[] szFormat, any ...)
{
	BSEnsureLogFolder();

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	LogToFileEx(szLogPath, "%s", szBuffer);
}

stock void BSNormalLogToFileEx(ConVar cvLogMode, const char[] szPrefix, const char[] szTag, const char[] szFormat, any ...)
{
	if (!BSIsNormalLogMode(cvLogMode))
		return;

	char szLogPath[PLATFORM_MAX_PATH];
	BSBuildNormalLogPath(szLogPath, sizeof(szLogPath));

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 5);

	if (szTag[0] != '\0')
		LogToFileEx(szLogPath, "%s[%s] %s", szPrefix, szTag, szBuffer);
	else
		LogToFileEx(szLogPath, "%s %s", szPrefix, szBuffer);
}

stock ReplySource BSGetClientPreferredReplySource(int iClient)
{
	if (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient))
		return SM_REPLY_TO_CHAT;

	return SM_REPLY_TO_CONSOLE;
}

stock int BSGetCommandIssuerUserId(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	return GetClientUserId(iClient);
}

stock void BSCReplyToCommandBufferWithSource(int iClient, ReplySource eReplySource, const char[] szMessage)
{
	ReplySource eOldSource = SetCmdReplySource(eReplySource);
	if (iClient > 0)
		SetGlobalTransTarget(iClient);

	CReplyToCommand(iClient, "%s", szMessage);
	SetCmdReplySource(eOldSource);
}

stock void BSCReplyToCommandPreferred(int iClient, const char[] szFormat, any ...)
{
	ReplySource eReplySource = BSGetClientPreferredReplySource(iClient);
	ReplySource eOldSource = SetCmdReplySource(eReplySource);

	static char szBuffer[1024];
	if (iClient > 0)
		SetGlobalTransTarget(iClient);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	CReplyToCommand(iClient, "%s", szBuffer);
	SetCmdReplySource(eOldSource);
}
