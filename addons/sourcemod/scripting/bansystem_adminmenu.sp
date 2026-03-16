#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <bansystem_access>
#include <bansystem_comm>
#include <bansystem_sprays>
#include <bansystem_adminsync>
#define REQUIRE_PLUGIN

#define BANSYSTEM_ADMINMENU_VERSION "0.1.0-dev"
#define BANSYSTEM_ADMINMENU_MAX_REASON_LENGTH 256
#define BANSYSTEM_ADMINMENU_MAX_PROMPT_LENGTH 256

TopMenu g_hBSAdminTopMenu;
TopMenuObject g_oBSAdminCategory = INVALID_TOPMENUOBJECT;
TopMenuObject g_oBSAdminAccess = INVALID_TOPMENUOBJECT;
TopMenuObject g_oBSAdminComm = INVALID_TOPMENUOBJECT;
TopMenuObject g_oBSAdminSprays = INVALID_TOPMENUOBJECT;
TopMenuObject g_oBSAdminAdmins = INVALID_TOPMENUOBJECT;
TopMenuObject g_oBSAdminGroups = INVALID_TOPMENUOBJECT;

enum BSAdminMenuPanelType
{
	BSAdminMenuPanel_None = 0,
	BSAdminMenuPanel_Access,
	BSAdminMenuPanel_Comm,
	BSAdminMenuPanel_Sprays
}

enum BSAdminMenuPanelStage
{
	BSAdminMenuStage_None = 0,
	BSAdminMenuStage_Reason,
	BSAdminMenuStage_Context
}

enum struct BSAdminMenuPanelState
{
	BSAdminMenuPanelType m_eType;
	BSAdminMenuPanelStage m_eStage;
	int m_iTargetUserId;
	int m_iAccountId;
	int m_iLength;
	eBSCommType m_eCommType;
	char m_szReason[BANSYSTEM_ADMINMENU_MAX_REASON_LENGTH];
}

BSAdminMenuPanelState g_eBSAdminPanelState[MAXPLAYERS + 1];

enum BSAdminMenuAdminSyncPromptState
{
	BSAdminMenuAdminSyncPrompt_None = 0,
	BSAdminMenuAdminSyncPrompt_AdminAddFlags,
	BSAdminMenuAdminSyncPrompt_AdminAddImmunity,
	BSAdminMenuAdminSyncPrompt_AdminEditFlags,
	BSAdminMenuAdminSyncPrompt_AdminEditImmunity,
	BSAdminMenuAdminSyncPrompt_GroupAddName,
	BSAdminMenuAdminSyncPrompt_GroupAddFlags,
	BSAdminMenuAdminSyncPrompt_GroupAddImmunity,
	BSAdminMenuAdminSyncPrompt_GroupEditFlags,
	BSAdminMenuAdminSyncPrompt_GroupEditImmunity
}

enum BSAdminMenuAdminSyncAction
{
	BSAdminMenuAdminSyncAction_None = 0,
	BSAdminMenuAdminSyncAction_AdminEditFlags,
	BSAdminMenuAdminSyncAction_AdminEditImmunity,
	BSAdminMenuAdminSyncAction_AdminDelete,
	BSAdminMenuAdminSyncAction_AdminAssignGroup,
	BSAdminMenuAdminSyncAction_AdminRemoveGroup,
	BSAdminMenuAdminSyncAction_GroupEditFlags,
	BSAdminMenuAdminSyncAction_GroupEditImmunity,
	BSAdminMenuAdminSyncAction_GroupDelete
}

enum struct BSAdminMenuAdminSyncState
{
	BSAdminMenuAdminSyncPromptState m_ePrompt;
	BSAdminMenuAdminSyncAction m_eAction;
	int m_iAccountId;
	int m_iImmunity;
	char m_szName[128];
	char m_szFlags[64];
	char m_szSteamId64[32];
	char m_szGroupName[128];
}

