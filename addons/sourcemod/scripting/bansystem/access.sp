/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

enum ePanelInputStage
{
	kPanelInput_None = 0,
	kPanelInput_DurationValue,
	kPanelInput_Reason,
	kPanelInput_Context
}

enum eDurationUnit
{
	kDurationUnit_None = 0,
	kDurationUnit_Minutes,
	kDurationUnit_Hours,
	kDurationUnit_Days,
	kDurationUnit_Weeks,
	kDurationUnit_Months,
	kDurationUnit_Permanent
}

enum struct sProcessAccess {
	int m_iTargetUserId;
	int m_iLength;
	ePanelInputStage m_eInputStage;
	eDurationUnit m_eDurationUnit;
	char m_szTargetAuthId[MAX_AUTHID_LENGTH];
	char m_szReason[MAX_MESSAGE_LENGTH];
	char m_szContext[512];
}

sProcessAccess g_eProcessAccess[MAXPLAYERS+1];
StringMap g_smAttemptAccessIpCache;

void vResetAccessProcessState(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	g_eProcessAccess[iClient].m_iTargetUserId = NO_INDEX;
	g_eProcessAccess[iClient].m_iLength = 0;
	g_eProcessAccess[iClient].m_eInputStage = kPanelInput_None;
	g_eProcessAccess[iClient].m_eDurationUnit = kDurationUnit_None;
	g_eProcessAccess[iClient].m_szTargetAuthId[0] = '\0';
	g_eProcessAccess[iClient].m_szReason[0] = '\0';
	g_eProcessAccess[iClient].m_szContext[0] = '\0';
}

void vSetAccessProcessTarget(int iClient, int iTarget)
{
	g_eProcessAccess[iClient].m_iTargetUserId = GetClientUserId(iTarget);

	if (!GetClientAuthId(iTarget, AuthId_Steam2, g_eProcessAccess[iClient].m_szTargetAuthId, MAX_AUTHID_LENGTH))
	{
		g_eProcessAccess[iClient].m_iTargetUserId = NO_INDEX;
		g_eProcessAccess[iClient].m_szTargetAuthId[0] = '\0';
	}
}

int iGetAccessProcessTarget(int iClient)
{
	int iTarget = GetClientOfUserId(g_eProcessAccess[iClient].m_iTargetUserId);
	if (iTarget <= SERVER_INDEX)
		return NO_INDEX;

	char szTargetAuthId[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId)))
		return NO_INDEX;

	if (!StrEqual(szTargetAuthId, g_eProcessAccess[iClient].m_szTargetAuthId))
		return NO_INDEX;

	return iTarget;
}

void vGetAccessProcessTargetLabel(int iClient, char[] szBuffer, int iMaxLength)
{
	int iTarget = iGetAccessProcessTarget(iClient);
	if (iTarget != NO_INDEX)
	{
		Format(szBuffer, iMaxLength, "%N", iTarget);
		return;
	}

	if (g_eProcessAccess[iClient].m_szTargetAuthId[0] != '\0')
	{
		strcopy(szBuffer, iMaxLength, g_eProcessAccess[iClient].m_szTargetAuthId);
		return;
	}

	strcopy(szBuffer, iMaxLength, "UNKNOWN");
}

bool bTryConvertDurationUnitToMinutes(eDurationUnit eUnit, int iValue, int &iMinutes)
{
	if (iValue < 0)
		return false;

	switch (eUnit)
	{
		case kDurationUnit_Minutes:
			iMinutes = iValue;
		case kDurationUnit_Hours:
			iMinutes = iValue * 60;
		case kDurationUnit_Days:
			iMinutes = iValue * 1440;
		case kDurationUnit_Weeks:
			iMinutes = iValue * 10080;
		case kDurationUnit_Months:
			iMinutes = iValue * 43200;
		case kDurationUnit_Permanent:
			iMinutes = 0;
		default:
			return false;
	}

	return true;
}

void vGetDurationUnitDisplay(int iClient, eDurationUnit eUnit, char[] szBuffer, int iMaxLength)
{
	switch (eUnit)
	{
		case kDurationUnit_Minutes:
			Format(szBuffer, iMaxLength, "%T", "Minutes", iClient);
		case kDurationUnit_Hours:
			Format(szBuffer, iMaxLength, "%T", "Hours", iClient);
		case kDurationUnit_Days:
			Format(szBuffer, iMaxLength, "%T", "Days", iClient);
		case kDurationUnit_Weeks:
			Format(szBuffer, iMaxLength, "%T", "Weeks", iClient);
		case kDurationUnit_Months:
			Format(szBuffer, iMaxLength, "%T", "Months", iClient);
		case kDurationUnit_Permanent:
			Format(szBuffer, iMaxLength, "%T", "Permanent", iClient);
		default:
			strcopy(szBuffer, iMaxLength, "Unknown");
	}
}

void vAccessContextMenu(int iClient)
{
	char szTitle[192];
	char szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH];
	char szTime[64];

	vGetAccessProcessTargetLabel(iClient, szTargetLabel, sizeof(szTargetLabel));
	GetTimeLength(g_eProcessAccess[iClient].m_iLength, szTime, sizeof(szTime));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%s", "Ban reason", iClient, szTargetLabel, szTime);

	Menu hContextMenu = new Menu(iAccessContextMenuHandler);
	hContextMenu.SetTitle(szTitle);
	hContextMenu.ExitBackButton = true;

	char szLabel[64];
	Format(szLabel, sizeof(szLabel), "%T", "BanContextSkip", iClient);
	hContextMenu.AddItem("0", szLabel);

	Format(szLabel, sizeof(szLabel), "%T", "BanContextAdd", iClient);
	hContextMenu.AddItem("1", szLabel);

	hContextMenu.Display(iClient, MENU_TIME_FOREVER);
}

