/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/


ConVar
	g_cvsv_alltalk;

enum struct eProcessComm {
	int m_iTargetUserId;
	int m_iLength;
	ePanelInputStage m_eInputStage;
	eTypeComms m_eComms;
	eDurationUnit m_eDurationUnit;
	char m_szTargetAuthId[MAX_AUTHID_LENGTH];
	char m_szReason[MAX_MESSAGE_LENGTH];
	char m_szContext[512];
}

eProcessComm g_eProcessComm[MAXPLAYERS+1];

void vRefreshBSCoreCommSummaryByAuthId(const char[] szTargetAuthId)
{
	if (!bCanUseBSCoreLibrary() || !bCanUsePrimaryDatabase())
		return;

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
		return;

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT `id`, `ban_type` FROM `%s` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ORDER BY `id` DESC LIMIT 1;", TABLE_COMM, iAccountId);

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbDatabase, vRefreshBSCoreCommSummaryCallback, szQuery, pContext);
}

void vRefreshBSCoreCommSummaryCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	if (!bCanUseBSCoreLibrary())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vRefreshBSCoreCommSummaryCallback");
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSCore_ClearSummaryModule(iAccountId, 2);
		delete rsResult;
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	int iCommType = rsResult.FetchInt(1);
	BSCore_SetCommSummary(iAccountId, iBanId, iCommType);
	delete rsResult;
}

void vResetCommProcessState(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	g_eProcessComm[iClient].m_iTargetUserId = NO_INDEX;
	g_eProcessComm[iClient].m_iLength = 0;
	g_eProcessComm[iClient].m_eInputStage = kPanelInput_None;
	g_eProcessComm[iClient].m_eComms = kNone;
	g_eProcessComm[iClient].m_eDurationUnit = kDurationUnit_None;
	g_eProcessComm[iClient].m_szTargetAuthId[0] = '\0';
	g_eProcessComm[iClient].m_szReason[0] = '\0';
	g_eProcessComm[iClient].m_szContext[0] = '\0';
}

void vSetCommProcessTarget(int iClient, int iTarget)
{
	g_eProcessComm[iClient].m_iTargetUserId = GetClientUserId(iTarget);

	if (!GetClientAuthId(iTarget, AuthId_Steam2, g_eProcessComm[iClient].m_szTargetAuthId, MAX_AUTHID_LENGTH))
	{
		g_eProcessComm[iClient].m_iTargetUserId = NO_INDEX;
		g_eProcessComm[iClient].m_szTargetAuthId[0] = '\0';
	}
}

int iGetCommProcessTarget(int iClient)
{
	int iTarget = GetClientOfUserId(g_eProcessComm[iClient].m_iTargetUserId);
	if (iTarget <= SERVER_INDEX)
		return NO_INDEX;

	char szTargetAuthId[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
		return NO_INDEX;

	if (!StrEqual(szTargetAuthId, g_eProcessComm[iClient].m_szTargetAuthId))
		return NO_INDEX;

	return iTarget;
}

void vGetCommProcessTargetLabel(int iClient, char[] szBuffer, int iMaxLength)
{
	int iTarget = iGetCommProcessTarget(iClient);
	if (iTarget != NO_INDEX)
	{
		Format(szBuffer, iMaxLength, "%N", iTarget);
		return;
	}

	if (g_eProcessComm[iClient].m_szTargetAuthId[0] != '\0')
	{
		strcopy(szBuffer, iMaxLength, g_eProcessComm[iClient].m_szTargetAuthId);
		return;
	}

	strcopy(szBuffer, iMaxLength, "UNKNOWN");
}

bool bCommTypeIncludes(eTypeComms eExisting, eTypeComms eRequested)
{
	if (eExisting == kNone || eRequested == kNone)
		return false;

	return ((view_as<int>(eExisting) & view_as<int>(eRequested)) == view_as<int>(eRequested));
}

eTypeComms eMergeCommTypes(eTypeComms eExisting, eTypeComms eRequested)
{
	return view_as<eTypeComms>(view_as<int>(eExisting) | view_as<int>(eRequested));
}

void vCommContextMenu(int iClient)
{
	char szTitle[MAX_MESSAGE_LENGTH];
	char szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH];
	char szTypeComm[32];
	char szTime[32];

	vFormatCommTypeDisplay(iClient, g_eProcessComm[iClient].m_eComms, szTypeComm, sizeof(szTypeComm));
	GetTimeLength(g_eProcessComm[iClient].m_iLength, szTime, sizeof(szTime));
	vGetCommProcessTargetLabel(iClient, szTargetLabel, sizeof(szTargetLabel));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%s\n>%s", "Ban reason", iClient, szTypeComm, szTargetLabel, szTime);

	Menu hContextMenu = new Menu(iCommContextMenuHandler);
	hContextMenu.SetTitle(szTitle);
	hContextMenu.ExitBackButton = true;

	char szLabel[64];
	Format(szLabel, sizeof(szLabel), "%T", "BanContextSkip", iClient);
	hContextMenu.AddItem("0", szLabel);

	Format(szLabel, sizeof(szLabel), "%T", "BanContextAdd", iClient);
	hContextMenu.AddItem("1", szLabel);

	hContextMenu.Display(iClient, MENU_TIME_FOREVER);
}

void vFinalizeCommProcess(int iClient)
{
	int iTarget = iGetCommProcessTarget(iClient);
	char szAuthId[MAX_AUTHID_LENGTH];
	char szReason[MAX_MESSAGE_LENGTH];
	char szContext[512];

	strcopy(szAuthId, sizeof(szAuthId), g_eProcessComm[iClient].m_szTargetAuthId);
	strcopy(szReason, sizeof(szReason), g_eProcessComm[iClient].m_szReason);
	strcopy(szContext, sizeof(szContext), g_eProcessComm[iClient].m_szContext);

	vRegComm(iClient, iTarget, szAuthId, g_eProcessComm[iClient].m_iLength, szReason, g_eProcessComm[iClient].m_eComms, szContext);
	vResetCommProcessState(iClient);
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

void vOnPluginStart_Communication()
{
    RegAdminCmd("sm_comm", aRegCommCmd, ADMFLAG_CHAT, "Ban a player from using the microphone and chat.");
    RegAdminCmd("sm_uncomm", aRemoveCommCmd, ADMFLAG_CHAT, "Unban a player from using the microphone and chat.");
    RegAdminCmd("sm_comm_info", aInfoCommCmd, ADMFLAG_CHAT, "Get information about a communication-banned player.");
	RegAdminCmd("sm_comm_clear", aClearCommCmd, ADMFLAG_ROOT, "Clear all communication bans.");
    RegAdminCmd("sm_comm_ls", aListCommCmd, ADMFLAG_CHAT, "List connected players with communication bans.");
    RegAdminCmd("sm_comm_db_ls", aListCommDbCmd, ADMFLAG_CHAT, "List active communication bans from the database.");

	g_cvsv_alltalk = FindConVar("sv_alltalk");
	if (g_cvsv_alltalk) {
		g_cvsv_alltalk.AddChangeHook(vAlltalkConVarChange);
	}
}

Action aRegCommCmd(int iClient, int iArgs)
{
	if (iClient != SERVER_INDEX)
		vResetPendingAdminProcesses(iClient);

	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	ReplySource eRsCmd = GetCmdReplySource();

	if (iArgs < 2)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vRegCommMenu(iClient);
		else
		{
			vReplyCommandUsage(iClient, "sm_comm <mic|chat|all> <#userid|name|steamid|steamid3|steamid64|accountid> [minutes|0] [reason|#CODE]");
			vPrintReasonCodeList(iClient, "Communication");
		}	
		return Plugin_Handled;
	}
	
	vProcessCommReg(iClient, iArgs);
	return Plugin_Handled;
}