BSAdminMenuAdminSyncState g_eBSAdminSyncState[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "BanSystem Admin Menu",
	author = "lechuga",
	description = "Admin menu bridge and panel runtime for the BanSystem modular suite.",
	version = BANSYSTEM_ADMINMENU_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public void OnPluginStart()
{
	LoadTranslations("bansystem_adminmenu.phrases");
	LoadTranslations("bansystem_access.phrases");
	LoadTranslations("bansystem_comm.phrases");
	LoadTranslations("bansystem_sprays.phrases");
	LoadTranslations("bansystem_adminsync.phrases");

	RegAdminCmd("sm_bs_access_panel", Command_BSAdminAccessPanel, ADMFLAG_ROOT, "Open the BanSystem Access panel.");
	RegAdminCmd("sm_bs_access_abort", Command_BSAdminAccessAbort, ADMFLAG_ROOT, "Abort the current BanSystem Access panel flow.");
	RegAdminCmd("sm_bs_comm_panel", Command_BSAdminCommPanel, ADMFLAG_ROOT, "Open the BanSystem Comm panel.");
	RegAdminCmd("sm_bs_comm_abort", Command_BSAdminCommAbort, ADMFLAG_ROOT, "Abort the current BanSystem Comm panel flow.");
	RegAdminCmd("sm_bs_sprays_panel", Command_BSAdminSpraysPanel, ADMFLAG_ROOT, "Open the BanSystem Sprays panel.");
	RegAdminCmd("sm_bs_sprays_abort", Command_BSAdminSpraysAbort, ADMFLAG_ROOT, "Abort the current BanSystem Sprays panel flow.");
	RegAdminCmd("sm_bs_admin_panel", Command_BSAdminSyncAdminPanel, ADMFLAG_ROOT, "Open the BanSystem Admin Sync admin panel.");
	RegAdminCmd("sm_bs_group_panel", Command_BSAdminSyncGroupPanel, ADMFLAG_ROOT, "Open the BanSystem Admin Sync group panel.");
	RegAdminCmd("sm_bs_adminsync_abort", Command_BSAdminSyncAbort, ADMFLAG_ROOT, "Abort the current BanSystem Admin Sync prompt.");

	if (LibraryExists("adminmenu"))
	{
		TopMenu hTopMenu = GetAdminTopMenu();
		if (hTopMenu != null)
		{
			OnAdminMenuReady(hTopMenu);
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	BSAdminMenu_ResetPanelState(iClient);
	BSAdminMenu_ResetAdminSyncState(iClient);
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
	{
		return Plugin_Continue;
	}

	if (g_eBSAdminPanelState[iClient].m_eStage == BSAdminMenuStage_None
		&& g_eBSAdminSyncState[iClient].m_ePrompt == BSAdminMenuAdminSyncPrompt_None)
	{
		return Plugin_Continue;
	}

	char szText[512];
	strcopy(szText, sizeof(szText), szArgs);
	TrimString(szText);
	StripQuotes(szText);

	if (szText[0] == '\0')
	{
		if (g_eBSAdminPanelState[iClient].m_eStage != BSAdminMenuStage_None)
		{
			BSAdminMenu_ReplyReasonCannotBeEmpty(iClient);
		}
		else
		{
			CReplyToCommand(iClient, "%t", "BSAdminSyncEmptyInput");
		}
		return Plugin_Handled;
	}

	if (g_eBSAdminPanelState[iClient].m_eStage != BSAdminMenuStage_None)
	{
		switch (g_eBSAdminPanelState[iClient].m_eStage)
		{
			case BSAdminMenuStage_Reason:
			{
				strcopy(g_eBSAdminPanelState[iClient].m_szReason, sizeof(g_eBSAdminPanelState[].m_szReason), szText);
				g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_Context;
				BSAdminMenu_ReplyContextPrompt(iClient);
				return Plugin_Handled;
			}

			case BSAdminMenuStage_Context:
			{
				char szContext[512];
				strcopy(szContext, sizeof(szContext), szText);

				if (StrEqual(szContext, "-", false))
				{
					szContext[0] = '\0';
				}

				if (!BSAdminMenu_ValidatePanelTarget(iClient))
				{
					return Plugin_Handled;
				}

				if (!BSAdminMenu_CommitPanelAction(iClient, szContext))
				{
					BSAdminMenu_ReplyDatabaseNotReady(iClient);
					return Plugin_Handled;
				}

				BSAdminMenu_ResetPanelState(iClient);
				return Plugin_Handled;
			}
		}
	}

	return BSAdminMenu_HandleAdminSyncPrompt(iClient, szText);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "adminmenu", false))
	{
		TopMenu hTopMenu = GetAdminTopMenu();
		if (hTopMenu != null)
		{
			OnAdminMenuReady(hTopMenu);
		}
		return;
	}

	if (g_hBSAdminTopMenu != null)
	{
		BSAdminMenu_TryAddItems();
	}
}

public void OnAdminMenuReady(Handle hTopMenuHandle)
{
	TopMenu hTopMenu = TopMenu.FromHandle(hTopMenuHandle);
	if (g_hBSAdminTopMenu == hTopMenu)
	{
		return;
	}

	g_hBSAdminTopMenu = hTopMenu;
	g_oBSAdminCategory = INVALID_TOPMENUOBJECT;
	g_oBSAdminAccess = INVALID_TOPMENUOBJECT;
	g_oBSAdminComm = INVALID_TOPMENUOBJECT;
	g_oBSAdminSprays = INVALID_TOPMENUOBJECT;
	g_oBSAdminAdmins = INVALID_TOPMENUOBJECT;
	g_oBSAdminGroups = INVALID_TOPMENUOBJECT;

	g_oBSAdminCategory = g_hBSAdminTopMenu.AddCategory("bansystem_adminmenu", BSAdminMenu_CategoryHandler);
	BSAdminMenu_TryAddItems();
}

static void BSAdminMenu_TryAddItems()
{
	if (g_hBSAdminTopMenu == null || g_oBSAdminCategory == INVALID_TOPMENUOBJECT)
	{
		return;
	}

	if (g_oBSAdminAccess == INVALID_TOPMENUOBJECT && LibraryExists("bansystem_access"))
	{
		g_oBSAdminAccess = g_hBSAdminTopMenu.AddItem("bansystem_access_panel", BSAdminMenu_AccessHandler, g_oBSAdminCategory, "sm_bs_access_panel", ADMFLAG_ROOT);
	}

	if (g_oBSAdminComm == INVALID_TOPMENUOBJECT && LibraryExists("bansystem_comm"))
	{
		g_oBSAdminComm = g_hBSAdminTopMenu.AddItem("bansystem_comm_panel", BSAdminMenu_CommHandler, g_oBSAdminCategory, "sm_bs_comm_panel", ADMFLAG_ROOT);
	}

	if (g_oBSAdminSprays == INVALID_TOPMENUOBJECT && LibraryExists("bansystem_sprays"))
	{
		g_oBSAdminSprays = g_hBSAdminTopMenu.AddItem("bansystem_sprays_panel", BSAdminMenu_SpraysHandler, g_oBSAdminCategory, "sm_bs_sprays_panel", ADMFLAG_ROOT);
	}

	if (g_oBSAdminAdmins == INVALID_TOPMENUOBJECT && LibraryExists("bansystem_adminsync"))
	{
		g_oBSAdminAdmins = g_hBSAdminTopMenu.AddItem("bansystem_adminsync_admins", BSAdminMenu_AdminsHandler, g_oBSAdminCategory, "sm_bs_admin_panel", ADMFLAG_ROOT);
	}

	if (g_oBSAdminGroups == INVALID_TOPMENUOBJECT && LibraryExists("bansystem_adminsync"))
	{
		g_oBSAdminGroups = g_hBSAdminTopMenu.AddItem("bansystem_adminsync_groups", BSAdminMenu_GroupsHandler, g_oBSAdminCategory, "sm_bs_group_panel", ADMFLAG_ROOT);
	}
}

public void BSAdminMenu_CategoryHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	switch (eAction)
	{
		case TopMenuAction_DisplayTitle, TopMenuAction_DisplayOption:
		{
			FormatEx(szBuffer, iMaxLength, "%T", "BSAdminMenuCategory", iClient);
		}
	}
}

