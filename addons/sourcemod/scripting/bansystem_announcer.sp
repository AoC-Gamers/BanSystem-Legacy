#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <bansystem_core>
#include <bansystem_access>
#define REQUIRE_PLUGIN

#define BANSYSTEM_ANNOUNCER_VERSION "0.1.0-dev"
#define BANSYSTEM_ANNOUNCER_DEBUG_LOG "logs/bansystem/BanSystem_Announcer.log"

enum eBSAnnouncerDebugMask
{
	kBSAnnouncerDebug_None = 0,
	kBSAnnouncerDebug_General = 1,
	kBSAnnouncerDebug_Timer = 2,
	kBSAnnouncerDebug_Announce = 4,
	kBSAnnouncerDebug_API = 8
}

ConVar g_cvBSAnnouncerSelfJoin;
ConVar g_cvBSAnnouncerPublicJoin;
ConVar g_cvBSAnnouncerPublicAccessDenied;
ConVar g_cvBSAnnouncerDebugMask;
ConVar g_cvBSLogMode;

char g_szBSAnnouncerLogPath[PLATFORM_MAX_PATH];

bool g_bBSAnnouncerHasCoreLibrary;
bool g_bBSAnnouncerJoinAnnouncementShown[MAXPLAYERS + 1];
bool g_bBSAnnouncerJoinAnnouncementPending[MAXPLAYERS + 1];
Handle g_hBSAnnouncerJoinTimer[MAXPLAYERS + 1];
int g_iBSAnnouncerJoinRetryCount[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "BanSystem Announcer",
	author = "lechuga",
	description = "Player-facing BanSystem status and sanction announcements.",
	version = BANSYSTEM_ANNOUNCER_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szBSAnnouncerLogPath, sizeof(g_szBSAnnouncerLogPath), BANSYSTEM_ANNOUNCER_DEBUG_LOG);
	LoadTranslations("bansystem_announcer.phrases");
	g_cvBSLogMode = BSEnsureLogModeConVar();
	g_cvBSAnnouncerSelfJoin = CreateConVar("sm_bs_announcer_join_self", "1", "Announce active BanSystem sanctions to the affected player when they join a team.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBSAnnouncerPublicJoin = CreateConVar("sm_bs_announcer_join_public", "0", "Announce active BanSystem sanctions to other players when a sanctioned player joins a team.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBSAnnouncerPublicAccessDenied = CreateConVar("sm_bs_announcer_access_denied_public", "1", "Announce to other players when BanSystem denies access to a player.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBSAnnouncerDebugMask = CreateConVar("sm_bs_announcer_debug_mask", "0", "Debug bitmask: 1=general, 2=timer, 4=announce, 8=api (all=15).", FCVAR_NONE, true, 0.0);
	g_bBSAnnouncerHasCoreLibrary = LibraryExists("bansystem_core");

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_announcer", BANSYSTEM_AUTOEXEC_FOLDER);

	RegConsoleCmd("sm_bs_status", Command_BSStatus, "Show your BanSystem sanction summary.");
	HookEvent("player_team", BSAnnouncer_OnPlayerTeam_Post, EventHookMode_Post);
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem Announcer]", "startup", "Plugin started. core=%d", g_bBSAnnouncerHasCoreLibrary ? 1 : 0);
	BSAnnouncer_Debug(kBSAnnouncerDebug_General, "Announcer started. core=%d", g_bBSAnnouncerHasCoreLibrary ? 1 : 0);
}
public void OnClientPutInServer(int iClient)
{
	BSAnnouncer_ResetClientState(iClient);
	BSAnnouncer_Debug(kBSAnnouncerDebug_General, "Client put in server: client=%d target_usable=%d viewer_usable=%d", iClient, BSAnnouncer_IsAnnounceTarget(iClient) ? 1 : 0, BSAnnouncer_CanReceiveAnnouncements(iClient) ? 1 : 0);
}

