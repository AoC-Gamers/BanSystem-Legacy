void vOnPluginStart_Panels()
{
	RegAdminCmd("sm_bs_admin_panel", Command_AdminPanel, ADMFLAG_ROOT, "Open the BanSystem Admin Sync admin panel.");
	RegAdminCmd("sm_bs_group_panel", Command_GroupPanel, ADMFLAG_ROOT, "Open the BanSystem Admin Sync group panel.");
	RegAdminCmd("sm_bs_adminsync_abort", Command_AdminSyncAbort, ADMFLAG_ROOT, "Abort the current adminsync text prompt.");

	AddCommandListener(CommandListener_AdminSyncSay, "say");
	AddCommandListener(CommandListener_AdminSyncSay, "say_team");
}

public Action Command_AdminPanel(int iClient, int iArgs)
{
	if (!bIsClientUsable(iClient))
		return Plugin_Handled;

	vShowAdminMainMenu(iClient);
	return Plugin_Handled;
}

public Action Command_GroupPanel(int iClient, int iArgs)
{
	if (!bIsClientUsable(iClient))
		return Plugin_Handled;

	vShowGroupMainMenu(iClient);
	return Plugin_Handled;
}

public Action Command_AdminSyncAbort(int iClient, int iArgs)
{
	if (g_ePromptState[iClient] == Prompt_None)
	{
		ReplyToCommand(iClient, "[BS AdminSync] No prompt is active.");
		return Plugin_Handled;
	}

	vResetPromptState(iClient);
	ReplyToCommand(iClient, "[BS AdminSync] Prompt aborted.");
	return Plugin_Handled;
}

public Action CommandListener_AdminSyncSay(int iClient, const char[] szCommand, int iArgs)
{
	if (!bIsClientUsable(iClient) || g_ePromptState[iClient] == Prompt_None)
		return Plugin_Continue;

	char szText[256];
	GetCmdArgString(szText, sizeof(szText));
	StripQuotes(szText);
	TrimString(szText);

	if (szText[0] == '\0')
	{
		ReplyToCommand(iClient, "[BS AdminSync] Empty input. Use sm_bs_adminsync_abort to cancel.");
		return Plugin_Handled;
	}

	switch (g_ePromptState[iClient])
	{
		case Prompt_AdminAddFlags:
		{
			strcopy(g_szPromptFlags[iClient], sizeof(g_szPromptFlags[]), szText);
			g_ePromptState[iClient] = Prompt_AdminAddImmunity;
			ReplyToCommand(iClient, "[BS AdminSync] Enter admin immunity as integer.");
		}
		case Prompt_AdminAddImmunity:
		{
			g_iPromptImmunity[iClient] = StringToInt(szText);
			vStartAdminMutationAdd(iClient, g_iPromptAccountId[iClient], g_szPromptName[iClient], g_szPromptSteamId64[iClient], g_szPromptFlags[iClient], g_iPromptImmunity[iClient]);
			vResetPromptState(iClient);
		}
		case Prompt_AdminEditFlags:
		{
			vStartAdminMutationSetFlags(iClient, g_iPromptAccountId[iClient], szText);
			vResetPromptState(iClient);
		}
		case Prompt_AdminEditImmunity:
		{
			vStartAdminMutationSetImmunity(iClient, g_iPromptAccountId[iClient], StringToInt(szText));
			vResetPromptState(iClient);
		}
		case Prompt_GroupAddName:
		{
			strcopy(g_szPromptGroupName[iClient], sizeof(g_szPromptGroupName[]), szText);
			g_ePromptState[iClient] = Prompt_GroupAddFlags;
			ReplyToCommand(iClient, "[BS AdminSync] Enter group flags.");
		}
		case Prompt_GroupAddFlags:
		{
			strcopy(g_szPromptFlags[iClient], sizeof(g_szPromptFlags[]), szText);
			g_ePromptState[iClient] = Prompt_GroupAddImmunity;
			ReplyToCommand(iClient, "[BS AdminSync] Enter group immunity as integer.");
		}
		case Prompt_GroupAddImmunity:
		{
			vStartGroupMutationAdd(iClient, g_szPromptGroupName[iClient], g_szPromptFlags[iClient], StringToInt(szText));
			vResetPromptState(iClient);
		}
		case Prompt_GroupEditFlags:
		{
			vStartGroupMutationSetFlags(iClient, g_szPromptGroupName[iClient], szText);
			vResetPromptState(iClient);
		}
		case Prompt_GroupEditImmunity:
		{
			vStartGroupMutationSetImmunity(iClient, g_szPromptGroupName[iClient], StringToInt(szText));
			vResetPromptState(iClient);
		}
	}

	return Plugin_Handled;
}

