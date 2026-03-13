/*****************************************************************
			P A N E L S
*****************************************************************/

stock void BSComm_OnPluginStart_Panels()
{
	RegAdminCmd("sm_bs_comm_panel", Command_BSCommPanel, ADMFLAG_ROOT, "Open the BanSystem Comm panel.");
	RegAdminCmd("sm_bs_comm_abort", Command_BSCommAbort, ADMFLAG_ROOT, "Abort the current BanSystem Comm panel flow.");
}

enum eBSCommPanelStage
{
	kBSCommPanelStage_None = 0,
	kBSCommPanelStage_Reason,
	kBSCommPanelStage_Context
}

enum struct eBSCommPanelProcess
{
	int m_iTargetUserId;
	int m_iAccountId;
	int m_iLength;
	int m_iCommType;
	eBSCommPanelStage m_eStage;
	char m_szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
}

eBSCommPanelProcess g_eBSCommPanelProcess[MAXPLAYERS + 1];

stock void BSComm_ResetPanelState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eBSCommPanelProcess[iClient].m_iTargetUserId = 0;
	g_eBSCommPanelProcess[iClient].m_iAccountId = 0;
	g_eBSCommPanelProcess[iClient].m_iLength = 0;
	g_eBSCommPanelProcess[iClient].m_iCommType = view_as<int>(kBSCommType_None);
	g_eBSCommPanelProcess[iClient].m_eStage = kBSCommPanelStage_None;
	g_eBSCommPanelProcess[iClient].m_szReason[0] = '\0';
}

stock int BSComm_GetPanelTargetClient(int iClient)
{
	return GetClientOfUserId(g_eBSCommPanelProcess[iClient].m_iTargetUserId);
}

