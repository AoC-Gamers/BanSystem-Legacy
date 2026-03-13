/*****************************************************************
			H E L P E R S
*****************************************************************/

void vReplyCommandPhrase(int iClient, const char[] szPhrase)
{
	CReplyToCommand(iClient, "%t %t", "Prefix", szPhrase);
}

void vReplyCommandPhraseString(int iClient, const char[] szPhrase, const char[] szValue)
{
	CReplyToCommand(iClient, "%t %t", "Prefix", szPhrase, szValue);
}

void vReplyCommandUsage(int iClient, const char[] szUsage)
{
	CReplyToCommand(iClient, "%t %t: %s", "Prefix", "Use", szUsage);
}

void vPrintConsoleHeader(int iClient, const char[] szTitle)
{
	PrintToConsole(iClient, "/***********[%s]***********\\", szTitle);
}

void vPrintInfoHeader(int iClient)
{
	char szTitle[64];
	Format(szTitle, sizeof(szTitle), "%T", "TitleInfo", (iClient != SERVER_INDEX) ? iClient : LANG_SERVER);
	vPrintConsoleHeader(iClient, szTitle);
}

void vNotifyInfoPrinted(int iClient, ReplySource eRsCmd)
{
	if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");
}

void vPrintReasonCodeList(int iClient, const char[] szSectionName)
{
	if (!g_kvReasons.JumpToKey(szSectionName, false))
		return;

	char
		szReasonValue[MAX_MESSAGE_LENGTH],
		szTranslation[MAX_MESSAGE_LENGTH];

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "/***********[%t]***********\\", "CodeList");
	if (g_kvReasons.GotoFirstSubKey(false))
	{
		do
		{
			g_kvReasons.GetString(NULL_STRING, szReasonValue, sizeof(szReasonValue), "#ERR");
			Format(szTranslation, sizeof(szTranslation), "%T", szReasonValue, iClient);
			PrintToConsole(iClient, "> %t: %s | %s", "Code", szReasonValue, szTranslation);
		}
		while (g_kvReasons.GotoNextKey(false));
	}

	PrintToConsole(iClient, "%t", "CodeNote");
	g_kvReasons.Rewind();
}

void vFormatDateOrPermanentDisplay(int iTranslationTarget, DBResultSet rsResult, int iField, char[] szBuffer, int iMaxLength)
{
	if (rsResult.IsFieldNull(iField))
		Format(szBuffer, iMaxLength, "%T", "Permanent", iTranslationTarget);
	else
		rsResult.FetchString(iField, szBuffer, iMaxLength);
}

void vFormatBannedByAuditDisplay(int iAdminAccountId, const char[] szAdminName, const char[] szAdminSteamId64, char[] szBuffer, int iMaxLength)
{
	if (iAdminAccountId <= 0)
	{
		strcopy(szBuffer, iMaxLength, "CONSOLE");
		return;
	}

	if (szAdminName[0] != '\0' && szAdminSteamId64[0] != '\0')
	{
		Format(szBuffer, iMaxLength, "%s | %s", szAdminName, szAdminSteamId64);
		return;
	}

	if (szAdminName[0] != '\0')
	{
		strcopy(szBuffer, iMaxLength, szAdminName);
		return;
	}

	if (szAdminSteamId64[0] != '\0')
	{
		strcopy(szBuffer, iMaxLength, szAdminSteamId64);
		return;
	}

	vFormatBannedByDisplay(iAdminAccountId, szBuffer, iMaxLength);
}

void vReplyAccessBanResult(int iClient, bool bAlreadyBanned, const char[] szTargetName)
{
	if (iClient == NO_INDEX)
		return;

	if (bAlreadyBanned)
		CReplyToCommand(iClient, "%t %t", "Prefix", "AlreadyAccessBanned", szTargetName);
	else
		CReplyToCommand(iClient, "%t %t", "Prefix", "BanAccessSuccess", szTargetName);
}

void vFormatCommTypeDisplay(int iTranslationTarget, eTypeComms eComms, char[] szBuffer, int iMaxLength)
{
	switch (eComms)
	{
		case kAll:
			Format(szBuffer, iMaxLength, "%T", "TypeCommAll", iTranslationTarget);
		case kMic:
			Format(szBuffer, iMaxLength, "%T", "TypeCommMic", iTranslationTarget);
		case kChat:
			Format(szBuffer, iMaxLength, "%T", "TypeCommChat", iTranslationTarget);
		default:
			strcopy(szBuffer, iMaxLength, "Unknown");
	}
}