void vShowAdminMainMenu(int iClient)
{
	Menu menu = new Menu(MenuHandler_AdminMain);
	menu.SetTitle("Admin Sync: Admins");
	menu.AddItem("add", "Add connected admin");
	menu.AddItem("edit_flags", "Edit admin flags");
	menu.AddItem("edit_immunity", "Edit admin immunity");
	menu.AddItem("add_group", "Assign group");
	menu.AddItem("remove_group", "Remove group");
	menu.AddItem("delete", "Delete admin");
	menu.ExitBackButton = false;
	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminMain(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[32];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	vAdminSyncMenu("Admin main menu selection: client=%d action=%s", iClient, szInfo);

	if (StrEqual(szInfo, "add"))
		vShowConnectedPlayerMenu(iClient, true);
	else if (StrEqual(szInfo, "edit_flags"))
		vShowSnapshotAdminMenu(iClient, Prompt_AdminEditFlags);
	else if (StrEqual(szInfo, "edit_immunity"))
		vShowSnapshotAdminMenu(iClient, Prompt_AdminEditImmunity);
	else if (StrEqual(szInfo, "add_group"))
		vShowSnapshotAdminGroupAdminMenu(iClient, true);
	else if (StrEqual(szInfo, "remove_group"))
		vShowSnapshotAdminGroupAdminMenu(iClient, false);
	else if (StrEqual(szInfo, "delete"))
		vShowSnapshotAdminDeleteMenu(iClient);

	return 0;
}

void vShowConnectedPlayerMenu(int iClient, bool bForAdminAdd)
{
	Menu menu = new Menu(MenuHandler_ConnectedPlayerSelect);
	menu.SetTitle(bForAdminAdd ? "Select player to add as admin" : "Select player");

	bool bAdded = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!bIsClientUsable(i))
			continue;

		char szName[128];
		char szInfo[16];
		GetClientName(i, szName, sizeof(szName));
		IntToString(GetClientUserId(i), szInfo, sizeof(szInfo));
		menu.AddItem(szInfo, szName);
		bAdded = true;
	}

	if (!bAdded)
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No usable connected players.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_ConnectedPlayerSelect(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[16];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	int iTarget = GetClientOfUserId(StringToInt(szInfo));
	if (!bIsClientUsable(iTarget))
	{
		ReplyToCommand(iClient, "[BS AdminSync] Target is no longer available.");
		return 0;
	}

	g_iPromptAccountId[iClient] = GetClientAccountID(iTarget);
	g_iPromptImmunity[iClient] = 0;
	GetClientName(iTarget, g_szPromptName[iClient], sizeof(g_szPromptName[]));
	if (!GetClientAuthId(iTarget, AuthId_SteamID64, g_szPromptSteamId64[iClient], sizeof(g_szPromptSteamId64[])))
		g_szPromptSteamId64[iClient][0] = '\0';

	g_ePromptState[iClient] = Prompt_AdminAddFlags;
	ReplyToCommand(iClient, "[BS AdminSync] Enter admin flags for %s.", g_szPromptName[iClient]);
	return 0;
}

void vShowSnapshotAdminMenu(int iClient, AdminSyncPromptState eNextPrompt)
{
	Menu menu = new Menu(MenuHandler_SnapshotAdminSelect);
	menu.SetTitle(eNextPrompt == Prompt_AdminEditFlags ? "Select admin to edit flags" : "Select admin to edit immunity");
	g_iPanelAction[iClient] = view_as<int>(eNextPrompt);

	if (!bPopulateSnapshotAdminMenu(menu))
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No admins available in local snapshot.");
		return;
	}

	menu.ExitBackButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}