Action aRemoveCommCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	ReplySource eRsCmd = GetCmdReplySource();
	if (iArgs == 0)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vRemoveCommMenu(iClient);
		else
			vReplyCommandUsage(iClient, "sm_uncomm <#userid|name|steamid|steamid3|steamid64|accountid>");

	
		return Plugin_Handled;
	}

	vProcessCommRemove(iClient);
	return Plugin_Handled;
}

Action aInfoCommCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	if (iArgs < 1)
	{
		vReplyCommandUsage(iClient, "sm_comm_info <steamid|steamid3|steamid64|accountid>");
		return Plugin_Handled;
	}

	ReplySource eRsCmd = GetCmdReplySource();
	char szAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szAuthId, sizeof(szAuthId));

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	if (!bResolveIdentityOnlyCommandInput(iClient, szAuthId, true, kIdentityRequest_CommInfo, szResolvedSteamId2, sizeof(szResolvedSteamId2)))
		return Plugin_Handled;

	vSubmitCommInfoByIdentity(iClient, szResolvedSteamId2, eRsCmd);
	return Plugin_Handled;
}

void vSubmitCommInfoByIdentity(int iClient, const char[] szAuthId, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iClient, "AuthIdError", szAuthId);
		return;
	}

	char szQuery[384];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `ip_address`, `ban_type`, `ban_length`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, `date_expire` FROM `%s` ", TABLE_COMM);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d ", iAccountId);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());");

	LogSQL("[aInfoCommCmd] szQuery: %s", szQuery);

	DataPack pInfoComm = new DataPack();
	pInfoComm.WriteCell(iGetCommandIssuerUserId(iClient));
	pInfoComm.WriteCell(eRsCmd);
	pInfoComm.WriteString(szAuthId);
	SQL_TQuery(g_dbDatabase, vInfoCommCallback, szQuery, pInfoComm);
}

Action aClearCommCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	char szQuery[128];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s`;", TABLE_COMM);

	DataPack pClearComm = new DataPack();
	pClearComm.WriteCell(iGetCommandIssuerUserId(iClient));
	pClearComm.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbDatabase, vClearCommDatabaseCallback, szQuery, pClearComm);
	return Plugin_Handled;
}

void vClearConnectedCommState(int iAdmin)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (g_ePunished[i].m_eComms == kNone)
			continue;

		eTypeComms eComms = g_ePunished[i].m_eComms;
		char szAuthId[MAX_AUTHID_LENGTH];
		bool bHasAuthId = GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId));

		vNotifyCommUnbanTarget(i);
		vResetPlayerPunishmentState(i);

		if (!bHasAuthId)
			continue;

		if (eComms == kChat || eComms == kAll)
		{
			Call_StartForward(g_gfOnUnBanChat);
			Call_PushCell(iAdmin);
			Call_PushCell(i);
			Call_PushString(szAuthId);
			Call_Finish();
		}

		if (eComms == kMic || eComms == kAll)
		{
			Call_StartForward(g_gfOnUnBanMic);
			Call_PushCell(iAdmin);
			Call_PushCell(i);
			Call_PushString(szAuthId);
			Call_Finish();
		}
	}
}

void vClearCommFinished(int iUserIdAdmin, ReplySource eRsCmd)
{
	int iAdmin = iResolveReplyClient(iUserIdAdmin, true);
	int iReplyClient = iResolveReplyClient(iUserIdAdmin, false);
	vClearConnectedCommState(iAdmin);

	if (iReplyClient == NO_INDEX)
		return;

	SetCmdReplySource(eRsCmd);
	CReplyToCommand(iReplyClient, "%t %t", "Prefix", "CommBansCleared");
}

void vClearCommDatabaseCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	ReplySource eRsCmd;
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;
	int iReplyClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vClearCommDatabaseCallback");
		delete rsResult;
		return;
	}

	delete rsResult;

	if (!g_cvSQLCache.BoolValue || g_dbCache == null)
	{
		vClearCommFinished(iUserId, eRsCmd);
		return;
	}

	char szQuery[128];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE ABS(ban_id) IN (2, 3, 4);", TABLE_CACHE);
	DataPack pCacheContext = new DataPack();
	pCacheContext.WriteCell(iUserId);
	pCacheContext.WriteCell(eRsCmd);
	SQL_TQuery(g_dbCache, vClearCommCacheCallback, szQuery, pCacheContext);
}

void vClearCommCacheCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	ReplySource eRsCmd;
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;
	int iReplyClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vClearCommCacheCallback");
		if (g_dbCache != null)
		{
			delete g_dbCache;
			g_dbCache = null;
		}
		delete rsResult;
		vClearConnectedCommState(iResolveReplyClient(iUserId, true));
		return;
	}

	delete rsResult;
	vClearCommFinished(iUserId, eRsCmd);
}

void vInfoCommCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];
	int iUserId;
	ReplySource eRsCmd;
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	pContext.ReadString(szAuthId, sizeof(szAuthId));
	delete pContext;
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
	if (rsResult == null || szError[0])
	{
		vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vInfoCommCallback");
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoBanInfo", szAuthId);
		delete rsResult;
		return;
	}

	char
		szPlayerName[MAX_NAME_LENGTH],
		szIpAddress[32],
		szBanReason[MAX_MESSAGE_LENGTH],
		szBanContext[512],
		szDisplayReason[MAX_MESSAGE_LENGTH],
		szTypeComm[64],
		szBannedBy[160],
		szBannedByName[MAX_NAME_LENGTH],
		szBannedBySteamId64[32],
		szDateExpire[64],
		szLength[128];

	int iLength, iBannedByAccountId;
	eTypeComms eComms;
	int iTranslationTarget = (iClient != SERVER_INDEX) ? iClient : LANG_SERVER;

	rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(1, szIpAddress, sizeof(szIpAddress));
	eComms = view_as<eTypeComms>(rsResult.FetchInt(2));
	iLength = rsResult.FetchInt(3);
	rsResult.FetchString(4, szBanReason, sizeof(szBanReason));
	rsResult.FetchString(5, szBanContext, sizeof(szBanContext));
	iBannedByAccountId = rsResult.FetchInt(6);
	rsResult.FetchString(7, szBannedByName, sizeof(szBannedByName));
	rsResult.FetchString(8, szBannedBySteamId64, sizeof(szBannedBySteamId64));
	vFormatBannedByAuditDisplay(iBannedByAccountId, szBannedByName, szBannedBySteamId64, szBannedBy, sizeof(szBannedBy));
	vFormatCommTypeDisplay(iTranslationTarget, eComms, szTypeComm, sizeof(szTypeComm));
	vGetReasonDisplayText(iTranslationTarget, szBanReason, szDisplayReason, sizeof(szDisplayReason));
	vFormatDateOrPermanentDisplay(iTranslationTarget, rsResult, 9, szDateExpire, sizeof(szDateExpire));

	GetTimeLength(iLength, szLength, sizeof(szLength));

	vPrintInfoHeader(iClient);
	PrintToConsole(iClient, "> %t: %s", "InfoPlayerName", szPlayerName);
	PrintToConsole(iClient, "> %t: %s", "InfoIpAddress", szIpAddress);
	PrintToConsole(iClient, "> %t: %s", "InfoTypeComm", szTypeComm);
	PrintToConsole(iClient, "> %t: %s", "InfoLength", szLength);
	PrintToConsole(iClient, "> %t: %s", "InfoReason", szDisplayReason);
	if (szBanContext[0] != '\0')
		PrintToConsole(iClient, "> %t: %s", "InfoContext", szBanContext);
	PrintToConsole(iClient, "> %t: %s", "InfonedBy", szBannedBy);
	PrintToConsole(iClient, "> %t: %s", "InfoTimestamp", szDateExpire);

	vNotifyInfoPrinted(iClient, eRsCmd);

	delete rsResult;
}

Action aListCommCmd(int iClient, int iArgs)
{
	int iFound = 0;
	vPrintConsoleHeader(iClient, "Connected Comm List");
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (g_ePunished[i].m_eComms == kNone)
			continue;

		char szTypeComm[64];
		vFormatCommTypeDisplay((iClient != SERVER_INDEX) ? iClient : LANG_SERVER, g_ePunished[i].m_eComms, szTypeComm, sizeof(szTypeComm));
		PrintToConsole(iClient, "> %N | %s", i, szTypeComm);
		iFound++;
	}

	if(iFound == 0)
		PrintToConsole(iClient, "%t", "NoCommBans");

	if (SM_REPLY_TO_CHAT == GetCmdReplySource() && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "ListBanComm", iClient);
	return Plugin_Handled;
}

Action aListCommDbCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	int iLimit = iGetQueryListLimit(iArgs);

	char szQuery[512];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_type`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, `date_expire` ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_COMM);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pListComm = new DataPack();
	pListComm.WriteCell(iGetCommandIssuerUserId(iClient));
	pListComm.WriteCell(GetCmdReplySource());
	SQL_TQuery(g_dbDatabase, vListCommDbCallback, szQuery, pListComm);
	return Plugin_Handled;
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