void vFinalizeAccessProcess(int iClient)
{
	int iTarget = iGetAccessProcessTarget(iClient);
	char szAuthId[MAX_AUTHID_LENGTH];
	char szReason[MAX_MESSAGE_LENGTH];
	char szContext[512];

	strcopy(szAuthId, sizeof(szAuthId), g_eProcessAccess[iClient].m_szTargetAuthId);
	strcopy(szReason, sizeof(szReason), g_eProcessAccess[iClient].m_szReason);
	strcopy(szContext, sizeof(szContext), g_eProcessAccess[iClient].m_szContext);

	vRegAccess(iClient, iTarget, szAuthId, g_eProcessAccess[iClient].m_iLength, szReason, szContext);
	vResetAccessProcessState(iClient);
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

void vOnPluginStart_Access()
{
	g_smAttemptAccessIpCache = new StringMap();

    RegAdminCmd("sm_ban", aRegAccessCmd, ADMFLAG_BAN, "Ban a player from the server.");
    RegAdminCmd("sm_unban", aRemoveAccessCmd, ADMFLAG_BAN, "Unban a player from the server.");
    RegAdminCmd("sm_ban_info", aInfoCmd, ADMFLAG_BAN, "Get information about a banned player.");
    RegAdminCmd("sm_ban_ls", aListAccessDbCmd, ADMFLAG_BAN, "List active access bans from the database.");
    RegAdminCmd("sm_ban_attempt_steamid", aInfoSteamIdCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_ban_attempt_ip", aInfoIpCmd, ADMFLAG_GENERIC);
}

void vBuildAttemptAccessCacheKey(int iAccountId, char[] szBuffer, int iMaxLength)
{
	IntToString(iAccountId, szBuffer, iMaxLength);
}

bool bRememberAttemptAccessIp(int iAccountId, const char[] szIpAddress)
{
	if (iAccountId == 0 || szIpAddress[0] == '\0' || g_smAttemptAccessIpCache == null)
		return false;

	char szKey[16];
	char szCachedIp[32];
	vBuildAttemptAccessCacheKey(iAccountId, szKey, sizeof(szKey));

	if (g_smAttemptAccessIpCache.GetString(szKey, szCachedIp, sizeof(szCachedIp)) && StrEqual(szCachedIp, szIpAddress, false))
		return false;

	g_smAttemptAccessIpCache.SetString(szKey, szIpAddress);
	return true;
}

void vForgetAttemptAccessIpIfMatches(int iAccountId, const char[] szIpAddress)
{
	if (iAccountId == 0 || szIpAddress[0] == '\0' || g_smAttemptAccessIpCache == null)
		return;

	char szKey[16];
	char szCachedIp[32];
	vBuildAttemptAccessCacheKey(iAccountId, szKey, sizeof(szKey));

	if (!g_smAttemptAccessIpCache.GetString(szKey, szCachedIp, sizeof(szCachedIp)))
		return;

	if (StrEqual(szCachedIp, szIpAddress, false))
		g_smAttemptAccessIpCache.Remove(szKey);
}

Action aRegAccessCmd(int iClient, int iArgs)
{
	if (iClient != SERVER_INDEX)
		vResetPendingAdminProcesses(iClient);

	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	ReplySource eRsCmd = GetCmdReplySource();
	if (iArgs == 0)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vAccessTargetMenu(iClient);
		else
		{
			vReplyCommandUsage(iClient, "sm_ban <#userid|name|steamid|steamid3|steamid64|accountid> [minutes|0] [reason|#CODE]");
			vPrintReasonCodeList(iClient, "Access");
		}
	
		return Plugin_Handled;
	}

	vProcessAccessReg(iClient, iArgs);
	return Plugin_Handled;
}

Action aRemoveAccessCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	if (iArgs < 1)
	{
		vReplyCommandUsage(iClient, "sm_unban <steamid|steamid3|steamid64|accountid>");
		return Plugin_Handled;
	}

	ReplySource eRsCmd = GetCmdReplySource();
	char szTargetAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szTargetAuthId, sizeof(szTargetAuthId));

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	if (!bResolveIdentityOnlyCommandInput(iClient, szTargetAuthId, true, kIdentityRequest_AccessUnban, szResolvedSteamId2, sizeof(szResolvedSteamId2)))
		return Plugin_Handled;

	vSubmitRemoveAccessByIdentity(iClient, szResolvedSteamId2, eRsCmd);
	return Plugin_Handled;
}

void vSubmitRemoveAccessByIdentity(int iClient, const char[] szTargetAuthId, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iClient, "AuthIdError", szTargetAuthId);
		return;
	}

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());", TABLE_ACCESS, iAccountId);

	LogSQL("[vSubmitRemoveAccessByIdentity] Query: %s", szQuery);

	DataPack pRemoveAccess = pCreateReplyContextString(iClient, szTargetAuthId, eRsCmd);
	SQL_TQuery(g_dbDatabase, vRemoveAccessCallback, szQuery, pRemoveAccess);
}

void vRemoveAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	int
		iAdmin,
		iReplyClient,
		iUserId;

	ReplySource eRsCmd;
	vReadReplyContextString(pData, iUserId, eRsCmd, szTargetAuthId, sizeof(szTargetAuthId));
	iReplyClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	iAdmin = iResolveReplyClient(iUserId, true);

	if (rsResult == null || szError[0])
	{
		if (iReplyClient != NO_INDEX)
			vReplyCommandPhrase(iReplyClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vRemoveAccessCallback");
		delete rsResult;
		return;
	}

	vRemoveSQLCache(szTargetAuthId);

	int iAffectedRows = SQL_GetAffectedRows(dbDataBase);
	LogSQL("[vRemoveAccessCallback] SQL_GetAffectedRows: %d", iAffectedRows);

   if (iAffectedRows == 0)
	{
		if (iReplyClient != NO_INDEX)
			CReplyToCommand(iReplyClient, "%t %t", "Prefix", "UnbanAccessNotFound", szTargetAuthId);
		delete rsResult;
		return;
	}

	if (iReplyClient != NO_INDEX)
		CReplyToCommand(iReplyClient, "%t %t", "Prefix", "UnbanAccessSuccess", szTargetAuthId);
	Call_StartForward(g_gfOnUnbanAcess);
	Call_PushCell(iAdmin);
	Call_PushString(szTargetAuthId);
	Call_Finish();

	delete rsResult;
	return;
}

Action aInfoCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

    if (iArgs < 1)
    {
        vReplyCommandUsage(iClient, "sm_ban_info <steamid|steamid3|steamid64|accountid>");
        return Plugin_Handled;
	}

	ReplySource eRsCmd = GetCmdReplySource();
	char szAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szAuthId, sizeof(szAuthId));

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	if (!bResolveIdentityOnlyCommandInput(iClient, szAuthId, true, kIdentityRequest_AccessInfo, szResolvedSteamId2, sizeof(szResolvedSteamId2)))
		return Plugin_Handled;

	vSubmitAccessInfoByIdentity(iClient, szResolvedSteamId2, eRsCmd);
	return Plugin_Handled;
}

void vSubmitAccessInfoByIdentity(int iClient, const char[] szAuthId, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iClient, "AuthIdError", szAuthId);
		return;
	}
 
    char szQuery[320];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `ip_address`, `ban_length`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, `date_expire`  FROM `%s` ", TABLE_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d ", iAccountId);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP());");

	LogSQL("[aInfoCmd] szQuery: %s", szQuery);

	DataPack pInfoCallback = pCreateReplyContextString(iClient, szAuthId, eRsCmd);
	SQL_TQuery(g_dbDatabase, vInfoCallback, szQuery, pInfoCallback);
}

void vInfoCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];
	int iUserId;
	ReplySource eRsCmd;
	vReadReplyContextString(pData, iUserId, eRsCmd, szAuthId, sizeof(szAuthId));
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}

    if (rsResult == null || szError[0])
    {
        vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vInfoCallback");
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
		szBannedBy[160],
		szBannedByName[MAX_NAME_LENGTH],
		szBannedBySteamId64[32],
		szDateExpire[64],
		szLength[128];

	int iLength, iBannedByAccountId;
	char szDisplayReason[MAX_MESSAGE_LENGTH];
	int iTranslationTarget = (iClient != SERVER_INDEX) ? iClient : LANG_SERVER;

	rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(1, szIpAddress, sizeof(szIpAddress));
    iLength = rsResult.FetchInt(2);
    rsResult.FetchString(3, szBanReason, sizeof(szBanReason));
	rsResult.FetchString(4, szBanContext, sizeof(szBanContext));
	iBannedByAccountId = rsResult.FetchInt(5);
	rsResult.FetchString(6, szBannedByName, sizeof(szBannedByName));
	rsResult.FetchString(7, szBannedBySteamId64, sizeof(szBannedBySteamId64));
	vFormatBannedByAuditDisplay(iBannedByAccountId, szBannedByName, szBannedBySteamId64, szBannedBy, sizeof(szBannedBy));
	vGetReasonDisplayText(iTranslationTarget, szBanReason, szDisplayReason, sizeof(szDisplayReason));
	vFormatDateOrPermanentDisplay(iTranslationTarget, rsResult, 8, szDateExpire, sizeof(szDateExpire));

	GetTimeLength(iLength, szLength, sizeof(szLength));

	vPrintInfoHeader(iClient);
    PrintToConsole(iClient, "> %t: %s", "InfoPlayerName", szPlayerName);
	PrintToConsole(iClient, "> %t: %s", "InfoIpAddress", szIpAddress);
    PrintToConsole(iClient, "> %t: %s", "InfoLength", szLength);
    PrintToConsole(iClient, "> %t: %s", "InfoReason", szDisplayReason);
	if (szBanContext[0] != '\0')
		PrintToConsole(iClient, "> %t: %s", "InfoContext", szBanContext);
    PrintToConsole(iClient, "> %t: %s", "InfonedBy", szBannedBy);
    PrintToConsole(iClient, "> %t: %s", "InfoTimestamp", szDateExpire);

	vNotifyInfoPrinted(iClient, eRsCmd);

    delete rsResult;
}

Action aInfoSteamIdCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

   if (iArgs < 1)
    {
        vReplyCommandUsage(iClient, "sm_ban_attempt_steamid <steamid|steamid3|steamid64|accountid>");
        return Plugin_Handled;
	}

	ReplySource eRsCmd = GetCmdReplySource();
	char szAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szAuthId, sizeof(szAuthId));

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	if (!bResolveIdentityOnlyCommandInput(iClient, szAuthId, true, kIdentityRequest_AccessAttemptInfo, szResolvedSteamId2, sizeof(szResolvedSteamId2)))
		return Plugin_Handled;

	vSubmitAccessAttemptInfoByIdentity(iClient, szResolvedSteamId2, eRsCmd);
	return Plugin_Handled;
}

