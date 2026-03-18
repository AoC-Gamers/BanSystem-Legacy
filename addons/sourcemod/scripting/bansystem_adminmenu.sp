#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <bansystem_access>
#include <bansystem_comm>
#include <bansystem_sprays>
#include <bansystem_adminsync>
#define REQUIRE_PLUGIN

#define BANSYSTEM_ADMINMENU_VERSION "1.1.0"
#define BANSYSTEM_ADMINMENU_MAX_REASON_LENGTH 256
#define BANSYSTEM_ADMINMENU_MAX_PROMPT_LENGTH 256
#define BANSYSTEM_ADMINMENU_PREVIEW_LENGTH 64
#define BANSYSTEM_ADMINMENU_MAX_TITLE_LENGTH 768

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
	BSAdminMenuStage_DurationValue,
	BSAdminMenuStage_Reason,
	BSAdminMenuStage_Context
}

enum BSAdminMenuDurationUnit
{
	BSAdminMenuDuration_None = 0,
	BSAdminMenuDuration_Minute,
	BSAdminMenuDuration_Hour,
	BSAdminMenuDuration_Day,
	BSAdminMenuDuration_Week,
	BSAdminMenuDuration_Month,
	BSAdminMenuDuration_Permanent
}

enum struct BSAdminMenuPanelState
{
	BSAdminMenuPanelType m_eType;
	BSAdminMenuPanelStage m_eStage;
	BSAdminMenuDurationUnit m_eDurationUnit;
	int m_iTargetUserId;
	int m_iAccountId;
	int m_iDurationValue;
	int m_iLength;
	eBSCommType m_eCommType;
	char m_szTargetName[MAX_NAME_LENGTH];
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
			switch (g_eBSAdminPanelState[iClient].m_eStage)
			{
				case BSAdminMenuStage_DurationValue:
				{
					BSAdminMenu_ReplyDurationValueInvalid(iClient);
					BSAdminMenu_ShowInputPromptPanel(iClient);
				}

				case BSAdminMenuStage_Reason:
				{
					BSAdminMenu_ReplyReasonCannotBeEmpty(iClient);
					BSAdminMenu_ShowInputPromptPanel(iClient);
				}

				case BSAdminMenuStage_Context:
				{
					BSAdminMenu_ReplyContextPrompt(iClient);
					BSAdminMenu_ShowInputPromptPanel(iClient);
				}
			}
		}
		else
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAdminSyncEmptyInput");
		}
		return Plugin_Handled;
	}

	if (g_eBSAdminPanelState[iClient].m_eStage != BSAdminMenuStage_None)
	{
		switch (g_eBSAdminPanelState[iClient].m_eStage)
		{
				case BSAdminMenuStage_DurationValue:
				{
					if (!BSAdminMenu_TrySetDurationValueFromText(iClient, szText))
					{
						BSAdminMenu_ReplyDurationValueInvalid(iClient);
						BSAdminMenu_ShowInputPromptPanel(iClient);
						return Plugin_Handled;
					}

					g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_Reason;
					BSAdminMenu_ReplyReasonPrompt(iClient);
					BSAdminMenu_ShowInputPromptPanel(iClient);
					return Plugin_Handled;
				}

			case BSAdminMenuStage_Reason:
			{
				strcopy(g_eBSAdminPanelState[iClient].m_szReason, sizeof(g_eBSAdminPanelState[].m_szReason), szText);
				g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_Context;
				BSAdminMenu_ReplyContextPrompt(iClient);
					BSAdminMenu_ShowInputPromptPanel(iClient);
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

				BSAdminMenu_ReplyPanelContextCaptured(iClient, szContext);

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
	g_eBSAdminPanelState[iClient].m_eDurationUnit = BSAdminMenuDuration_None;
	g_eBSAdminPanelState[iClient].m_iTargetUserId = 0;
	g_eBSAdminPanelState[iClient].m_iAccountId = 0;
	g_eBSAdminPanelState[iClient].m_iDurationValue = 0;
	g_eBSAdminPanelState[iClient].m_iLength = 0;
	g_eBSAdminPanelState[iClient].m_eCommType = kBSCommType_None;
	g_eBSAdminPanelState[iClient].m_szTargetName[0] = '\0';
	g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
}

static void BSAdminMenu_ResetPanelTargetProgress(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
	{
		return;
	}

	g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
	g_eBSAdminPanelState[iClient].m_eDurationUnit = BSAdminMenuDuration_None;
	g_eBSAdminPanelState[iClient].m_iTargetUserId = 0;
	g_eBSAdminPanelState[iClient].m_iAccountId = 0;
	g_eBSAdminPanelState[iClient].m_iDurationValue = 0;
	g_eBSAdminPanelState[iClient].m_iLength = 0;
	g_eBSAdminPanelState[iClient].m_szTargetName[0] = '\0';
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

static bool BSAdminMenu_TryGetMenuAccountId(Menu hMenu, int iItem, int &iAccountId)
{
	char szInfo[16];
	hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
	iAccountId = StringToInt(szInfo);
	return (iAccountId > 0);
}

static void BSAdminMenu_BeginAdminSyncPrompt(int iClient, BSAdminMenuAdminSyncPromptState ePrompt, const char[] szPhrase)
{
	g_eBSAdminSyncState[iClient].m_ePrompt = ePrompt;
	CReplyToCommand(iClient, "%t", szPhrase);
}

static void BSAdminMenu_BeginAdminSyncAction(int iClient, BSAdminMenuAdminSyncAction eAction)
{
	g_eBSAdminSyncState[iClient].m_eAction = eAction;
}

static bool BSAdminMenu_TryDisplayPopulatedMenu(int iClient, Menu hMenu, bool bPopulated, const char[] szEmptyPhrase)
{
	if (!bPopulated)
	{
		delete hMenu;
		CReplyToCommand(iClient, "%t", szEmptyPhrase);
		return false;
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
	return true;
}

static bool BSAdminMenu_TryGetAdminMainAction(const char[] szInfo, BSAdminMenuAdminSyncAction &eAction)
{
	if (StrEqual(szInfo, "edit_flags"))
	{
		eAction = BSAdminMenuAdminSyncAction_AdminEditFlags;
		return true;
	}

	if (StrEqual(szInfo, "edit_immunity"))
	{
		eAction = BSAdminMenuAdminSyncAction_AdminEditImmunity;
		return true;
	}

	if (StrEqual(szInfo, "add_group"))
	{
		eAction = BSAdminMenuAdminSyncAction_AdminAssignGroup;
		return true;
	}

	if (StrEqual(szInfo, "remove_group"))
	{
		eAction = BSAdminMenuAdminSyncAction_AdminRemoveGroup;
		return true;
	}

	if (StrEqual(szInfo, "delete"))
	{
		eAction = BSAdminMenuAdminSyncAction_AdminDelete;
		return true;
	}

	eAction = BSAdminMenuAdminSyncAction_None;
	return false;
}

static bool BSAdminMenu_TryGetGroupMainAction(const char[] szInfo, BSAdminMenuAdminSyncAction &eAction)
{
	if (StrEqual(szInfo, "edit_flags"))
	{
		eAction = BSAdminMenuAdminSyncAction_GroupEditFlags;
		return true;
	}

	if (StrEqual(szInfo, "edit_immunity"))
	{
		eAction = BSAdminMenuAdminSyncAction_GroupEditImmunity;
		return true;
	}

	if (StrEqual(szInfo, "delete"))
	{
		eAction = BSAdminMenuAdminSyncAction_GroupDelete;
		return true;
	}

	eAction = BSAdminMenuAdminSyncAction_None;
	return false;
}

static void BSAdminMenu_BeginAdminSyncAdminEditPrompt(int iClient)
{
	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminEditFlags)
	{
		BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_AdminEditFlags, "BSAdminSyncPromptEnterNewAdminFlags");
		return;
	}

	BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_AdminEditImmunity, "BSAdminSyncPromptEnterNewAdminImmunity");
}

static void BSAdminMenu_BeginAdminSyncGroupEditPrompt(int iClient)
{
	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_GroupEditFlags)
	{
		BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_GroupEditFlags, "BSAdminSyncPromptEnterNewGroupFlags");
		return;
	}

	BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_GroupEditImmunity, "BSAdminSyncPromptEnterNewGroupImmunity");
}