public void vAlltalkConVarChange(ConVar cvConVar, const char[] szOldValue, const char[] szNewValue)
{	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (g_ePunished[i].m_eComms == kMic || g_ePunished[i].m_eComms == kAll)
			SetClientListeningFlags(i, VOICE_MUTED);
	}
}

Action aOnClientSayCommand_Communication(int iClient, const char[] szArgs)
{
	if (bIsClientAuthorizationPending(iClient))
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "AuthCheckPending");
		return Plugin_Stop;
	}

	if (g_eProcessComm[iClient].m_eInputStage != kPanelInput_None && !IsChatTrigger())
	{
		SetCmdReplySource(SM_REPLY_TO_CHAT);

		switch (g_eProcessComm[iClient].m_eInputStage)
		{
			case kPanelInput_DurationValue:
			{
				char szValue[32];
				strcopy(szValue, sizeof(szValue), szArgs);
				TrimString(szValue);
				StripQuotes(szValue);

				if (!bIsInteger(szValue) || StringToInt(szValue) <= 0)
				{
					CPrintToChat(iClient, "%t %t", "Prefix", "BanDurationValueInvalid");
					return Plugin_Stop;
				}

				int iMinutes;
				if (!bTryConvertDurationUnitToMinutes(g_eProcessComm[iClient].m_eDurationUnit, StringToInt(szValue), iMinutes))
				{
					CPrintToChat(iClient, "%t %t", "Prefix", "BanDurationValueInvalid");
					return Plugin_Stop;
				}

				g_eProcessComm[iClient].m_iLength = iMinutes;
				g_eProcessComm[iClient].m_eInputStage = kPanelInput_None;
				vCommReasonMenu(iClient);
			}
			case kPanelInput_Reason:
			{
				g_eProcessComm[iClient].m_eInputStage = kPanelInput_None;
				strcopy(g_eProcessComm[iClient].m_szReason, sizeof(g_eProcessComm[].m_szReason), szArgs);
				TrimString(g_eProcessComm[iClient].m_szReason);
				StripQuotes(g_eProcessComm[iClient].m_szReason);
				vCommContextMenu(iClient);
			}
			case kPanelInput_Context:
			{
				g_eProcessComm[iClient].m_eInputStage = kPanelInput_None;
				strcopy(g_eProcessComm[iClient].m_szContext, sizeof(g_eProcessComm[].m_szContext), szArgs);
				TrimString(g_eProcessComm[iClient].m_szContext);
				StripQuotes(g_eProcessComm[iClient].m_szContext);
				vFinalizeCommProcess(iClient);
			}
		}

		return Plugin_Stop;
	}

	if (g_ePunished[iClient].m_eComms == kChat || g_ePunished[iClient].m_eComms == kAll)
	{
		if (GetUserAdmin(iClient) == INVALID_ADMIN_ID || !IsChatTrigger())
		{
			CPrintToChat(iClient, "%t %t", "Prefix", "BannedCommChat");
			return Plugin_Stop;
		}
	}

	return Plugin_Continue;
}

void vListCommDbCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	ReplySource eRsCmd;
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
	if (rsResult == null || szError[0])
	{
		vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vListCommDbCallback");
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoActiveCommDbBans");
		delete rsResult;
		return;
	}

	int iTranslationTarget = (iClient != SERVER_INDEX) ? iClient : LANG_SERVER;

	vPrintConsoleHeader(iClient, "Active Comm Bans");
	do
	{
		char szPlayerName[MAX_NAME_LENGTH];
		char szAuthId[MAX_AUTHID_LENGTH];
		char szReason[MAX_MESSAGE_LENGTH];
		char szDisplayReason[MAX_MESSAGE_LENGTH];
		char szBanContext[512];
		char szBannedBy[160];
		char szBannedByName[MAX_NAME_LENGTH];
		char szBannedBySteamId64[32];
		char szDateExpire[64];
		char szLength[128];
		char szTypeComm[64];

		int iLength = rsResult.FetchInt(3);
		int iBannedByAccountId = rsResult.FetchInt(6);
		eTypeComms eComms = view_as<eTypeComms>(rsResult.FetchInt(2));
		int iAccountId = rsResult.FetchInt(1);

		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		rsResult.FetchString(4, szReason, sizeof(szReason));
		rsResult.FetchString(5, szBanContext, sizeof(szBanContext));
		rsResult.FetchString(7, szBannedByName, sizeof(szBannedByName));
		rsResult.FetchString(8, szBannedBySteamId64, sizeof(szBannedBySteamId64));
		bGetAuthIdFromAccountId(iAccountId, szAuthId, sizeof(szAuthId));
		vFormatBannedByAuditDisplay(iBannedByAccountId, szBannedByName, szBannedBySteamId64, szBannedBy, sizeof(szBannedBy));

		vFormatCommTypeDisplay(iTranslationTarget, eComms, szTypeComm, sizeof(szTypeComm));
		vGetReasonDisplayText(iTranslationTarget, szReason, szDisplayReason, sizeof(szDisplayReason));
		GetTimeLength(iLength, szLength, sizeof(szLength));
		vFormatDateOrPermanentDisplay(iTranslationTarget, rsResult, 9, szDateExpire, sizeof(szDateExpire));

		PrintToConsole(iClient, "> %s | SteamID: %s | %t: %s | %t: %s | %t: %s | %t: %s | %t: %s",
			szPlayerName,
			szAuthId,
			"InfoTypeComm", szTypeComm,
			"InfoLength", szLength,
			"InfoReason", szDisplayReason,
			"InfonedBy", szBannedBy,
			"InfoTimestamp", szDateExpire);

		if (szBanContext[0] != '\0')
			PrintToConsole(iClient, "  %t: %s", "InfoContext", szBanContext);
	} while (rsResult.FetchRow());

	vNotifyInfoPrinted(iClient, eRsCmd);

	delete rsResult;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void vProcessCommRemove(int iClient)
{
    char szTarget[65];

    GetCmdArg(1, szTarget, sizeof(szTarget));

	int iTarget;
	char szAuthId[MAX_AUTHID_LENGTH];
	if (!bResolveTargetCommandInput(iClient, szTarget, true, kIdentityRequest_CommUnban, szAuthId, sizeof(szAuthId), iTarget))
		return;

	vRemoveComm(iClient, iTarget, szAuthId);
}

void vSubmitRemoveCommByIdentity(int iClient, const char[] szTargetAuthId, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iTarget = FindClientBySteamID2(szTargetAuthId);
	if (iTarget <= SERVER_INDEX)
		iTarget = NO_INDEX;

	vRemoveComm(iClient, iTarget, szTargetAuthId);
}

/**
 * Removes a communication ban for a specified target from the database.
 *
 * @param iAdmin            The index of the admin initiating the removal. Use SERVER_INDEX if the server is the initiator.
 * @param iTarget           The index of the target client whose communication ban is being removed. Use NO_INDEX if the target is not a connected client.
 * @param szTargetAuthId    The Steam ID (Auth ID) of the target whose communication ban is being removed.
 */
void vRemoveComm(int iAdmin, int iTarget, const char[] szTargetAuthId)
{
	if (iAdmin != SERVER_INDEX && !bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget != NO_INDEX && !bIsUsableClient(iTarget))
		iTarget = NO_INDEX;

	if (!bEnsurePrimaryDatabaseReady(iAdmin))
		return;

	int
		iAccountId;

	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iAdmin, "AuthIdError", szTargetAuthId);
		return;
	}

	ReplySource eRsCmd = GetCmdReplySource();

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT `ban_type`, `player_name` FROM `%s` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());", TABLE_COMM, iAccountId);

	LogSQL("[vRemoveComm] szQuery: %s", szQuery);

	DataPack pRemoveComm = pCreateAdminTargetAuthReplyContext(iAdmin, iTarget, szTargetAuthId, eRsCmd);
	SQL_TQuery(g_dbDatabase, vRemoveCommLookupCallback, szQuery, pRemoveComm);
}

void vRemoveCommLookupCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int
		iUserIdAdmin,
		iUserIdTarget,
		iReplyClient;

	char szTargetAuthId[MAX_AUTHID_LENGTH];

	ReplySource eRsCmd;
	vReadAdminTargetAuthReplyContext(pData, iUserIdAdmin, iUserIdTarget, szTargetAuthId, sizeof(szTargetAuthId), eRsCmd);

	LogDebug("[vRemoveCommLookupCallback] iUserIdAdmin: %d | iUserIdTarget: %d | szTargetAuthId: %s", iUserIdAdmin, iUserIdTarget, szTargetAuthId);

	iReplyClient = iResolveReplyClientForCommand(iUserIdAdmin, eRsCmd, false);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vRemoveCommLookupCallback");
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		if (iReplyClient != NO_INDEX)
			CReplyToCommand(iReplyClient, "%t %t", "Prefix", "UnbanCommNotFound", szTargetAuthId);
		delete rsResult;
		return;
	}

	eTypeComms eComms = view_as<eTypeComms>(rsResult.FetchInt(0));
	char szTargetName[MAX_NAME_LENGTH];

	if (rsResult.IsFieldNull(1))
		strcopy(szTargetName, sizeof(szTargetName), szTargetAuthId);
	else
		rsResult.FetchString(1, szTargetName, sizeof(szTargetName));

	delete rsResult;

	char szQuery[256];
	int iAccountId;
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhraseString(iReplyClient, "AuthIdError", szTargetAuthId);
		return;
	}

	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());", TABLE_COMM, iAccountId);

	DataPack pDeleteComm = pCreateAdminTargetAuthNameTypeReplyContext(iResolveReplyClient(iUserIdAdmin, true), iResolveReplyClient(iUserIdTarget, false), szTargetAuthId, szTargetName, eComms, eRsCmd);

	LogSQL("[vRemoveCommLookupCallback] delete query: %s", szQuery);
	SQL_TQuery(g_dbDatabase, vRemoveCommCallback, szQuery, pDeleteComm);
}

void vRemoveCommCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int
		iUserIdAdmin,
		iUserIdTarget,
		iAdmin,
		iReplyClient,
		iTarget = NO_INDEX;

	char
		szTargetAuthId[MAX_AUTHID_LENGTH],
		szTargetName[MAX_NAME_LENGTH];

	eTypeComms eComms;
	ReplySource eRsCmd;
	vReadAdminTargetAuthNameTypeReplyContext(pData, iUserIdAdmin, iUserIdTarget, szTargetAuthId, sizeof(szTargetAuthId), szTargetName, sizeof(szTargetName), eComms, eRsCmd);

	iReplyClient = iResolveReplyClientForCommand(iUserIdAdmin, eRsCmd, false);
	iAdmin = iResolveReplyClient(iUserIdAdmin, true);
	vResolveTargetClientByUserId(iUserIdTarget, iTarget);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vRemoveCommCallback");
		delete rsResult;
		return;
	}

	vRemoveSQLCache(szTargetAuthId);

	int iAffectedRows = SQL_GetAffectedRows(dbDataBase);
	LogSQL("[vRemoveCommCallback] SQL_GetAffectedRows: %d", iAffectedRows);

	if (iAffectedRows == 0)
	{
		if (iReplyClient != NO_INDEX)
			CReplyToCommand(iReplyClient, "%t %t", "Prefix", "UnbanCommNotFound", szTargetAuthId);
		delete rsResult;
		return;
	}

	if (iReplyClient != NO_INDEX)
		CReplyToCommand(iReplyClient, "%t %t", "Prefix", "UnbanCommSuccess", szTargetName);

	vClearBSCoreSummaryModuleByAuthId(szTargetAuthId, 2);

	if (iTarget != NO_INDEX)
	{
		CReplyToCommand(iTarget, "%t %t", "Prefix", "YouUnbanCommSuccess");
		vResetPlayerPunishmentState(iTarget);
	}

	if (eComms == kChat || eComms == kAll)
	{
		Call_StartForward(g_gfOnUnBanChat);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_Finish();
	}

	if (eComms == kMic || eComms == kAll)
	{
		Call_StartForward(g_gfOnUnBanMic);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_Finish();
	}

	LogDebug("[vRemoveCommCallback] iTarget: %d | eComms: %d", iTarget, eComms);
	delete rsResult;
	return;
}