void vSubmitAccessAttemptInfoByIdentity(int iClient, const char[] szAuthId, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iClient, "AuthIdError", szAuthId);
		return;
	}
 
    char szQuery[256];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT DISTINCT CONCAT(player_name, ' - ', ip_address) AS player_info ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_DATA_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `accountid` = %d;", iAccountId);

	LogSQL("[aInfoSteamIdCmd] szQuery: %s", szQuery);

	DataPack pInfoIp = pCreateReplyContextString(iClient, szAuthId, eRsCmd);
	SQL_TQuery(g_dbDatabase, vInfoSteamIdCallback, szQuery, pInfoIp);
}

void vInfoSteamIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];
	int iUserId;
	ReplySource eRsCmd;
	vReadReplyContextString(pData, iUserId, eRsCmd, szAuthId, sizeof(szAuthId));
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}

    if (rsResult == null || szError[0])
    {
        vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vInfoSteamIdCallback");
		delete rsResult;
        return;
    }
	
    if (!rsResult.FetchRow())
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "NoBanInfo", szAuthId);
        delete rsResult;
        return;
    }

	vPrintInfoHeader(iClient);
    do
    {
		char szPlayerName[MAX_NAME_LENGTH];
		char szPlayerAuthId[MAX_AUTHID_LENGTH];
		int iAccountId = rsResult.FetchInt(1);

		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		bGetAuthIdFromAccountId(iAccountId, szPlayerAuthId, sizeof(szPlayerAuthId));
        PrintToConsole(iClient, "> %s - %s", szPlayerName, szPlayerAuthId);
    } while (rsResult.FetchRow());

	vNotifyInfoPrinted(iClient, eRsCmd);

	delete rsResult;
}

Action aInfoIpCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

   if (iArgs < 1)
    {
        vReplyCommandUsage(iClient, "sm_ban_attempt_ip <\"ip\">");
        return Plugin_Handled;
    }

    char szIpAddress[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szIpAddress, sizeof(szIpAddress));

    ReplaceString(szIpAddress, sizeof(szIpAddress), "\"", "");

    if (!bIsIpAddress(szIpAddress))
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "IpAddressError", szIpAddress);
        return Plugin_Handled;
    }
 
    char szQuery[256];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT DISTINCT `player_name`, `accountid` ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_DATA_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `ip_address` = '%s';", szIpAddress);

	LogSQL("[aInfoIpCmd] szQuery: %s", szQuery);

	DataPack pInfoIp = pCreateReplyContextString(iClient, szIpAddress, GetCmdReplySource());
	SQL_TQuery(g_dbDatabase, vInfoIpCallback, szQuery, pInfoIp);
	return Plugin_Handled;
}