public void BSAdminMenu_AccessHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	BSAdminMenu_HandleItem(eAction, iClient, szBuffer, iMaxLength, "BSAdminMenuAccess", "bansystem_access", "sm_bs_access_panel");
}

public void BSAdminMenu_CommHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	BSAdminMenu_HandleItem(eAction, iClient, szBuffer, iMaxLength, "BSAdminMenuComm", "bansystem_comm", "sm_bs_comm_panel");
}

public void BSAdminMenu_SpraysHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	BSAdminMenu_HandleItem(eAction, iClient, szBuffer, iMaxLength, "BSAdminMenuSprays", "bansystem_sprays", "sm_bs_sprays_panel");
}

public void BSAdminMenu_AdminsHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	BSAdminMenu_HandleItem(eAction, iClient, szBuffer, iMaxLength, "BSAdminMenuAdmins", "bansystem_adminsync", "sm_bs_admin_panel");
}

public void BSAdminMenu_GroupsHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	BSAdminMenu_HandleItem(eAction, iClient, szBuffer, iMaxLength, "BSAdminMenuGroups", "bansystem_adminsync", "sm_bs_group_panel");
}

static void BSAdminMenu_HandleItem(TopMenuAction eAction, int iClient, char[] szBuffer, int iMaxLength, const char[] szPhrase, const char[] szLibrary, const char[] szCommand)
{
	switch (eAction)
	{
		case TopMenuAction_DisplayOption:
		{
			FormatEx(szBuffer, iMaxLength, "%T", szPhrase, iClient);
		}

		case TopMenuAction_SelectOption:
		{
			if (!LibraryExists(szLibrary))
			{
				CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", szLibrary);
				return;
			}

			FakeClientCommand(iClient, szCommand);
		}
	}
}

Action Command_BSAdminAccessPanel(int iClient, int iArgs)
{
	return BSAdminMenu_CommandOpenPanel(iClient, BSAdminMenuPanel_Access);
}

Action Command_BSAdminAccessAbort(int iClient, int iArgs)
{
	return BSAdminMenu_CommandAbortPanel(iClient, BSAdminMenuPanel_Access);
}

Action Command_BSAdminCommPanel(int iClient, int iArgs)
{
	return BSAdminMenu_CommandOpenPanel(iClient, BSAdminMenuPanel_Comm);
}

Action Command_BSAdminCommAbort(int iClient, int iArgs)
{
	return BSAdminMenu_CommandAbortPanel(iClient, BSAdminMenuPanel_Comm);
}

Action Command_BSAdminSpraysPanel(int iClient, int iArgs)
{
	return BSAdminMenu_CommandOpenPanel(iClient, BSAdminMenuPanel_Sprays);
}

Action Command_BSAdminSpraysAbort(int iClient, int iArgs)
{
	return BSAdminMenu_CommandAbortPanel(iClient, BSAdminMenuPanel_Sprays);
}

Action Command_BSAdminSyncAdminPanel(int iClient, int iArgs)
{
	if (!BSAdminMenu_IsUsableClient(iClient))
	{
		return Plugin_Handled;
	}

	if (!LibraryExists("bansystem_adminsync"))
	{
		CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_adminsync");
		return Plugin_Handled;
	}

	BSAdminMenu_ResetAdminSyncState(iClient);
	BSAdminMenu_ShowAdminSyncAdminMainMenu(iClient);
	return Plugin_Handled;
}

Action Command_BSAdminSyncGroupPanel(int iClient, int iArgs)
{
	if (!BSAdminMenu_IsUsableClient(iClient))
	{
		return Plugin_Handled;
	}

	if (!LibraryExists("bansystem_adminsync"))
	{
		CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_adminsync");
		return Plugin_Handled;
	}

	BSAdminMenu_ResetAdminSyncState(iClient);
	BSAdminMenu_ShowAdminSyncGroupMainMenu(iClient);
	return Plugin_Handled;
}