/**
 * Displays a menu to the specified client for removing communication punishments
 * from other connected players.
 *
 * @param client The client index of the player who will see the menu.
 */
void vRemoveCommMenu(int client)
{
	Menu hMenu = new Menu(iRemoveCommMenuHandler);
	
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%T", "MenuCommTitle", client);
	hMenu.SetTitle(sBuffer);
	
	char
		szName[MAX_NAME_LENGTH],
		szInfo[16],
		szAuthId[MAX_AUTHID_LENGTH],
		szDisplay[MAX_NAME_LENGTH+MAX_AUTHID_LENGTH];

	int iTargetFound = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		if (!GetClientName(i, szName, sizeof(szName)))
			continue;

		if (!GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
			continue;
		
		if (g_ePunished[i].m_eComms == kNone)
			continue;

		Format(szInfo, sizeof(szInfo), "%d", GetClientUserId(i));
		
		Format(szDisplay, sizeof(szDisplay), "%s (%s)", szName, szAuthId);
		if (!CanUserTarget(client, i))
			hMenu.AddItem(szInfo, szDisplay, ITEMDRAW_DISABLED);
		else
		{
			hMenu.AddItem(szInfo, szDisplay);
			iTargetFound++;
		}
	}
	
	if (iTargetFound == 0)
	{
		delete hMenu;
		CReplyToCommand(client, "%t %t", "Prefix", "NoTargetsRemoveComm");
		return;
	}

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int iRemoveCommMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char
				szInfo[32];

			int
				iUserId,
				iTarget;

			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			iUserId = StringToInt(szInfo);

			if ((iTarget = GetClientOfUserId(iUserId)) == 0)
				CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
			else if (!CanUserTarget(iParam1, iTarget))
				CPrintToChat(iParam1, "%t %t", "Prefix", "Unable to target");
			else
			{
				char szAuthId[MAX_AUTHID_LENGTH];
				if (!GetClientAuthId(iTarget, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
				{
					CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
					return 0;
				}
				vRemoveComm(iParam1, iTarget, szAuthId);
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	return 0;
}

/**
 * Registers and displays a communication menu for a specific client.
 *
 * @param client The client index to whom the menu will be displayed.
 */
void vRegCommMenu(int client)
{
	Menu hMenu = new Menu(iCommMenuHandler);
	
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%T\n", "MenuCommTitle", client);
	hMenu.SetTitle(sBuffer);

	sBuffer[0] = '\0';
	Format(sBuffer, sizeof(sBuffer), "%T", "MenuMicDesc", client);
	hMenu.AddItem("1", sBuffer);

	sBuffer[0] = '\0';
	Format(sBuffer, sizeof(sBuffer), "%T", "MenuChatDesc", client);
	hMenu.AddItem("2", sBuffer);

	sBuffer[0] = '\0';
	Format(sBuffer, sizeof(sBuffer), "%T", "MenuAllDesc", client);
	hMenu.AddItem("3", sBuffer);

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int iCommMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[32];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			eTypeComms eComm = view_as<eTypeComms>(StringToInt(szInfo));

			switch (eComm)
			{
				case kAll,kMic,kChat:
				{
					g_eProcessComm[iParam1].m_eComms = eComm;
					g_eProcessComm[iParam1].m_eDurationUnit = kDurationUnit_None;
					g_eProcessComm[iParam1].m_iLength = 0;
					vCommTargetMenu(iParam1);
				}
				default:
				{
					vRegCommMenu(iParam1);
				}
			}
		}

		case MenuAction_Cancel:
			vResetCommProcessState(iParam1);

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

/**
 * Displays a menu to the specified client, allowing them to select a communication target.
 *
 * @param iClient The client index to whom the menu will be displayed.
 */
void vCommTargetMenu(int iClient)
{
	char
		szTitle[MAX_MESSAGE_LENGTH],
		szTypeComm[32];

	vFormatCommTypeDisplay(iClient, g_eProcessComm[iClient].m_eComms, szTypeComm, sizeof(szTypeComm));

	Format(szTitle, sizeof(szTitle), "%T\n>%s", "Ban player", iClient, szTypeComm);

	Menu hTargetMenu = new Menu(iCommTargetsMenuHandler);
	hTargetMenu.SetTitle(szTitle);
	hTargetMenu.ExitBackButton = true;

	char
		szName[MAX_NAME_LENGTH],
		szInfo[16],
		szAuthId[MAX_AUTHID_LENGTH],
		szDisplay[MAX_NAME_LENGTH+MAX_AUTHID_LENGTH];

	int iTargetFound = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		if (!GetClientName(i, szName, sizeof(szName)))
			continue;

		if (!GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
			continue;
		
		Format(szInfo, sizeof(szInfo), "%d", GetClientUserId(i));
		Format(szDisplay, sizeof(szDisplay), "%s (%s)", szName, szAuthId);

		eTypeComms ePunishedComms = g_ePunished[i].m_eComms;

		if (!CanUserTarget(iClient, i) || bCommTypeIncludes(ePunishedComms, g_eProcessComm[iClient].m_eComms))
			hTargetMenu.AddItem(szInfo, szDisplay, ITEMDRAW_DISABLED);
		else
		{
			hTargetMenu.AddItem(szInfo, szDisplay);
			iTargetFound++;
		}
	}

	if (iTargetFound == 0)
	{
		delete hTargetMenu;
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoTargetsCommBan");
		return;
	}

	hTargetMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int iCommTargetsMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;
		
		case MenuAction_Select:
		{
			char
				szInfo[32];

			int
				iUserId,
				iTarget;

			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			iUserId = StringToInt(szInfo);

			if ((iTarget = GetClientOfUserId(iUserId)) == 0)
			{
				CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
				vCommTargetMenu(iParam1);
			}
			else if (!CanUserTarget(iParam1, iTarget))
			{
				CPrintToChat(iParam1, "%t %t", "Prefix", "Unable to target");
				vCommTargetMenu(iParam1);
			}
			else
			{
				vSetCommProcessTarget(iParam1, iTarget);
				vCommTimeMenu(iParam1);
			}
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vRegCommMenu(iParam1);
			else
				vResetCommProcessState(iParam1);
		}
	}
	return 0;
}

/**
 * Displays a communication time selection menu to the specified client.
 *
 * @param iClient The client index to whom the menu will be displayed.
 */
void vCommTimeMenu(int iClient)
{
	char
		szTitle[MAX_MESSAGE_LENGTH],
		szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH],
		szTypeComm[32];

	vFormatCommTypeDisplay(iClient, g_eProcessComm[iClient].m_eComms, szTypeComm, sizeof(szTypeComm));

	vGetCommProcessTargetLabel(iClient, szTargetLabel, sizeof(szTargetLabel));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%s", "Ban Time", iClient, szTypeComm, szTargetLabel);
	
	Menu hTimeMenu = new Menu(iCommTimeMenuHandler);
	hTimeMenu.SetTitle(szTitle);
	hTimeMenu.ExitBackButton = true;

	char szLabel[64];
	Format(szLabel, sizeof(szLabel), "%T", "Minutes", iClient);
	hTimeMenu.AddItem("1", szLabel);
	Format(szLabel, sizeof(szLabel), "%T", "Hours", iClient);
	hTimeMenu.AddItem("2", szLabel);
	Format(szLabel, sizeof(szLabel), "%T", "Days", iClient);
	hTimeMenu.AddItem("3", szLabel);
	Format(szLabel, sizeof(szLabel), "%T", "Weeks", iClient);
	hTimeMenu.AddItem("4", szLabel);
	Format(szLabel, sizeof(szLabel), "%T", "Months", iClient);
	hTimeMenu.AddItem("5", szLabel);
	Format(szLabel, sizeof(szLabel), "%T", "Permanent", iClient);
	hTimeMenu.AddItem("6", szLabel);

	hTimeMenu.Display(iClient, MENU_TIME_FOREVER);
}

int iCommTimeMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			char szInfo[32];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			g_eProcessComm[iParam1].m_eDurationUnit = view_as<eDurationUnit>(StringToInt(szInfo));
			if (g_eProcessComm[iParam1].m_eDurationUnit == kDurationUnit_Permanent)
			{
				g_eProcessComm[iParam1].m_iLength = 0;
				vCommReasonMenu(iParam1);
			}
			else
			{
				char szUnit[64];
				vGetDurationUnitDisplay(iParam1, g_eProcessComm[iParam1].m_eDurationUnit, szUnit, sizeof(szUnit));
				g_eProcessComm[iParam1].m_eInputStage = kPanelInput_DurationValue;
				CPrintToChat(iParam1, "%t %t", "Prefix", "BanDurationValuePrompt", szUnit, "sm_abort");
			}
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
			{
				g_eProcessComm[iParam1].m_iLength = 0;
				g_eProcessComm[iParam1].m_eDurationUnit = kDurationUnit_None;
				vCommTargetMenu(iParam1);
			}
			else
				vResetCommProcessState(iParam1);
		}
	}

	return 0;
}

