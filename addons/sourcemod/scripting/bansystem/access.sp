/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

enum struct sProcessAccess {
	int m_iTarget;
	int m_iLength;
	bool m_bIsWaitingChatReason;
}

sProcessAccess g_eProcessAccess[MAXPLAYERS+1];

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

void vOnPluginStart_Access()
{
    RegAdminCmd("sm_ban", aRegAccessCmd, ADMFLAG_BAN, "Ban a player from the server.");
    RegAdminCmd("sm_unban", aRemoveAccessCmd, ADMFLAG_BAN, "Unban a player from the server.");
    RegAdminCmd("sm_ban_info", aInfoCmd, ADMFLAG_BAN, "Get information about a banned player.");
    RegAdminCmd("sm_ban_attempt_steamid", aInfoSteamIdCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_ban_attempt_ip", aInfoIpCmd, ADMFLAG_GENERIC);
}

Action aRegAccessCmd(int iClient, int iArgs)
{
	ReplySource eRsCmd = GetCmdReplySource();
	if (iArgs == 0)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vAccessTargetMenu(iClient);
		else
		{
			CReplyToCommand(iClient, "%t %t: sm_ban <#userid|name|\"steamid\"> <minutes|0> [reason|#CODE]", "Prefix", "Use");

			if (!g_kvReasons.JumpToKey("Access", false))
				return Plugin_Handled;

			
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
					
				} while (g_kvReasons.GotoNextKey(false));
			}
			PrintToConsole(iClient, "%t", "CodeNote");
			g_kvReasons.Rewind();
		}
	
		return Plugin_Handled;
	}

	vProcessAccessReg(iClient, iArgs);
	return Plugin_Handled;
}

Action aRemoveAccessCmd(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t %t: sm_unban <\"steamid\">", "Prefix", "Use");
		return Plugin_Handled;
	}

	char szTargetAuthId[MAX_AUTHID_LENGTH];
	GetCmdArgString(szTargetAuthId, sizeof(szTargetAuthId));
	ReplySource eRsCmd = GetCmdReplySource();

	if (!bIsSteamId(szTargetAuthId))
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szTargetAuthId);
		return Plugin_Handled;
	}

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE steam_id = '%s'; ", TABLE_ACCESS, szTargetAuthId);

	LogSQL("[aRemoveAccessCmd] Query: %s", szQuery);

	int iUserId;
	if(iClient != SERVER_INDEX)
		iUserId = GetClientUserId(iClient);
	else
		iUserId = SERVER_INDEX;

	DataPack pRemoveAccess = new DataPack(); 
	pRemoveAccess.WriteCell(iUserId);
	pRemoveAccess.WriteString(szTargetAuthId);
	pRemoveAccess.WriteCell(eRsCmd);

	SQL_TQuery(g_dbDatabase, vRemoveAccessCallback, szQuery, pRemoveAccess);
	return Plugin_Handled;
}

void vRemoveAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szTargetAuthId[MAX_AUTHID_LENGTH];

	int
		iAdmin,
		iUserId;

	ReplySource eRsCmd;
	DataPack pRemoveAccess = view_as<DataPack>(pData);
	pRemoveAccess.Reset();

	iUserId = pRemoveAccess.ReadCell();
	pRemoveAccess.ReadString(szTargetAuthId, sizeof(szTargetAuthId));
	eRsCmd = pRemoveAccess.ReadCell();
	delete pRemoveAccess;

	SetCmdReplySource(eRsCmd);
	if(iUserId != SERVER_INDEX)
		iAdmin = GetClientOfUserId(iUserId);
	else
		iAdmin = SERVER_INDEX;

	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vRemoveAccessCallback");
		delete rsResult;
		return;
	}

	int iAffectedRows = SQL_GetAffectedRows(dbDataBase);
	LogSQL("[vRemoveAccessCallback] SQL_GetAffectedRows: %d", iAffectedRows);

   if (iAffectedRows == 0)
	{
        CReplyToCommand(iAdmin, "%t %t", "Prefix", "UnbanAccessNotFound", szTargetAuthId);
		delete rsResult;
		return;
	}

	CReplyToCommand(iAdmin, "%t %t", "Prefix", "UnbanAccessSuccess", szTargetAuthId);
	Call_StartForward(g_gfOnUnbanAcess);
	Call_PushCell(iAdmin);
	Call_PushString(szTargetAuthId);
	Call_Finish();

	delete rsResult;
	return;
}