Action Command_BSAdminSyncAbort(int iClient, int iArgs)
{
	if (!BSAdminMenu_IsUsableClient(iClient))
	{
		return Plugin_Handled;
	}

	if (g_eBSAdminSyncState[iClient].m_ePrompt == BSAdminMenuAdminSyncPrompt_None)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoPromptActive");
		return Plugin_Handled;
	}

	BSAdminMenu_ResetAdminSyncState(iClient);
	CReplyToCommand(iClient, "%t", "BSAdminSyncPromptAborted");
	return Plugin_Handled;
}

static Action BSAdminMenu_CommandOpenPanel(int iClient, BSAdminMenuPanelType eType)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
	{
		return Plugin_Handled;
	}

	if (!BSAdminMenu_IsPanelLibraryAvailable(eType))
	{
		BSAdminMenu_ReplyModuleUnavailable(iClient, eType);
		return Plugin_Handled;
	}

	BSAdminMenu_ResetPanelState(iClient);
	g_eBSAdminPanelState[iClient].m_eType = eType;
	BSAdminMenu_ShowTargetPanel(iClient);
	return Plugin_Handled;
}

static Action BSAdminMenu_CommandAbortPanel(int iClient, BSAdminMenuPanelType eType)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
	{
		return Plugin_Handled;
	}

	if (g_eBSAdminPanelState[iClient].m_eType != eType || g_eBSAdminPanelState[iClient].m_eStage == BSAdminMenuStage_None)
	{
		BSAdminMenu_ReplyNoPanelFlow(iClient, eType);
		return Plugin_Handled;
	}

	BSAdminMenu_ResetPanelState(iClient);
	BSAdminMenu_ReplyPanelAborted(iClient, eType);
	return Plugin_Handled;
}

static void BSAdminMenu_ResetPanelState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
	{
		return;
	}

	g_eBSAdminPanelState[iClient].m_eType = BSAdminMenuPanel_None;
	g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
	g_eBSAdminPanelState[iClient].m_iTargetUserId = 0;
	g_eBSAdminPanelState[iClient].m_iAccountId = 0;
	g_eBSAdminPanelState[iClient].m_iLength = 0;
	g_eBSAdminPanelState[iClient].m_eCommType = kBSCommType_None;
	g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
}

static void BSAdminMenu_ResetAdminSyncState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
	{
		return;
	}

	g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_None;
	g_eBSAdminSyncState[iClient].m_eAction = BSAdminMenuAdminSyncAction_None;
	g_eBSAdminSyncState[iClient].m_iAccountId = 0;
	g_eBSAdminSyncState[iClient].m_iImmunity = 0;
	g_eBSAdminSyncState[iClient].m_szName[0] = '\0';
	g_eBSAdminSyncState[iClient].m_szFlags[0] = '\0';
	g_eBSAdminSyncState[iClient].m_szSteamId64[0] = '\0';
	g_eBSAdminSyncState[iClient].m_szGroupName[0] = '\0';
}

static bool BSAdminMenu_IsUsableClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

static bool BSAdminMenu_IsPanelLibraryAvailable(BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			return LibraryExists("bansystem_access");
		}

		case BSAdminMenuPanel_Comm:
		{
			return LibraryExists("bansystem_comm");
		}

		case BSAdminMenuPanel_Sprays:
		{
			return LibraryExists("bansystem_sprays");
		}
	}

	return false;
}

static void BSAdminMenu_ReplyModuleUnavailable(int iClient, BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_access");
		}

		case BSAdminMenuPanel_Comm:
		{
			CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_comm");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_sprays");
		}
	}
}

static void BSAdminMenu_ShowTargetPanel(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_TargetPanelHandler);

	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			hMenu.SetTitle("BanSystem Access\nSelect target");
		}

		case BSAdminMenuPanel_Comm:
		{
			hMenu.SetTitle("BanSystem Comm\nSelect target");
		}

		case BSAdminMenuPanel_Sprays:
		{
			hMenu.SetTitle("BanSystem Sprays\nSelect target");
		}
	}

	hMenu.ExitBackButton = false;

	int iCount = 0;
	char szInfo[16];
	char szName[MAX_NAME_LENGTH];
	for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
	{
		if (!IsClientInGame(iTarget) || IsFakeClient(iTarget))
		{
			continue;
		}

		if (!CanUserTarget(iClient, iTarget))
		{
			continue;
		}

		IntToString(GetClientUserId(iTarget), szInfo, sizeof(szInfo));
		GetClientName(iTarget, szName, sizeof(szName));
		hMenu.AddItem(szInfo, szName);
		iCount++;
	}

	if (iCount == 0)
	{
		delete hMenu;
		BSAdminMenu_ReplyNoTargets(iClient);
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static void BSAdminMenu_ShowCommTypePanel(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_TypePanelHandler);
	hMenu.SetTitle("BanSystem Comm\nSelect type");
	hMenu.ExitBackButton = true;
	hMenu.AddItem("mic", "Mic");
	hMenu.AddItem("chat", "Chat");
	hMenu.AddItem("all", "All");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static void BSAdminMenu_ShowDurationPanel(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_DurationPanelHandler);

	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			hMenu.SetTitle("BanSystem Access\nSelect duration");
		}

		case BSAdminMenuPanel_Comm:
		{
			hMenu.SetTitle("BanSystem Comm\nSelect duration");
		}

		case BSAdminMenuPanel_Sprays:
		{
			hMenu.SetTitle("BanSystem Sprays\nSelect duration");
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.AddItem("10", "10 minutes");
	hMenu.AddItem("30", "30 minutes");
	hMenu.AddItem("60", "60 minutes");
	hMenu.AddItem("1440", "1 day");
	hMenu.AddItem("0", "Permanent");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_TargetPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

			int iTarget = GetClientOfUserId(StringToInt(szInfo));
			if (iTarget <= 0 || !IsClientInGame(iTarget))
			{
				BSAdminMenu_ReplyTargetUnavailable(iParam1);
				BSAdminMenu_ShowTargetPanel(iParam1);
				return 0;
			}

			g_eBSAdminPanelState[iParam1].m_iTargetUserId = GetClientUserId(iTarget);
			g_eBSAdminPanelState[iParam1].m_iAccountId = GetSteamAccountID(iTarget);
			if (g_eBSAdminPanelState[iParam1].m_iAccountId <= 0)
			{
				BSAdminMenu_ReplyTargetUnavailable(iParam1);
				g_eBSAdminPanelState[iParam1].m_iTargetUserId = 0;
				BSAdminMenu_ShowTargetPanel(iParam1);
				return 0;
			}

			if (g_eBSAdminPanelState[iParam1].m_eType == BSAdminMenuPanel_Comm)
			{
				BSAdminMenu_ShowCommTypePanel(iParam1);
			}
			else
			{
				BSAdminMenu_ShowDurationPanel(iParam1);
			}
		}
	}

	return 0;
}