/**
 * Displays a menu to the client for selecting a ban reason.
 *
 * @param client        The client index to whom the menu will be displayed.
 */
void vCommReasonMenu(int iClient)
{
	char
		szTitle[MAX_MESSAGE_LENGTH],
		szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH],
		szTypeComm[32],
		szTime[32],
		szCustomReason[64];

	vFormatCommTypeDisplay(iClient, g_eProcessComm[iClient].m_eComms, szTypeComm, sizeof(szTypeComm));

	GetTimeLength(g_eProcessComm[iClient].m_iLength, szTime, sizeof(szTime));
	vGetCommProcessTargetLabel(iClient, szTargetLabel, sizeof(szTargetLabel));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%s\n>%s", "Ban reason", iClient, szTypeComm, szTargetLabel, szTime);

	Menu hCommReasonMenu = new Menu(iCommReasonMenuHandler);
	hCommReasonMenu.SetTitle(szTitle);
	hCommReasonMenu.ExitBackButton = true;
	
	Format(szCustomReason, sizeof(szCustomReason), "%t", "CustomReason", iClient);
	hCommReasonMenu.AddItem("", szCustomReason);
	
	char
		szReasonValue[MAX_NAME_LENGTH],
		szTranslation[MAX_MESSAGE_LENGTH];
	
    if (!g_kvReasons.JumpToKey("Communication", false))
    {
        delete hCommReasonMenu;
		g_kvReasons.Rewind();
		vResetCommProcessState(iClient);
        PrintToServer("%t", "ErrorSectionName", "Communication");
        return;
    }
    
    if (g_kvReasons.GotoFirstSubKey(false))
    {
        do
        {
            g_kvReasons.GetString(NULL_STRING, szReasonValue, sizeof(szReasonValue), "#ERR");
			Format(szTranslation, sizeof(szTranslation), "%T", szReasonValue, iClient);
            hCommReasonMenu.AddItem(szReasonValue, szTranslation);
            
        } while (g_kvReasons.GotoNextKey(false));
    }
	
	g_kvReasons.Rewind();
	hCommReasonMenu.Display(iClient, MENU_TIME_FOREVER);
}

int iCommReasonMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			if (iParam2 == 0)
			{
				CPrintToChat(iParam1, "%t %t", "Prefix", "Custom ban reason explanation", "sm_abort");
				g_eProcessComm[iParam1].m_eInputStage = kPanelInput_Reason;
				return 0;
			}

			char
				szReason[MAX_MESSAGE_LENGTH],
				szTargetAuthId[MAX_AUTHID_LENGTH];

			hMenu.GetItem(iParam2, szReason, sizeof(szReason));
			strcopy(g_eProcessComm[iParam1].m_szReason, sizeof(g_eProcessComm[].m_szReason), szReason);
			strcopy(szTargetAuthId, sizeof(szTargetAuthId), g_eProcessComm[iParam1].m_szTargetAuthId);
			int iTarget = iGetCommProcessTarget(iParam1);

			LogMenu("[iCommReasonMenuHandler] iParam1: %N | iTarget: %d | szTargetAuthId: %s | m_iLength: %d | szReason: %s | m_eComms %d", iParam1, iTarget, szTargetAuthId, g_eProcessComm[iParam1].m_iLength, szReason, g_eProcessComm[iParam1].m_eComms);
			vCommContextMenu(iParam1);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vCommTimeMenu(iParam1);
			else
				vResetCommProcessState(iParam1);
		}
	}
	return 0;
}

int iCommContextMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			char szInfo[8];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

			if (StringToInt(szInfo) == 0)
			{
				g_eProcessComm[iParam1].m_szContext[0] = '\0';
				vFinalizeCommProcess(iParam1);
			}
			else
			{
				g_eProcessComm[iParam1].m_eInputStage = kPanelInput_Context;
				CPrintToChat(iParam1, "%t %t", "Prefix", "BanContextPrompt", "sm_abort");
			}
		}

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				vCommReasonMenu(iParam1);
			else
				vResetCommProcessState(iParam1);
		}
	}

	return 0;
}

/**
 * Processes a communication restriction command issued by a client.
 *
 * @param iClient       The client index of the player issuing the command.
 * @param iArgs         The number of arguments passed with the command.
 */