Action aInfoCmd(int iClient, int iArgs)
{
    if (iArgs < 1)
    {
        CReplyToCommand(iClient, "%t %t: sm_baninfo <\"steamid\">", "Prefix", "Use");
        return Plugin_Handled;
    }

    char szAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szAuthId, sizeof(szAuthId));

    ReplaceString(szAuthId, sizeof(szAuthId), "\"", "");	

    if (!bIsSteamId(szAuthId))
    {
        CPrintToChat(iClient, "%t %t", "Prefix", "AuthIdError");
        return Plugin_Handled;
    }
 
    char szQuery[256];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `player_name`, `ip_address`, `ban_length`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`ban_reason`, `banned_by`, `date_expire`  FROM `%s` ", TABLE_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `steam_id` = '%s';", szAuthId);

#if DEBUG_SQL
	LogDebug("[aInfoCmd] szQuery: %s", szQuery);
#endif

	DataPack pInfoCallback = new DataPack();
	pInfoCallback.WriteCell(iClient);
	pInfoCallback.WriteString(szAuthId);
	pInfoCallback.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbDatabase, vInfoCallback, szQuery, pInfoCallback);
    return Plugin_Handled;
}

void vInfoCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];
	DataPack pInfoIp  = view_as<DataPack>(pData);
	pInfoIp.Reset();

	int iClient = pInfoIp.ReadCell();
	pInfoIp.ReadString(szAuthId, sizeof(szAuthId));
	ReplySource eRsCmd = view_as<ReplySource>(pInfoIp.ReadCell());
	delete pInfoIp;
	
	SetCmdReplySource(eRsCmd);
    if (rsResult == null || szError[0])
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
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
    	szBannedBy[MAX_AUTHID_LENGTH],
    	szDateExpire[64],
		szLength[128];

	int iLength;

    rsResult.FetchString(0, szPlayerName, sizeof(szPlayerName));
	rsResult.FetchString(1, szIpAddress, sizeof(szIpAddress));
    iLength = rsResult.FetchInt(2);
    rsResult.FetchString(3, szBanReason, sizeof(szBanReason));
    rsResult.FetchString(4, szBannedBy, sizeof(szBannedBy));

	if (rsResult.IsFieldNull(5))
		Format(szDateExpire, sizeof(szDateExpire), "%t", "Permanent");
	else
    	rsResult.FetchString(5, szDateExpire, sizeof(szDateExpire));

	GetTimeLength(iLength, szLength, sizeof(szLength));

	PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
    PrintToConsole(iClient, "> %t: %s", "InfoPlayerName", szPlayerName);
	PrintToConsole(iClient, "> %t: %s", "InfoIpAddress", szIpAddress);
    PrintToConsole(iClient, "> %t: %s", "InfoLength", szLength);
    PrintToConsole(iClient, "> %t: %s", "InfoReason", szBanReason);
    PrintToConsole(iClient, "> %t: %s", "InfonedBy", szBannedBy);
    PrintToConsole(iClient, "> %t: %s", "InfoTimestamp", szDateExpire);

	if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

    delete rsResult;
}