bool bPopulateSnapshotAdminMenu(Menu menu)
{
	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `accountid`, `name` FROM `adminsync_admins` WHERE `enabled` = 1 ORDER BY `id` ASC;");
		if (rsResult == null)
			return false;

		bool bAdded = false;
		while (rsResult.FetchRow())
		{
			char szName[128];
			char szInfo[16];
			rsResult.FetchString(1, szName, sizeof(szName));
			IntToString(rsResult.FetchInt(0), szInfo, sizeof(szInfo));
			menu.AddItem(szInfo, szName);
			bAdded = true;
		}
		delete rsResult;
		return bAdded;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("admins", false))
	{
		delete kv;
		return false;
	}

	bool bAdded = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			char szInfo[16];
			kv.GetString("name", szName, sizeof(szName));
			IntToString(kv.GetNum("accountid", 0), szInfo, sizeof(szInfo));
			menu.AddItem(szInfo, szName);
			bAdded = true;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bAdded;
}

public int MenuHandler_SnapshotAdminSelect(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[16];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	g_iPromptAccountId[iClient] = StringToInt(szInfo);

	if (g_iPanelAction[iClient] == view_as<int>(Prompt_AdminEditFlags))
	{
		g_ePromptState[iClient] = Prompt_AdminEditFlags;
		ReplyToCommand(iClient, "[BS AdminSync] Enter new admin flags.");
	}
	else
	{
		g_ePromptState[iClient] = Prompt_AdminEditImmunity;
		ReplyToCommand(iClient, "[BS AdminSync] Enter new admin immunity.");
	}

	return 0;
}