void vProcessCommReg(int iClient, int iArgs)
{
    char szCommType[5];
    char szTarget[65];
    char szReason[MAX_MESSAGE_LENGTH] = "";
	int iTime;

    GetCmdArg(1, szCommType, sizeof(szCommType));
    GetCmdArg(2, szTarget, sizeof(szTarget));

    eTypeComms eCommType;

	if (!bTryParseCommType(szCommType, eCommType))
	{
		vReplyCommandPhrase(iClient, "InvalidCommType");
		return;
	}

	if (!bTryGetCommandDurationArg(iArgs, 3, iTime))
	{
		vReplyCommandPhrase(iClient, "InvalidDuration");
		return;
	}

	vBuildCommandReasonFromArgs(4, iArgs, szReason, sizeof(szReason));

	int iTarget;
	char szAuthId[MAX_AUTHID_LENGTH];
	if (!bResolveTargetCommandInput(iClient, szTarget, true, kIdentityRequest_CommBan, szAuthId, sizeof(szAuthId), iTarget, view_as<int>(eCommType), iTime, szReason))
		return;

	vRegComm(iClient, iTarget, szAuthId, iTime, szReason, eCommType);
}

void vSubmitCommRegistrationByIdentity(int iClient, const char[] szTargetAuthId, int iTime, const char[] szReason, eTypeComms eCommType, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iTarget = FindClientBySteamID2(szTargetAuthId);
	if (iTarget <= SERVER_INDEX)
		iTarget = NO_INDEX;

	vRegComm(iClient, iTarget, szTargetAuthId, iTime, szReason, eCommType);
}

/**
 * Registers a communication ban in the database for a specific player.
 *
 * @param iAdmin            The index of the admin issuing the ban. Use SERVER_INDEX for server bans.
 * @param iTarget           The index of the target player being banned. Use NO_INDEX if the player is not in the server.
 * @param szTargetAuthId    The Steam2 Auth ID of the target player.
 * @param iLength           The duration of the ban in minutes. Use 0 for permanent bans.
 * @param szReason          The reason for the ban. Can be an empty string if no reason is provided.
 * @param eComms            The type of communication ban (e.g., voice, text, or all).
 */
void vRegComm(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason, eTypeComms eComms, const char[] szContext = "")
{
	LogDebug("[vRegComm] iAdmin: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | reason: %s | eComms: %d", iAdmin, iTarget, szTargetAuthId, iLength, szReason, eComms);

	if (iAdmin != SERVER_INDEX && !bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget != NO_INDEX && !bIsUsableClient(iTarget))
		iTarget = NO_INDEX;

	if (!bEnsurePrimaryDatabaseReady(iAdmin))
		return;

	int
		iAccountId;

	ReplySource eRsCmd = GetCmdReplySource();
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iAdmin, "AuthIdError", szTargetAuthId);
		return;
	}

	char szLookupQuery[256];
	g_dbDatabase.Format(szLookupQuery, sizeof(szLookupQuery),
		"SELECT `ban_type`, CASE WHEN `ban_length` = 0 OR `date_expire` IS NULL THEN 0 ELSE GREATEST(TIMESTAMPDIFF(MINUTE, UTC_TIMESTAMP(), `date_expire`), 0) END AS `remaining_minutes`, `ban_reason`, `ban_context` FROM `%s` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());",
		TABLE_COMM, iAccountId);

	LogSQL("[vRegComm] lookup query: %s", szLookupQuery);

	DataPack pRegComm = pCreateAdminTargetAuthLengthReasonContextTypeReplyContext(iAdmin, iTarget, szTargetAuthId, iLength, szReason, szContext, eComms, eRsCmd);
	SQL_TQuery(g_dbDatabase, vRegCommLookupCallback, szLookupQuery, pRegComm);
}

void vRegCommLookupCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char
		szTargetAuthId[MAX_AUTHID_LENGTH],
		szReason[MAX_MESSAGE_LENGTH],
		szContext[512],
		szTargetName[MAX_NAME_LENGTH],
		szAdminName[MAX_NAME_LENGTH] = "Console";

	int
		iAdmin,
		iAccountId,
		iReplyClient,
		iUserIdAdmin,
		iTarget,
		iUserIdTarget,
		iLength,
		iExistingRemainingLength;

	eTypeComms eComms, eExistingComms;
	ReplySource eRsCmd;
	vReadAdminTargetAuthLengthReasonContextTypeReplyContext(pData, iUserIdAdmin, iUserIdTarget, szTargetAuthId, sizeof(szTargetAuthId), iLength, szReason, sizeof(szReason), szContext, sizeof(szContext), eComms, eRsCmd);

	iReplyClient = iResolveReplyClientForCommand(iUserIdAdmin, eRsCmd, false);
	iAdmin = iResolveAdminForAudit(iUserIdAdmin, szAdminName, sizeof(szAdminName));
	vResolveTargetForAudit(iUserIdTarget, szTargetAuthId, iTarget, szTargetName, sizeof(szTargetName));

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vRegCommLookupCallback");
		delete rsResult;
		return;
	}

	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhraseString(iReplyClient, "AuthIdError", szTargetAuthId);
		delete rsResult;
		return;
	}

	bool bUpdateExisting = false;
	eTypeComms eFinalComms = eComms;
	int iFinalLength = iLength;
	char szFinalReason[MAX_MESSAGE_LENGTH];
	char szFinalContext[512];
	strcopy(szFinalReason, sizeof(szFinalReason), szReason);
	strcopy(szFinalContext, sizeof(szFinalContext), szContext);

	if (rsResult.FetchRow())
	{
		char szExistingReason[MAX_MESSAGE_LENGTH];
		char szExistingContext[512];

		eExistingComms = view_as<eTypeComms>(rsResult.FetchInt(0));
		iExistingRemainingLength = rsResult.FetchInt(1);
		rsResult.FetchString(2, szExistingReason, sizeof(szExistingReason));
		rsResult.FetchString(3, szExistingContext, sizeof(szExistingContext));

		if (bCommTypeIncludes(eExistingComms, eComms))
		{
			bRemoveLocalCache(szTargetAuthId);
			vSyncConnectedClientState(szTargetAuthId, iTarget);
			vReplyCommBanResult(iReplyClient, eComms, true, szTargetName);
			delete rsResult;
			return;
		}

		bUpdateExisting = true;
		eFinalComms = eMergeCommTypes(eExistingComms, eComms);
		if (iExistingRemainingLength == 0 || iLength == 0)
			iFinalLength = 0;
		else
			iFinalLength = (iExistingRemainingLength > iLength) ? iExistingRemainingLength : iLength;

		if (szFinalReason[0] == '\0')
			strcopy(szFinalReason, sizeof(szFinalReason), szExistingReason);
		if (szFinalContext[0] == '\0')
			strcopy(szFinalContext, sizeof(szFinalContext), szExistingContext);
	}

	delete rsResult;

	vSubmitCommRegistrationQuery(iAdmin, iTarget, iAccountId, szTargetAuthId, iFinalLength, szFinalReason, szFinalContext, eComms, eFinalComms, szTargetName, bUpdateExisting, eRsCmd);
}