public int BSAdminMenu_TypePanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				BSAdminMenu_ShowTargetPanel(iParam1);
			}
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

			if (StrEqual(szInfo, "mic", false))
			{
				g_eBSAdminPanelState[iParam1].m_eCommType = kBSCommType_Mic;
			}
			else if (StrEqual(szInfo, "chat", false))
			{
				g_eBSAdminPanelState[iParam1].m_eCommType = kBSCommType_Chat;
			}
			else if (StrEqual(szInfo, "all", false))
			{
				g_eBSAdminPanelState[iParam1].m_eCommType = kBSCommType_All;
			}
			else
			{
				CReplyToCommand(iParam1, "%t", "BSCommInvalidTypeShort");
				BSAdminMenu_ShowCommTypePanel(iParam1);
				return 0;
			}

			BSAdminMenu_ShowDurationPanel(iParam1);
		}
	}

	return 0;
}

public int BSAdminMenu_DurationPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (g_eBSAdminPanelState[iParam1].m_eType == BSAdminMenuPanel_Comm)
				{
					BSAdminMenu_ShowCommTypePanel(iParam1);
				}
				else
				{
					BSAdminMenu_ShowTargetPanel(iParam1);
				}
			}
		}

		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iParam2, szInfo, sizeof(szInfo));
			g_eBSAdminPanelState[iParam1].m_iLength = StringToInt(szInfo);
			g_eBSAdminPanelState[iParam1].m_eStage = BSAdminMenuStage_Reason;
			BSAdminMenu_ReplyReasonPrompt(iParam1);
		}
	}

	return 0;
}

static bool BSAdminMenu_CommitPanelAction(int iClient, const char[] szContext)
{
	int iAccountId = g_eBSAdminPanelState[iClient].m_iAccountId;
	int iLength = g_eBSAdminPanelState[iClient].m_iLength;
	char szReason[BANSYSTEM_ADMINMENU_MAX_REASON_LENGTH];
	strcopy(szReason, sizeof(szReason), g_eBSAdminPanelState[iClient].m_szReason);

	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			return BSAccess_AddBanByAccountId(iClient, iAccountId, iLength, szReason, szContext);
		}

		case BSAdminMenuPanel_Comm:
		{
			return BSComm_AddBanByAccountId(iClient, iAccountId, g_eBSAdminPanelState[iClient].m_eCommType, iLength, szReason, szContext);
		}

		case BSAdminMenuPanel_Sprays:
		{
			return BSSprays_AddBanByAccountId(iClient, iAccountId, iLength, szReason, szContext);
		}
	}

	return false;
}

static bool BSAdminMenu_ValidatePanelTarget(int iClient)
{
	int iTarget = GetClientOfUserId(g_eBSAdminPanelState[iClient].m_iTargetUserId);
	if (iTarget <= 0 || !IsClientInGame(iTarget) || IsFakeClient(iTarget) || !CanUserTarget(iClient, iTarget))
	{
		BSAdminMenu_ReplyTargetUnavailable(iClient);
		g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
		g_eBSAdminPanelState[iClient].m_iTargetUserId = 0;
		g_eBSAdminPanelState[iClient].m_iAccountId = 0;
		g_eBSAdminPanelState[iClient].m_iLength = 0;
		g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
		BSAdminMenu_ShowTargetPanel(iClient);
		return false;
	}

	int iAccountId = GetSteamAccountID(iTarget);
	if (iAccountId <= 0 || iAccountId != g_eBSAdminPanelState[iClient].m_iAccountId)
	{
		BSAdminMenu_ReplyTargetUnavailable(iClient);
		g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
		g_eBSAdminPanelState[iClient].m_iTargetUserId = 0;
		g_eBSAdminPanelState[iClient].m_iAccountId = 0;
		g_eBSAdminPanelState[iClient].m_iLength = 0;
		g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
		BSAdminMenu_ShowTargetPanel(iClient);
		return false;
	}

	return true;
}

static void BSAdminMenu_ReplyNoTargets(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessNoTargets");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommNoTargets");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysNoTargets");
		}
	}
}