Action aInfoSteamIdCmd(int iClient, int iArgs)
{
   if (iArgs < 1)
    {
        CReplyToCommand(iClient, "%t %t: sm_ban_info_steamid <\"steamid\">", "Prefix", "Use");
        return Plugin_Handled;
    }

    char szAuthId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szAuthId, sizeof(szAuthId));

    ReplaceString(szAuthId, sizeof(szAuthId), "\"", "");

    if (!bIsSteamId(szAuthId))
    {
        CPrintToChat(iClient, "%t %t", "Prefix", "AuthIdError");
        return Plugin_Handled;
    }
 
    char szQuery[256];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT DISTINCT CONCAT(player_name, ' - ', ip_address) AS player_info ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_DATA_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `steam_id` = '%s';", szAuthId);

#if DEBUG_SQL
	LogDebug("[aInfoSteamIdCmd] szQuery: %s", szQuery);
#endif

	DataPack pInfoIp = new DataPack();
	pInfoIp.WriteCell(iClient);
	pInfoIp.WriteString(szAuthId);
	pInfoIp.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbDatabase, vInfoSteamIdCallback, szQuery, pInfoIp);
    return Plugin_Handled;
}

void vInfoSteamIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];
	DataPack pInfoIp  = view_as<DataPack>(pData);
	pInfoIp.Reset();

	int iClient = pInfoIp.ReadCell();
	pInfoIp.ReadString(szAuthId, sizeof(szAuthId));
	ReplySource eRsCmd = view_as<ReplySource>(pInfoIp.ReadCell());
	delete pInfoIp;
	
	SetCmdReplySource(eRsCmd);
    if (rsResult == null || szError[0])
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
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

	PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
    do
    {
        char szPlayerInfo[MAX_NAME_LENGTH + 32];
        rsResult.FetchString(0, szPlayerInfo, sizeof(szPlayerInfo));
        PrintToConsole(iClient, "> %s", szPlayerInfo);
    } while (rsResult.FetchRow());

	if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

	delete rsResult;
}