public void OnClientDisconnect(int iClient)
{
	BSAnnouncer_Debug(kBSAnnouncerDebug_General, "Client disconnect: client=%d", iClient);
	BSAnnouncer_ResetClientState(iClient);
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSAnnouncerHasCoreLibrary = true;
		BSAnnouncer_Debug(kBSAnnouncerDebug_API, "Library added: bansystem_core ready=%d", BSCore_IsAuthReady() ? 1 : 0);
		if (BSCore_IsAuthReady())
			BSAnnouncer_TryAnnounceAllEligibleClients();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "bansystem_core", false))
	{
		g_bBSAnnouncerHasCoreLibrary = false;
		BSAnnouncer_Debug(kBSAnnouncerDebug_API, "Library removed: bansystem_core");
	}
}

public void BSCore_OnAuthReadyChanged(bool bReady)
{
	BSAnnouncer_Debug(kBSAnnouncerDebug_API, "Core auth ready changed: ready=%d core_library=%d", bReady ? 1 : 0, g_bBSAnnouncerHasCoreLibrary ? 1 : 0);
	if (!bReady || !g_bBSAnnouncerHasCoreLibrary)
		return;

	BSAnnouncer_TryAnnounceAllEligibleClients();
}

public void BSAccess_OnClientDenied(int iClient, int iAccountId)
{
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Access denied forward: client=%d accountid=%d public_enabled=%d", iClient, iAccountId, (g_cvBSAnnouncerPublicAccessDenied != null && g_cvBSAnnouncerPublicAccessDenied.BoolValue) ? 1 : 0);
	if (g_cvBSAnnouncerPublicAccessDenied == null || !g_cvBSAnnouncerPublicAccessDenied.BoolValue)
		return;

	if (!BSAnnouncer_IsAnnounceTarget(iClient))
		return;

	char szSteam2[32];
	if (!GetClientAuthId(iClient, AuthId_Steam2, szSteam2, sizeof(szSteam2)) || szSteam2[0] == '\0')
		strcopy(szSteam2, sizeof(szSteam2), "UNKNOWN");

	char szDisplay[96];
	FormatEx(szDisplay, sizeof(szDisplay), "%N(%s)", iClient, szSteam2);

	for (int iViewer = 1; iViewer <= MaxClients; iViewer++)
	{
		if (iViewer == iClient || !BSAnnouncer_CanReceiveAnnouncements(iViewer) || !IsClientInGame(iViewer))
			continue;

		CPrintToChat(iViewer, "%t", "BSAnnouncerAccessDeniedPublic", szDisplay);
	}
}

public void BSAnnouncer_OnPlayerTeam_Post(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int iTeam = hEvent.GetInt("team");
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "player_team event: client=%d team=%d oldteam=%d dont_broadcast=%d target_usable=%d viewer_usable=%d", iClient, iTeam, hEvent.GetInt("oldteam"), bDontBroadcast ? 1 : 0, BSAnnouncer_IsAnnounceTarget(iClient) ? 1 : 0, BSAnnouncer_CanReceiveAnnouncements(iClient) ? 1 : 0);
	if (!BSAnnouncer_IsAnnounceTarget(iClient))
		return;

	if (iTeam <= 1)
		return;

	if (BSAnnouncer_TryAnnounceClient(iClient))
		return;

	g_bBSAnnouncerJoinAnnouncementPending[iClient] = true;
	g_iBSAnnouncerJoinRetryCount[iClient] = 0;
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Announcement pending after player_team: client=%d", iClient);
	BSAnnouncer_EnsureJoinTimer(iClient);
}

public Action Command_BSStatus(int iClient, int iArgs)
{
	ReplySource eReplySource = GetCmdReplySource();

	if (!BSAnnouncer_IsAnnounceTarget(iClient))
	{
		ReplyToCommand(iClient, "[BanSystem] This command is only available for connected players.");
		return Plugin_Handled;
	}

	if (!g_bBSAnnouncerHasCoreLibrary || !BSCore_IsAuthReady() || BSCore_IsClientAuthPending(iClient) || !BSCore_HasResolvedSummary(iClient))
	{
		BSAnnouncer_CReplyToCommandWithSource(iClient, eReplySource, "%t", "BSAnnouncerStatusPending");
		return Plugin_Handled;
	}

	char szSummary[192];
	if (!BSAnnouncer_BuildSummaryText(iClient, iClient, szSummary, sizeof(szSummary)))
	{
		BSAnnouncer_CReplyToCommandWithSource(iClient, eReplySource, "%t", "BSAnnouncerStatusNone");
		return Plugin_Handled;
	}

	BSAnnouncer_CReplyToCommandWithSource(iClient, eReplySource, "%t", "BSAnnouncerStatusSelf", szSummary);
	BSAnnouncer_PrintResolvedDetailsToConsole(iClient);
	BSAnnouncer_CReplyToCommandWithSource(iClient, eReplySource, "%t", "BSAnnouncerDetailPrinted");
	return Plugin_Handled;
}