Action aListAccessDbCmd(int iClient, int iArgs)
{
	if (!bEnsurePrimaryDatabaseReady(iClient))
		return Plugin_Handled;

	int iLimit = iGetQueryListLimit(iArgs);

	char szQuery[512];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `accountid`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`, `date_expire` ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ORDER BY `date_reg` DESC LIMIT %d;", iLimit);

	DataPack pListAccess = pCreateReplyContext(iClient, GetCmdReplySource());
	SQL_TQuery(g_dbDatabase, vListAccessCallback, szQuery, pListAccess);
	return Plugin_Handled;
}

void vInfoIpCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szIpAddress[MAX_AUTHID_LENGTH];
	int iUserId;
	ReplySource eRsCmd;
	vReadReplyContextString(pData, iUserId, eRsCmd, szIpAddress, sizeof(szIpAddress));
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0])
	{
		vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vInfoIpCallback");
		delete rsResult;
		return;
	}
	
    if (!rsResult.FetchRow())
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "NoBanInfo", szIpAddress);
        delete rsResult;
        return;
    }

	vPrintInfoHeader(iClient);
    do
    {
		char szPlayerName[MAX_NAME_LENGTH];
		char szAuthId[MAX_AUTHID_LENGTH];
		int iAccountId = rsResult.FetchInt(1);

		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		bGetAuthIdFromAccountId(iAccountId, szAuthId, sizeof(szAuthId));
		PrintToConsole(iClient, "> %s - %s", szPlayerName, szAuthId);
	} while (rsResult.FetchRow());

	vNotifyInfoPrinted(iClient, eRsCmd);

	delete rsResult;
}

void vListAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int iUserId;
	ReplySource eRsCmd;
	vReadReplyContext(pData, iUserId, eRsCmd);
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
	if (rsResult == null || szError[0])
	{
		vReplyCommandPhrase(iClient, "SQLError");
		logErrorSQL(dbDataBase, szError, "vListAccessCallback");
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoActiveAccessBans");
		delete rsResult;
		return;
	}

	int iTranslationTarget = (iClient != SERVER_INDEX) ? iClient : LANG_SERVER;

	vPrintConsoleHeader(iClient, "Active Access Bans");
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

		int iLength = rsResult.FetchInt(2);
		int iBannedByAccountId = rsResult.FetchInt(5);
		int iAccountId = rsResult.FetchInt(1);

		rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
		rsResult.FetchString(3, szReason, sizeof(szReason));
		rsResult.FetchString(4, szBanContext, sizeof(szBanContext));
		rsResult.FetchString(6, szBannedByName, sizeof(szBannedByName));
		rsResult.FetchString(7, szBannedBySteamId64, sizeof(szBannedBySteamId64));
		bGetAuthIdFromAccountId(iAccountId, szAuthId, sizeof(szAuthId));
		vFormatBannedByAuditDisplay(iBannedByAccountId, szBannedByName, szBannedBySteamId64, szBannedBy, sizeof(szBannedBy));

		vGetReasonDisplayText(iTranslationTarget, szReason, szDisplayReason, sizeof(szDisplayReason));
		GetTimeLength(iLength, szLength, sizeof(szLength));

		vFormatDateOrPermanentDisplay(iTranslationTarget, rsResult, 8, szDateExpire, sizeof(szDateExpire));

		PrintToConsole(iClient, "> %s | SteamID: %s | %t: %s | %t: %s | %t: %s | %t: %s",
			szPlayerName,
			szAuthId,
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

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

Action aOnClientSayCommand_Access(int iClient, const char[] szArgs)
{
	if (g_eProcessAccess[iClient].m_eInputStage == kPanelInput_None || IsChatTrigger())
		return Plugin_Continue;

	SetCmdReplySource(SM_REPLY_TO_CHAT);
	switch (g_eProcessAccess[iClient].m_eInputStage)
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
			if (!bTryConvertDurationUnitToMinutes(g_eProcessAccess[iClient].m_eDurationUnit, StringToInt(szValue), iMinutes))
			{
				CPrintToChat(iClient, "%t %t", "Prefix", "BanDurationValueInvalid");
				return Plugin_Stop;
			}

			g_eProcessAccess[iClient].m_iLength = iMinutes;
			g_eProcessAccess[iClient].m_eInputStage = kPanelInput_None;
			vAccessReasonMenu(iClient);
		}
		case kPanelInput_Reason:
		{
			g_eProcessAccess[iClient].m_eInputStage = kPanelInput_None;
			strcopy(g_eProcessAccess[iClient].m_szReason, sizeof(g_eProcessAccess[].m_szReason), szArgs);
			TrimString(g_eProcessAccess[iClient].m_szReason);
			StripQuotes(g_eProcessAccess[iClient].m_szReason);
			vAccessContextMenu(iClient);
		}
		case kPanelInput_Context:
		{
			g_eProcessAccess[iClient].m_eInputStage = kPanelInput_None;
			strcopy(g_eProcessAccess[iClient].m_szContext, sizeof(g_eProcessAccess[].m_szContext), szArgs);
			TrimString(g_eProcessAccess[iClient].m_szContext);
			StripQuotes(g_eProcessAccess[iClient].m_szContext);
			vFinalizeAccessProcess(iClient);
		}
	}

	return Plugin_Stop;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Displays a menu to the specified client for selecting a target player to ban.
 *
 * @param client The client index of the player who will see the menu.
 */
void vAccessTargetMenu(int iClient)
{
	char szTitle[MAX_MESSAGE_LENGTH];
	Format(szTitle, sizeof(szTitle), "%T:", "Ban player", iClient);

	Menu hTargetMenu = new Menu(iAccessTargetMenuHandler);
	hTargetMenu.SetTitle(szTitle);

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

		if (!CanUserTarget(iClient, i))
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
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoTargetsAccessBan");
		return;
	}

	hTargetMenu.Display(iClient, MENU_TIME_FOREVER);
}

int iAccessTargetMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
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
				iUserid,
				iTarget;

			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			iUserid = StringToInt(szInfo);

			if ((iTarget = GetClientOfUserId(iUserid)) == 0)
			{
				CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
				vAccessTargetMenu(iParam1);
			}
			else if (!CanUserTarget(iParam1, iTarget))
			{
				CPrintToChat(iParam1, "%t %t", "Prefix", "Unable to target");
				vAccessTargetMenu(iParam1);
			}
			else
			{
				vSetAccessProcessTarget(iParam1, iTarget);
				g_eProcessAccess[iParam1].m_eDurationUnit = kDurationUnit_None;
				g_eProcessAccess[iParam1].m_iLength = 0;
				vAccessTimeMenu(iParam1);
			}
		}

		case MenuAction_Cancel:
			vResetAccessProcessState(iParam1);
	}

	return 0;
}

/**
 * Displays a menu to the client for selecting a ban duration.
 *
 * @param iClient The client index to whom the menu will be displayed.
 */
void vAccessTimeMenu(int iClient)
{
	char
		szTitle[64],
		szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH];

	vGetAccessProcessTargetLabel(iClient, szTargetLabel, sizeof(szTargetLabel));
	Format(szTitle, sizeof(szTitle), "%T\n>%s", "Ban player", iClient, szTargetLabel);

	Menu hTimeMenu = new Menu(iAccessTimeMenuHandler);
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

int iAccessTimeMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			char szInfo[32];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			g_eProcessAccess[iParam1].m_eDurationUnit = view_as<eDurationUnit>(StringToInt(szInfo));
			if (g_eProcessAccess[iParam1].m_eDurationUnit == kDurationUnit_Permanent)
			{
				g_eProcessAccess[iParam1].m_iLength = 0;
				vAccessReasonMenu(iParam1);
			}
			else
			{
				char szUnit[64];
				vGetDurationUnitDisplay(iParam1, g_eProcessAccess[iParam1].m_eDurationUnit, szUnit, sizeof(szUnit));
				g_eProcessAccess[iParam1].m_eInputStage = kPanelInput_DurationValue;
				CPrintToChat(iParam1, "%t %t", "Prefix", "BanDurationValuePrompt", szUnit, "sm_abort");
			}
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
			{
				g_eProcessAccess[iParam1].m_iLength = 0;
				g_eProcessAccess[iParam1].m_eDurationUnit = kDurationUnit_None;
				vAccessTargetMenu(iParam1);
			}
			else
				vResetAccessProcessState(iParam1);
		}
	}

	return 0;
}

/**
 * Displays a menu to the client for selecting a ban reason.
 *
 * @param client        The client index to whom the menu will be displayed.
 */
void vAccessReasonMenu(int client)
{
	char
		szTitle[128],
		szTargetLabel[MAX_NAME_LENGTH + MAX_AUTHID_LENGTH],
		szTime[32],
		szCustomReason[64];
	
	GetTimeLength(g_eProcessAccess[client].m_iLength, szTime, sizeof(szTime));
	vGetAccessProcessTargetLabel(client, szTargetLabel, sizeof(szTargetLabel));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%s", "Ban reason", client, szTargetLabel, szTime);

	Menu hAccessReasonMenu = new Menu(iAccessReasonMenuHandler);
	hAccessReasonMenu.SetTitle(szTitle);
	hAccessReasonMenu.ExitBackButton = true;
	
	Format(szCustomReason, sizeof(szCustomReason), "%t", "CustomReason", client);
	hAccessReasonMenu.AddItem("", szCustomReason);
	
	char
		szReasonValue[MAX_NAME_LENGTH],
		szTranslation[MAX_MESSAGE_LENGTH];
	
    if (!g_kvReasons.JumpToKey("Access", false))
    {
        delete hAccessReasonMenu;
		g_kvReasons.Rewind();
		vResetAccessProcessState(client);
        PrintToServer("%t", "ErrorSectionName", "Access");
        return;
    }
    
    if (g_kvReasons.GotoFirstSubKey(false))
    {
        do
        {
            g_kvReasons.GetString(NULL_STRING, szReasonValue, sizeof(szReasonValue), "#ERR");
			Format(szTranslation, sizeof(szTranslation), "%T", szReasonValue, client);
            hAccessReasonMenu.AddItem(szReasonValue, szTranslation);
            
        } while (g_kvReasons.GotoNextKey(false));
    }
	
	g_kvReasons.Rewind();
	hAccessReasonMenu.Display(client, MENU_TIME_FOREVER);
}

int iAccessReasonMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			if (iParam2 == 0)
			{
				g_eProcessAccess[iParam1].m_eInputStage = kPanelInput_Reason;
				CPrintToChat(iParam1, "%t %t", "Prefix", "Custom ban reason explanation", "sm_abort");
				return 0;
			}

			char
				szReason[MAX_MESSAGE_LENGTH],
				szTargetAuthId[MAX_AUTHID_LENGTH];

			hMenu.GetItem(iParam2, szReason, sizeof(szReason));
			strcopy(g_eProcessAccess[iParam1].m_szReason, sizeof(g_eProcessAccess[].m_szReason), szReason);
			strcopy(szTargetAuthId, sizeof(szTargetAuthId), g_eProcessAccess[iParam1].m_szTargetAuthId);
			int iTarget = iGetAccessProcessTarget(iParam1);

			LogMenu("[iAccessReasonMenuHandler] iParam1: %N | iTarget: %d | szTargetAuthId: %s | m_iLength: %d | szReason: %s", iParam1, iTarget, szTargetAuthId, g_eProcessAccess[iParam1].m_iLength, szReason);
			vAccessContextMenu(iParam1);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vAccessTimeMenu(iParam1);
			else
				vResetAccessProcessState(iParam1);
		}
	}

	return 0;
}

int iAccessContextMenuHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
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
				g_eProcessAccess[iParam1].m_szContext[0] = '\0';
				vFinalizeAccessProcess(iParam1);
			}
			else
			{
				g_eProcessAccess[iParam1].m_eInputStage = kPanelInput_Context;
				CPrintToChat(iParam1, "%t %t", "Prefix", "BanContextPrompt", "sm_abort");
			}
		}

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				vAccessReasonMenu(iParam1);
			else
				vResetAccessProcessState(iParam1);
		}
	}

	return 0;
}

/**
 * Processes the access registration command for a client.
 *
 * @param iClient       The client index of the player issuing the command.
 * @param iArgs         The number of arguments provided with the command.
 */
void vProcessAccessReg(int iClient, int iArgs)
{
	char
		szTarget[65],
    	szReason[MAX_MESSAGE_LENGTH] = "";

	int iTime;

    GetCmdArg(1, szTarget, sizeof(szTarget));

	if (!bTryGetCommandDurationArg(iArgs, 2, iTime))
	{
		vReplyCommandPhrase(iClient, "InvalidDuration");
		return;
	}

	vBuildCommandReasonFromArgs(3, iArgs, szReason, sizeof(szReason));

	int iTarget;
	char szAuthId[MAX_AUTHID_LENGTH];
	if (!bResolveTargetCommandInput(iClient, szTarget, true, kIdentityRequest_AccessBan, szAuthId, sizeof(szAuthId), iTarget, iTime, 0, szReason))
		return;

	vRegAccess(iClient, iTarget, szAuthId, iTime, szReason);
}

void vSubmitAccessRegistrationByIdentity(int iClient, const char[] szTargetAuthId, int iTime, const char[] szReason, ReplySource eRsCmd)
{
	SetCmdReplySource(eRsCmd);

	int iTarget = FindClientBySteamID2(szTargetAuthId);
	if (iTarget <= SERVER_INDEX)
		iTarget = NO_INDEX;

	vRegAccess(iClient, iTarget, szTargetAuthId, iTime, szReason);
}

/**
 * Registers a ban for a target client.
 *
 * @param iAdmin        The client index of the player issuing the ban. Use SERVER_INDEX for server.
 * @param iTarget        The client index of the target player to be banned. Use NO_INDEX if not applicable.
 * @param szTargetAuthId The Steam2 Auth ID of the target player.
 * @param iLength        The length of the ban in minutes. Default is 0 (permanent ban).
 * @param szReason       The reason for the ban. Default is an empty string.
 */
void vRegAccess(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength = 0, const char[] szReason = "", const char[] szContext = "")
{
	LogDebug("[vRegister] iAdmin: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | reason: %s", iAdmin, iTarget, szTargetAuthId, iLength, szReason);

	if (iAdmin != SERVER_INDEX && !bIsUsableClient(iAdmin))
		iAdmin = SERVER_INDEX;

	if (iTarget != NO_INDEX && !bIsUsableClient(iTarget))
		iTarget = NO_INDEX;

	if (!bEnsurePrimaryDatabaseReady(iAdmin))
		return;

	int
		iAccountId,
		iAdminAccountId;

    char
		szTargetIp[32],
		szTargetSteamId64[32],
		szAdminSteamId64[32],
		szSafeTargetIp[64],
		szAdminName[MAX_NAME_LENGTH] = "Console",
        szTargetName[MAX_NAME_LENGTH],
		szSafeAdminName[(MAX_NAME_LENGTH * 2) + 1],
		szSafeTargetName[(MAX_NAME_LENGTH * 2) + 1],
		szSafeTargetSteamId64[64],
		szSafeAdminSteamId64[64],
		szSafeReason[(MAX_MESSAGE_LENGTH * 2) + 1],
		szSafeContext[(512 * 2) + 1];

	ReplySource eRsCmd = GetCmdReplySource();
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
	{
		vReplyCommandPhraseString(iAdmin, "AuthIdError", szTargetAuthId);
		return;
	}

	if (!bResolveSteamId64(iTarget, iAccountId, szTargetSteamId64, sizeof(szTargetSteamId64)))
	{
		vReplyCommandPhraseString(iAdmin, "AuthIdError", szTargetAuthId);
		return;
	}

	if(iAdmin != SERVER_INDEX)
	{
		iAdminAccountId = iGetAdminAccountId(iAdmin);
		GetClientName(iAdmin, szAdminName, sizeof(szAdminName));
		bResolveSteamId64(iAdmin, iAdminAccountId, szAdminSteamId64, sizeof(szAdminSteamId64));
	}
	else
	{
		iAdminAccountId = 0;
		szAdminSteamId64[0] = '\0';
	}

	if(iTarget != NO_INDEX)
	{
        GetClientName(iTarget, szTargetName, sizeof(szTargetName));
		GetClientIP(iTarget, szTargetIp, sizeof(szTargetIp));
		g_dbDatabase.Escape(szTargetName, szSafeTargetName, sizeof(szSafeTargetName));
		g_dbDatabase.Escape(szTargetIp, szSafeTargetIp, sizeof(szSafeTargetIp));
	}
	else
	{
		strcopy(szTargetName, sizeof(szTargetName), szTargetAuthId);
		g_dbDatabase.Escape(szTargetName, szSafeTargetName, sizeof(szSafeTargetName));
	}

	g_dbDatabase.Escape(szTargetSteamId64, szSafeTargetSteamId64, sizeof(szSafeTargetSteamId64));
	g_dbDatabase.Escape(szAdminName, szSafeAdminName, sizeof(szSafeAdminName));
	g_dbDatabase.Escape(szAdminSteamId64, szSafeAdminSteamId64, sizeof(szSafeAdminSteamId64));
	if (strlen(szReason) != 0)
		g_dbDatabase.Escape(szReason, szSafeReason, sizeof(szSafeReason));
	if (strlen(szContext) != 0)
		g_dbDatabase.Escape(szContext, szSafeContext, sizeof(szSafeContext));
	else
		szSafeContext[0] = '\0';

	char szQuery[1024];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` (", TABLE_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`accountid`, `steamid64`");
	if(iTarget != NO_INDEX)
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `player_name`");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ip_address`");
	}
	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_length`");
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_reason`");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") VALUES (");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "%d, '%s'", iAccountId, szSafeTargetSteamId64);
	if(iTarget != NO_INDEX)
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szSafeTargetName);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szSafeTargetIp);
	}
	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", iLength);
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szSafeReason);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s', %d, '%s', '%s'", szSafeContext, iAdminAccountId, szSafeAdminName, szSafeAdminSteamId64);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ")");

	LogSQL("[vRegAccess] szQuery: %s", szQuery);

	DataPack pRegAccess = pCreateAdminTargetAuthLengthReasonReplyContext(iAdmin, iTarget, szTargetAuthId, iLength, szReason, eRsCmd);
	SQL_TQuery(g_dbDatabase, vRegAccessCallback, szQuery, pRegAccess);
}

void vRegAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char
		szAdminName[MAX_NAME_LENGTH] = "Console",
		szTargetName[MAX_NAME_LENGTH],
		szTargetAuthId[MAX_AUTHID_LENGTH],
		szReason[MAX_MESSAGE_LENGTH];

	int
		iAdmin,
		iReplyClient,
		iUserIdAdmin,
		iTarget,
		iUserIdTarget,
		iLength;

	ReplySource eRsCmd;
	vReadAdminTargetAuthLengthReasonReplyContext(pData, iUserIdAdmin, iUserIdTarget, szTargetAuthId, sizeof(szTargetAuthId), iLength, szReason, sizeof(szReason), eRsCmd);

	iReplyClient = iResolveReplyClientForCommand(iUserIdAdmin, eRsCmd, false);
	iAdmin = iResolveAdminForAudit(iUserIdAdmin, szAdminName, sizeof(szAdminName));
	vResolveTargetForAudit(iUserIdTarget, szTargetAuthId, iTarget, szTargetName, sizeof(szTargetName));

	LogDebug("[vRegAccessCallback] iUserIdAdmin: %d | iAdmin: %d | iUserIdTarget: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | szReason: %s | szTargetName: %s" , iUserIdAdmin, iAdmin, iUserIdTarget, iTarget, szTargetAuthId, iLength, szReason, szTargetName);
	
	if (rsResult == null || szError[0])
	{
		if (StrContains(szError, "Duplicate entry", false) != -1)
		{
			bRemoveLocalCache(szTargetAuthId);
			vSyncConnectedClientState(szTargetAuthId, iTarget);
			vReplyAccessBanResult(iReplyClient, true, szTargetName);
			delete rsResult;
			return;
		}
		else
		{
			if (iReplyClient != NO_INDEX)
				vReplyCommandPhrase(iReplyClient, "SQLError");
			logErrorSQL(dbDataBase, szError, "vRegAccessCallback");
		}
		delete rsResult;
		return;
	}

	bRemoveLocalCache(szTargetAuthId);
	if (iLength == 0)
		bRegisterCache(szTargetAuthId, 1);
	
	vReplyAccessBanResult(iReplyClient, false, szTargetName);
	
	if(iTarget != NO_INDEX)
	{
		vNotifyAccessBanTarget(iTarget, szAdminName, iLength, szReason);
		CreateTimer(0.2, aKickAccessTimer, iUserIdTarget);
	}

	Call_StartForward(g_gfOnBanAccess);
	Call_PushCell(iAdmin);
	Call_PushCell(iTarget);
	Call_PushString(szTargetAuthId);
	Call_PushCell(iLength);
	Call_PushString(szReason);
	Call_Finish();
}

