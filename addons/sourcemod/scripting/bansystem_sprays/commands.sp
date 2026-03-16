/*****************************************************************
			C O M M A N D S
*****************************************************************/

stock void BSSprays_OnPluginStart_Commands()
{
	RegAdminCmd("sm_bs_sprays_status", Command_BSSpraysStatus, ADMFLAG_ROOT, "Show BanSystem Sprays scaffold status.");
	RegAdminCmd("sm_bs_sprays_detail", Command_BSSpraysDetail, ADMFLAG_ROOT, "Show resolved spray detail for a connected client.");
	RegAdminCmd("sm_bs_sprays_add", Command_BSSpraysAdd, ADMFLAG_ROOT, "Add or update a spray ban in the modular sprays table.");
	RegAdminCmd("sm_bs_sprays_remove", Command_BSSpraysRemove, ADMFLAG_ROOT, "Remove a spray ban from the modular sprays table.");
	RegAdminCmd("sm_bs_sprays_info", Command_BSSpraysInfo, ADMFLAG_ROOT, "Show active spray ban info for an identity.");
	RegAdminCmd("sm_bs_sprays_list", Command_BSSpraysList, ADMFLAG_ROOT, "List active modular spray bans.");
}

Action Command_BSSpraysStatus(int iClient, int iArgs)
{
	CReplyToCommand(
		iClient,
		"%t",
		"BSSpraysStatus",
		BSSprays_CanUseCoreLibrary() ? 1 : 0,
		BSSprays_CanUseCoreLibrary() ? (BSCore_IsModuleRegistered(BANSYSTEM_SPRAYS_MODULE_NAME) ? 1 : 0) : 0,
		BSSprays_CanUseDatabase() ? 1 : 0
	);

	return Plugin_Handled;
}

Action Command_BSSpraysDetail(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysUsageDetail");
		return Plugin_Handled;
	}

	char szTarget[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));

	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget <= 0)
		return Plugin_Handled;

	if (!g_eBSSpraysResolvedDetail[iTarget].m_bLoaded)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysNoResolvedDetail", iTarget);
		return Plugin_Handled;
	}

	char szDateExpire[64];
	BSSprays_FormatExpireDisplay(g_eBSSpraysResolvedDetail[iTarget].m_iDateExpireTs, szDateExpire, sizeof(szDateExpire));

	CReplyToCommand(
		iClient,
		"%t",
		"BSSpraysResolvedDetail",
		iTarget,
		g_eBSSpraysResolvedDetail[iTarget].m_iBanId,
		g_eBSSpraysResolvedDetail[iTarget].m_iAccountId,
		g_eBSSpraysResolvedDetail[iTarget].m_iLength,
		g_eBSSpraysResolvedDetail[iTarget].m_szSteamId64,
		g_eBSSpraysResolvedDetail[iTarget].m_szReason,
		g_eBSSpraysResolvedDetail[iTarget].m_szContext[0] != '\0' ? g_eBSSpraysResolvedDetail[iTarget].m_szContext : "<none>",
		g_eBSSpraysResolvedDetail[iTarget].m_iBannedBy,
		g_eBSSpraysResolvedDetail[iTarget].m_szBannedByName,
		szDateExpire
	);

	return Plugin_Handled;
}

Action Command_BSSpraysAdd(int iClient, int iArgs)
{
	if (iArgs < 3)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysUsageAdd");
		return Plugin_Handled;
	}

	if (!BSSprays_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSSpraysDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	char szMinutes[16];
	char szReason[BANSYSTEM_SPRAYS_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSSpraysResolvedDetail[].m_szContext)];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);
	SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szMinutes, sizeof(szMinutes));
	SteamIDTools_GetCmdArgNormalized(iNextArg + 1, iArgs, szReason, sizeof(szReason));
	SteamIDTools_JoinCmdArgs(iNextArg + 2, iArgs, szContext, sizeof(szContext));

	int iLength = StringToInt(szMinutes);
	if (iLength < 0)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysInvalidDuration");
		return Plugin_Handled;
	}

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSSprays_QueueIdentityLookup(iClient, szInput, kBSSpraysIdentityAction_Add, iLength, szReason, szContext);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSSprays_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSSpraysResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSSprays_QueueAddBan(iClient, iAccountId, iTargetClient, iLength, szReason, szContext);
	return Plugin_Handled;
}

Action Command_BSSpraysRemove(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysUsageRemove");
		return Plugin_Handled;
	}

	if (!BSSprays_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSSpraysDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSSprays_QueueIdentityLookup(iClient, szInput, kBSSpraysIdentityAction_Remove, 0);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSSprays_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSSpraysResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSSprays_QueueRemoveBan(iClient, iAccountId);
	return Plugin_Handled;
}

Action Command_BSSpraysInfo(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSSpraysUsageInfo");
		return Plugin_Handled;
	}

	if (!BSSprays_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSSpraysDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSSprays_QueueIdentityLookup(iClient, szInput, kBSSpraysIdentityAction_Info, 0);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSSprays_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSSpraysResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSSprays_QueueInfoByAccountId(iClient, iAccountId);
	return Plugin_Handled;
}

Action Command_BSSpraysList(int iClient, int iArgs)
{
	if (!BSSprays_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSSpraysDatabaseNotReady");
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

	BSSprays_QueueList(iClient, iLimit);
	return Plugin_Handled;
}