stock void BSAnnouncer_ResetClientState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	BSAnnouncer_Debug(kBSAnnouncerDebug_General, "Reset client state: client=%d shown=%d pending=%d retries=%d timer=%d", iClient, g_bBSAnnouncerJoinAnnouncementShown[iClient] ? 1 : 0, g_bBSAnnouncerJoinAnnouncementPending[iClient] ? 1 : 0, g_iBSAnnouncerJoinRetryCount[iClient], g_hBSAnnouncerJoinTimer[iClient] != null ? 1 : 0);

	g_bBSAnnouncerJoinAnnouncementShown[iClient] = false;
	g_bBSAnnouncerJoinAnnouncementPending[iClient] = false;
	g_iBSAnnouncerJoinRetryCount[iClient] = 0;

	if (g_hBSAnnouncerJoinTimer[iClient] != null)
	{
		delete g_hBSAnnouncerJoinTimer[iClient];
		g_hBSAnnouncerJoinTimer[iClient] = null;
	}
}

stock bool BSAnnouncer_IsAnnounceTarget(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient) && !IsFakeClient(iClient));
}

stock bool BSAnnouncer_CanReceiveAnnouncements(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient))
		return false;

	if (!IsFakeClient(iClient))
		return true;

	return IsClientSourceTV(iClient);
}

stock void BSAnnouncer_EnsureJoinTimer(int iClient)
{
	if (g_hBSAnnouncerJoinTimer[iClient] != null)
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Timer, "Join timer already active: client=%d", iClient);
		return;
	}

	g_hBSAnnouncerJoinTimer[iClient] = CreateTimer(1.0, BSAnnouncer_OnJoinTimer, GetClientUserId(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	BSAnnouncer_Debug(kBSAnnouncerDebug_Timer, "Join timer created: client=%d userid=%d", iClient, GetClientUserId(iClient));
}

stock bool BSAnnouncer_ShouldLogJoinTimerTick(int iRetryCount)
{
	return (iRetryCount <= 0 || (iRetryCount % 5) == 0 || iRetryCount >= 14);
}

public Action BSAnnouncer_OnJoinTimer(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient > 0 && iClient <= MaxClients && BSAnnouncer_ShouldLogJoinTimerTick(g_iBSAnnouncerJoinRetryCount[iClient]))
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Timer, "Join timer tick: userid=%d client=%d pending=%d shown=%d retries=%d in_game=%d team=%d core=%d auth_ready=%d auth_pending=%d resolved=%d", iUserId, iClient, g_bBSAnnouncerJoinAnnouncementPending[iClient] ? 1 : 0, g_bBSAnnouncerJoinAnnouncementShown[iClient] ? 1 : 0, g_iBSAnnouncerJoinRetryCount[iClient], IsClientInGame(iClient) ? 1 : 0, IsClientInGame(iClient) ? GetClientTeam(iClient) : -1, g_bBSAnnouncerHasCoreLibrary ? 1 : 0, (g_bBSAnnouncerHasCoreLibrary && BSCore_IsAuthReady()) ? 1 : 0, (g_bBSAnnouncerHasCoreLibrary ? (BSCore_IsClientAuthPending(iClient) ? 1 : 0) : 0), (g_bBSAnnouncerHasCoreLibrary ? (BSCore_HasResolvedSummary(iClient) ? 1 : 0) : 0));
	}
	if (!BSAnnouncer_IsAnnounceTarget(iClient))
		return Plugin_Stop;

	if (g_hBSAnnouncerJoinTimer[iClient] != hTimer)
		return Plugin_Stop;

	if (!g_bBSAnnouncerJoinAnnouncementPending[iClient] || g_bBSAnnouncerJoinAnnouncementShown[iClient])
		return BSAnnouncer_StopJoinTimer(iClient);

	if (!IsClientInGame(iClient) || GetClientTeam(iClient) <= 1)
	{
		g_iBSAnnouncerJoinRetryCount[iClient]++;
		if (g_iBSAnnouncerJoinRetryCount[iClient] >= 15)
			return BSAnnouncer_StopJoinTimer(iClient);
		return Plugin_Continue;
	}

	if (BSAnnouncer_TryAnnounceClient(iClient))
		return BSAnnouncer_StopJoinTimer(iClient);

	if (g_bBSAnnouncerHasCoreLibrary && BSCore_IsAuthReady() && !BSCore_IsClientAuthPending(iClient) && BSCore_HasResolvedSummary(iClient))
		return BSAnnouncer_StopJoinTimer(iClient);

	g_iBSAnnouncerJoinRetryCount[iClient]++;
	if (g_iBSAnnouncerJoinRetryCount[iClient] >= 15)
		return BSAnnouncer_StopJoinTimer(iClient);

	return Plugin_Continue;
}

