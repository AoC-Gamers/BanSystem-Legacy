/*****************************************************************
			C O M M A N D S
*****************************************************************/

stock void BSAccess_OnPluginStart_Commands()
{
	RegAdminCmd("sm_bs_access_detail", Command_BSAccessDetail, ADMFLAG_ROOT, "Show resolved access detail for a connected client.");
	RegAdminCmd("sm_bs_access_add", Command_BSAccessAdd, ADMFLAG_ROOT, "Add or update an access ban in the modular access table.");
	RegAdminCmd("sm_bs_access_remove", Command_BSAccessRemove, ADMFLAG_ROOT, "Remove an access ban from the modular access table.");
	RegAdminCmd("sm_bs_access_info", Command_BSAccessInfo, ADMFLAG_ROOT, "Show active access ban info for an identity.");
	RegAdminCmd("sm_bs_access_list", Command_BSAccessList, ADMFLAG_ROOT, "List active modular access bans.");
}

Action Command_BSAccessAdd(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 3)
	{
		CReplyToCommand(iClient, "%t", "BSAccessUsageAdd");
		return Plugin_Handled;
	}

	if (!BSAccess_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSAccessDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	char szMinutes[16];
	char szReason[sizeof(g_eBSAccessResolvedDetail[].m_szReason)];
	char szContext[sizeof(g_eBSAccessResolvedDetail[].m_szContext)];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);
	SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szMinutes, sizeof(szMinutes));
	SteamIDTools_GetCmdArgNormalized(iNextArg + 1, iArgs, szReason, sizeof(szReason));
	SteamIDTools_JoinCmdArgs(iNextArg + 2, iArgs, szContext, sizeof(szContext));

	int iLength = StringToInt(szMinutes);
	if (iLength < 0)
	{
		CReplyToCommand(iClient, "%t", "BSAccessInvalidDuration");
		return Plugin_Handled;
	}

	if (IsValidSteamID64(szInput) || DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		if (BSAccess_QueueIdentityLookup(iClient, szInput, kBSAccessIdentityAction_Add, iLength, szReason, szContext, eReplySource))
			return Plugin_Handled;
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSAccess_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSAccessResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSAccess_QueueAddBan(iClient, iAccountId, iTargetClient, iLength, szReason, szContext, "", "UNKNOWN", eReplySource);
	return Plugin_Handled;
}

Action Command_BSAccessRemove(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSAccessUsageRemove");
		return Plugin_Handled;
	}

	if (!BSAccess_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSAccessDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (IsValidSteamID64(szInput) || DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		if (BSAccess_QueueIdentityLookup(iClient, szInput, kBSAccessIdentityAction_Remove, 0, "", "", eReplySource))
			return Plugin_Handled;
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSAccess_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSAccessResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSAccess_QueueRemoveBan(iClient, iAccountId, eReplySource);
	return Plugin_Handled;
}

Action Command_BSAccessInfo(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSAccessUsageInfo");
		return Plugin_Handled;
	}

	if (!BSAccess_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSAccessDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (IsValidSteamID64(szInput) || DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		if (BSAccess_QueueIdentityLookup(iClient, szInput, kBSAccessIdentityAction_Info, 0, "", "", eReplySource))
			return Plugin_Handled;
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSAccess_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSAccessResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSAccess_QueueInfoByAccountId(iClient, iAccountId, eReplySource);
	return Plugin_Handled;
}

Action Command_BSAccessList(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSAccess_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSAccessDatabaseNotReady");
		return Plugin_Handled;
	}

	int iLimit = 50;
	if (iArgs >= 1)
	{
		char szLimit[16];
		GetCmdArg(1, szLimit, sizeof(szLimit));
		iLimit = StringToInt(szLimit);
		if (iLimit <= 0)
			iLimit = 50;
		if (iLimit > 200)
			iLimit = 200;
	}

	BSAccess_QueueList(iClient, iLimit, eReplySource);
	return Plugin_Handled;
}

Action Command_BSAccessDetail(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSAccessUsageDetail");
		return Plugin_Handled;
	}

	char szTarget[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));

	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget <= 0)
		return Plugin_Handled;

	if (!g_eBSAccessResolvedDetail[iTarget].m_bLoaded)
	{
		CReplyToCommand(iClient, "%t", "BSAccessNoResolvedDetail", iTarget);
		return Plugin_Handled;
	}

	char szDateExpire[64];
	char szSteam2[32];
	BSAccess_FormatExpireDisplay(g_eBSAccessResolvedDetail[iTarget].m_iDateExpireTs, szDateExpire, sizeof(szDateExpire));
	if (!AccountIDToSteamID2(g_eBSAccessResolvedDetail[iTarget].m_iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	CReplyToCommand(
		iClient,
		"%t",
		"BSAccessResolvedDetail",
		iTarget,
		g_eBSAccessResolvedDetail[iTarget].m_iBanId,
		g_eBSAccessResolvedDetail[iTarget].m_iAccountId,
		g_eBSAccessResolvedDetail[iTarget].m_iLength,
		szSteam2,
		g_eBSAccessResolvedDetail[iTarget].m_szReason,
		g_eBSAccessResolvedDetail[iTarget].m_szContext[0] != '\0' ? g_eBSAccessResolvedDetail[iTarget].m_szContext : "<none>",
		g_eBSAccessResolvedDetail[iTarget].m_iBannedBy,
		g_eBSAccessResolvedDetail[iTarget].m_szBannedByName,
		szDateExpire
	);

	return Plugin_Handled;
}
