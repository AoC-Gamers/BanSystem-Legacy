#if defined _bansystem_shared_included
	#endinput
#endif
#define _bansystem_shared_included

#define BANSYSTEM_AUTOEXEC_FOLDER "sourcemod/bansystem"
#define BANSYSTEM_AUTOEXEC_FOLDER_PATH "../../cfg/sourcemod/bansystem"
#define BANSYSTEM_SM_LOGS_FOLDER "logs"
#define BANSYSTEM_LOG_FOLDER "logs/bansystem"
#define BANSYSTEM_LOG_FOLDER_PATH BANSYSTEM_LOG_FOLDER

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

stock void BSEnsureLogFolder()
{
	char szLogsPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szLogsPath, sizeof(szLogsPath), BANSYSTEM_SM_LOGS_FOLDER);
	if (!DirExists(szLogsPath))
		CreateDirectory(szLogsPath, 511);

	char szFolderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFolderPath, sizeof(szFolderPath), BANSYSTEM_LOG_FOLDER_PATH);
	if (!DirExists(szFolderPath))
		CreateDirectory(szFolderPath, 511);
	}

stock void BSLogToFileEx(const char[] szLogPath, const char[] szFormat, any ...)
{
	BSEnsureLogFolder();

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	LogToFileEx(szLogPath, "%s", szBuffer);
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
