/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/


ConVar
	g_cvsv_alltalk;

enum struct eProcessComm {
	int m_iTarget;
	int m_iLength;
	bool m_bIsWaitingChatReason;
	eTypeComms m_eComms;
}

eProcessComm g_eProcessComm[MAXPLAYERS+1];

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

void vOnPluginStart_Communication()
{
    RegAdminCmd("sm_comm", aRegCommCmd, ADMFLAG_CHAT, "Ban a player from using the microphone and chat.");
    RegAdminCmd("sm_uncomm", aRemoveCommCmd, ADMFLAG_CHAT, "Unban a player from using the microphone and chat.");
	RegAdminCmd("sm_comm_clear", aClearCommCmd, ADMFLAG_ROOT, "Clear all communication bans.");
	RegAdminCmd("sm_comm_ls", aListCommCmd, ADMFLAG_CHAT, "Clear all communication bans.");

	g_cvsv_alltalk = FindConVar("sv_alltalk");
	if (g_cvsv_alltalk) {
		g_cvsv_alltalk.AddChangeHook(vAlltalkConVarChange);
	}
}

Action aRegCommCmd(int iClient, int iArgs)
{
	ReplySource eRsCmd = GetCmdReplySource();

	if (iArgs < 2)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vRegCommMenu(iClient);
		else
		{
			CReplyToCommand(iClient, "%t %t: sm_comm <mic|chat|all> <#userid|name|\"steamid\"> <minutes|0> [reason|#CODE]", "Prefix", "Use");
			
			if (!g_kvReasons.JumpToKey("Communication", false))
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
	
	vProcessCommReg(iClient, iArgs);
	return Plugin_Handled;
}

Action aRemoveCommCmd(int iClient, int iArgs)
{
	ReplySource eRsCmd = GetCmdReplySource();
	if (iArgs == 0)
	{
		if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
			vRemoveCommMenu(iClient);
		else
			CReplyToCommand(iClient, "%t %t: sm_uncomm <#userid|name|\"steamid\">", "Prefix", "Use");

	
		return Plugin_Handled;
	}

	vProcessCommRemove(iClient);
	return Plugin_Handled;
}

Action aClearCommCmd(int iClient, int iArgs)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (g_ePunished[i].m_eComms == kMic)
		{
			SetClientListeningFlags(i, VOICE_NORMAL);
			g_ePunished[i].m_eComms = kNone;
			CReplyToCommand(iClient, "%t %t", "Prefix", "localUnbanComm", "TypeCommMic", i);
		}

		if (g_ePunished[i].m_eComms == kChat)
		{
			g_ePunished[i].m_eComms = kNone;
			CReplyToCommand(iClient, "%t %t", "Prefix", "localUnbanComm", "TypeCommChat", i);
		}

		if (g_ePunished[i].m_eComms == kAll)
		{
			SetClientListeningFlags(i, VOICE_NORMAL);
			g_ePunished[i].m_eComms = kNone;
			CReplyToCommand(iClient, "%t %t", "Prefix", "localUnbanComm", "TypeCommAll", i);
		}

	}

	return Plugin_Handled;
}

Action aListCommCmd(int iClient, int iArgs)
{
	int iFound = 0;
	PrintToConsole(iClient, "/***********[Comm List]***********\\");
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		switch (g_ePunished[i].m_eComms)
		{
			case kMic:
			{
				PrintToConsole(iClient, "> %N | %t", i, "TypeCommMic");
				iFound++;
			}

			case kChat:
			{
				PrintToConsole(iClient, "> %N | %t", i, "TypeCommChat");
				iFound++;
			}

			case kAll:
			{
				PrintToConsole(iClient, "> %N | %t", i, "TypeCommAll");
				iFound++;
			}

			default:
				continue;
		}
	}

	if(iFound == 0)
		PrintToConsole(iClient, "%t", "NoCommBans");

	if (SM_REPLY_TO_CHAT == GetCmdReplySource() && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "ListBanComm", iClient);
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
		
		if (g_ePunished[i].m_eComms == kMic)
			SetClientListeningFlags(i, VOICE_MUTED);
	}
}

