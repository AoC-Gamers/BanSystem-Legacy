/*****************************************************************
			P A N E L S
*****************************************************************/

enum eBSAccessPanelStage
{
	kBSAccessPanelStage_None = 0,
	kBSAccessPanelStage_Reason,
	kBSAccessPanelStage_Context
}

enum struct eBSAccessPanelProcess
{
	int m_iTargetUserId;
	int m_iAccountId;
	int m_iLength;
	eBSAccessPanelStage m_eStage;
	char m_szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
}

eBSAccessPanelProcess g_eBSAccessPanelProcess[MAXPLAYERS + 1];

stock void BSAccess_OnPluginStart_Panels()
{
	RegAdminCmd("sm_bs_access_panel", Command_BSAccessPanel, ADMFLAG_ROOT, "Open the BanSystem Access panel.");
	RegAdminCmd("sm_bs_access_abort", Command_BSAccessAbort, ADMFLAG_ROOT, "Abort the current BanSystem Access panel flow.");
}

stock void BSAccess_ResetPanelState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eBSAccessPanelProcess[iClient].m_iTargetUserId = 0;
	g_eBSAccessPanelProcess[iClient].m_iAccountId = 0;
	g_eBSAccessPanelProcess[iClient].m_iLength = 0;
	g_eBSAccessPanelProcess[iClient].m_eStage = kBSAccessPanelStage_None;
	g_eBSAccessPanelProcess[iClient].m_szReason[0] = '\0';
}

stock int BSAccess_GetPanelTargetClient(int iClient)
{
	return GetClientOfUserId(g_eBSAccessPanelProcess[iClient].m_iTargetUserId);
}

stock void BSAccess_ShowTargetPanel(int iClient)
{
	Menu hMenu = new Menu(BSAccess_TargetPanelHandler);
	hMenu.SetTitle("BanSystem Access\nSelect target");
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
		CReplyToCommand(iClient, "%t", "BSAccessNoTargets");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

stock void BSAccess_ShowDurationPanel(int iClient)
{
	Menu hMenu = new Menu(BSAccess_DurationPanelHandler);
	hMenu.SetTitle("BanSystem Access\nSelect duration");
	hMenu.ExitBackButton = true;
	hMenu.AddItem("10", "10 minutes");
	hMenu.AddItem("30", "30 minutes");
	hMenu.AddItem("60", "60 minutes");
	hMenu.AddItem("1440", "1 day");
	hMenu.AddItem("0", "Permanent");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

stock Action BSAccess_HandlePanelSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if (szCommand[0] == '\0')
		return Plugin_Continue;

	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return Plugin_Continue;

	switch (g_eBSAccessPanelProcess[iClient].m_eStage)
	{
		case kBSAccessPanelStage_Reason:
		{
			char szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
			strcopy(szReason, sizeof(szReason), szArgs);
			TrimString(szReason);
			StripQuotes(szReason);

			if (szReason[0] == '\0')
			{
				CReplyToCommand(iClient, "%t", "BSAccessReasonCannotBeEmpty");
				return Plugin_Handled;
			}

			strcopy(g_eBSAccessPanelProcess[iClient].m_szReason, sizeof(g_eBSAccessPanelProcess[].m_szReason), szReason);
			g_eBSAccessPanelProcess[iClient].m_eStage = kBSAccessPanelStage_Context;
			CReplyToCommand(iClient, "%t", "BSAccessContextPrompt");
			return Plugin_Handled;
		}

		case kBSAccessPanelStage_Context:
		{
			char szContext[512];
			strcopy(szContext, sizeof(szContext), szArgs);
			TrimString(szContext);
			StripQuotes(szContext);

			if (StrEqual(szContext, "-", false))
				szContext[0] = '\0';

			int iAccountId = g_eBSAccessPanelProcess[iClient].m_iAccountId;
			int iLength = g_eBSAccessPanelProcess[iClient].m_iLength;
			int iTargetClient = BSAccess_GetPanelTargetClient(iClient);
			char szReason[BANSYSTEM_ACCESS_MAX_REASON_LENGTH];
			strcopy(szReason, sizeof(szReason), g_eBSAccessPanelProcess[iClient].m_szReason);
			BSAccess_ResetPanelState(iClient);
			BSAccess_QueueAddBan(iClient, iAccountId, iTargetClient, iLength, szReason, szContext);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

Action Command_BSAccessPanel(int iClient, int iArgs)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
		return Plugin_Handled;

	BSAccess_ResetPanelState(iClient);
	BSAccess_ShowTargetPanel(iClient);
	return Plugin_Handled;
}

Action Command_BSAccessAbort(int iClient, int iArgs)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
		return Plugin_Handled;

	if (g_eBSAccessPanelProcess[iClient].m_eStage == kBSAccessPanelStage_None)
	{
		CReplyToCommand(iClient, "%t", "BSAccessNoPanelFlow");
		return Plugin_Handled;
	}

	BSAccess_ResetPanelState(iClient);
	CReplyToCommand(iClient, "%t", "BSAccessPanelAborted");
	return Plugin_Handled;
}

public int BSAccess_TargetPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
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
				CReplyToCommand(iParam1, "%t", "BSAccessTargetUnavailable");
				BSAccess_ShowTargetPanel(iParam1);
				return 0;
			}

			g_eBSAccessPanelProcess[iParam1].m_iTargetUserId = GetClientUserId(iTarget);
			g_eBSAccessPanelProcess[iParam1].m_iAccountId = GetClientAccountID(iTarget);
			BSAccess_ShowDurationPanel(iParam1);
		}
	}

	return 0;
}

public int BSAccess_DurationPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				BSAccess_ShowTargetPanel(iParam1);
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			g_eBSAccessPanelProcess[iParam1].m_iLength = StringToInt(szInfo);
			g_eBSAccessPanelProcess[iParam1].m_eStage = kBSAccessPanelStage_Reason;
			CReplyToCommand(iParam1, "%t", "BSAccessReasonPrompt");
		}
	}

	return 0;
}