stock void BSComm_ShowTargetPanel(int iClient)
{
	Menu hMenu = new Menu(BSComm_TargetPanelHandler);
	hMenu.SetTitle("BanSystem Comm\nSelect target");
	hMenu.ExitBackButton = false;

	int iCount = 0;
	char szInfo[16];
	char szName[MAX_NAME_LENGTH];
	for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
	{
		if (!IsClientInGame(iTarget) || IsFakeClient(iTarget))
			continue;

		if (!CanUserTarget(iClient, iTarget))
			continue;

		IntToString(GetClientUserId(iTarget), szInfo, sizeof(szInfo));
		GetClientName(iTarget, szName, sizeof(szName));
		hMenu.AddItem(szInfo, szName);
		iCount++;
	}

	if (iCount == 0)
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSCommNoTargets");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

stock void BSComm_ShowTypePanel(int iClient)
{
	Menu hMenu = new Menu(BSComm_TypePanelHandler);
	hMenu.SetTitle("BanSystem Comm\nSelect type");
	hMenu.ExitBackButton = true;
	hMenu.AddItem("mic", "Mic");
	hMenu.AddItem("chat", "Chat");
	hMenu.AddItem("all", "All");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

stock void BSComm_ShowDurationPanel(int iClient)
{
	Menu hMenu = new Menu(BSComm_DurationPanelHandler);
	hMenu.SetTitle("BanSystem Comm\nSelect duration");
	hMenu.ExitBackButton = true;
	hMenu.AddItem("10", "10 minutes");
	hMenu.AddItem("30", "30 minutes");
	hMenu.AddItem("60", "60 minutes");
	hMenu.AddItem("1440", "1 day");
	hMenu.AddItem("0", "Permanent");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

stock Action BSComm_HandlePanelSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if (szCommand[0] == '\0')
		return Plugin_Continue;

	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return Plugin_Continue;

	switch (g_eBSCommPanelProcess[iClient].m_eStage)
	{
		case kBSCommPanelStage_Reason:
		{
			char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
			strcopy(szReason, sizeof(szReason), szArgs);
			TrimString(szReason);
			StripQuotes(szReason);

			if (szReason[0] == '\0')
			{
				CReplyToCommand(iClient, "%t", "BSCommReasonCannotBeEmpty");
				return Plugin_Handled;
			}

			strcopy(g_eBSCommPanelProcess[iClient].m_szReason, sizeof(g_eBSCommPanelProcess[].m_szReason), szReason);
			g_eBSCommPanelProcess[iClient].m_eStage = kBSCommPanelStage_Context;
			CReplyToCommand(iClient, "%t", "BSCommContextPrompt");
			return Plugin_Handled;
		}

		case kBSCommPanelStage_Context:
		{
			char szContext[sizeof(g_eBSCommResolvedDetail[].m_szContext)];
			strcopy(szContext, sizeof(szContext), szArgs);
			TrimString(szContext);
			StripQuotes(szContext);

			if (StrEqual(szContext, "-", false))
				szContext[0] = '\0';

			int iAccountId = g_eBSCommPanelProcess[iClient].m_iAccountId;
			int iLength = g_eBSCommPanelProcess[iClient].m_iLength;
			eBSCommType eCommType = view_as<eBSCommType>(g_eBSCommPanelProcess[iClient].m_iCommType);
			int iTargetClient = BSComm_GetPanelTargetClient(iClient);
			char szReason[BANSYSTEM_COMM_MAX_REASON_LENGTH];
			strcopy(szReason, sizeof(szReason), g_eBSCommPanelProcess[iClient].m_szReason);
			BSComm_ResetPanelState(iClient);
			BSComm_QueueAddBan(iClient, iAccountId, iTargetClient, eCommType, iLength, szReason, szContext);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

Action Command_BSCommPanel(int iClient, int iArgs)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
		return Plugin_Handled;

	BSComm_ResetPanelState(iClient);
	BSComm_ShowTargetPanel(iClient);
	return Plugin_Handled;
}

Action Command_BSCommAbort(int iClient, int iArgs)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
		return Plugin_Handled;

	if (g_eBSCommPanelProcess[iClient].m_eStage == kBSCommPanelStage_None)
	{
		CReplyToCommand(iClient, "%t", "BSCommNoPanelFlow");
		return Plugin_Handled;
	}

	BSComm_ResetPanelState(iClient);
	CReplyToCommand(iClient, "%t", "BSCommPanelAborted");
	return Plugin_Handled;
}

public int BSComm_TargetPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

			int iTarget = GetClientOfUserId(StringToInt(szInfo));
			if (iTarget <= 0 || !IsClientInGame(iTarget))
			{
				CReplyToCommand(iParam1, "%t", "BSCommTargetUnavailable");
				BSComm_ShowTargetPanel(iParam1);
				return 0;
			}

			g_eBSCommPanelProcess[iParam1].m_iTargetUserId = GetClientUserId(iTarget);
			g_eBSCommPanelProcess[iParam1].m_iAccountId = GetClientAccountID(iTarget);
			BSComm_ShowTypePanel(iParam1);
		}
	}

	return 0;
}

public int BSComm_TypePanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				BSComm_ShowTargetPanel(iParam1);
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

			eBSCommType eCommType;
			if (!BSComm_ParseCommTypeString(szInfo, eCommType))
			{
				CReplyToCommand(iParam1, "%t", "BSCommInvalidTypeShort");
				BSComm_ShowTypePanel(iParam1);
				return 0;
			}

			g_eBSCommPanelProcess[iParam1].m_iCommType = view_as<int>(eCommType);
			BSComm_ShowDurationPanel(iParam1);
		}
	}

	return 0;
}

public int BSComm_DurationPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				BSComm_ShowTypePanel(iParam1);
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			g_eBSCommPanelProcess[iParam1].m_iLength = StringToInt(szInfo);
			g_eBSCommPanelProcess[iParam1].m_eStage = kBSCommPanelStage_Reason;
			CReplyToCommand(iParam1, "%t", "BSCommReasonPrompt");
		}
	}

	return 0;
}