static void BSAdminMenu_ReplyTargetUnavailable(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessTargetUnavailable");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommTargetUnavailable");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysTargetUnavailable");
		}
	}
}

static void BSAdminMenu_ReplyReasonCannotBeEmpty(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessReasonCannotBeEmpty");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommReasonCannotBeEmpty");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysReasonCannotBeEmpty");
		}
	}
}

static void BSAdminMenu_ReplyReasonPrompt(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessReasonPrompt");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommReasonPrompt");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysReasonPrompt");
		}
	}
}

static void BSAdminMenu_ReplyContextPrompt(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessContextPrompt");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommContextPrompt");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysContextPrompt");
		}
	}
}

static void BSAdminMenu_ReplyNoPanelFlow(int iClient, BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessNoPanelFlow");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommNoPanelFlow");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysNoPanelFlow");
		}
	}
}

static void BSAdminMenu_ReplyPanelAborted(int iClient, BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessPanelAborted");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommPanelAborted");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysPanelAborted");
		}
	}
}

static void BSAdminMenu_ReplyDatabaseNotReady(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			CReplyToCommand(iClient, "%t", "BSAccessDatabaseNotReady");
		}

		case BSAdminMenuPanel_Comm:
		{
			CReplyToCommand(iClient, "%t", "BSCommDatabaseNotReady");
		}

		case BSAdminMenuPanel_Sprays:
		{
			CReplyToCommand(iClient, "%t", "BSSpraysDatabaseNotReady");
		}
	}
}

static Action BSAdminMenu_HandleAdminSyncPrompt(int iClient, const char[] szText)
{
	if (g_eBSAdminSyncState[iClient].m_ePrompt == BSAdminMenuAdminSyncPrompt_None)
	{
		return Plugin_Continue;
	}

	if (!LibraryExists("bansystem_adminsync"))
	{
		BSAdminMenu_ResetAdminSyncState(iClient);
		CPrintToChat(iClient, "%t", "BSAdminMenuModuleUnavailable", "bansystem_adminsync");
		return Plugin_Handled;
	}

	switch (g_eBSAdminSyncState[iClient].m_ePrompt)
	{
		case BSAdminMenuAdminSyncPrompt_AdminAddFlags:
		{
			strcopy(g_eBSAdminSyncState[iClient].m_szFlags, sizeof(g_eBSAdminSyncState[].m_szFlags), szText);
			g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_AdminAddImmunity;
			CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterAdminImmunity");
		}

		case BSAdminMenuAdminSyncPrompt_AdminAddImmunity:
		{
			g_eBSAdminSyncState[iClient].m_iImmunity = StringToInt(szText);
			bBSASAddAdmin(
				g_eBSAdminSyncState[iClient].m_iAccountId,
				g_eBSAdminSyncState[iClient].m_szName,
				g_eBSAdminSyncState[iClient].m_szSteamId64,
				g_eBSAdminSyncState[iClient].m_iImmunity,
				g_eBSAdminSyncState[iClient].m_szFlags
			);
			BSAdminMenu_ResetAdminSyncState(iClient);
		}

		case BSAdminMenuAdminSyncPrompt_AdminEditFlags:
		{
			bBSASSetAdminFlags(g_eBSAdminSyncState[iClient].m_iAccountId, szText);
			BSAdminMenu_ResetAdminSyncState(iClient);
		}

		case BSAdminMenuAdminSyncPrompt_AdminEditImmunity:
		{
			bBSASSetAdminImmunity(g_eBSAdminSyncState[iClient].m_iAccountId, StringToInt(szText));
			BSAdminMenu_ResetAdminSyncState(iClient);
		}

		case BSAdminMenuAdminSyncPrompt_GroupAddName:
		{
			strcopy(g_eBSAdminSyncState[iClient].m_szGroupName, sizeof(g_eBSAdminSyncState[].m_szGroupName), szText);
			g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_GroupAddFlags;
			CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterGroupFlags");
		}

		case BSAdminMenuAdminSyncPrompt_GroupAddFlags:
		{
			strcopy(g_eBSAdminSyncState[iClient].m_szFlags, sizeof(g_eBSAdminSyncState[].m_szFlags), szText);
			g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_GroupAddImmunity;
			CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterGroupImmunity");
		}

		case BSAdminMenuAdminSyncPrompt_GroupAddImmunity:
		{
			bBSASAddGroup(g_eBSAdminSyncState[iClient].m_szGroupName, g_eBSAdminSyncState[iClient].m_szFlags, StringToInt(szText));
			BSAdminMenu_ResetAdminSyncState(iClient);
		}

		case BSAdminMenuAdminSyncPrompt_GroupEditFlags:
		{
			bBSASSetGroupFlags(g_eBSAdminSyncState[iClient].m_szGroupName, szText);
			BSAdminMenu_ResetAdminSyncState(iClient);
		}

		case BSAdminMenuAdminSyncPrompt_GroupEditImmunity:
		{
			bBSASSetGroupImmunity(g_eBSAdminSyncState[iClient].m_szGroupName, StringToInt(szText));
			BSAdminMenu_ResetAdminSyncState(iClient);
		}
	}

	return Plugin_Handled;
}