stock Action BSAnnouncer_StopJoinTimer(int iClient)
{
	BSAnnouncer_Debug(kBSAnnouncerDebug_Timer, "Stopping join timer: client=%d shown=%d pending=%d retries=%d", iClient, g_bBSAnnouncerJoinAnnouncementShown[iClient] ? 1 : 0, g_bBSAnnouncerJoinAnnouncementPending[iClient] ? 1 : 0, g_iBSAnnouncerJoinRetryCount[iClient]);
	g_bBSAnnouncerJoinAnnouncementPending[iClient] = false;
	g_iBSAnnouncerJoinRetryCount[iClient] = 0;
	g_hBSAnnouncerJoinTimer[iClient] = null;
	return Plugin_Stop;
}

stock void BSAnnouncer_TryAnnounceAllEligibleClients()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!BSAnnouncer_IsAnnounceTarget(iClient) || !IsClientInGame(iClient) || GetClientTeam(iClient) <= 1)
			continue;

		BSAnnouncer_Debug(kBSAnnouncerDebug_API, "Rechecking eligible client after core/library change: client=%d shown=%d pending=%d", iClient, g_bBSAnnouncerJoinAnnouncementShown[iClient] ? 1 : 0, g_bBSAnnouncerJoinAnnouncementPending[iClient] ? 1 : 0);
		if (BSAnnouncer_TryAnnounceClient(iClient))
			continue;

		g_bBSAnnouncerJoinAnnouncementPending[iClient] = true;
		BSAnnouncer_EnsureJoinTimer(iClient);
	}
}

stock bool BSAnnouncer_TryAnnounceClient(int iClient)
{
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "TryAnnounceClient start: client=%d target_usable=%d viewer_usable=%d in_game=%d team=%d shown=%d core=%d auth_ready=%d auth_pending=%d resolved=%d", iClient, BSAnnouncer_IsAnnounceTarget(iClient) ? 1 : 0, BSAnnouncer_CanReceiveAnnouncements(iClient) ? 1 : 0, IsClientInGame(iClient) ? 1 : 0, IsClientInGame(iClient) ? GetClientTeam(iClient) : -1, g_bBSAnnouncerJoinAnnouncementShown[iClient] ? 1 : 0, g_bBSAnnouncerHasCoreLibrary ? 1 : 0, (g_bBSAnnouncerHasCoreLibrary && BSCore_IsAuthReady()) ? 1 : 0, (g_bBSAnnouncerHasCoreLibrary ? (BSCore_IsClientAuthPending(iClient) ? 1 : 0) : 0), (g_bBSAnnouncerHasCoreLibrary ? (BSCore_HasResolvedSummary(iClient) ? 1 : 0) : 0));
	if (!BSAnnouncer_IsAnnounceTarget(iClient) || !IsClientInGame(iClient) || GetClientTeam(iClient) <= 1)
		return false;

	if (g_bBSAnnouncerJoinAnnouncementShown[iClient])
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "TryAnnounceClient skipped because already shown: client=%d", iClient);
		return true;
	}

	if (!g_bBSAnnouncerHasCoreLibrary || !BSCore_IsAuthReady() || BSCore_IsClientAuthPending(iClient) || !BSCore_HasResolvedSummary(iClient))
	{
		if (!g_bBSAnnouncerJoinAnnouncementPending[iClient])
			BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "TryAnnounceClient waiting for core resolution: client=%d", iClient);
		return false;
	}

	char szSelfSummary[192];
	if (!BSAnnouncer_BuildSummaryText(iClient, iClient, szSelfSummary, sizeof(szSelfSummary)))
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "TryAnnounceClient found no announceable sanctions: client=%d", iClient);
		g_bBSAnnouncerJoinAnnouncementShown[iClient] = true;
		return true;
	}

	if (g_cvBSAnnouncerSelfJoin != null && g_cvBSAnnouncerSelfJoin.BoolValue)
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Sending self join announcement: client=%d summary=%s", iClient, szSelfSummary);
		CPrintToChat(iClient, "%t", "BSAnnouncerJoinSelf", szSelfSummary, "!bs_status");
	}
	else
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Self join announcement suppressed by cvar: client=%d", iClient);
	}

	if (g_cvBSAnnouncerPublicJoin != null && g_cvBSAnnouncerPublicJoin.BoolValue)
	{
		for (int iViewer = 1; iViewer <= MaxClients; iViewer++)
		{
			if (iViewer == iClient || !BSAnnouncer_CanReceiveAnnouncements(iViewer) || !IsClientInGame(iViewer))
				continue;

			char szPublicSummary[192];
			if (!BSAnnouncer_BuildSummaryText(iViewer, iClient, szPublicSummary, sizeof(szPublicSummary)))
				continue;

			BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Sending public join announcement: target=%d viewer=%d summary=%s", iClient, iViewer, szPublicSummary);
			CPrintToChat(iViewer, "%t", "BSAnnouncerJoinPublic", iClient, szPublicSummary);
		}
	}

	g_bBSAnnouncerJoinAnnouncementShown[iClient] = true;
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "Announcement completed: client=%d", iClient);
	return true;
}