static void BSAdminMenu_ApplyAdminSyncGroupMembershipAction(int iClient, const char[] szGroupName)
{
	if (g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminAssignGroup)
	{
		bBSASAddAdminGroup(g_eBSAdminSyncState[iClient].m_iAccountId, szGroupName);
		return;
	}

	bBSASRemoveAdminGroup(g_eBSAdminSyncState[iClient].m_iAccountId, szGroupName);
}

static bool BSAdminMenu_TryGetCommTypeFromMenuInfo(const char[] szInfo, eBSCommType &eCommType)
{
	if (StrEqual(szInfo, "mic", false))
	{
		eCommType = kBSCommType_Mic;
		return true;
	}

	if (StrEqual(szInfo, "chat", false))
	{
		eCommType = kBSCommType_Chat;
		return true;
	}

	if (StrEqual(szInfo, "all", false))
	{
		eCommType = kBSCommType_All;
		return true;
	}

	eCommType = kBSCommType_None;
	return false;
}

static BSAdminMenuDurationUnit BSAdminMenu_GetDurationUnitFromMenuInfo(const char[] szInfo)
{
	if (StrEqual(szInfo, "minute", false))
		return BSAdminMenuDuration_Minute;
	if (StrEqual(szInfo, "hour", false))
		return BSAdminMenuDuration_Hour;
	if (StrEqual(szInfo, "day", false))
		return BSAdminMenuDuration_Day;
	if (StrEqual(szInfo, "week", false))
		return BSAdminMenuDuration_Week;
	if (StrEqual(szInfo, "month", false))
		return BSAdminMenuDuration_Month;

	return BSAdminMenuDuration_Permanent;
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
	char szTitle[BANSYSTEM_ADMINMENU_MAX_TITLE_LENGTH];
	BSAdminMenu_BuildSelectionTitle(iClient, szTitle, sizeof(szTitle), "Seleccione objetivo");
	hMenu.SetTitle(szTitle);

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
	char szTitle[BANSYSTEM_ADMINMENU_MAX_TITLE_LENGTH];
	BSAdminMenu_BuildSelectionTitle(iClient, szTitle, sizeof(szTitle), "Seleccione tipo de comm");
	hMenu.SetTitle(szTitle);
	hMenu.ExitBackButton = true;
	hMenu.AddItem("mic", "Mic");
	hMenu.AddItem("chat", "Chat");
	hMenu.AddItem("all", "All");
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static void BSAdminMenu_ShowDurationUnitPanel(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_DurationPanelHandler);
	char szTitle[BANSYSTEM_ADMINMENU_MAX_TITLE_LENGTH];
	BSAdminMenu_BuildSelectionTitle(iClient, szTitle, sizeof(szTitle), "Seleccione formato de tiempo");
	hMenu.SetTitle(szTitle);

	hMenu.ExitBackButton = true;
	hMenu.AddItem("minute", "Minuto(s)");
	hMenu.AddItem("hour", "Hora(s)");
	hMenu.AddItem("day", "Dia(s)");
	hMenu.AddItem("week", "Semana(s)");
	hMenu.AddItem("month", "Mes(es)");
	hMenu.AddItem("permanent", "Permanente");
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
			GetClientName(iTarget, g_eBSAdminPanelState[iParam1].m_szTargetName, sizeof(g_eBSAdminPanelState[].m_szTargetName));
			if (g_eBSAdminPanelState[iParam1].m_iAccountId <= 0)
			{
				BSAdminMenu_ReplyTargetUnavailable(iParam1);
				g_eBSAdminPanelState[iParam1].m_iTargetUserId = 0;
				g_eBSAdminPanelState[iParam1].m_szTargetName[0] = '\0';
				BSAdminMenu_ShowTargetPanel(iParam1);
				return 0;
			}

			if (g_eBSAdminPanelState[iParam1].m_eType == BSAdminMenuPanel_Comm)
			{
				BSAdminMenu_ShowCommTypePanel(iParam1);
			}
			else
			{
				BSAdminMenu_ShowDurationUnitPanel(iParam1);
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

			eBSCommType eCommType;
			if (!BSAdminMenu_TryGetCommTypeFromMenuInfo(szInfo, eCommType))
			{
				CReplyToCommand(iParam1, "%t", "BSCommInvalidTypeShort");
				BSAdminMenu_ShowCommTypePanel(iParam1);
				return 0;
			}

			g_eBSAdminPanelState[iParam1].m_eCommType = eCommType;

			BSAdminMenu_ShowDurationUnitPanel(iParam1);
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

			g_eBSAdminPanelState[iParam1].m_eDurationUnit = BSAdminMenu_GetDurationUnitFromMenuInfo(szInfo);

			g_eBSAdminPanelState[iParam1].m_iDurationValue = 0;
			g_eBSAdminPanelState[iParam1].m_iLength = 0;

			if (g_eBSAdminPanelState[iParam1].m_eDurationUnit == BSAdminMenuDuration_Permanent)
			{
				g_eBSAdminPanelState[iParam1].m_eStage = BSAdminMenuStage_Reason;
				BSAdminMenu_ReplyReasonPrompt(iParam1);
			}
			else
			{
				g_eBSAdminPanelState[iParam1].m_eStage = BSAdminMenuStage_DurationValue;
				BSAdminMenu_ReplyDurationValuePrompt(iParam1);
			}

			BSAdminMenu_ShowInputPromptPanel(iParam1);
		}
	}

	return 0;
}