void vSubmitCommRegistrationQuery(int iAdmin, int iTarget, int iAccountId, const char[] szTargetAuthId, int iLength, const char[] szReason, const char[] szContext, eTypeComms eRequestedComms, eTypeComms eStoredComms, const char[] szTargetName, bool bUpdateExisting, ReplySource eRsCmd)
{
	char
		szTargetIp[32],
		szTargetSteamId64[32],
		szAdminName[MAX_NAME_LENGTH] = "Console",
		szAdminSteamId64[32],
		szSafeTargetIp[64],
		szSafeTargetName[(MAX_NAME_LENGTH * 2) + 1],
		szSafeTargetSteamId64[64],
		szSafeAdminName[(MAX_NAME_LENGTH * 2) + 1],
		szSafeAdminSteamId64[64],
		szSafeReason[(MAX_MESSAGE_LENGTH * 2) + 1],
		szSafeContext[(512 * 2) + 1];

	int iAdminAccountId = 0;
	if (iAdmin != SERVER_INDEX && bIsUsableClient(iAdmin))
	{
		iAdminAccountId = iGetAdminAccountId(iAdmin);
		GetClientName(iAdmin, szAdminName, sizeof(szAdminName));
		bResolveSteamId64(iAdmin, iAdminAccountId, szAdminSteamId64, sizeof(szAdminSteamId64));
	}
	else
		szAdminSteamId64[0] = '\0';

	if (!bResolveSteamId64(iTarget, iAccountId, szTargetSteamId64, sizeof(szTargetSteamId64)))
	{
		int iReplyClient = iResolveReplyClientForCommand(iGetCommandIssuerUserId(iAdmin), eRsCmd, false);
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhraseString(iReplyClient, "AuthIdError", szTargetAuthId);
		return;
	}

	if (iTarget != NO_INDEX)
	{
		char szRuntimeTargetName[MAX_NAME_LENGTH];
		GetClientName(iTarget, szRuntimeTargetName, sizeof(szRuntimeTargetName));
		GetClientIP(iTarget, szTargetIp, sizeof(szTargetIp));
		g_dbDatabase.Escape(szRuntimeTargetName, szSafeTargetName, sizeof(szSafeTargetName));
		g_dbDatabase.Escape(szTargetIp, szSafeTargetIp, sizeof(szSafeTargetIp));
	}
	else
	{
		g_dbDatabase.Escape(szTargetName, szSafeTargetName, sizeof(szSafeTargetName));
	}

	g_dbDatabase.Escape(szTargetSteamId64, szSafeTargetSteamId64, sizeof(szSafeTargetSteamId64));
	g_dbDatabase.Escape(szAdminName, szSafeAdminName, sizeof(szSafeAdminName));
	g_dbDatabase.Escape(szAdminSteamId64, szSafeAdminSteamId64, sizeof(szSafeAdminSteamId64));
	if (strlen(szReason) != 0)
		g_dbDatabase.Escape(szReason, szSafeReason, sizeof(szSafeReason));
	else
		szSafeReason[0] = '\0';
	if (strlen(szContext) != 0)
		g_dbDatabase.Escape(szContext, szSafeContext, sizeof(szSafeContext));
	else
		szSafeContext[0] = '\0';

	char szQuery[1400];
	int iLen = 0;

	if (!bUpdateExisting)
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` (", TABLE_COMM);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`accountid`, `steamid64`");

		if (iTarget != NO_INDEX)
		{
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `player_name`, `ip_address`");
		}

		if (eStoredComms != kAll)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_type`");

		if (iLength != 0)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_length`");
		if (strlen(szReason) != 0)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_reason`");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") VALUES (%d, '%s'", iAccountId, szSafeTargetSteamId64);

		if (iTarget != NO_INDEX)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s', '%s'", szSafeTargetName, szSafeTargetIp);
		if (eStoredComms != kAll)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", eStoredComms);
		if (iLength != 0)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", iLength);
		if (strlen(szReason) != 0)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szSafeReason);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s', %d, '%s', '%s')", szSafeContext, iAdminAccountId, szSafeAdminName, szSafeAdminSteamId64);
	}
	else
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "UPDATE `%s` SET `steamid64` = '%s'", TABLE_COMM, szSafeTargetSteamId64);
		if (iTarget != NO_INDEX)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `player_name` = '%s', `ip_address` = '%s'", szSafeTargetName, szSafeTargetIp);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_type` = %d, `ban_length` = %d", eStoredComms, iLength);
		if (strlen(szReason) != 0)
			iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_reason` = '%s'", szSafeReason);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_context` = '%s', `banned_by` = %d, `banned_by_name` = '%s', `banned_by_steamid64` = '%s' WHERE `accountid` = %d", szSafeContext, iAdminAccountId, szSafeAdminName, szSafeAdminSteamId64, iAccountId);
	}

	LogSQL("[vSubmitCommRegistrationQuery] szQuery: %s", szQuery);

	DataPack pRegComm = pCreateAdminTargetAuthLengthReasonTypeReplyContext(iAdmin, iTarget, szTargetAuthId, iLength, szReason, eRequestedComms, eRsCmd);
	SQL_TQuery(g_dbDatabase, vRegCommCallback, szQuery, pRegComm);
}

void vRegCommCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char
		szTargetAuthId[MAX_AUTHID_LENGTH],
		szReason[MAX_MESSAGE_LENGTH],
		szTargetName[MAX_NAME_LENGTH],
		szAdminName[MAX_NAME_LENGTH] = "Console";

	int
		iAdmin,
		iReplyClient,
		iUserIdAdmin,
		iTarget,
		iUserIdTarget,
		iLength;

	eTypeComms eComms;
	ReplySource eRsCmd;
	vReadAdminTargetAuthLengthReasonTypeReplyContext(pData, iUserIdAdmin, iUserIdTarget, szTargetAuthId, sizeof(szTargetAuthId), iLength, szReason, sizeof(szReason), eComms, eRsCmd);

	iReplyClient = iResolveReplyClientForCommand(iUserIdAdmin, eRsCmd, false);
	iAdmin = iResolveAdminForAudit(iUserIdAdmin, szAdminName, sizeof(szAdminName));
	vResolveTargetForAudit(iUserIdTarget, szTargetAuthId, iTarget, szTargetName, sizeof(szTargetName));

	LogDebug("[vRegCommCallback] iUserIdAdmin: %d | iAdmin: %d | iUserIdTarget: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | szReason: %s | szTargetName: %s | eComms: %d" , iUserIdAdmin, iAdmin, iUserIdTarget, iTarget, szTargetAuthId, iLength, szReason, szTargetName, eComms);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vRegCommCallback");
		delete rsResult;
		return;
	}

	if(iTarget != NO_INDEX)
	{
		vSyncConnectedClientState(szTargetAuthId, iTarget);
		vNotifyCommBanTarget(iTarget, eComms, szAdminName, iLength, szReason);
	}

	vRefreshBSCoreCommSummaryByAuthId(szTargetAuthId);

	if (eComms == kChat || eComms == kAll)
	{
		Call_StartForward(g_gfOnBanChat);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_PushCell(iLength);
		Call_PushString(szReason);
		Call_Finish();
	}
	if (eComms == kMic || eComms == kAll)
	{
		Call_StartForward(g_gfOnBanMic);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_PushCell(iLength);
		Call_PushString(szReason);
		Call_Finish();
	}
}