stock bool BSAnnouncer_BuildSummaryText(int iViewer, int iTarget, char[] szBuffer, int iMaxLength)
{
	szBuffer[0] = '\0';

	if (!g_bBSAnnouncerHasCoreLibrary || !BSCore_HasResolvedSummary(iTarget))
	{
		BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "BuildSummaryText aborted: viewer=%d target=%d core=%d resolved=%d", iViewer, iTarget, g_bBSAnnouncerHasCoreLibrary ? 1 : 0, (g_bBSAnnouncerHasCoreLibrary && BSCore_HasResolvedSummary(iTarget)) ? 1 : 0);
		return false;
	}

	eBSCoreModuleBit eEffectiveMask = BSAnnouncer_GetEffectiveResolvedModuleMask(iTarget);
	bool bHasComm = BSAnnouncer_HasEffectiveResolvedModule(iTarget, kBSCoreModule_Communication);
	bool bHasSprays = BSAnnouncer_HasEffectiveResolvedModule(iTarget, kBSCoreModule_Sprays);
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "BuildSummaryText mask evaluation: viewer=%d target=%d resolved_mask=%d registered_mask=%d effective_mask=%d has_comm=%d has_sprays=%d comm_type=%d", iViewer, iTarget, view_as<int>(BSCore_GetResolvedModuleMask(iTarget)), view_as<int>(BSCore_GetRegisteredModuleMask()), view_as<int>(eEffectiveMask), bHasComm ? 1 : 0, bHasSprays ? 1 : 0, view_as<int>(BSCore_GetResolvedCommType(iTarget)));
	if (!bHasComm && !bHasSprays)
		return false;

	char szCommLabel[96];
	if (bHasComm)
	{
		switch (BSCore_GetResolvedCommType(iTarget))
		{
			case kBSCoreComm_Mic:
				FormatEx(szCommLabel, sizeof(szCommLabel), "%T", "BSAnnouncerLabelCommMic", iViewer);
			case kBSCoreComm_Chat:
				FormatEx(szCommLabel, sizeof(szCommLabel), "%T", "BSAnnouncerLabelCommChat", iViewer);
			case kBSCoreComm_All:
				FormatEx(szCommLabel, sizeof(szCommLabel), "%T", "BSAnnouncerLabelCommAll", iViewer);
			default:
				FormatEx(szCommLabel, sizeof(szCommLabel), "%T", "BSAnnouncerLabelComm", iViewer);
		}
	}

	if (bHasComm && bHasSprays)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerSummaryCommAndSprays", iViewer, szCommLabel);
		return true;
	}

	if (bHasComm)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerSummaryComm", iViewer, szCommLabel);
		return true;
	}

	FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerSummarySprays", iViewer);
	BSAnnouncer_Debug(kBSAnnouncerDebug_Announce, "BuildSummaryText result: viewer=%d target=%d summary=%s", iViewer, iTarget, szBuffer);
	return true;
}

