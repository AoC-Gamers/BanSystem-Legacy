/*****************************************************************
			C O M M A N D S
*****************************************************************/

stock void BSComm_OnPluginStart_Commands()
{
	RegAdminCmd("sm_bs_comm_status", Command_BSCommStatus, ADMFLAG_ROOT, "Show BanSystem Comm scaffold status.");
	RegAdminCmd("sm_bs_comm_detail", Command_BSCommDetail, ADMFLAG_ROOT, "Show resolved communication detail for a connected client.");
	RegAdminCmd("sm_bs_comm_add", Command_BSCommAdd, ADMFLAG_ROOT, "Add or update a communication ban in the modular communication table.");
	RegAdminCmd("sm_bs_comm_remove", Command_BSCommRemove, ADMFLAG_ROOT, "Remove a communication ban from the modular communication table.");
	RegAdminCmd("sm_bs_comm_info", Command_BSCommInfo, ADMFLAG_ROOT, "Show active communication ban info for an identity.");
	RegAdminCmd("sm_bs_comm_list", Command_BSCommList, ADMFLAG_ROOT, "List active modular communication bans.");
}

Action Command_BSCommStatus(int iClient, int iArgs)
{
	CReplyToCommand(
		iClient,
		"%t",
		"BSCommStatus",
		BSComm_CanUseCoreLibrary() ? 1 : 0,
		BSComm_CanUseCoreLibrary() ? (BSCore_IsModuleRegistered(BANSYSTEM_COMM_MODULE_NAME) ? 1 : 0) : 0,
		BSComm_CanUseDatabase() ? 1 : 0
	);

	return Plugin_Handled;
}

Action Command_BSCommDetail(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSCommUsageDetail");
		return Plugin_Handled;
	}

	char szTarget[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));

	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget <= 0)
		return Plugin_Handled;

	if (!g_eBSCommResolvedDetail[iTarget].m_bLoaded)
	{
		CReplyToCommand(iClient, "%t", "BSCommNoResolvedDetail", iTarget);
		return Plugin_Handled;
	}

	char szDateExpire[64];
	char szSteam2[32];
	BSComm_FormatExpireDisplay(g_eBSCommResolvedDetail[iTarget].m_iDateExpireTs, szDateExpire, sizeof(szDateExpire));
	if (!AccountIDToSteamID2(g_eBSCommResolvedDetail[iTarget].m_iAccountId, szSteam2, sizeof(szSteam2)))
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	CReplyToCommand(
		iClient,
		"%t",
		"BSCommResolvedDetail",
		iTarget,
		g_eBSCommResolvedDetail[iTarget].m_iBanId,
		g_eBSCommResolvedDetail[iTarget].m_iAccountId,
		g_eBSCommResolvedDetail[iTarget].m_iCommType,
		g_eBSCommResolvedDetail[iTarget].m_iLength,
		szSteam2,
		g_eBSCommResolvedDetail[iTarget].m_szReason,
		g_eBSCommResolvedDetail[iTarget].m_szContext[0] != '\0' ? g_eBSCommResolvedDetail[iTarget].m_szContext : "<none>",
		g_eBSCommResolvedDetail[iTarget].m_iBannedBy,
		g_eBSCommResolvedDetail[iTarget].m_szBannedByName,
		szDateExpire
	);

	return Plugin_Handled;
}

Action Command_BSCommAdd(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 4)
	{
		CReplyToCommand(iClient, "%t", "BSCommUsageAdd");
		return Plugin_Handled;
	}

	if (!BSComm_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSCommDatabaseNotReady");
		return Plugin_Handled;
	}

	char szType[16];
	char szInput[64];
	char szMinutes[16];
	char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
	char szContext[sizeof(g_eBSCommResolvedDetail[].m_szContext)];
	int iNextArg = 0;
	SteamIDTools_GetCmdArgNormalized(1, iArgs, szType, sizeof(szType));
	SteamIDTools_TryGetIdentityFromCmdArgs(2, iArgs, szInput, sizeof(szInput), iNextArg);
	SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szMinutes, sizeof(szMinutes));
	SteamIDTools_GetCmdArgNormalized(iNextArg + 1, iArgs, szReason, sizeof(szReason));
	SteamIDTools_JoinCmdArgs(iNextArg + 2, iArgs, szContext, sizeof(szContext));

	eBSCommType eCommType;
	if (!BSComm_ParseCommTypeString(szType, eCommType))
	{
		CReplyToCommand(iClient, "%t", "BSCommInvalidType");
		return Plugin_Handled;
	}

	int iLength = StringToInt(szMinutes);
	if (iLength < 0)
	{
		CReplyToCommand(iClient, "%t", "BSCommInvalidDuration");
		return Plugin_Handled;
	}

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSComm_QueueIdentityLookup(iClient, szInput, kBSCommIdentityAction_Add, iLength, view_as<int>(eCommType), szReason, szContext, eReplySource);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSComm_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSCommResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSComm_QueueAddBan(iClient, iAccountId, iTargetClient, eCommType, iLength, szReason, szContext, "", "UNKNOWN", eReplySource);
	return Plugin_Handled;
}

Action Command_BSCommRemove(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSCommUsageRemove");
		return Plugin_Handled;
	}

	if (!BSComm_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSCommDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSComm_QueueIdentityLookup(iClient, szInput, kBSCommIdentityAction_Remove, 0, 0, "", "", eReplySource);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSComm_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSCommResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSComm_QueueRemoveBan(iClient, iAccountId, eReplySource);
	return Plugin_Handled;
}

Action Command_BSCommInfo(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSCommUsageInfo");
		return Plugin_Handled;
	}

	if (!BSComm_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSCommDatabaseNotReady");
		return Plugin_Handled;
	}

	char szInput[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szInput, sizeof(szInput), iNextArg);

	if (DetectSteamIDFormat(szInput) == STEAMID_FORMAT_STEAMID64)
	{
		BSComm_QueueIdentityLookup(iClient, szInput, kBSCommIdentityAction_Info, 0, 0, "", "", eReplySource);
		return Plugin_Handled;
	}

	int iAccountId;
	int iTargetClient;
	if (!BSComm_TryResolveInputAccountId(iClient, szInput, iAccountId, iTargetClient))
	{
		CReplyToCommand(iClient, "%t", "BSCommResolveFailed", szInput);
		return Plugin_Handled;
	}

	BSComm_QueueInfoByAccountId(iClient, iAccountId, eReplySource);
	return Plugin_Handled;
}

Action Command_BSCommList(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSComm_CanUseDatabase())
	{
		CReplyToCommand(iClient, "%t", "BSCommDatabaseNotReady");
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

	BSComm_QueueList(iClient, iLimit, eReplySource);
	return Plugin_Handled;
}