Action aKickAccessTimer(Handle hTimer, any pData)
{
	int iClient = GetClientOfUserId(view_as<int>(pData));
	if (iClient > SERVER_INDEX)
		KickClientEx(iClient, "%t", "BannedAccess");
	return Plugin_Stop;
}

/**
 * Attempts to log an access attempt by a client and notifies admins.
 *
 * @param iClient       The client index attempting access.
 * @param szAuthId      The authentication ID (e.g., SteamID) of the client.
 */
void vAttemptAccess(int iClient, int iAccountId, const char[] szAuthId)
{
	vAttemptPrintToAdmins(iClient, szAuthId);

	if(!g_cvRegAttemptAccess.BoolValue || iAccountId == 0 || !bCanUsePrimaryDatabase())
		return;

	char
		szIpAddress[32],
		szName[64],
		szSteamId64[32],
		szSafeName[(MAX_NAME_LENGTH * 2) + 1];

	GetClientIP(iClient, szIpAddress, sizeof(szIpAddress));
	if (!bRememberAttemptAccessIp(iAccountId, szIpAddress))
	{
		LogDebug("[vAttemptAccess] Skipping duplicate attempts_access insert for client %N (%s) with unchanged IP %s", iClient, szAuthId, szIpAddress);
		return;
	}

	if (!bResolveSteamId64(iClient, iAccountId, szSteamId64, sizeof(szSteamId64)))
	{
		vForgetAttemptAccessIpIfMatches(iAccountId, szIpAddress);
		LogError("[vAttemptAccess] Failed to resolve steamid64 for client %N (%s)", iClient, szAuthId);
		return;
	}

	GetClientName(iClient, szName, sizeof(szName));
	g_dbDatabase.Escape(szName, szSafeName, sizeof(szSafeName));

	char szQuery[512];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "CALL AttemptAccess(%d, '%s', '%s', '%s')", iAccountId, szSteamId64, szSafeName, szIpAddress);

	LogSQL("[vAttemptAccess] Query: %s", szQuery);

	DataPack pAttemptContext = new DataPack();
	pAttemptContext.WriteCell(iClient);
	pAttemptContext.WriteCell(iAccountId);
	pAttemptContext.WriteString(szIpAddress);
	SQL_TQuery(g_dbDatabase, vAttemptAccessCallback, szQuery, pAttemptContext);
}

void vAttemptAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iClient = pContext.ReadCell();
	int iAccountId = pContext.ReadCell();
	char szIpAddress[32];
	pContext.ReadString(szIpAddress, sizeof(szIpAddress));
	delete pContext;

    if (rsResult == null || szError[0])
    {
		vForgetAttemptAccessIpIfMatches(iAccountId, szIpAddress);
        logErrorSQL(dbDataBase, szError, "vAttemptAccessCallback");
		delete rsResult;
        return;
    }

	LogDebug("[vAttemptAccessCallback] attempts_access saved for client index %d account_id=%d ip=%s", iClient, iAccountId, szIpAddress);

	delete rsResult;
}

/**
 * Attempts to notify all connected admins about a client's access attempt.
 *
 * This function iterates through all connected clients and sends a chat message
 * to those who are admins, informing them about a specific client's access attempt.
 *
 * @param iClient   The client index of the player attempting access.
 * @param szAuthId  The authentication ID (e.g., SteamID) of the client attempting access.
 */
void vAttemptPrintToAdmins(int iClient, const char[] szAuthId)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (GetUserAdmin(i) == INVALID_ADMIN_ID)
			continue;

		CPrintToChat(i, "%t %t", "Prefix", "AttemptAccess", iClient, szAuthId);
	}
}