stock void BSAnnouncer_LogCategory(eBSAnnouncerDebugMask eMask, const char[] szTag, const char[] szMessage)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAnnouncerDebugMask, view_as<int>(eMask)))
		return;

	BSLogToFileEx(g_szBSAnnouncerLogPath, "[%s] %s", szTag, szMessage);
}

stock void BSAnnouncer_Debug(eBSAnnouncerDebugMask eMask, const char[] szMessage, any ...)
{
	if (!BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSAnnouncerDebugMask, view_as<int>(eMask)))
		return;

	static char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
	BSAnnouncer_LogCategory(eMask, "Debug", szBuffer);
}

stock void BSAnnouncer_PrintConsoleLine(int iClient, const char[] szFormat, any ...)
{
	static char szBuffer[256];
	if (iClient > 0)
		SetGlobalTransTarget(iClient);
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	PrintToConsole(iClient, "%s", szBuffer);
}

stock void BSAnnouncer_PrintConsoleFrameTop(int iClient)
{
	PrintToConsole(iClient, "//============= BanSystem =============\\");
}

stock void BSAnnouncer_PrintConsoleFrameBottom(int iClient)
{
	PrintToConsole(iClient, "//=====================================\\");
}

stock void BSAnnouncer_PrintConsoleTitle(int iClient)
{
	BSAnnouncer_PrintConsoleLine(iClient, "%T", "BSAnnouncerConsoleTitle", iClient);
}

stock void BSAnnouncer_PrintConsoleSpacer(int iClient)
{
	PrintToConsole(iClient, "|");
}

stock void BSAnnouncer_PrintConsoleSectionTitle(int iClient, const char[] szPhrase)
{
	BSAnnouncer_PrintConsoleLine(iClient, "%T", szPhrase, iClient);
}

stock void BSAnnouncer_PrintConsoleField(int iClient, const char[] szPhrase, const char[] szValue)
{
	BSAnnouncer_PrintConsoleLine(iClient, "%T", szPhrase, iClient, szValue);
}

stock void BSAnnouncer_FormatExpireDisplay(int iClient, int iExpireTs, char[] szBuffer, int iMaxLength)
{
	if (iExpireTs <= 0)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerConsolePermanent", iClient);
		return;
	}

	FormatTime(szBuffer, iMaxLength, "%Y-%m-%d %H:%M:%S", iExpireTs);
}

stock void BSAnnouncer_FormatDurationDisplay(int iClient, int iDurationMinutes, char[] szBuffer, int iMaxLength)
{
	if (iDurationMinutes <= 0)
	{
		FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerConsolePermanent", iClient);
		return;
	}

	FormatEx(szBuffer, iMaxLength, "%T", "BSAnnouncerConsoleDurationMinutes", iClient, iDurationMinutes);
}