Action aOnClientSayCommand_Communication(int iClient, const char[] szArgs)
{
	if (g_ePunished[iClient].m_eComms == kChat || g_ePunished[iClient].m_eComms == kAll)
	{
		if (GetUserAdmin(iClient) == INVALID_ADMIN_ID || !IsChatTrigger())
		{
			CPrintToChat(iClient, "%t %t", "Prefix", "BannedCommChat");
			return Plugin_Stop;
		}
	}

	if (!g_eProcessComm[iClient].m_bIsWaitingChatReason || IsChatTrigger())
		return Plugin_Continue;

	g_eProcessComm[iClient].m_bIsWaitingChatReason = false;

	char szAuthId[MAX_AUTHID_LENGTH];
	GetClientAuthId(g_eProcessComm[iClient].m_iTarget, AuthId_Steam2, szAuthId, sizeof(szAuthId));

	SetCmdReplySource(SM_REPLY_TO_CHAT);
	vRegComm(iClient, g_eProcessComm[iClient].m_iTarget, szAuthId, g_eProcessComm[iClient].m_iLength, szArgs, g_eProcessComm[iClient].m_eComms);
	return Plugin_Stop;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void vProcessCommRemove(int iClient)
{
    char szTarget[65];

    GetCmdArg(1, szTarget, sizeof(szTarget));

    if (bIsSteamId(szTarget))
    {
        vRemoveComm(iClient, NO_INDEX, szTarget);
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

    vRemoveComm(iClient, iTarget, szAuthId);
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
	int
		iUserIdAdmin,
		iUserIdTarget;

	if(iAdmin != SERVER_INDEX)
		iUserIdAdmin = GetClientUserId(iAdmin);
	else
		iUserIdAdmin = SERVER_INDEX;

	if(iTarget != NO_INDEX)
		iUserIdTarget = GetClientUserId(iTarget);
	else
		iUserIdTarget = NO_INDEX;

	ReplySource eRsCmd = GetCmdReplySource();

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE steam_id = '%s'; ", g_szTableComm, szTargetAuthId);

	LogSQL("[vRemoveComm] szQuery: %s", szQuery);

	DataPack pRemoveComm = new DataPack();
	pRemoveComm.WriteCell(iUserIdAdmin);
	pRemoveComm.WriteCell(iUserIdTarget);
	pRemoveComm.WriteString(szTargetAuthId);
	pRemoveComm.WriteCell(eRsCmd);

	SQL_TQuery(g_dbDatabase, vRemoveCommCallback, szQuery, pRemoveComm);
}

void vRemoveCommCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int
		iUserIdAdmin,
		iUserIdTarget,
		iAdmin,
		iTarget;

	char
		szTargetAuthId[MAX_AUTHID_LENGTH],
		szTargetName[MAX_NAME_LENGTH],
		szAdminName[MAX_NAME_LENGTH] = "Console";

	ReplySource eRsCmd;
	DataPack pRemoveComm = view_as<DataPack>(pData);
	pRemoveComm.Reset();

	iUserIdAdmin = pRemoveComm.ReadCell();
	iUserIdTarget = pRemoveComm.ReadCell();
	pRemoveComm.ReadString(szTargetAuthId, sizeof(szTargetAuthId));
	eRsCmd = view_as<ReplySource>(pRemoveComm.ReadCell());
	delete pRemoveComm;

	LogDebug("[vRemoveCommCallback] iUserIdAdmin: %d | iUserIdTarget: %d | szTargetAuthId: %s", iUserIdAdmin, iUserIdTarget, szTargetAuthId);
	if(iUserIdTarget != SERVER_INDEX)
		LogDebug("[vRemoveCommCallback] iTarget: %N", GetClientOfUserId(iUserIdTarget));

	SetCmdReplySource(eRsCmd);
	if(iUserIdAdmin != SERVER_INDEX)
	{
		iAdmin = GetClientOfUserId(iUserIdAdmin);
		GetClientAuthId(iAdmin, AuthId_Steam2, szAdminName, sizeof(szAdminName));
	}
	else
		iAdmin = SERVER_INDEX;

	if(iUserIdTarget != SERVER_INDEX)
	{
		iTarget = GetClientOfUserId(iUserIdTarget);
		GetClientName(iTarget, szTargetName, sizeof(szTargetName));
	}
	else
	{
		iTarget = SERVER_INDEX;
		strcopy(szTargetName, sizeof(szTargetName), szTargetAuthId);
	}

	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vRemoveCommCallback");
		return;
	}

	int iAffectedRows = SQL_GetAffectedRows(dbDataBase);
	LogSQL("[vRemoveCommCallback] SQL_GetAffectedRows: %d", iAffectedRows);

    if (iAffectedRows == 0)
	{
        CReplyToCommand(iAdmin, "%t %t", "Prefix", "UnbanCommNotFound", szTargetAuthId);
		delete rsResult;
		return;
	}

	CReplyToCommand(iAdmin, "%t %t", "Prefix", "UnbanCommSuccess", szTargetName);

	if(iTarget == SERVER_INDEX)
		return;

	CReplyToCommand(iTarget, "%t %t", "Prefix", "YouUnbanCommSuccess");
	if (g_eProcessComm[iTarget].m_eComms == kChat || g_eProcessComm[iTarget].m_eComms == kAll)
	{
		Call_StartForward(g_gfOnUnBanChat);
		Call_PushCell(iAdmin);
		Call_PushString(szTargetAuthId);
		Call_Finish();
	}

	if (g_eProcessComm[iTarget].m_eComms == kMic || g_eProcessComm[iTarget].m_eComms == kAll)
	{
		SetClientListeningFlags(iTarget, VOICE_NORMAL);

		Call_StartForward(g_gfOnUnBanMic);
		Call_PushCell(iAdmin);
		Call_PushString(szTargetAuthId);
		Call_Finish();
	}
	
	LogDebug("[vRemoveCommCallback] iTarget: %N | g_eProcessComm[iTarget].m_eComms: %d", iTarget, g_eProcessComm[iTarget].m_eComms);
	g_ePunished[iTarget].m_eComms = kNone;
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
		hMenu.AddItem(szInfo, szDisplay);
		iTargetFound++;
	}
	
	if (iTargetFound == 0)
	{
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
			else
			{
				char szAuthId[MAX_AUTHID_LENGTH];
				GetClientAuthId(iTarget, AuthId_Steam2, szAuthId, sizeof(szAuthId));
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
					vCommTargetMenu(iParam1);
				}
				default:
				{
					vRegCommMenu(iParam1);
				}
			}
		}
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
	
	switch (g_eProcessComm[iClient].m_eComms)
	{
		case kAll:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommAll", iClient);
		case kMic:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommMic", iClient);
		case kChat:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommChat", iClient);
	}

	Format(szTitle, sizeof(szTitle), "%T\n>%s", "Ban player", iClient, szTypeComm);

	Menu hTargetMenu = new Menu(iCommTargetsMenuHandler);
	hTargetMenu.SetTitle(szTitle);
	hTargetMenu.ExitBackButton = true;

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

		eTypeComms ePunishedComms = g_ePunished[i].m_eComms;

		if (ePunishedComms == kAll || ePunishedComms == kMic || ePunishedComms == kChat)
			hTargetMenu.AddItem(szInfo, szDisplay, ITEMDRAW_DISABLED);
		else
			hTargetMenu.AddItem(szInfo, szDisplay);
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
				CPrintToChat(iParam1, "%t %t", "Prefix", "Player no longer available");
			else if (!CanUserTarget(iParam1, iTarget))
				CPrintToChat(iParam1, "%t %t", "Prefix", "Unable to target");
			else
			{
				g_eProcessComm[iParam1].m_iTarget = iTarget;
				vCommTimeMenu(iParam1);
			}
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vRegCommMenu(iParam1);
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
		szTypeComm[32];
	
	switch (g_eProcessComm[iClient].m_eComms)
	{
		case kAll:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommAll", iClient);
		case kMic:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommMic", iClient);
		case kChat:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommChat", iClient);
	}

	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%N", "Ban Time", iClient, szTypeComm, g_eProcessComm[iClient].m_iTarget);
	
	Menu hTimeMenu = new Menu(iCommTimeMenuHandler);
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
			g_eProcessComm[iParam1].m_iLength = StringToInt(szInfo);
			vCommReasonMenu(iParam1);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vCommTargetMenu(iParam1);
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
		szTypeComm[32],
		szTime[32],
		szCustomReason[64];

	switch (g_eProcessComm[iClient].m_eComms)
	{
		case kAll:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommAll", iClient);
		case kMic:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommMic", iClient);
		case kChat:
			Format(szTypeComm, sizeof(szTypeComm), "%T", "TypeCommChat", iClient);
	}

	GetTimeLength(g_eProcessComm[iClient].m_iLength, szTime, sizeof(szTime));
	Format(szTitle, sizeof(szTitle), "%T\n>%s\n>%N\n>%s", "Ban reason", iClient, szTypeComm, g_eProcessComm[iClient].m_iTarget, szTime);

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
        PrintToServer("Error: no se encontró la sección 'Access'.");
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
				g_eProcessComm[iParam1].m_bIsWaitingChatReason = true;
				return 0;
			}

			char
				szReason[MAX_MESSAGE_LENGTH],
				szTargetAuthId[MAX_AUTHID_LENGTH];

			hMenu.GetItem(iParam2, szReason, sizeof(szReason));
			GetClientAuthId(g_eProcessComm[iParam1].m_iTarget, AuthId_Steam2, szTargetAuthId , sizeof(szTargetAuthId ));

			LogMenu("[iCommReasonMenuHandler] iParam1: %N | m_iTarget: %N | szTargetAuthId: %s | m_iLength: %d | szReason: %s | m_eComms %d", iParam1, g_eProcessComm[iParam1].m_iTarget, szTargetAuthId, g_eProcessComm[iParam1].m_iLength, szReason, g_eProcessComm[iParam1].m_eComms);
			vRegComm(iParam1, g_eProcessComm[iParam1].m_iTarget, szTargetAuthId, g_eProcessComm[iParam1].m_iLength, szReason, g_eProcessComm[iParam1].m_eComms);
		}

		case MenuAction_Cancel:
		{
			if(iParam2 == MenuCancel_ExitBack)
				vCommTimeMenu(iParam1);
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
    char szTime[12] = "0";
    char szReason[MAX_MESSAGE_LENGTH] = "";

    GetCmdArg(1, szCommType, sizeof(szCommType));
    GetCmdArg(2, szTarget, sizeof(szTarget));

    if (iArgs > 2)
        GetCmdArg(3, szTime, sizeof(szTime));

    if (iArgs > 3)
    {
        int iReasonLen = 0;
        for (int i = 4; i <= iArgs; i++)
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
    }

    int iTime = StringToInt(szTime);
    eTypeComms eCommType;

    if (StrEqual(szCommType, "mic", false))
        eCommType = kMic;
    else if (StrEqual(szCommType, "chat", false))
        eCommType = kChat;
    else if (StrEqual(szCommType, "all", false))
        eCommType = kAll;
	else
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "InvalidCommType");
		return;
	}

    if (bIsSteamId(szTarget))
    {
        vRegComm(iClient, NO_INDEX, szTarget, iTime, szReason, eCommType);
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

    vRegComm(iClient, iTarget, szAuthId, iTime, szReason, eCommType);
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
void vRegComm(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason, eTypeComms eComms)
{
#if DEBUG
	LogMessage("[vRegComm] iAdmin: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | reason: %s | eComms: %d", iAdmin, iTarget, szTargetAuthId, iLength, szReason, eComms);
#endif

	int
		iUserIdAdmin,
		iUserIdTarget;

	char
		szTargetIp[32],
		szBannedBy[128],
		szTargetName[MAX_NAME_LENGTH];

	ReplySource eRsCmd = GetCmdReplySource();
	if(iAdmin != SERVER_INDEX)
	{
		iUserIdAdmin = GetClientUserId(iAdmin);
		GetClientAuthId(iAdmin, AuthId_Steam2, szBannedBy, sizeof(szBannedBy));
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

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` (", g_szTableComm);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`steam_id`");

	if(iTarget != NO_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `player_name`");

	if(eComms != kAll)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_type`");

	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_length`");
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", `ban_reason`");
	if(iAdmin != SERVER_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ",`banned_by`");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ") VALUES (");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "'%s'", szTargetAuthId);

	if(iTarget != NO_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szTargetName);

	if(eComms != kAll)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", eComms);

	if (iLength != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%d'", iLength);
	if (strlen(szReason) != 0)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szReason);

	if(iAdmin != SERVER_INDEX)
		iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ", '%s'", szBannedBy);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, ")");

	LogSQL("[vRegComm] szQuery: %s", szQuery);

	DataPack pRegComm = new DataPack();
	pRegComm.WriteCell(iUserIdAdmin);
	pRegComm.WriteCell(iUserIdTarget);
	pRegComm.WriteString(szTargetAuthId);
	pRegComm.WriteCell(iLength);
	pRegComm.WriteString(szReason);
	pRegComm.WriteCell(eComms);
	pRegComm.WriteCell(eRsCmd);

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
		iUserIdAdmin,
		iTarget,
		iUserIdTarget,
		iLength;

	eTypeComms eComms;
	ReplySource eRsCmd;

	DataPack pRegComm = view_as<DataPack>(pData);
	pRegComm.Reset();

	iUserIdAdmin = pRegComm.ReadCell();
	iUserIdTarget = pRegComm.ReadCell();
	pRegComm.ReadString(szTargetAuthId, sizeof(szTargetAuthId));
	iLength = pRegComm.ReadCell();
	pRegComm.ReadString(szReason, sizeof(szReason));
	eComms = view_as<eTypeComms>(pRegComm.ReadCell());
	eRsCmd = view_as<ReplySource>(pRegComm.ReadCell());
	delete pRegComm;

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

	LogDebug("[vRegCommCallback] iUserIdAdmin: %d | iAdmin: %d | iUserIdTarget: %d | iTarget: %d | szTargetAuthId: %s | iLength: %d | szReason: %s | szTargetName: %s | eComms: %d" , iUserIdAdmin, iAdmin, iUserIdTarget, iTarget, szTargetAuthId, iLength, szReason, szTargetName, eComms);
		
	if (rsResult == null || szError[0])
	{
		if (StrContains(szError, "Duplicate entry", false) != -1)
			CReplyToCommand(iAdmin, "%t %t", "Prefix", "AlreadyCommBanned", szTargetName);
		else
			logErrorSQL(dbDataBase, szError, "vRegCommCallback");
		delete rsResult;
		return;
	}

	bRemoveLocalCache(szTargetAuthId);
	if (iLength == 0)
		bRegisterCache(szTargetAuthId, (view_as<int>(eComms) + 1));
	
	char sComms[64];
	switch (eComms)
	{
		case kAll:
		{
			Format(sComms, sizeof(sComms), "mic, chat");
			CReplyToCommand(iAdmin, "%t %t", "Prefix", "BanCommSuccess", szTargetName);
		}
		case kMic:
		{
			Format(sComms, sizeof(sComms), "mic");
			CReplyToCommand(iAdmin, "%t %t", "Prefix", "BanMicSuccess", szTargetName);
		}
		case kChat:
		{
			Format(sComms, sizeof(sComms), "chat");
			CReplyToCommand(iAdmin, "%t %t", "Prefix", "BanChatSuccess", szTargetName);
		}
	}

	char szTimeLength[128];
	GetTimeLength(iLength, szTimeLength, sizeof(szTimeLength));
	if(iTarget != NO_INDEX)
	{
		LogDebug("[vRegCommCallback] pre g_ePunished[iTarget].m_eComms: %d", g_ePunished[iTarget].m_eComms);
		g_ePunished[iTarget].m_eComms = eComms;
		LogDebug("[vRegCommCallback] pre g_ePunished[iTarget].m_eComms: %d", g_ePunished[iTarget].m_eComms);
		SetGlobalTransTarget(iTarget);

		PrintToConsole(iTarget, "\n\n");
		PrintToConsole(iTarget, "// -------------------------------- \\");
		PrintToConsole(iTarget, "|");
		PrintToConsole(iTarget, "| %t", "BannedCommConsoleTitle");
		PrintToConsole(iTarget, "| %t", "BannedConsoleEject", szAdminName);
		PrintToConsole(iTarget, "| %t", "BannedConsoleLength", szTimeLength);
		PrintToConsole(iTarget, "| %t", "BannedConsoleTypecomm", sComms);

		if (strlen(szReason) != 0 && szReason[0] == '#')
		{
			char szTranslation[MAX_MESSAGE_LENGTH];
			Format(szTranslation, sizeof(szTranslation), "%T", szReason, iTarget);
			PrintToConsole(iTarget, "| %t", "BannedConsoleReason", szTranslation);
		}

		PrintToConsole(iTarget, "|");
		PrintToConsole(iTarget, "// -------------------------------- \\");
		PrintToConsole(iTarget, "\n\n");

		CPrintToChat(iTarget, "%t %t", "Prefix", "BannedComm", sComms);
	}

	if (eComms == kChat || eComms == kAll)
	{
		Call_StartForward(g_gfOnBanMic);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_PushCell(iLength);
		Call_PushString(szReason);
		Call_Finish();
	}
	if (eComms == kMic || eComms == kAll)
	{
		Call_StartForward(g_gfOnBanChat);
		Call_PushCell(iAdmin);
		Call_PushCell(iTarget);
		Call_PushString(szTargetAuthId);
		Call_PushCell(iLength);
		Call_PushString(szReason);
		Call_Finish();
	}
}