Action aInfoIpCmd(int iClient, int iArgs)
{
   if (iArgs < 1)
    {
        CReplyToCommand(iClient, "%t %t: sm_ban_info_ip <\"steamid\">", "Prefix", "Use");
        return Plugin_Handled;
    }

    char szIpAddress[MAX_AUTHID_LENGTH];
	GetCmdArg(1, szIpAddress, sizeof(szIpAddress));

    ReplaceString(szIpAddress, sizeof(szIpAddress), "\"", "");

    if (!bIsIpAddress(szIpAddress))
    {
        CPrintToChat(iClient, "%t %t", "Prefix", "IpAddressError", szIpAddress);
        return Plugin_Handled;
    }
 
    char szQuery[256];
	int iLen = 0;
	
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT DISTINCT CONCAT(player_name, ' - ', steam_id) AS player_info ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` ", TABLE_DATA_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE `ip_address` = '%s';", szIpAddress);

#if DEBUG_SQL
	LogDebug("[aInfoIpCmd] szQuery: %s", szQuery);
#endif

	DataPack pInfoIp = new DataPack();
	pInfoIp.WriteCell(iClient);
	pInfoIp.WriteString(szIpAddress);
	pInfoIp.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbDatabase, vInfoIpCallback, szQuery, pInfoIp);
	return Plugin_Handled;
}

void vInfoIpCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szIpAddress[MAX_AUTHID_LENGTH];
	DataPack pInfoIp  = view_as<DataPack>(pData);
	pInfoIp.Reset();

	int iClient = pInfoIp.ReadCell();
	pInfoIp.ReadString(szIpAddress, sizeof(szIpAddress));
	ReplySource eRsCmd = view_as<ReplySource>(pInfoIp.ReadCell());
	delete pInfoIp;
	
	SetCmdReplySource(eRsCmd);
	if (rsResult == null || szError[0])
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
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

	PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
    do
    {
        char szPlayerInfo[MAX_NAME_LENGTH + 32];
        rsResult.FetchString(0, szPlayerInfo, sizeof(szPlayerInfo));
        PrintToConsole(iClient, "> %s", szPlayerInfo);
    } while (rsResult.FetchRow());

	if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

	delete rsResult;
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

Action aOnClientSayCommand_Access(int iClient, const char[] szArgs)
{
	if (!g_eProcessAccess[iClient].m_bIsWaitingChatReason || IsChatTrigger())
		return Plugin_Continue;

	g_eProcessAccess[iClient].m_bIsWaitingChatReason = false;

	char szAuthId[MAX_AUTHID_LENGTH];
	GetClientAuthId(g_eProcessAccess[iClient].m_iTarget, AuthId_Steam2, szAuthId, sizeof(szAuthId));

	SetCmdReplySource(SM_REPLY_TO_CHAT);
	vRegAccess(iClient, g_eProcessAccess[iClient].m_iTarget, szAuthId, g_eProcessAccess[iClient].m_iLength, szArgs);
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

		hTargetMenu.AddItem(szInfo, szDisplay);
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
				CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
			else if (!CanUserTarget(iParam1, iTarget))
				CPrintToChat(iParam1, "%t %t", "Prefix", "Unable to target");
			else
			{
				g_eProcessAccess[iParam1].m_iTarget = iTarget;
				vAccessTimeMenu(iParam1);
			}
		}
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
	char szTitle[64];
	Format(szTitle, sizeof(szTitle), "%T\n>%N", "Ban player", iClient, g_eProcessAccess[iClient].m_iTarget);

	Menu hTimeMenu = new Menu(iAccessTimeMenuHandler);
	hTimeMenu.SetTitle(szTitle);
	hTimeMenu.ExitBackButton = true;

	char szTime[64];

	for (int i = 0; i < sizeof(g_iTimeDurations); i++)
	{
		GetTimeLength(g_iTimeDurations[i], szTime, sizeof(szTime));
		hTimeMenu.AddItem(g_sTimeDurationsChat[i], szTime);
	}

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
			g_eProcessAccess[iParam1].m_iLength = StringToInt(szInfo);
			vAccessReasonMenu(iParam1);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vAccessTargetMenu(iParam1);
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
		szTime[32],
		szCustomReason[64];
	
	GetTimeLength(g_eProcessAccess[client].m_iLength, szTime, sizeof(szTime));
	Format(szTitle, sizeof(szTitle), "%T\n>%N\n>%s", "Ban reason", client, g_eProcessAccess[client].m_iTarget, szTime);

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
        PrintToServer("Error: no se encontró la sección 'Access'.");
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
				g_eProcessAccess[iParam1].m_bIsWaitingChatReason = true;
				CPrintToChat(iParam1, "%t %t", "Prefix", "Custom ban reason explanation", "sm_abort");
				return 0;
			}

			char
				szReason[MAX_MESSAGE_LENGTH],
				szTargetAuthId[MAX_AUTHID_LENGTH];

			hMenu.GetItem(iParam2, szReason, sizeof(szReason));
			GetClientAuthId(g_eProcessAccess[iParam1].m_iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId));

			LogMenu("[iAccessReasonMenuHandler] iParam1: %N | m_iTarget: %N | szTargetAuthId: %s | m_iLength: %d | szReason: %s", iParam1, g_eProcessAccess[iParam1].m_iTarget, szTargetAuthId, g_eProcessAccess[iParam1].m_iLength, szReason);
			vRegAccess(iParam1, g_eProcessAccess[iParam1].m_iTarget, szTargetAuthId, g_eProcessAccess[iParam1].m_iLength, szReason);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vAccessTimeMenu(iParam1);
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

    if (iArgs > 1)
        iTime = GetCmdArgInt(2);

    if (iArgs > 2)
    {
        int iReasonLen = 0;
        for (int i = 3; i <= iArgs; i++)
        {
            char szArg[128];
            GetCmdArg(i, szArg, sizeof(szArg));
            if (iReasonLen > 0)
            {
                strcopy(szReason[iReasonLen], sizeof(szReason) - iReasonLen, " ");
                iReasonLen++;
            }
            strcopy(szReason[iReasonLen], sizeof(szReason) - iReasonLen, szArg);
            iReasonLen += strlen(szArg);
        }
        TrimString(szReason);
        StripQuotes(szReason);
    }

    if (bIsSteamId(szTarget))
    {
        vRegAccess(iClient, NO_INDEX, szTarget, iTime, szReason);
        return;
    }

    int iTarget = FindTarget(iClient, szTarget, true, false);
    if (iTarget == NO_INDEX)
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "NoMatchingClient", szTarget);
        return;
    }

    char szAuthId[MAX_AUTHID_LENGTH];
    if (!GetClientAuthId(iTarget, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szAuthId);
        return;
    }

    vRegAccess(iClient, iTarget, szAuthId, iTime, szReason);
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
void vRegAccess(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength = 0, const char[] szReason = "")
{
	LogDebug("[vRegister] iAdmin: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | reason: %s", iAdmin, iTarget, szTargetAuthId, iLength, szReason);

	int
		iUserIdAdmin,
		iUserIdTarget;

    char
		szTargetIp[32],
        szAdminName[MAX_NAME_LENGTH] = "Console",
        szTargetName[MAX_NAME_LENGTH];

	ReplySource eRsCmd = GetCmdReplySource();
	if(iAdmin != SERVER_INDEX)
	{
		iUserIdAdmin = GetClientUserId(iAdmin);
		GetClientAuthId(iAdmin, AuthId_Steam2, szAdminName, sizeof(szAdminName));
	}
	else
		iUserIdAdmin = SERVER_INDEX;

	if(iTarget != NO_INDEX)
	{
		iUserIdTarget = GetClientUserId(iTarget);
        GetClientName(iTarget, szTargetName, sizeof(szTargetName));
		GetClientIP(iTarget, szTargetIp, sizeof(szTargetIp));
	}
	else
	{
		iUserIdTarget = NO_INDEX;
		strcopy(szTargetName, sizeof(szTargetName), szTargetAuthId);
	}

	char szQuery[1024];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` (", TABLE_ACCESS);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id`");
	if(iTarget != NO_INDEX)
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `player_name`");
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ip_address`");
	}
	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_length`");
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_reason`");
	if(iAdmin != SERVER_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ",`banned_by`");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") VALUES (");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "'%s'", szTargetAuthId);
	if(iTarget != NO_INDEX)
	{
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szTargetName);
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szTargetIp);
	}
	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", iLength);
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szReason);

	if(iAdmin != SERVER_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szAdminName);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ")");

	LogSQL("[vRegAccess] szQuery: %s", szQuery);

	DataPack pRegAccess = new DataPack();
	pRegAccess.WriteCell(iUserIdAdmin);
	pRegAccess.WriteCell(iUserIdTarget);
	pRegAccess.WriteString(szTargetAuthId);
	pRegAccess.WriteCell(iLength);
	pRegAccess.WriteString(szReason);
	pRegAccess.WriteCell(eRsCmd);

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
		iUserIdAdmin,
		iTarget,
		iUserIdTarget,
		iLength;

	ReplySource eRsCmd;
	DataPack pRegAccess = view_as<DataPack>(pData);
	pRegAccess.Reset();

	iUserIdAdmin = pRegAccess.ReadCell();
	iUserIdTarget = pRegAccess.ReadCell();
	pRegAccess.ReadString(szTargetAuthId, sizeof(szTargetAuthId));
	iLength = pRegAccess.ReadCell();
	pRegAccess.ReadString(szReason, sizeof(szReason));
	eRsCmd = view_as<ReplySource>(pRegAccess.ReadCell());
	delete pRegAccess;

	SetCmdReplySource(eRsCmd);
	if(iUserIdAdmin != SERVER_INDEX)
	{
		iAdmin = GetClientOfUserId(iUserIdAdmin);
		GetClientAuthId(iAdmin, AuthId_Steam2, szAdminName, sizeof(szAdminName));
	}
	else
		iAdmin = SERVER_INDEX;
	
	if(iUserIdTarget != NO_INDEX)
	{
		iTarget = GetClientOfUserId(iUserIdTarget);
		GetClientName(iTarget, szTargetName, sizeof(szTargetName));
	}
	else
	{
		iTarget = NO_INDEX;
		strcopy(szTargetName, sizeof(szTargetName), szTargetAuthId);
	}

	LogDebug("[vRegAccessCallback] iUserIdAdmin: %d | iAdmin: %d | iUserIdTarget: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | szReason: %s | szTargetName: %s" , iUserIdAdmin, iAdmin, iUserIdTarget, iTarget, szTargetAuthId, iLength, szReason, szTargetName);
	
	if (rsResult == null || szError[0])
	{
		if (StrContains(szError, "Duplicate entry", false) != -1)
		{
			CReplyToCommand(iAdmin, "%t %t", "Prefix", "AlreadyAccessBanned", szTargetName);
			return;
		}
		else
			logErrorSQL(dbDataBase, szError, "vRegAccessCallback");
		delete rsResult;
		return;
	}

	bRemoveLocalCache(szTargetAuthId);
	if (iLength == 0)
		bRegisterCache(szTargetAuthId, 1);
	
	CReplyToCommand(iAdmin, "%t %t", "Prefix", "BanAccessSuccess", szTargetName);

	char szTimeLength[128];
	GetTimeLength(iLength, szTimeLength, sizeof(szTimeLength));
	
	if(iTarget != NO_INDEX)
	{
		SetGlobalTransTarget(iTarget);
		PrintToConsole(iTarget, "\n\n");
		PrintToConsole(iTarget, "// -------------------------------- \\");
		PrintToConsole(iTarget, "|");
		PrintToConsole(iTarget, "| %t", "BannedAccessConsoleTitle");
		PrintToConsole(iTarget, "| %t", "BannedConsoleEject", szAdminName);
		PrintToConsole(iTarget, "| %t", "BannedConsoleLength", szTimeLength);

		if (strlen(szReason) != 0 && szReason[0] == '#')
		{
			char szTranslation[MAX_MESSAGE_LENGTH];
			Format(szTranslation, sizeof(szTranslation), "%T", szReason, iTarget);
			PrintToConsole(iTarget, "| %t", "BannedConsoleReason", szTranslation);
		}
		else if (strlen(szReason) != 0)
		{
			PrintToConsole(iTarget, "| %t", "BannedConsoleReason", szReason);
		}

		PrintToConsole(iTarget, "|");
		PrintToConsole(iTarget, "// -------------------------------- \\");
		PrintToConsole(iTarget, "\n\n");

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
	KickClientEx(iClient, "%t", "BannedAccess");
	return Plugin_Stop;
}

/**
 * Attempts to log an access attempt by a client and notifies admins.
 *
 * @param iClient       The client index attempting access.
 * @param szAuthId      The authentication ID (e.g., SteamID) of the client.
 */
void vAttemptAccess(int iClient, const char[] szAuthId)
{
	vAttemptPrintToAdmins(iClient, szAuthId);

	if(!g_cvRegAttemptAccess)
		return;

	char
		szIpAddress[32],
		szName[64],
		szSafeName[64];

	GetClientIP(iClient, szIpAddress, sizeof(szIpAddress));
	GetClientName(iClient, szName, sizeof(szName));
	g_dbDatabase.Escape(szName, szSafeName, sizeof(szSafeName));

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "CALL AttemptAccess('%s', '%s', '%s')", szAuthId, szSafeName, szIpAddress);

#if DEBUG_SQL
	LogDebug("[vAttemptAccess] Query: %s", szQuery);
#endif

	SQL_TQuery(g_dbDatabase, vAttemptAccessCallback, szQuery, iClient);
}

void vAttemptAccessCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    if (rsResult == null || szError[0])
    {
        logErrorSQL(dbDataBase, szError, "vAttemptAccessCallback");
		delete rsResult;
        return;
    }
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