public int BSAdminMenu_InputPromptPanelHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
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

			if (StrEqual(szInfo, "back", false))
			{
				BSAdminMenu_HandlePromptBack(iParam1);
			}
			else if (StrEqual(szInfo, "cancel", false))
			{
				BSAdminMenuPanelType eType = g_eBSAdminPanelState[iParam1].m_eType;
				BSAdminMenu_ResetPanelState(iParam1);
				BSAdminMenu_ReplyPanelAborted(iParam1, eType);
			}
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
	ReplySource eOldSource = SetCmdReplySource(BSGetClientPreferredReplySource(iClient));
	bool bResult = false;

	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			bResult = BSAccess_AddBanByAccountId(iClient, iAccountId, iLength, szReason, szContext);
		}

		case BSAdminMenuPanel_Comm:
		{
			bResult = BSComm_AddBanByAccountId(iClient, iAccountId, g_eBSAdminPanelState[iClient].m_eCommType, iLength, szReason, szContext);
		}

		case BSAdminMenuPanel_Sprays:
		{
			bResult = BSSprays_AddBanByAccountId(iClient, iAccountId, iLength, szReason, szContext);
		}
	}

	SetCmdReplySource(eOldSource);
	return bResult;
}

static bool BSAdminMenu_ValidatePanelTarget(int iClient)
{
	int iTarget = GetClientOfUserId(g_eBSAdminPanelState[iClient].m_iTargetUserId);
	if (iTarget <= 0 || !IsClientInGame(iTarget) || IsFakeClient(iTarget) || !CanUserTarget(iClient, iTarget))
	{
		BSAdminMenu_ReplyTargetUnavailable(iClient);
		BSAdminMenu_ResetPanelTargetProgress(iClient);
		BSAdminMenu_ShowTargetPanel(iClient);
		return false;
	}

	int iAccountId = GetSteamAccountID(iTarget);
	if (iAccountId <= 0 || iAccountId != g_eBSAdminPanelState[iClient].m_iAccountId)
	{
		BSAdminMenu_ReplyTargetUnavailable(iClient);
		BSAdminMenu_ResetPanelTargetProgress(iClient);
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
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessNoTargets");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommNoTargets");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysNoTargets");
		}
	}
}