stock void BSAnnouncer_PrintResolvedDetailsToConsole(int iClient)
{
	bool bHeaderPrinted = false;
	bool bPrintedSection = false;

	if (BSAnnouncer_HasEffectiveResolvedModule(iClient, kBSCoreModule_Communication))
	{
		if (!bHeaderPrinted)
		{
			BSAnnouncer_PrintConsoleFrameTop(iClient);
			BSAnnouncer_PrintConsoleTitle(iClient);
			BSAnnouncer_PrintConsoleSpacer(iClient);
			bHeaderPrinted = true;
		}

		if (bPrintedSection)
			BSAnnouncer_PrintConsoleSpacer(iClient);

		BSAnnouncer_PrintConsoleSectionTitle(iClient, "BSAnnouncerConsoleCommSection");

		char szType[48];
		switch (BSCore_GetResolvedCommType(iClient))
		{
			case kBSCoreComm_Mic:
				FormatEx(szType, sizeof(szType), "%T", "BSAnnouncerLabelCommMic", iClient);
			case kBSCoreComm_Chat:
				FormatEx(szType, sizeof(szType), "%T", "BSAnnouncerLabelCommChat", iClient);
			case kBSCoreComm_All:
				FormatEx(szType, sizeof(szType), "%T", "BSAnnouncerLabelCommAll", iClient);
			default:
				FormatEx(szType, sizeof(szType), "%T", "BSAnnouncerLabelComm", iClient);
		}
		char szExpire[64];
		BSAnnouncer_FormatExpireDisplay(iClient, BSCore_GetResolvedCommExpireTs(iClient), szExpire, sizeof(szExpire));
		char szDuration[32];
		BSAnnouncer_FormatDurationDisplay(iClient, BSCore_GetResolvedCommLength(iClient), szDuration, sizeof(szDuration));
		char szReason[256];
		char szContext[512];
		char szAdmin[64];
		BSCore_GetResolvedCommReason(iClient, szReason, sizeof(szReason));
		BSCore_GetResolvedCommContext(iClient, szContext, sizeof(szContext));
		BSCore_GetResolvedCommBannedByName(iClient, szAdmin, sizeof(szAdmin));
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldType", szType);
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldDuration", szDuration);
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldReason", szReason[0] != '\0' ? szReason : "-");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldContext", szContext[0] != '\0' ? szContext : "-");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldAdmin", szAdmin[0] != '\0' ? szAdmin : "Console");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldExpire", szExpire);
		bPrintedSection = true;
	}

	if (BSAnnouncer_HasEffectiveResolvedModule(iClient, kBSCoreModule_Sprays))
	{
		if (!bHeaderPrinted)
		{
			BSAnnouncer_PrintConsoleFrameTop(iClient);
			BSAnnouncer_PrintConsoleTitle(iClient);
			BSAnnouncer_PrintConsoleSpacer(iClient);
			bHeaderPrinted = true;
		}

		if (bPrintedSection)
			BSAnnouncer_PrintConsoleSpacer(iClient);

		BSAnnouncer_PrintConsoleSectionTitle(iClient, "BSAnnouncerConsoleSpraysSection");

		char szExpire[64];
		BSAnnouncer_FormatExpireDisplay(iClient, BSCore_GetResolvedSprayExpireTs(iClient), szExpire, sizeof(szExpire));
		char szDuration[32];
		BSAnnouncer_FormatDurationDisplay(iClient, BSCore_GetResolvedSprayLength(iClient), szDuration, sizeof(szDuration));
		char szReason[256];
		char szContext[512];
		char szAdmin[64];
		BSCore_GetResolvedSprayReason(iClient, szReason, sizeof(szReason));
		BSCore_GetResolvedSprayContext(iClient, szContext, sizeof(szContext));
		BSCore_GetResolvedSprayBannedByName(iClient, szAdmin, sizeof(szAdmin));
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldDuration", szDuration);
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldReason", szReason[0] != '\0' ? szReason : "-");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldContext", szContext[0] != '\0' ? szContext : "-");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldAdmin", szAdmin[0] != '\0' ? szAdmin : "Console");
		BSAnnouncer_PrintConsoleField(iClient, "BSAnnouncerConsoleFieldExpire", szExpire);
		bPrintedSection = true;
	}

	if (bHeaderPrinted)
		BSAnnouncer_PrintConsoleFrameBottom(iClient);
}

stock eBSCoreModuleBit BSAnnouncer_GetEffectiveResolvedModuleMask(int iClient)
{
	eBSCoreModuleBit eMask = BSCore_GetResolvedModuleMask(iClient);
	eMask &= BSCore_GetRegisteredModuleMask();
	return eMask;
}

stock bool BSAnnouncer_HasEffectiveResolvedModule(int iClient, eBSCoreModuleBit eModuleBit)
{
	return ((BSAnnouncer_GetEffectiveResolvedModuleMask(iClient) & eModuleBit) != kBSCoreModule_None);
}

stock void BSAnnouncer_CReplyToCommandWithSource(int iClient, ReplySource eReplySource, const char[] szFormat, any ...)
{
	ReplySource eOldSource = SetCmdReplySource(eReplySource);

	static char szBuffer[256];
	if (iClient > 0)
		SetGlobalTransTarget(iClient);

	VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);
	CReplyToCommand(iClient, "%s", szBuffer);
	SetCmdReplySource(eOldSource);
}