void vShowSnapshotAdminDeleteMenu(int iClient)
{
	Menu menu = new Menu(MenuHandler_SnapshotAdminDelete);
	menu.SetTitle("Select admin to delete");

	if (!bPopulateSnapshotAdminMenu(menu))
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No admins available in local snapshot.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_SnapshotAdminDelete(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[16];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	vStartAdminMutationDelete(iClient, StringToInt(szInfo));
	return 0;
}

void vShowSnapshotAdminGroupAdminMenu(int iClient, bool bAssign)
{
	Menu menu = new Menu(MenuHandler_AdminGroupAdminSelect);
	menu.SetTitle(bAssign ? "Select admin to assign group" : "Select admin to remove group");
	g_iPanelAction[iClient] = bAssign ? 100 : 101;

	if (!bPopulateSnapshotAdminMenu(menu))
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No admins available in local snapshot.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminGroupAdminSelect(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[16];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	g_iPromptAccountId[iClient] = StringToInt(szInfo);
	vShowSnapshotGroupMembershipMenu(iClient, g_iPanelAction[iClient] == 100);
	return 0;
}

void vShowSnapshotGroupMembershipMenu(int iClient, bool bAssign)
{
	Menu menu = new Menu(MenuHandler_GroupMembershipSelect);
	menu.SetTitle(bAssign ? "Select group to assign" : "Select group to remove");

	if (!bPopulateSnapshotGroupMenuFiltered(menu, g_iPromptAccountId[iClient], bAssign))
	{
		delete menu;
		ReplyToCommand(iClient, bAssign
			? "[BS AdminSync] No assignable groups available for this admin."
			: "[BS AdminSync] No removable groups available for this admin.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_GroupMembershipSelect(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[128];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));

	if (g_iPanelAction[iClient] == 100)
		vStartAdminMutationAddGroup(iClient, g_iPromptAccountId[iClient], szInfo);
	else
		vStartAdminMutationRemoveGroup(iClient, g_iPromptAccountId[iClient], szInfo);

	return 0;
}

void vShowGroupMainMenu(int iClient)
{
	Menu menu = new Menu(MenuHandler_GroupMain);
	menu.SetTitle("Admin Sync: Groups");
	menu.AddItem("add", "Add group");
	menu.AddItem("edit_flags", "Edit group flags");
	menu.AddItem("edit_immunity", "Edit group immunity");
	menu.AddItem("delete", "Delete group");
	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_GroupMain(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[32];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	vAdminSyncMenu("Group main menu selection: client=%d action=%s", iClient, szInfo);

	if (StrEqual(szInfo, "add"))
	{
		g_ePromptState[iClient] = Prompt_GroupAddName;
		ReplyToCommand(iClient, "[BS AdminSync] Enter new group name.");
	}
	else if (StrEqual(szInfo, "edit_flags"))
	{
		vShowSnapshotGroupMenu(iClient, Prompt_GroupEditFlags);
	}
	else if (StrEqual(szInfo, "edit_immunity"))
	{
		vShowSnapshotGroupMenu(iClient, Prompt_GroupEditImmunity);
	}
	else if (StrEqual(szInfo, "delete"))
	{
		vShowSnapshotGroupDeleteMenu(iClient);
	}

	return 0;
}

void vShowSnapshotGroupMenu(int iClient, AdminSyncPromptState eNextPrompt)
{
	Menu menu = new Menu(MenuHandler_SnapshotGroupSelect);
	menu.SetTitle(eNextPrompt == Prompt_GroupEditFlags ? "Select group to edit flags" : "Select group to edit immunity");
	g_iPanelAction[iClient] = view_as<int>(eNextPrompt);

	if (!bPopulateSnapshotGroupMenu(menu))
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No groups available in local snapshot.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

bool bPopulateSnapshotGroupMenu(Menu menu)
{
	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `name` FROM `adminsync_groups` WHERE `enabled` = 1 ORDER BY `id` ASC;");
		if (rsResult == null)
			return false;

		bool bAdded = false;
		while (rsResult.FetchRow())
		{
			char szName[128];
			rsResult.FetchString(0, szName, sizeof(szName));
			menu.AddItem(szName, szName);
			bAdded = true;
		}
		delete rsResult;
		return bAdded;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("groups", false))
	{
		delete kv;
		return false;
	}

	bool bAdded = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			kv.GetString("name", szName, sizeof(szName));
			menu.AddItem(szName, szName);
			bAdded = true;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bAdded;
}

bool bPopulateSnapshotGroupMenuFiltered(Menu menu, int iAccountId, bool bAssign)
{
	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `name` FROM `adminsync_groups` WHERE `enabled` = 1 ORDER BY `id` ASC;");
		if (rsResult == null)
			return false;

		bool bAdded = false;
		while (rsResult.FetchRow())
		{
			char szName[128];
			rsResult.FetchString(0, szName, sizeof(szName));

			bool bHasGroup = bSnapshotAdminHasGroup(iAccountId, szName);
			if ((bAssign && bHasGroup) || (!bAssign && !bHasGroup))
				continue;

			menu.AddItem(szName, szName);
			bAdded = true;
		}

		delete rsResult;
		return bAdded;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("groups", false))
	{
		delete kv;
		return false;
	}

	bool bAdded = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			kv.GetString("name", szName, sizeof(szName));

			bool bHasGroup = bSnapshotAdminHasGroup(iAccountId, szName);
			if ((bAssign && bHasGroup) || (!bAssign && !bHasGroup))
				continue;

			menu.AddItem(szName, szName);
			bAdded = true;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bAdded;
}

public int MenuHandler_SnapshotGroupSelect(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[128];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	strcopy(g_szPromptGroupName[iClient], sizeof(g_szPromptGroupName[]), szInfo);

	if (g_iPanelAction[iClient] == view_as<int>(Prompt_GroupEditFlags))
	{
		g_ePromptState[iClient] = Prompt_GroupEditFlags;
		ReplyToCommand(iClient, "[BS AdminSync] Enter new group flags.");
	}
	else
	{
		g_ePromptState[iClient] = Prompt_GroupEditImmunity;
		ReplyToCommand(iClient, "[BS AdminSync] Enter new group immunity.");
	}

	return 0;
}

void vShowSnapshotGroupDeleteMenu(int iClient)
{
	Menu menu = new Menu(MenuHandler_SnapshotGroupDelete);
	menu.SetTitle("Select group to delete");

	if (!bPopulateSnapshotGroupMenu(menu))
	{
		delete menu;
		ReplyToCommand(iClient, "[BS AdminSync] No groups available in local snapshot.");
		return;
	}

	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_SnapshotGroupDelete(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
		return 0;

	char szInfo[128];
	menu.GetItem(iItem, szInfo, sizeof(szInfo));
	vStartGroupMutationDelete(iClient, szInfo);
	return 0;
}