static void BSAdminMenu_ReplyTargetUnavailable(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessTargetUnavailable");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommTargetUnavailable");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysTargetUnavailable");
		}
	}
}

static void BSAdminMenu_ReplyReasonCannotBeEmpty(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessReasonCannotBeEmpty");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommReasonCannotBeEmpty");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysReasonCannotBeEmpty");
		}
	}
}

static void BSAdminMenu_ReplyReasonPrompt(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessReasonPrompt");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommReasonPrompt");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysReasonPrompt");
		}
	}
}

static void BSAdminMenu_ReplyContextPrompt(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessContextPrompt");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommContextPrompt");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysContextPrompt");
		}
	}
}

static void BSAdminMenu_ReplyDurationValuePrompt(int iClient)
{
	char szUnit[32];
	BSAdminMenu_GetDurationUnitLabel(g_eBSAdminPanelState[iClient].m_eDurationUnit, szUnit, sizeof(szUnit));
	BSCReplyToCommandPreferred(iClient, "%t", "BSAdminMenuDurationPrompt", szUnit);
}

static void BSAdminMenu_ReplyDurationValueInvalid(int iClient)
{
	BSCReplyToCommandPreferred(iClient, "%t", "BSAdminMenuDurationInvalid");
}

static void BSAdminMenu_ReplyNoPanelFlow(int iClient, BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessNoPanelFlow");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommNoPanelFlow");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysNoPanelFlow");
		}
	}
}

static void BSAdminMenu_ReplyPanelAborted(int iClient, BSAdminMenuPanelType eType)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessPanelAborted");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommPanelAborted");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysPanelAborted");
		}
	}
}

static void BSAdminMenu_ReplyDatabaseNotReady(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAccessDatabaseNotReady");
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSCommDatabaseNotReady");
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSSpraysDatabaseNotReady");
		}
	}
}