void vReplyCommBanResult(int iClient, eTypeComms eComms, bool bAlreadyBanned, const char[] szTargetName)
{
	if (iClient == NO_INDEX)
		return;

	if (bAlreadyBanned)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "AlreadyCommBanned", szTargetName);
		return;
	}

	switch (eComms)
	{
		case kAll:
			CReplyToCommand(iClient, "%t %t", "Prefix", "BanCommSuccess", szTargetName);
		case kMic:
			CReplyToCommand(iClient, "%t %t", "Prefix", "BanMicSuccess", szTargetName);
		case kChat:
			CReplyToCommand(iClient, "%t %t", "Prefix", "BanChatSuccess", szTargetName);
	}
}

void vNotifyAccessBanTarget(int iTarget, const char[] szAdminName, int iLength, const char[] szReason)
{
	if (!bIsUsableClient(iTarget))
		return;

	char szTimeLength[128];
	GetTimeLength(iLength, szTimeLength, sizeof(szTimeLength));

	SetGlobalTransTarget(iTarget);
	PrintToConsole(iTarget, "\n\n");
	PrintToConsole(iTarget, "// -------------------------------- \\");
	PrintToConsole(iTarget, "|");
	PrintToConsole(iTarget, "| %t", "BannedAccessConsoleTitle");
	PrintToConsole(iTarget, "| %t", "BannedConsoleEject", szAdminName);
	PrintToConsole(iTarget, "| %t", "BannedConsoleLength", szTimeLength);

	if (strlen(szReason) != 0)
	{
		char szDisplayReason[MAX_MESSAGE_LENGTH];
		vGetReasonDisplayText(iTarget, szReason, szDisplayReason, sizeof(szDisplayReason));
		PrintToConsole(iTarget, "| %t", "BannedConsoleReason", szDisplayReason);
	}

	PrintToConsole(iTarget, "|");
	PrintToConsole(iTarget, "// -------------------------------- \\");
	PrintToConsole(iTarget, "\n\n");
}

void vNotifyCommBanTarget(int iTarget, eTypeComms eComms, const char[] szAdminName, int iLength, const char[] szReason)
{
	if (!bIsUsableClient(iTarget))
		return;

	char szTimeLength[128];
	char szComms[64];
	GetTimeLength(iLength, szTimeLength, sizeof(szTimeLength));
	vFormatCommTypeDisplay(iTarget, eComms, szComms, sizeof(szComms));

	SetGlobalTransTarget(iTarget);
	PrintToConsole(iTarget, "\n\n");
	PrintToConsole(iTarget, "// -------------------------------- \\");
	PrintToConsole(iTarget, "|");
	PrintToConsole(iTarget, "| %t", "BannedCommConsoleTitle");
	PrintToConsole(iTarget, "| %t", "BannedConsoleEject", szAdminName);
	PrintToConsole(iTarget, "| %t", "BannedConsoleLength", szTimeLength);
	PrintToConsole(iTarget, "| %t", "BannedConsoleTypecomm", szComms);

	if (strlen(szReason) != 0)
	{
		char szDisplayReason[MAX_MESSAGE_LENGTH];
		vGetReasonDisplayText(iTarget, szReason, szDisplayReason, sizeof(szDisplayReason));
		PrintToConsole(iTarget, "| %t", "BannedConsoleReason", szDisplayReason);
	}

	PrintToConsole(iTarget, "|");
	PrintToConsole(iTarget, "// -------------------------------- \\");
	PrintToConsole(iTarget, "\n\n");

	CPrintToChat(iTarget, "%t %t", "Prefix", "BannedComm", szComms);
}

void vNotifyCommUnbanTarget(int iTarget)
{
	if (!bIsUsableClient(iTarget))
		return;

	CPrintToChat(iTarget, "%t %t", "Prefix", "YouUnbanCommSuccess");
}

DataPack pCreateReplyContext(int iClient, ReplySource eRsCmd)
{
	return pCreateReplyContextUserId(iGetCommandIssuerUserId(iClient), eRsCmd);
}

DataPack pCreateReplyContextUserId(int iUserId, ReplySource eRsCmd)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(iUserId);
	pContext.WriteCell(eRsCmd);
	return pContext;
}

DataPack pCreateReplyContextString(int iClient, const char[] szValue, ReplySource eRsCmd)
{
	DataPack pContext = pCreateReplyContextUserId(iGetCommandIssuerUserId(iClient), eRsCmd);
	pContext.WriteString(szValue);
	return pContext;
}

void vReadReplyContext(any pData, int &iUserId, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;
}

void vReadReplyContextString(any pData, int &iUserId, ReplySource &eRsCmd, char[] szValue, int iMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	pContext.ReadString(szValue, iMaxLength);
	delete pContext;
}

int iResolveReplyClientForCommand(int iUserId, ReplySource eRsCmd, bool bFallbackToServer = false)
{
	int iClient = iResolveReplyClient(iUserId, bFallbackToServer);
	if (iClient != NO_INDEX)
		SetCmdReplySource(eRsCmd);

	return iClient;
}