static void BSAdminMenu_ShowAdminSyncAdminMainMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncAdminMainHandler);
	char szText[128];

	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminTitle", iClient);
	hMenu.SetTitle(szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminAdd", iClient);
	hMenu.AddItem("add", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminEditFlags", iClient);
	hMenu.AddItem("edit_flags", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminEditImmunity", iClient);
	hMenu.AddItem("edit_immunity", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminAssignGroup", iClient);
	hMenu.AddItem("add_group", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminRemoveGroup", iClient);
	hMenu.AddItem("remove_group", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuAdminDelete", iClient);
	hMenu.AddItem("delete", szText);
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncAdminMainHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[32];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));

	if (StrEqual(szInfo, "add"))
	{
		BSAdminMenu_ShowAdminSyncConnectedPlayerMenu(iClient);
	}
	else if (StrEqual(szInfo, "edit_flags"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotAdminMenu(iClient, BSAdminMenuAdminSyncAction_AdminEditFlags);
	}
	else if (StrEqual(szInfo, "edit_immunity"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotAdminMenu(iClient, BSAdminMenuAdminSyncAction_AdminEditImmunity);
	}
	else if (StrEqual(szInfo, "add_group"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(iClient, true);
	}
	else if (StrEqual(szInfo, "remove_group"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(iClient, false);
	}
	else if (StrEqual(szInfo, "delete"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotAdminDeleteMenu(iClient);
	}

	return 0;
}

static void BSAdminMenu_ShowAdminSyncConnectedPlayerMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncConnectedPlayerHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", "BSAdminSyncMenuSelectPlayerAdd", iClient);
	hMenu.SetTitle(szTitle);

	bool bAdded = false;
	for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
	{
		if (!BSAdminMenu_IsUsableClient(iTarget))
		{
			continue;
		}

		char szName[128];
		char szInfo[16];
		GetClientName(iTarget, szName, sizeof(szName));
		IntToString(GetClientUserId(iTarget), szInfo, sizeof(szInfo));
		hMenu.AddItem(szInfo, szName);
		bAdded = true;
	}

	if (!bAdded)
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoUsablePlayers");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncConnectedPlayerHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[16];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
	int iTarget = GetClientOfUserId(StringToInt(szInfo));
	if (!BSAdminMenu_IsUsableClient(iTarget))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncTargetUnavailable");
		return 0;
	}

	BSAdminMenu_ResetAdminSyncState(iClient);
	g_eBSAdminSyncState[iClient].m_iAccountId = GetSteamAccountID(iTarget);
	GetClientName(iTarget, g_eBSAdminSyncState[iClient].m_szName, sizeof(g_eBSAdminSyncState[].m_szName));
	if (!GetClientAuthId(iTarget, AuthId_SteamID64, g_eBSAdminSyncState[iClient].m_szSteamId64, sizeof(g_eBSAdminSyncState[].m_szSteamId64)))
	{
		g_eBSAdminSyncState[iClient].m_szSteamId64[0] = '\0';
	}

	g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_AdminAddFlags;
	CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterAdminFlagsFor", g_eBSAdminSyncState[iClient].m_szName);
	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotAdminMenu(int iClient, BSAdminMenuAdminSyncAction eAction)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotAdminHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T",
		eAction == BSAdminMenuAdminSyncAction_AdminEditFlags ? "BSAdminSyncMenuSelectAdminEditFlags" : "BSAdminSyncMenuSelectAdminEditImmunity",
		iClient);
	hMenu.SetTitle(szTitle);

	g_eBSAdminSyncState[iClient].m_eAction = eAction;

	if (!BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoAdminsAvailable");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static bool BSAdminMenu_PopulateAdminSyncAdminMenu(Menu hMenu)
{
	int iCount = iBSASGetAdminCount();
	bool bAdded = false;

	for (int iIndex = 0; iIndex < iCount; iIndex++)
	{
		int iAccountId = 0;
		char szName[128];
		char szInfo[16];

		if (!bBSASGetAdminByIndex(iIndex, iAccountId, szName, sizeof(szName)))
		{
			continue;
		}

		IntToString(iAccountId, szInfo, sizeof(szInfo));
		hMenu.AddItem(szInfo, szName);
		bAdded = true;
	}

	return bAdded;
}

public int BSAdminMenu_AdminSyncSnapshotAdminHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[16];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
	g_eBSAdminSyncState[iClient].m_iAccountId = StringToInt(szInfo);

	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminEditFlags)
	{
		g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_AdminEditFlags;
		CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterNewAdminFlags");
	}
	else
	{
		g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_AdminEditImmunity;
		CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterNewAdminImmunity");
	}

	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotAdminDeleteMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotAdminDeleteHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", "BSAdminSyncMenuSelectAdminDelete", iClient);
	hMenu.SetTitle(szTitle);

	if (!BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoAdminsAvailable");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncSnapshotAdminDeleteHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[16];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
	bBSASDeleteAdmin(StringToInt(szInfo));
	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(int iClient, bool bAssign)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncAdminGroupAdminHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", bAssign ? "BSAdminSyncMenuSelectAdminAssignGroup" : "BSAdminSyncMenuSelectAdminRemoveGroup", iClient);
	hMenu.SetTitle(szTitle);

	g_eBSAdminSyncState[iClient].m_eAction = bAssign ? BSAdminMenuAdminSyncAction_AdminAssignGroup : BSAdminMenuAdminSyncAction_AdminRemoveGroup;

	if (!BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoAdminsAvailable");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncAdminGroupAdminHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[16];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
	g_eBSAdminSyncState[iClient].m_iAccountId = StringToInt(szInfo);
	BSAdminMenu_ShowAdminSyncSnapshotGroupMembershipMenu(iClient, g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminAssignGroup);
	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotGroupMembershipMenu(int iClient, bool bAssign)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncGroupMembershipHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", bAssign ? "BSAdminSyncMenuSelectGroupAssign" : "BSAdminSyncMenuSelectGroupRemove", iClient);
	hMenu.SetTitle(szTitle);

	if (!BSAdminMenu_PopulateAdminSyncGroupMenuFiltered(hMenu, g_eBSAdminSyncState[iClient].m_iAccountId, bAssign))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", bAssign ? "BSAdminSyncNoAssignableGroups" : "BSAdminSyncNoRemovableGroups");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static bool BSAdminMenu_PopulateAdminSyncGroupMenuFiltered(Menu hMenu, int iAccountId, bool bAssign)
{
	int iCount = iBSASGetGroupCount();
	bool bAdded = false;

	for (int iIndex = 0; iIndex < iCount; iIndex++)
	{
		char szName[128];
		if (!bBSASGetGroupByIndex(iIndex, szName, sizeof(szName)))
		{
			continue;
		}

		bool bHasGroup = bBSASAdminHasGroup(iAccountId, szName);
		if ((bAssign && bHasGroup) || (!bAssign && !bHasGroup))
		{
			continue;
		}

		hMenu.AddItem(szName, szName);
		bAdded = true;
	}

	return bAdded;
}

public int BSAdminMenu_AdminSyncGroupMembershipHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szGroupName[128];
	hMenu.GetItem(iItem, szGroupName, sizeof(szGroupName));

	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminAssignGroup)
	{
		bBSASAddAdminGroup(g_eBSAdminSyncState[iClient].m_iAccountId, szGroupName);
	}
	else
	{
		bBSASRemoveAdminGroup(g_eBSAdminSyncState[iClient].m_iAccountId, szGroupName);
	}

	return 0;
}

static void BSAdminMenu_ShowAdminSyncGroupMainMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncGroupMainHandler);
	char szText[128];

	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuGroupTitle", iClient);
	hMenu.SetTitle(szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuGroupAdd", iClient);
	hMenu.AddItem("add", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuGroupEditFlags", iClient);
	hMenu.AddItem("edit_flags", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuGroupEditImmunity", iClient);
	hMenu.AddItem("edit_immunity", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminSyncMenuGroupDelete", iClient);
	hMenu.AddItem("delete", szText);
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncGroupMainHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szInfo[32];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));

	if (StrEqual(szInfo, "add"))
	{
		g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_GroupAddName;
		CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterNewGroupName");
	}
	else if (StrEqual(szInfo, "edit_flags"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotGroupMenu(iClient, BSAdminMenuAdminSyncAction_GroupEditFlags);
	}
	else if (StrEqual(szInfo, "edit_immunity"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotGroupMenu(iClient, BSAdminMenuAdminSyncAction_GroupEditImmunity);
	}
	else if (StrEqual(szInfo, "delete"))
	{
		BSAdminMenu_ShowAdminSyncSnapshotGroupDeleteMenu(iClient);
	}

	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotGroupMenu(int iClient, BSAdminMenuAdminSyncAction eAction)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotGroupHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T",
		eAction == BSAdminMenuAdminSyncAction_GroupEditFlags ? "BSAdminSyncMenuSelectGroupEditFlags" : "BSAdminSyncMenuSelectGroupEditImmunity",
		iClient);
	hMenu.SetTitle(szTitle);

	g_eBSAdminSyncState[iClient].m_eAction = eAction;

	if (!BSAdminMenu_PopulateAdminSyncGroupMenu(hMenu))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoGroupsAvailable");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static bool BSAdminMenu_PopulateAdminSyncGroupMenu(Menu hMenu)
{
	int iCount = iBSASGetGroupCount();
	bool bAdded = false;

	for (int iIndex = 0; iIndex < iCount; iIndex++)
	{
		char szName[128];
		if (!bBSASGetGroupByIndex(iIndex, szName, sizeof(szName)))
		{
			continue;
		}

		hMenu.AddItem(szName, szName);
		bAdded = true;
	}

	return bAdded;
}

public int BSAdminMenu_AdminSyncSnapshotGroupHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	hMenu.GetItem(iItem, g_eBSAdminSyncState[iClient].m_szGroupName, sizeof(g_eBSAdminSyncState[].m_szGroupName));

	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_GroupEditFlags)
	{
		g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_GroupEditFlags;
		CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterNewGroupFlags");
	}
	else
	{
		g_eBSAdminSyncState[iClient].m_ePrompt = BSAdminMenuAdminSyncPrompt_GroupEditImmunity;
		CReplyToCommand(iClient, "%t", "BSAdminSyncPromptEnterNewGroupImmunity");
	}

	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotGroupDeleteMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotGroupDeleteHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", "BSAdminSyncMenuSelectGroupDelete", iClient);
	hMenu.SetTitle(szTitle);

	if (!BSAdminMenu_PopulateAdminSyncGroupMenu(hMenu))
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", "BSAdminSyncNoGroupsAvailable");
		return;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int BSAdminMenu_AdminSyncSnapshotGroupDeleteHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_End)
	{
		delete hMenu;
		return 0;
	}

	if (eAction != MenuAction_Select)
	{
		return 0;
	}

	char szGroupName[128];
	hMenu.GetItem(iItem, szGroupName, sizeof(szGroupName));
	bBSASDeleteGroup(szGroupName);
	return 0;
}