static void BSAdminMenu_ReplyPanelContextCaptured(int iClient, const char[] szContext)
{
	if (szContext[0] == '\0')
	{
		return;
	}

	char szPreview[BANSYSTEM_ADMINMENU_PREVIEW_LENGTH + 4];
	BSAdminMenu_FormatPreview(szContext, szPreview, sizeof(szPreview));

	switch (g_eBSAdminPanelState[iClient].m_eType)
	{
		case BSAdminMenuPanel_Access:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAdminMenuAccessContextCaptured", szPreview);
		}

		case BSAdminMenuPanel_Comm:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAdminMenuCommContextCaptured", szPreview);
		}

		case BSAdminMenuPanel_Sprays:
		{
			BSCReplyToCommandPreferred(iClient, "%t", "BSAdminMenuSpraysContextCaptured", szPreview);
		}
	}
}

static void BSAdminMenu_ShowInputPromptPanel(int iClient)
{
	if (!BSAdminMenu_IsUsableClient(iClient) || g_eBSAdminPanelState[iClient].m_eStage == BSAdminMenuStage_None)
	{
		return;
	}

	Menu hMenu = new Menu(BSAdminMenu_InputPromptPanelHandler);
	char szTitle[BANSYSTEM_ADMINMENU_MAX_TITLE_LENGTH];
	char szText[64];
	BSAdminMenu_BuildPromptPanelTitle(iClient, szTitle, sizeof(szTitle));
	hMenu.SetTitle(szTitle);
	hMenu.AddItem("hint", "Escriba en el chat para continuar.", ITEMDRAW_DISABLED);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminMenuBack", iClient);
	hMenu.AddItem("back", szText);
	FormatEx(szText, sizeof(szText), "%T", "BSAdminMenuCancel", iClient);
	hMenu.AddItem("cancel", szText);
	hMenu.ExitButton = false;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

static void BSAdminMenu_HandlePromptBack(int iClient)
{
	switch (g_eBSAdminPanelState[iClient].m_eStage)
	{
		case BSAdminMenuStage_DurationValue:
		{
			g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
			g_eBSAdminPanelState[iClient].m_eDurationUnit = BSAdminMenuDuration_None;
			BSAdminMenu_ShowDurationUnitPanel(iClient);
		}

		case BSAdminMenuStage_Reason:
		{
			g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_None;
			g_eBSAdminPanelState[iClient].m_eDurationUnit = BSAdminMenuDuration_None;
			g_eBSAdminPanelState[iClient].m_iDurationValue = 0;
			g_eBSAdminPanelState[iClient].m_iLength = 0;
			g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
			BSAdminMenu_ShowDurationUnitPanel(iClient);
		}

		case BSAdminMenuStage_Context:
		{
			g_eBSAdminPanelState[iClient].m_eStage = BSAdminMenuStage_Reason;
			g_eBSAdminPanelState[iClient].m_szReason[0] = '\0';
			BSAdminMenu_ReplyReasonPrompt(iClient);
			BSAdminMenu_ShowInputPromptPanel(iClient);
		}
	}
}

static bool BSAdminMenu_TrySetDurationValueFromText(int iClient, const char[] szText)
{
	int iValue = StringToInt(szText);
	int iMultiplier = BSAdminMenu_GetDurationUnitMultiplier(g_eBSAdminPanelState[iClient].m_eDurationUnit);
	if (iValue <= 0 || iMultiplier <= 0)
	{
		return false;
	}

	if (iValue > (2147483647 / iMultiplier))
	{
		return false;
	}

	g_eBSAdminPanelState[iClient].m_iDurationValue = iValue;
	g_eBSAdminPanelState[iClient].m_iLength = iValue * iMultiplier;
	return true;
}

static int BSAdminMenu_GetDurationUnitMultiplier(BSAdminMenuDurationUnit eUnit)
{
	switch (eUnit)
	{
		case BSAdminMenuDuration_Minute: return 1;
		case BSAdminMenuDuration_Hour: return 60;
		case BSAdminMenuDuration_Day: return 1440;
		case BSAdminMenuDuration_Week: return 10080;
		case BSAdminMenuDuration_Month: return 43200;
	}

	return 0;
}

static void BSAdminMenu_GetPanelTypeTitle(BSAdminMenuPanelType eType, char[] szBuffer, int iMaxLength)
{
	switch (eType)
	{
		case BSAdminMenuPanel_Access: strcopy(szBuffer, iMaxLength, "BanSystem Access");
		case BSAdminMenuPanel_Comm: strcopy(szBuffer, iMaxLength, "BanSystem Comm");
		case BSAdminMenuPanel_Sprays: strcopy(szBuffer, iMaxLength, "BanSystem Sprays");
		default: strcopy(szBuffer, iMaxLength, "BanSystem");
	}
}

static void BSAdminMenu_GetCommTypeLabel(eBSCommType eType, char[] szBuffer, int iMaxLength)
{
	switch (eType)
	{
		case kBSCommType_Mic: strcopy(szBuffer, iMaxLength, "Mic");
		case kBSCommType_Chat: strcopy(szBuffer, iMaxLength, "Chat");
		case kBSCommType_All: strcopy(szBuffer, iMaxLength, "All");
		default: strcopy(szBuffer, iMaxLength, "Pendiente");
	}
}

static void BSAdminMenu_GetDurationUnitLabel(BSAdminMenuDurationUnit eUnit, char[] szBuffer, int iMaxLength)
{
	switch (eUnit)
	{
		case BSAdminMenuDuration_Minute: strcopy(szBuffer, iMaxLength, "minutos");
		case BSAdminMenuDuration_Hour: strcopy(szBuffer, iMaxLength, "horas");
		case BSAdminMenuDuration_Day: strcopy(szBuffer, iMaxLength, "dias");
		case BSAdminMenuDuration_Week: strcopy(szBuffer, iMaxLength, "semanas");
		case BSAdminMenuDuration_Month: strcopy(szBuffer, iMaxLength, "meses");
		case BSAdminMenuDuration_Permanent: strcopy(szBuffer, iMaxLength, "permanente");
		default: strcopy(szBuffer, iMaxLength, "pendiente");
	}
}

static void BSAdminMenu_FormatDurationSummary(int iClient, char[] szBuffer, int iMaxLength)
{
	if (g_eBSAdminPanelState[iClient].m_eDurationUnit == BSAdminMenuDuration_Permanent)
	{
		strcopy(szBuffer, iMaxLength, "Permanente");
		return;
	}

	if (g_eBSAdminPanelState[iClient].m_iDurationValue > 0)
	{
		char szUnit[32];
		BSAdminMenu_GetDurationUnitLabel(g_eBSAdminPanelState[iClient].m_eDurationUnit, szUnit, sizeof(szUnit));
		FormatEx(szBuffer, iMaxLength, "%d %s", g_eBSAdminPanelState[iClient].m_iDurationValue, szUnit);
		return;
	}

	if (g_eBSAdminPanelState[iClient].m_eDurationUnit != BSAdminMenuDuration_None)
	{
		char szUnit[32];
		BSAdminMenu_GetDurationUnitLabel(g_eBSAdminPanelState[iClient].m_eDurationUnit, szUnit, sizeof(szUnit));
		FormatEx(szBuffer, iMaxLength, "Esperando cantidad de %s", szUnit);
		return;
	}

	strcopy(szBuffer, iMaxLength, "Pendiente");
}

static void BSAdminMenu_BuildSelectionTitle(int iClient, char[] szBuffer, int iMaxLength, const char[] szStep)
{
	char szModule[64];
	BSAdminMenu_GetPanelTypeTitle(g_eBSAdminPanelState[iClient].m_eType, szModule, sizeof(szModule));
	FormatEx(szBuffer, iMaxLength, "%s\n%s", szModule, szStep);

	if (g_eBSAdminPanelState[iClient].m_szTargetName[0] != '\0')
	{
		StrCat(szBuffer, iMaxLength, "\nObjetivo: ");
		StrCat(szBuffer, iMaxLength, g_eBSAdminPanelState[iClient].m_szTargetName);
	}

	if (g_eBSAdminPanelState[iClient].m_eType == BSAdminMenuPanel_Comm)
	{
		char szCommType[32];
		BSAdminMenu_GetCommTypeLabel(g_eBSAdminPanelState[iClient].m_eCommType, szCommType, sizeof(szCommType));
		StrCat(szBuffer, iMaxLength, "\nComm: ");
		StrCat(szBuffer, iMaxLength, szCommType);
	}

	if (g_eBSAdminPanelState[iClient].m_eDurationUnit != BSAdminMenuDuration_None)
	{
		char szDuration[64];
		BSAdminMenu_FormatDurationSummary(iClient, szDuration, sizeof(szDuration));
		StrCat(szBuffer, iMaxLength, "\nDuracion: ");
		StrCat(szBuffer, iMaxLength, szDuration);
	}
}

static void BSAdminMenu_BuildPromptPanelTitle(int iClient, char[] szBuffer, int iMaxLength)
{
	char szPrompt[192];
	char szModule[64];
	char szDuration[64];
	char szReasonPreview[BANSYSTEM_ADMINMENU_PREVIEW_LENGTH + 4];
	BSAdminMenu_GetPanelTypeTitle(g_eBSAdminPanelState[iClient].m_eType, szModule, sizeof(szModule));
	BSAdminMenu_FormatDurationSummary(iClient, szDuration, sizeof(szDuration));
	BSAdminMenu_FormatPreview(g_eBSAdminPanelState[iClient].m_szReason, szReasonPreview, sizeof(szReasonPreview));

	switch (g_eBSAdminPanelState[iClient].m_eStage)
	{
		case BSAdminMenuStage_DurationValue:
		{
			char szUnit[32];
			BSAdminMenu_GetDurationUnitLabel(g_eBSAdminPanelState[iClient].m_eDurationUnit, szUnit, sizeof(szUnit));
			FormatEx(szPrompt, sizeof(szPrompt), "Escriba la cantidad de %s en el chat.", szUnit);
		}

		case BSAdminMenuStage_Reason:
		{
			strcopy(szPrompt, sizeof(szPrompt), "Escriba la razon en el chat.");
		}

		case BSAdminMenuStage_Context:
		{
			strcopy(szPrompt, sizeof(szPrompt), "Escriba el contexto en el chat o '-' para omitirlo.");
		}

		default:
		{
			strcopy(szPrompt, sizeof(szPrompt), "Esperando entrada.");
		}
	}

	FormatEx(szBuffer, iMaxLength, "%s\nObjetivo: %s", szModule, g_eBSAdminPanelState[iClient].m_szTargetName[0] != '\0' ? g_eBSAdminPanelState[iClient].m_szTargetName : "Pendiente");

	if (g_eBSAdminPanelState[iClient].m_eType == BSAdminMenuPanel_Comm)
	{
		char szCommType[32];
		BSAdminMenu_GetCommTypeLabel(g_eBSAdminPanelState[iClient].m_eCommType, szCommType, sizeof(szCommType));
		StrCat(szBuffer, iMaxLength, "\nComm: ");
		StrCat(szBuffer, iMaxLength, szCommType);
	}

	StrCat(szBuffer, iMaxLength, "\nDuracion: ");
	StrCat(szBuffer, iMaxLength, szDuration);

	if (g_eBSAdminPanelState[iClient].m_szReason[0] != '\0')
	{
		StrCat(szBuffer, iMaxLength, "\nRazon: ");
		StrCat(szBuffer, iMaxLength, szReasonPreview);
	}

	StrCat(szBuffer, iMaxLength, "\n\n");
	StrCat(szBuffer, iMaxLength, szPrompt);
	StrCat(szBuffer, iMaxLength, "\n\nSeleccione una opcion:");
}

static void BSAdminMenu_FormatPreview(const char[] szInput, char[] szOutput, int iOutputLen)
{
	if (iOutputLen <= 0)
	{
		return;
	}

	int iInputLen = strlen(szInput);
	if (iInputLen <= BANSYSTEM_ADMINMENU_PREVIEW_LENGTH)
	{
		strcopy(szOutput, iOutputLen, szInput);
		return;
	}

	strcopy(szOutput, iOutputLen, szInput);
	szOutput[BANSYSTEM_ADMINMENU_PREVIEW_LENGTH] = '\0';
	StrCat(szOutput, iOutputLen, "...");
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
			BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_AdminAddImmunity, "BSAdminSyncPromptEnterAdminImmunity");
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
			BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_GroupAddFlags, "BSAdminSyncPromptEnterGroupFlags");
		}

		case BSAdminMenuAdminSyncPrompt_GroupAddFlags:
		{
			strcopy(g_eBSAdminSyncState[iClient].m_szFlags, sizeof(g_eBSAdminSyncState[].m_szFlags), szText);
			BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_GroupAddImmunity, "BSAdminSyncPromptEnterGroupImmunity");
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
		return 0;
	}

	BSAdminMenuAdminSyncAction eMenuAction;
	if (!BSAdminMenu_TryGetAdminMainAction(szInfo, eMenuAction))
	{
		return 0;
	}

	switch (eMenuAction)
	{
		case BSAdminMenuAdminSyncAction_AdminEditFlags, BSAdminMenuAdminSyncAction_AdminEditImmunity:
		{
			BSAdminMenu_ShowAdminSyncSnapshotAdminMenu(iClient, eMenuAction);
		}

		case BSAdminMenuAdminSyncAction_AdminAssignGroup:
		{
			BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(iClient, true);
		}

		case BSAdminMenuAdminSyncAction_AdminRemoveGroup:
		{
			BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(iClient, false);
		}

		case BSAdminMenuAdminSyncAction_AdminDelete:
		{
			BSAdminMenu_ShowAdminSyncSnapshotAdminDeleteMenu(iClient);
		}
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

	BSAdminMenu_BeginAdminSyncAction(iClient, eAction);
	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu), "BSAdminSyncNoAdminsAvailable");
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

	if (!BSAdminMenu_TryGetMenuAccountId(hMenu, iItem, g_eBSAdminSyncState[iClient].m_iAccountId))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncTargetUnavailable");
		return 0;
	}

	BSAdminMenu_BeginAdminSyncAdminEditPrompt(iClient);

	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotAdminDeleteMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotAdminDeleteHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", "BSAdminSyncMenuSelectAdminDelete", iClient);
	hMenu.SetTitle(szTitle);

	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu), "BSAdminSyncNoAdminsAvailable");
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

	int iAccountId;
	if (!BSAdminMenu_TryGetMenuAccountId(hMenu, iItem, iAccountId))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncTargetUnavailable");
		return 0;
	}

	bBSASDeleteAdmin(iAccountId);
	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotAdminGroupAdminMenu(int iClient, bool bAssign)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncAdminGroupAdminHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", bAssign ? "BSAdminSyncMenuSelectAdminAssignGroup" : "BSAdminSyncMenuSelectAdminRemoveGroup", iClient);
	hMenu.SetTitle(szTitle);

	BSAdminMenu_BeginAdminSyncAction(iClient, bAssign ? BSAdminMenuAdminSyncAction_AdminAssignGroup : BSAdminMenuAdminSyncAction_AdminRemoveGroup);
	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncAdminMenu(hMenu), "BSAdminSyncNoAdminsAvailable");
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

	if (!BSAdminMenu_TryGetMenuAccountId(hMenu, iItem, g_eBSAdminSyncState[iClient].m_iAccountId))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncTargetUnavailable");
		return 0;
	}
	BSAdminMenu_ShowAdminSyncSnapshotGroupMembershipMenu(iClient, g_eBSAdminSyncState[iClient].m_eAction == BSAdminMenuAdminSyncAction_AdminAssignGroup);
	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotGroupMembershipMenu(int iClient, bool bAssign)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncGroupMembershipHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", bAssign ? "BSAdminSyncMenuSelectGroupAssign" : "BSAdminSyncMenuSelectGroupRemove", iClient);
	hMenu.SetTitle(szTitle);

	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncGroupMenuFiltered(hMenu, g_eBSAdminSyncState[iClient].m_iAccountId, bAssign), bAssign ? "BSAdminSyncNoAssignableGroups" : "BSAdminSyncNoRemovableGroups");
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

	BSAdminMenu_ApplyAdminSyncGroupMembershipAction(iClient, szGroupName);

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
		BSAdminMenu_BeginAdminSyncPrompt(iClient, BSAdminMenuAdminSyncPrompt_GroupAddName, "BSAdminSyncPromptEnterNewGroupName");
		return 0;
	}

	BSAdminMenuAdminSyncAction eMenuAction;
	if (!BSAdminMenu_TryGetGroupMainAction(szInfo, eMenuAction))
	{
		return 0;
	}

	switch (eMenuAction)
	{
		case BSAdminMenuAdminSyncAction_GroupEditFlags, BSAdminMenuAdminSyncAction_GroupEditImmunity:
		{
			BSAdminMenu_ShowAdminSyncSnapshotGroupMenu(iClient, eMenuAction);
		}

		case BSAdminMenuAdminSyncAction_GroupDelete:
		{
			BSAdminMenu_ShowAdminSyncSnapshotGroupDeleteMenu(iClient);
		}
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

	BSAdminMenu_BeginAdminSyncAction(iClient, eAction);
	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncGroupMenu(hMenu), "BSAdminSyncNoGroupsAvailable");
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

	BSAdminMenu_BeginAdminSyncGroupEditPrompt(iClient);

	return 0;
}

static void BSAdminMenu_ShowAdminSyncSnapshotGroupDeleteMenu(int iClient)
{
	Menu hMenu = new Menu(BSAdminMenu_AdminSyncSnapshotGroupDeleteHandler);
	char szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "%T", "BSAdminSyncMenuSelectGroupDelete", iClient);
	hMenu.SetTitle(szTitle);

	BSAdminMenu_TryDisplayPopulatedMenu(iClient, hMenu, BSAdminMenu_PopulateAdminSyncGroupMenu(hMenu), "BSAdminSyncNoGroupsAvailable");
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
