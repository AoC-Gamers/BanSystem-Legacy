/*****************************************************************
			H E L P E R S
*****************************************************************/

stock void BSCore_Log(eBSCoreDebugMask eMask, const char[] szTag, const char[] szMessage, int iVFormatArg)
{
	if (g_cvCoreDebugMask == null)
		return;

	int iMask = g_cvCoreDebugMask.IntValue;
	if ((iMask & view_as<int>(eMask)) == 0)
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, iVFormatArg);
	LogToFileEx(g_szCoreLogPath, "[%s] %s", szTag, szBuffer);
}

stock void BSCore_Debug(const char[] szMessage, any ...)
{
	BSCore_Log(kBSCoreDebug_General, "Debug", szMessage, 2);
}

stock void BSCore_SQL(const char[] szMessage, any ...)
{
	BSCore_Log(kBSCoreDebug_SQL, "SQL", szMessage, 2);
}

stock void BSCore_TransitionLog(const char[] szMessage, any ...)
{
	BSCore_Log(kBSCoreDebug_Transition, "Transition", szMessage, 2);
}

stock void BSCore_API(const char[] szMessage, any ...)
{
	BSCore_Log(kBSCoreDebug_API, "API", szMessage, 2);
}

stock void BSCore_NormalizeInput(const char[] szInput, char[] szOutput, int iMaxLength)
{
	strcopy(szOutput, iMaxLength, szInput);
	TrimString(szOutput);
	StripQuotes(szOutput);
}

stock bool BSCore_IsUsableClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient));
}

stock int BSCore_GetCommandIssuerUserId(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return 0;

	return GetClientUserId(iClient);
}

stock bool BSCore_HasModule(int iModuleMask, eBSCoreModuleBit eModuleBit)
{
	return ((iModuleMask & view_as<int>(eModuleBit)) != 0);
}

stock void BSCore_AddModule(int &iModuleMask, eBSCoreModuleBit eModuleBit)
{
	iModuleMask |= view_as<int>(eModuleBit);
}

stock void BSCore_RemoveModule(int &iModuleMask, eBSCoreModuleBit eModuleBit)
{
	iModuleMask &= ~view_as<int>(eModuleBit);
}

stock bool BSCore_IsValidModuleMask(int iModuleMask)
{
	int iAllowedMask = view_as<int>(kBSCoreModule_Access) | view_as<int>(kBSCoreModule_Communication) | view_as<int>(kBSCoreModule_Sprays);
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
