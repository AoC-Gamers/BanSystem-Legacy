/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSCore_Log(eBSCoreDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvCoreDebugMask == null)
		return;

	int iMask = g_cvCoreDebugMask.IntValue;
	if ((iMask & view_as<int>(eMask)) == 0)
		return;

	BSLogToFileEx(g_szCoreLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSCore_LogFormatted(eBSCoreDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (g_cvCoreDebugMask == null)
		return;

	int iMask = g_cvCoreDebugMask.IntValue;
	if ((iMask & view_as<int>(eMask)) == 0)
		return;

	BSLogToFileEx(g_szCoreLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSCore_Debug(const char[] szMessage, any ...)
{
	if (g_cvCoreDebugMask == null || (g_cvCoreDebugMask.IntValue & view_as<int>(kBSCoreDebug_General)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSCore_LogFormatted(kBSCoreDebug_General, "Debug", szBuffer);
}

stock void BSCore_SQL(const char[] szMessage, any ...)
{
	if (g_cvCoreDebugMask == null || (g_cvCoreDebugMask.IntValue & view_as<int>(kBSCoreDebug_SQL)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSCore_LogFormatted(kBSCoreDebug_SQL, "SQL", szBuffer);
}

stock void BSCore_TransitionLog(const char[] szMessage, any ...)
{
	if (g_cvCoreDebugMask == null || (g_cvCoreDebugMask.IntValue & view_as<int>(kBSCoreDebug_Transition)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSCore_LogFormatted(kBSCoreDebug_Transition, "Transition", szBuffer);
}

stock void BSCore_API(const char[] szMessage, any ...)
{
	if (g_cvCoreDebugMask == null || (g_cvCoreDebugMask.IntValue & view_as<int>(kBSCoreDebug_API)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	BSCore_LogFormatted(kBSCoreDebug_API, "API", szBuffer);
}

stock void BSCore_NormalizeInput(const char[] szInput, char[] szOutput, int iMaxLength)
{
	strcopy(szOutput, iMaxLength, szInput);
	TrimString(szOutput);
	StripQuotes(szOutput);
}

stock bool BSCore_IsUsableClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient));
}

stock int BSCore_GetCommandIssuerUserId(int iClient)
{
	return BSGetCommandIssuerUserId(iClient);
}

stock bool BSCore_HasModule(eBSCoreModuleBit eModuleMask, eBSCoreModuleBit eModuleBit)
{
	return ((view_as<int>(eModuleMask) & view_as<int>(eModuleBit)) != 0);
}

stock void BSCore_AddModule(eBSCoreModuleBit &eModuleMask, eBSCoreModuleBit eModuleBit)
{
	eModuleMask = view_as<eBSCoreModuleBit>(view_as<int>(eModuleMask) | view_as<int>(eModuleBit));
}

stock void BSCore_RemoveModule(eBSCoreModuleBit &eModuleMask, eBSCoreModuleBit eModuleBit)
{
	eModuleMask = view_as<eBSCoreModuleBit>(view_as<int>(eModuleMask) & ~view_as<int>(eModuleBit));
}

stock bool BSCore_IsValidModuleMask(eBSCoreModuleBit eModuleMask)
{
	int iAllowedMask = view_as<int>(kBSCoreModule_Access) | view_as<int>(kBSCoreModule_Communication) | view_as<int>(kBSCoreModule_Sprays);
	int iModuleMask = view_as<int>(eModuleMask);
	return ((iModuleMask & ~iAllowedMask) == 0);
}

stock void BSCore_GetModuleName(eBSCoreModuleBit eModuleBit, char[] szBuffer, int iMaxLength)
{
	switch (eModuleBit)
	{
		case kBSCoreModule_Access:
			strcopy(szBuffer, iMaxLength, "access");
		case kBSCoreModule_Communication:
			strcopy(szBuffer, iMaxLength, "communication");
		case kBSCoreModule_Sprays:
			strcopy(szBuffer, iMaxLength, "sprays");
		default:
			strcopy(szBuffer, iMaxLength, "unknown");
	}
}

stock void BSCore_GetCommTypeName(eBSCoreCommType eCommType, char[] szBuffer, int iMaxLength)
{
	switch (eCommType)
	{
		case kBSCoreComm_Mic:
			strcopy(szBuffer, iMaxLength, "mic");
		case kBSCoreComm_Chat:
			strcopy(szBuffer, iMaxLength, "chat");
		case kBSCoreComm_All:
			strcopy(szBuffer, iMaxLength, "all");
		default:
			strcopy(szBuffer, iMaxLength, "none");
	}
}

stock bool BSCore_IsPermanentLength(int iLength)
{
	return (iLength <= 0);
}
