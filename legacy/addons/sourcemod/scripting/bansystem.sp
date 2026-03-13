#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <adminmenu>
#include <sdktools>
#include <steamidtools>
#include <l4d2_changelevel>

#undef REQUIRE_PLUGIN
#include <bansystem_core>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PATCH_DEBUG	"logs/BanSystem.log"

#define PLUGIN_VERSION	"1.0.0"
// SourcePawn cannot safely manipulate STEAMID64_BASE as a 64-bit integer, so we keep its decimal string form here.
#define STEAMID64_BASE_STRING "76561197960265728"

char g_sDatabase[][32] = {"bansystem", "bansystemcache"};

enum eDatabase
{
	kNoDB		= 0,
	kPrimary	= 1,
	kCache 		= 2
}

enum eDebugMask
{
	kDebug_None    = 0,
	kDebug_General = 1,
	kDebug_SQL     = 2,
	kDebug_Menu    = 4,
	kDebug_API     = 8
}

enum eIdentityResolution
{
	kIdentityResolution_Invalid = 0,
	kIdentityResolution_Resolved,
	kIdentityResolution_OnlinePending
}

enum eIdentityRequestKind
{
	kIdentityRequest_None = 0,
	kIdentityRequest_AccessUnban,
	kIdentityRequest_AccessInfo,
	kIdentityRequest_AccessAttemptInfo,
	kIdentityRequest_AccessBan,
	kIdentityRequest_CommInfo,
	kIdentityRequest_CommUnban,
	kIdentityRequest_CommBan
}

enum eAuthState
{
	kAuthState_Idle = 0,
	kAuthState_Queued,
	kAuthState_Checking
}

Database
	g_dbDatabase,
	g_dbCache;

bool g_bPrimaryDatabaseReady;
bool g_bMapTransitionActive;
bool g_bHasL4D2ChangeLevel;
bool g_bHasBSCoreLibrary;

KeyValues g_kvReasons;

char g_sLogPath[PLATFORM_MAX_PATH];

char g_szBanReasonsPath[PLATFORM_MAX_PATH];

enum eTypeComms
{
	kNone = 0,
    kMic = 1,
    kChat = 2,
    kAll = 3,
}

enum struct ePlayerState {
	eTypeComms m_eComms;
	bool m_bPerm;
}

ePlayerState g_ePunished[MAXPLAYERS+1];
ArrayList g_arrCacheNoPunishment;
StringMap g_smIdentityRequestContext;
Handle g_hCommExpireTimer[MAXPLAYERS+1];
Handle g_hAuthCheckTimer[MAXPLAYERS+1];
eAuthState g_eAuthState[MAXPLAYERS+1];

ConVar
	g_cvSQLCache,
	g_cvLocalCache,
	g_cvAuthCheckTimeout,
	g_cvSteamIdProvider,
	g_cvDebugMask;

#include "bansystem/schema.sp"
#include "bansystem/helpers.sp"
#include "bansystem/api.sp"
#include "bansystem/identity.sp"
#include "bansystem/auth.sp"
#include "bansystem/db.sp"
#include "bansystem/access.sp"
#include "bansystem/communication.sp"
#include "bansystem/cache.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "BanSystem",
	author		= "lechuga",
	description = "Integrates database to sanctions",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/AoC-Gamers/AoC-L4D2-Competitive"
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrMax)
{
	vRegisterApiLibrary();
	return APLRes_Success;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), PATCH_DEBUG);
	BuildPath(Path_SM, g_szBanReasonsPath, sizeof(g_szBanReasonsPath), "configs/bansystem_reasons.txt");

	g_arrCacheNoPunishment = new ArrayList();
	g_smIdentityRequestContext = new StringMap();
	g_bMapTransitionActive = true;
	g_bHasL4D2ChangeLevel = LibraryExists("l4d2_changelevel");
	g_bHasBSCoreLibrary = LibraryExists("bansystem_core");
	vOnPluginStart_Api();

	vLoadTranslation("common.phrases");
	vLoadTranslation("bansystem.phrases");
	vLoadTranslation("bansystem.reasons.phrases");
	vLoadTranslation("basebans.phrases");
	vLoadTranslation("core.phrases");

	g_cvSQLCache = CreateConVar("sm_bansystem_sqlitecache", "1", "Enables the SQL Lite cache that stores players with bans.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLocalCache = CreateConVar("sm_bansystem_localcache", "1", "Enables local cache confirming players without bans.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvAuthCheckTimeout = CreateConVar("sm_bansystem_auth_timeout", "8.0", "Seconds to wait for an auth check before rejecting the player.", FCVAR_NONE, true, 1.0);
	g_cvSteamIdProvider = CreateConVar("sm_bansystem_steamid_provider", "auto", "Online provider used to resolve SteamID64 inputs: auto, steamworks or system2.", FCVAR_NONE);
	g_cvDebugMask = CreateConVar("sm_bansystem_debug_mask", "0", "Debug bitmask: 1=general, 2=sql, 4=menu, 8=api.", FCVAR_NONE, true, 0.0);

	vOnPluginStart_Schema();
	vOnPluginStart_Access();
	vOnPluginStart_Communication();
	vOnPluginStart_Cache();
	vTryRegisterBSCoreModules();

	RegConsoleCmd("sm_abort", Command_AbortBan);
	AutoExecConfig(true, "bansystem");
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "l4d2_changelevel", false))
		g_bHasL4D2ChangeLevel = true;
	else if (StrEqual(szName, "bansystem_core", false))
	{
		g_bHasBSCoreLibrary = true;
		vTryRegisterBSCoreModules();
	}
}

public void OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "l4d2_changelevel", false))
		g_bHasL4D2ChangeLevel = false;
	else if (StrEqual(szName, "bansystem_core", false))
		g_bHasBSCoreLibrary = false;
}

public Action Command_AbortBan(int iClient, int iArgs)
{
	if (g_eProcessAccess[iClient].m_eInputStage != kPanelInput_None)
	{
		vResetAccessProcessState(iClient);
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBanApplied");
	}
	else if (g_eProcessComm[iClient].m_eInputStage != kPanelInput_None)
	{
		vResetCommProcessState(iClient);
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBanApplied");
	}
	else
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBanNoPendingProcess");

	return Plugin_Handled;
}

void vResetPendingAdminProcesses(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	vResetAccessProcessState(iClient);
	vResetCommProcessState(iClient);
}

public void OnConfigsExecuted()
{
	g_bMapTransitionActive = true;
	g_bPrimaryDatabaseReady = false;
	vConnectDB(g_sDatabase[0]);

	if (g_cvSQLCache.BoolValue)
		vConnectDB(g_sDatabase[1], true);
	else if (g_dbCache != null)
	{
		delete g_dbCache;
		g_dbCache = null;
		g_bSQLiteCacheReady = false;
	}

	vLoadReasons();
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

public void OnClientDisconnect(int iClient)
{
	vResetClientAuthorizationState(iClient);
	vResetAccessProcessState(iClient);
	vResetCommProcessState(iClient);
	vResetPlayerPunishmentState(iClient);
}

bool bIsUsableClient(int iClient)
{
	return (iClient > SERVER_INDEX && iClient <= MaxClients && IsClientConnected(iClient));
}

bool bCanUsePrimaryDatabase()
{
	return (g_dbDatabase != null && g_bPrimaryDatabaseReady);
}

bool bEnsurePrimaryDatabaseReady(int iClient)
{
	if (bCanUsePrimaryDatabase())
		return true;

	vReplyCommandPhrase(iClient, "DatabaseNotReady");
	return false;
}

DataPack pCreateAdminTargetAuthReplyContext(int iAdmin, int iTarget, const char[] szTargetAuthId, ReplySource eRsCmd)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(iGetCommandIssuerUserId(iAdmin));
	pContext.WriteCell(iGetCommandIssuerUserId(iTarget));
	pContext.WriteString(szTargetAuthId);
	pContext.WriteCell(eRsCmd);
	return pContext;
}

void vReadAdminTargetAuthReplyContext(any pData, int &iUserIdAdmin, int &iUserIdTarget, char[] szTargetAuthId, int iAuthIdMaxLength, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserIdAdmin = pContext.ReadCell();
	iUserIdTarget = pContext.ReadCell();
	pContext.ReadString(szTargetAuthId, iAuthIdMaxLength);
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	delete pContext;
}

DataPack pCreateAdminTargetAuthLengthReasonReplyContext(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason, ReplySource eRsCmd)
{
	DataPack pContext = pCreateAdminTargetAuthReplyContext(iAdmin, iTarget, szTargetAuthId, eRsCmd);
	pContext.WriteCell(iLength);
	pContext.WriteString(szReason);
	return pContext;
}

void vReadAdminTargetAuthLengthReasonReplyContext(any pData, int &iUserIdAdmin, int &iUserIdTarget, char[] szTargetAuthId, int iAuthIdMaxLength, int &iLength, char[] szReason, int iReasonMaxLength, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserIdAdmin = pContext.ReadCell();
	iUserIdTarget = pContext.ReadCell();
	pContext.ReadString(szTargetAuthId, iAuthIdMaxLength);
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	iLength = pContext.ReadCell();
	pContext.ReadString(szReason, iReasonMaxLength);
	delete pContext;
}

DataPack pCreateAdminTargetAuthLengthReasonTypeReplyContext(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason, eTypeComms eComms, ReplySource eRsCmd)
{
	DataPack pContext = pCreateAdminTargetAuthLengthReasonReplyContext(iAdmin, iTarget, szTargetAuthId, iLength, szReason, eRsCmd);
	pContext.WriteCell(eComms);
	return pContext;
}

void vReadAdminTargetAuthLengthReasonTypeReplyContext(any pData, int &iUserIdAdmin, int &iUserIdTarget, char[] szTargetAuthId, int iAuthIdMaxLength, int &iLength, char[] szReason, int iReasonMaxLength, eTypeComms &eComms, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserIdAdmin = pContext.ReadCell();
	iUserIdTarget = pContext.ReadCell();
	pContext.ReadString(szTargetAuthId, iAuthIdMaxLength);
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	iLength = pContext.ReadCell();
	pContext.ReadString(szReason, iReasonMaxLength);
	eComms = view_as<eTypeComms>(pContext.ReadCell());
	delete pContext;
}

DataPack pCreateAdminTargetAuthLengthReasonContextTypeReplyContext(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason, const char[] szContext, eTypeComms eComms, ReplySource eRsCmd)
{
	DataPack pContext = pCreateAdminTargetAuthLengthReasonTypeReplyContext(iAdmin, iTarget, szTargetAuthId, iLength, szReason, eComms, eRsCmd);
	pContext.WriteString(szContext);
	return pContext;
}

void vReadAdminTargetAuthLengthReasonContextTypeReplyContext(any pData, int &iUserIdAdmin, int &iUserIdTarget, char[] szTargetAuthId, int iAuthIdMaxLength, int &iLength, char[] szReason, int iReasonMaxLength, char[] szContext, int iContextMaxLength, eTypeComms &eComms, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserIdAdmin = pContext.ReadCell();
	iUserIdTarget = pContext.ReadCell();
	pContext.ReadString(szTargetAuthId, iAuthIdMaxLength);
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	iLength = pContext.ReadCell();
	pContext.ReadString(szReason, iReasonMaxLength);
	eComms = view_as<eTypeComms>(pContext.ReadCell());
	pContext.ReadString(szContext, iContextMaxLength);
	delete pContext;
}

DataPack pCreateAdminTargetAuthNameTypeReplyContext(int iAdmin, int iTarget, const char[] szTargetAuthId, const char[] szTargetName, eTypeComms eComms, ReplySource eRsCmd)
{
	DataPack pContext = pCreateAdminTargetAuthReplyContext(iAdmin, iTarget, szTargetAuthId, eRsCmd);
	pContext.WriteString(szTargetName);
	pContext.WriteCell(eComms);
	return pContext;
}

void vReadAdminTargetAuthNameTypeReplyContext(any pData, int &iUserIdAdmin, int &iUserIdTarget, char[] szTargetAuthId, int iAuthIdMaxLength, char[] szTargetName, int iTargetNameMaxLength, eTypeComms &eComms, ReplySource &eRsCmd)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserIdAdmin = pContext.ReadCell();
	iUserIdTarget = pContext.ReadCell();
	pContext.ReadString(szTargetAuthId, iAuthIdMaxLength);
	eRsCmd = view_as<ReplySource>(pContext.ReadCell());
	pContext.ReadString(szTargetName, iTargetNameMaxLength);
	eComms = view_as<eTypeComms>(pContext.ReadCell());
	delete pContext;
}

int iResolveAdminForAudit(int iUserIdAdmin, char[] szAdminAuthId, int iMaxLength)
{
	strcopy(szAdminAuthId, iMaxLength, "Console");

	if (iUserIdAdmin == SERVER_INDEX)
		return SERVER_INDEX;

	int iAdmin = iResolveReplyClient(iUserIdAdmin, true);
	if (!bIsUsableClient(iAdmin))
		return SERVER_INDEX;

	GetClientAuthId(iAdmin, AuthId_Steam2, szAdminAuthId, iMaxLength);
	return iAdmin;
}

void vResolveTargetForAudit(int iUserIdTarget, const char[] szFallbackAuthId, int &iTarget, char[] szTargetName, int iMaxLength)
{
	if (iUserIdTarget != NO_INDEX)
	{
		iTarget = GetClientOfUserId(iUserIdTarget);
		if (bIsUsableClient(iTarget) && GetClientName(iTarget, szTargetName, iMaxLength))
			return;
	}

	iTarget = NO_INDEX;
	strcopy(szTargetName, iMaxLength, szFallbackAuthId);
}

void vResolveTargetClientByUserId(int iUserIdTarget, int &iTarget)
{
	if (iUserIdTarget == NO_INDEX)
	{
		iTarget = NO_INDEX;
		return;
	}

	iTarget = GetClientOfUserId(iUserIdTarget);
	if (!bIsUsableClient(iTarget))
		iTarget = NO_INDEX;
}

DataPack pCreateIdentityRequestContext(eIdentityRequestKind eKind, int iClient, ReplySource eReplySource, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "")
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(view_as<int>(eKind));
	pContext.WriteCell(iGetCommandIssuerUserId(iClient));
	pContext.WriteCell(view_as<int>(eReplySource));
	pContext.WriteCell(iArg0);
	pContext.WriteCell(iArg1);
	pContext.WriteString(szExtra);
	return pContext;
}

void vReadIdentityRequestContext(any pData, eIdentityRequestKind &eKind, int &iUserId, ReplySource &eReplySource, int &iArg0, int &iArg1, char[] szExtra, int iExtraMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	eKind = view_as<eIdentityRequestKind>(pContext.ReadCell());
	iUserId = pContext.ReadCell();
	eReplySource = view_as<ReplySource>(pContext.ReadCell());
	iArg0 = pContext.ReadCell();
	iArg1 = pContext.ReadCell();
	pContext.ReadString(szExtra, iExtraMaxLength);
	delete pContext;
}

DataPack pCreateAuthCheckContext(int iClient, int iAccountId, const char[] szAuthId)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(GetClientUserId(iClient));
	pContext.WriteCell(iAccountId);
	pContext.WriteString(szAuthId);
	return pContext;
}

void vReadAuthCheckContext(any pData, int &iUserId, int &iAccountId, char[] szAuthId, int iAuthIdMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	iAccountId = pContext.ReadCell();
	pContext.ReadString(szAuthId, iAuthIdMaxLength);
	delete pContext;
}

DataPack pCreateCommAnnouncementContext(int iUserId, const char[] szComms, const char[] szDate)
{
	DataPack pContext = new DataPack();
	pContext.WriteCell(iUserId);
	pContext.WriteString(szComms);
	pContext.WriteString(szDate);
	return pContext;
}

void vReadCommAnnouncementContext(any pData, int &iUserId, char[] szComms, int iCommsMaxLength, char[] szDate, int iDateMaxLength)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	iUserId = pContext.ReadCell();
	pContext.ReadString(szComms, iCommsMaxLength);
	pContext.ReadString(szDate, iDateMaxLength);
}

bool bTryParseCommandDuration(const char[] szInput, int &iMinutes)
{
	char szNormalized[32];
	vNormalizeCommandInput(szInput, szNormalized, sizeof(szNormalized));

	if (szNormalized[0] == '\0')
		return false;

	if (StrEqual(szNormalized, "perm", false) || StrEqual(szNormalized, "permanent", false))
	{
		iMinutes = 0;
		return true;
	}

	if (!bIsInteger(szNormalized))
		return false;

	iMinutes = StringToInt(szNormalized);
	return (iMinutes >= 0);
}

bool bTryGetCommandDurationArg(int iArgs, int iArgIndex, int &iMinutes, int iDefaultMinutes = 0)
{
	if (iArgs < iArgIndex)
	{
		iMinutes = iDefaultMinutes;
		return true;
	}

	char szDuration[32];
	GetCmdArg(iArgIndex, szDuration, sizeof(szDuration));
	return bTryParseCommandDuration(szDuration, iMinutes);
}

void vBuildCommandReasonFromArgs(int iStartArg, int iArgs, char[] szReason, int iMaxLength)
{
	szReason[0] = '\0';

	if (iArgs < iStartArg)
		return;

	for (int i = iStartArg; i <= iArgs; i++)
	{
		char szArg[128];
		GetCmdArg(i, szArg, sizeof(szArg));

		if (szReason[0] != '\0')
			StrCat(szReason, iMaxLength, " ");

		StrCat(szReason, iMaxLength, szArg);
	}

	TrimString(szReason);
	StripQuotes(szReason);
}

bool bTryParseCommType(const char[] szInput, eTypeComms &eCommType)
{
	char szNormalized[16];
	vNormalizeCommandInput(szInput, szNormalized, sizeof(szNormalized));

	if (StrEqual(szNormalized, "mic", false))
	{
		eCommType = kMic;
		return true;
	}

	if (StrEqual(szNormalized, "chat", false))
	{
		eCommType = kChat;
		return true;
	}

	if (StrEqual(szNormalized, "all", false))
	{
		eCommType = kAll;
		return true;
	}

	return false;
}

void vDenyAuthorization(int iClient)
{
	if (!bIsUsableClient(iClient))
		return;

	vCompleteClientAuthorizationCheck(iClient);
	KickClient(iClient, "%t", "AuthCheckUnavailable");
}

void vSyncConnectedClientState(const char[] szAuthId, int iTarget = NO_INDEX)
{
	if (!bCanUsePrimaryDatabase())
		return;

	int iClient = iTarget;
	if (!bIsUsableClient(iClient))
	{
		iClient = FindClientBySteamID2(szAuthId);
		if (iClient <= SERVER_INDEX)
			iClient = NO_INDEX;
	}

	if (!bIsUsableClient(iClient))
		return;

	int iAccountId;
	iAccountId = GetClientAccountID(iClient);
	if (iAccountId == 0 && !bGetAccountIdFromAuthId(szAuthId, iAccountId))
		return;

	bRemoveLocalCacheAccountId(iAccountId);
	vBeginClientAuthorizationCheck(iClient);
	vCheckAuthId(iClient, iAccountId, szAuthId);
}

int iGetAdminAccountId(int iAdmin)
{
	if (!bIsUsableClient(iAdmin))
		return 0;

	int iAccountId = GetClientAccountID(iAdmin);
	if (iAccountId != 0)
		return iAccountId;

	char szAuthId[MAX_AUTHID_LENGTH];
	if (GetClientAuthId(iAdmin, AuthId_Steam2, szAuthId, sizeof(szAuthId)) && bGetAccountIdFromAuthId(szAuthId, iAccountId))
		return iAccountId;

	return 0;
}

void vFormatBannedByDisplay(int iAdminAccountId, char[] szBuffer, int iMaxLength)
{
	if (iAdminAccountId <= 0)
	{
		strcopy(szBuffer, iMaxLength, "CONSOLE");
		return;
	}

	bGetAuthIdFromAccountId(iAdminAccountId, szBuffer, iMaxLength);
}

int iGetCommandIssuerUserId(int iClient)
{
	if (iClient == SERVER_INDEX)
		return SERVER_INDEX;

	if (!bIsUsableClient(iClient))
		return NO_INDEX;

	return GetClientUserId(iClient);
}

int iResolveReplyClient(int iUserId, bool bFallbackToServer = true)
{
	if (iUserId == SERVER_INDEX)
		return SERVER_INDEX;

	int iClient = GetClientOfUserId(iUserId);
	if (iClient > SERVER_INDEX)
		return iClient;

	return bFallbackToServer ? SERVER_INDEX : NO_INDEX;
}

int iGetQueryListLimit(int iArgs, int iDefaultLimit = 50, int iMaxLimit = 200)
{
	if (iArgs < 1)
		return iDefaultLimit;

	int iLimit = GetCmdArgInt(1);
	if (iLimit <= 0)
		return iDefaultLimit;

	if (iLimit > iMaxLimit)
		return iMaxLimit;

	return iLimit;
}

void vCancelCommExpireTimer(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	if (g_hCommExpireTimer[iClient] != null)
	{
		delete g_hCommExpireTimer[iClient];
		g_hCommExpireTimer[iClient] = null;
	}
}

void vSetPlayerCommPunishmentState(int iClient, eTypeComms eComms, bool bPerm)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	vCancelCommExpireTimer(iClient);
	g_ePunished[iClient].m_eComms = eComms;
	g_ePunished[iClient].m_bPerm = bPerm;

	vRefreshPlayerCommState(iClient);
}

void vRefreshPlayerCommState(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients || !IsClientInGame(iClient))
		return;

	if (bIsClientAuthorizationPending(iClient) || g_ePunished[iClient].m_eComms == kMic || g_ePunished[iClient].m_eComms == kAll)
		SetClientListeningFlags(iClient, VOICE_MUTED);
	else
		SetClientListeningFlags(iClient, VOICE_NORMAL);
}

int iUnixTimeFromUTC(int iYear, int iMonth, int iDay, int iHour, int iMinute, int iSecond)
{
	iYear -= (iMonth <= 2) ? 1 : 0;

	int iEra = iYear / 400;
	int iYearOfEra = iYear - (iEra * 400);
	int iMonthPrime = iMonth + ((iMonth > 2) ? -3 : 9);
	int iDayOfYear = (((153 * iMonthPrime) + 2) / 5) + iDay - 1;
	int iDayOfEra = (iYearOfEra * 365) + (iYearOfEra / 4) - (iYearOfEra / 100) + iDayOfYear;
	int iDays = (iEra * 146097) + iDayOfEra - 719468;

	return (iDays * 86400) + (iHour * 3600) + (iMinute * 60) + iSecond;
}

bool bTryParseSQLDateTimeUTC(const char[] szDateTime, int &iUnixTime)
{
	if (strlen(szDateTime) < 19)
		return false;

	if (szDateTime[4] != '-' || szDateTime[7] != '-' || szDateTime[10] != ' ' || szDateTime[13] != ':' || szDateTime[16] != ':')
		return false;

	int iYear = StringToInt(szDateTime);
	int iMonth = StringToInt(szDateTime[5]);
	int iDay = StringToInt(szDateTime[8]);
	int iHour = StringToInt(szDateTime[11]);
	int iMinute = StringToInt(szDateTime[14]);
	int iSecond = StringToInt(szDateTime[17]);

	if (iYear < 1970 || iMonth < 1 || iMonth > 12 || iDay < 1 || iDay > 31 || iHour < 0 || iHour > 23 || iMinute < 0 || iMinute > 59 || iSecond < 0 || iSecond > 59)
		return false;

	iUnixTime = iUnixTimeFromUTC(iYear, iMonth, iDay, iHour, iMinute, iSecond);
	return true;
}

void vScheduleCommExpireTimer(int iClient, float flDelay)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients || !IsClientConnected(iClient) || flDelay <= 0.0)
		return;

	vCancelCommExpireTimer(iClient);
	g_hCommExpireTimer[iClient] = CreateTimer(flDelay, Timer_CommExpire, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

void vScheduleCommExpireByDate(int iClient, const char[] szExpire)
{
	int iExpireAt;
	if (!bTryParseSQLDateTimeUTC(szExpire, iExpireAt))
	{
		LogError("[vScheduleCommExpireByDate] Invalid expire datetime '%s' for client %d", szExpire, iClient);
		return;
	}

	int iDelay = iExpireAt - GetTime();
	if (iDelay <= 0)
	{
		vExpireCommPunishment(iClient, true);
		return;
	}

	vScheduleCommExpireTimer(iClient, float(iDelay));
}

Action Timer_CommExpire(Handle hTimer, any pData)
{
	int iClient = GetClientOfUserId(view_as<int>(pData));
	if (iClient <= SERVER_INDEX)
		return Plugin_Stop;

	if (g_hCommExpireTimer[iClient] == hTimer)
		g_hCommExpireTimer[iClient] = null;

	if (g_ePunished[iClient].m_eComms != kNone && !g_ePunished[iClient].m_bPerm)
	{
		vExpireCommPunishment(iClient, true);
	}

	return Plugin_Stop;
}

void vExpireCommPunishment(int iClient, bool bNotifyClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	eTypeComms eComms = g_ePunished[iClient].m_eComms;
	char szAuthId[MAX_AUTHID_LENGTH];
	bool bHasAuthId = GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId));

	int iAccountId = GetClientAccountID(iClient);
	bool bHasAccountId = (iAccountId != 0);

	vResetPlayerPunishmentState(iClient);

	if (bNotifyClient && bIsUsableClient(iClient))
		CPrintToChat(iClient, "%t %t", "Prefix", "YouUnbanCommSuccess");

	if (bHasAuthId)
	{
		if (eComms == kChat || eComms == kAll)
		{
			Call_StartForward(g_gfOnUnBanChat);
			Call_PushCell(SERVER_INDEX);
			Call_PushCell(iClient);
			Call_PushString(szAuthId);
			Call_Finish();
		}

		if (eComms == kMic || eComms == kAll)
		{
			Call_StartForward(g_gfOnUnBanMic);
			Call_PushCell(SERVER_INDEX);
			Call_PushCell(iClient);
			Call_PushString(szAuthId);
			Call_Finish();
		}
	}

	if (bHasAuthId)
		vRemoveSQLCache(szAuthId);

	if (!bHasAccountId || !bCanUsePrimaryDatabase())
		return;

	char szQuery[192];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d AND `ban_length` != 0;", TABLE_COMM, iAccountId);
	SQL_TQuery(g_dbDatabase, vExpireCommDatabaseCallback, szQuery, iAccountId);
}

void vExpireCommDatabaseCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	int iAccountId = pData;
	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vExpireCommDatabaseCallback");
		delete rsResult;
		return;
	}

	if (bCanUseBSCoreLibrary() && iAccountId > 0)
		BSCore_ClearSummaryModule(iAccountId, 2);

	delete rsResult;
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if (iClient == SERVER_INDEX)
		return Plugin_Continue;

	Action eAction;
	eAction = aOnClientSayCommand_Access(iClient, szArgs);
	if (eAction == Plugin_Stop)
		return eAction;

	eAction = aOnClientSayCommand_Communication(iClient, szArgs);
	if (eAction == Plugin_Stop)
		return eAction;

	return Plugin_Continue;
}

/**
 * Timer callback function that announces communication bans to a specific client.
 *
 * @param hTimer       Handle to the timer that triggered this callback.
 * @param pData        Data associated with the timer, expected to be a DataPack containing:
 */
void AnnouncerCommTimer(Handle hTimer, any pData)
{
	int
		iClient,
		iUserId;

	char
		szComms[64],
		szDate[128];

	vReadCommAnnouncementContext(pData, iUserId, szComms, sizeof(szComms), szDate, sizeof(szDate));

	iClient = GetClientOfUserId(iUserId); 
	if (iClient == NO_INDEX)
		return;

	SetGlobalTransTarget(iClient);

	PrintToConsole(iClient, "\n\n");
	PrintToConsole(iClient, "// -------------------------------- \\");
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "| %t", "BannedCommConsoleTitle");
	PrintToConsole(iClient, "| %t", "BannedConsoleLength", szDate);
	PrintToConsole(iClient, "| %t", "BannedConsoleTypecomm", szComms);
	PrintToConsole(iClient, "|");
	PrintToConsole(iClient, "// -------------------------------- \\");
	PrintToConsole(iClient, "\n\n");

	CPrintToChat(iClient, "%t %t", "Prefix", "BannedComm", szComms);
}

/**
 * Logs SQL errors and the corresponding query that caused the error.
 *
 * @param db        The database connection handle.
 * @param sQuery    The SQL query that failed.
 * @param sName     The name of the source or context where the error occurred.
 */
void logErrorSQL(Database pDb, const char[] szQuery, const char[] szName)
{
	if (pDb == null)
	{
		LogError("[%s] Database handle is null.", szName);
		LogError("[%s] Query dump: %s", szName, szQuery);
		return;
	}

	char szSQLError[4096];
	SQL_GetError(pDb, szSQLError, sizeof(szSQLError));
	LogError("[%s] SQL failed: %s", szName, szSQLError);
	LogError("[%s] Query dump: %s", szName, szQuery);
}

void vResetPlayerPunishmentState(int iClient)
{
	if (iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	vCancelCommExpireTimer(iClient);
	g_ePunished[iClient].m_eComms = kNone;
	g_ePunished[iClient].m_bPerm = false;

	vRefreshPlayerCommState(iClient);
}

bool bIsValidAuthCheckResult(int iResult)
{
	switch (iResult)
	{
		case 0, -1, 1, -2, 2, -3, 3, -4, 4:
			return true;
	}

	return false;
}

/**
 * @brief Checks if the given string represents an integer.
 *
 * This function iterates through each character of the input string and
 * verifies if all characters are numeric.
 *
 * @param szString The string to be checked.
 * @return True if the string represents an integer, false otherwise.
 */
bool bIsInteger(const char[] szString)
{
	int iLen = strlen(szString);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsCharNumeric(szString[i]))
			return false;
	}
	return true;
}

/**
 * Check if the translation file exists
 *
 * @param szTranslation   Translation name.
 * @noreturn
 */
stock void vLoadTranslation(const char[] szTranslation)
{
	char szPath[PLATFORM_MAX_PATH],
		szName[64];

	Format(szName, sizeof(szName), "translations/%s.txt", szTranslation);
	BuildPath(Path_SM, szPath, sizeof(szPath), szName);
	if (!FileExists(szPath))
		SetFailState("Missing translation file %s.txt", szTranslation);

	LoadTranslations(szTranslation);
}

/**
 * Formats a time duration into a human-readable string representation.
 *
 * @param iTime         The time duration in minutes to be formatted.
 *                      - If `iTime` is 0, the function will format the string as "Permanent".
 * @param szTimeLength  The output buffer to store the formatted time string.
 * @param iMaxLength    The maximum length of the output buffer.
 */
void GetTimeLength(int iTime, char[] szTimeLength, int iMaxLength)
{
	if (iTime == 0)
	{
		Format(szTimeLength, iMaxLength, "%t", "Permanent");
		return;
	}

	int iMonths = iTime / 43200; // 30 days per month
	int iWeeks = (iTime % 43200) / 10080; // 7 days per week
	int iDays = (iTime % 10080) / 1440;
	int iHours = (iTime % 1440) / 60;
	int iMinutes = iTime % 60;

	if (iMonths > 0)
	{
		if (iWeeks > 0)
		{
			Format(szTimeLength, iMaxLength, "%d %t, %d %t",
				iMonths, (iMonths == 1 ? "Month" : "Months"),
				iWeeks, (iWeeks == 1 ? "Week" : "Weeks"));
		}
		else
		{
			Format(szTimeLength, iMaxLength, "%d %t",
				iMonths, (iMonths == 1 ? "Month" : "Months"));
		}
	}
	else if (iWeeks > 0)
	{
		if (iDays > 0)
		{
			Format(szTimeLength, iMaxLength, "%d %t, %d %t",
				iWeeks, (iWeeks == 1 ? "Week" : "Weeks"),
				iDays, (iDays == 1 ? "Day" : "Days"));
		}
		else
		{
			Format(szTimeLength, iMaxLength, "%d %t",
				iWeeks, (iWeeks == 1 ? "Week" : "Weeks"));
		}
	}
	else if (iDays > 0)
	{
		if (iHours > 0)
		{
			Format(szTimeLength, iMaxLength, "%d %t, %d %t",
				iDays, (iDays == 1 ? "Day" : "Days"),
				iHours, (iHours == 1 ? "Hour" : "Hours"));
		}
		else
		{
			Format(szTimeLength, iMaxLength, "%d %t",
				iDays, (iDays == 1 ? "Day" : "Days"));
		}
	}
	else if (iHours > 0)
	{
		if (iMinutes > 0)
		{
			Format(szTimeLength, iMaxLength, "%d %t, %d %t",
				iHours, (iHours == 1 ? "Hour" : "Hours"),
				iMinutes, (iMinutes == 1 ? "Minute" : "Minutes"));
		}
		else
		{
			Format(szTimeLength, iMaxLength, "%d %t",
				iHours, (iHours == 1 ? "Hour" : "Hours"));
		}
	}
	else
	{
		Format(szTimeLength, iMaxLength, "%d %t",
			iMinutes, (iMinutes == 1 ? "Minute" : "Minutes"));
	}
}

/**
 * Returns the absolute value of an integer.
 *
 * @param n The integer value for which the absolute value is to be computed.
 * @return The absolute value of the input integer `n`.
 */
stock int IntAbs(int n)
{
   return (n ^ (n >> 31)) - (n >> 31);
} 

void vGetReasonDisplayText(int iClient, const char[] szReason, char[] szBuffer, int iMaxLength)
{
	if (szReason[0] == '\0')
	{
		szBuffer[0] = '\0';
		return;
	}

	if (szReason[0] == '#')
	{
		Format(szBuffer, iMaxLength, "%T", szReason, iClient);
		return;
	}

	strcopy(szBuffer, iMaxLength, szReason);
}

/**
 * Loads ban reasons from a KeyValues file into memory.
 */
void vLoadReasons()
{
	delete g_kvReasons;

	g_kvReasons = new KeyValues("Reasons");

	if (!g_kvReasons.ImportFromFile(g_szBanReasonsPath))
	{
		SetFailState("Error in %s: File not found, corrupt or in the wrong format", g_szBanReasonsPath);
		return;
	}
	
	if (!g_kvReasons.JumpToKey("Access", false))
	{
		SetFailState("Error in %s: Couldn't find 'Access' section", g_szBanReasonsPath);
		return;
	}

	g_kvReasons.GoBack();
	if (!g_kvReasons.JumpToKey("Communication", false))
	{
		SetFailState("Error in %s: Couldn't find 'Communication' section", g_szBanReasonsPath);
		return;
	}

	g_kvReasons.Rewind();
}

/**
 * Checks if the given string is a valid IPv4 address.
 *
 * This function validates whether the input string represents a valid IPv4 address
 * by ensuring it contains exactly three dots ('.') and that each segment between
 * the dots is an integer.
 *
 * @param szIpAddress The string to validate as an IPv4 address.
 * @return True if the string is a valid IPv4 address, false otherwise.
 */
bool bIsIpAddress(const char[] szIpAddress)
{
	if (strlen(szIpAddress) == 0)
		return false;

	int iCount = 0;
	for (int i = 0; i < strlen(szIpAddress); i++)
	{
		if (szIpAddress[i] == '.')
			iCount++;
	}

	if (iCount != 3)
		return false;

	char szTemp[16];
	int iIndex = 0;
	for (int i = 0; i < strlen(szIpAddress); i++)
	{
		if (szIpAddress[i] == '.')
		{
			szTemp[iIndex] = '\0';
			if (!bIsInteger(szTemp))
				return false;
			iIndex = 0;
		}
		else
		{
			szTemp[iIndex] = szIpAddress[i];
			iIndex++;
		}
	}

	szTemp[iIndex] = '\0';
	if (!bIsInteger(szTemp))
		return false;

	return true;
}

void LogSQL(const char[] sMessage, any...)
{
	LogCategory(kDebug_SQL, "SQL", sMessage, 2);
}

void LogMenu(const char[] sMessage, any...)
{
	LogCategory(kDebug_Menu, "Menu", sMessage, 2);
}

void LogDebug(const char[] sMessage, any...)
{
	LogCategory(kDebug_General, "Debug", sMessage, 2);
}

void LogAPI(const char[] sMessage, any...)
{
	LogCategory(kDebug_API, "API", sMessage, 2);
}

void LogCategory(eDebugMask eMask, const char[] szTag, const char[] sMessage, int iVFormatArg)
{
	if (g_cvDebugMask == null)
		return;

	if (!(g_cvDebugMask.IntValue & view_as<int>(eMask)))
		return;

	static char sFormat[1024];
	VFormat(sFormat, sizeof(sFormat), sMessage, iVFormatArg);
	LogToFileEx(g_sLogPath, "[%s] %s", szTag, sFormat);
}

bool bCanUseBSCoreLibrary()
{
	return g_bHasBSCoreLibrary;
}

void vTryRegisterBSCoreModules()
{
	if (!bCanUseBSCoreLibrary())
		return;

	BSCore_RegisterModule("access", 1);
	BSCore_RegisterModule("communication", 2);
	LogAPI("Registered BanSystem modules in bansystem_core.");
}

void vClearBSCoreSummaryModuleByAuthId(const char[] szTargetAuthId, int iModuleBit)
{
	if (!bCanUseBSCoreLibrary())
		return;

	int iAccountId;
	if (!bGetAccountIdFromAuthId(szTargetAuthId, iAccountId))
		return;

	if (BSCore_ClearSummaryModule(iAccountId, iModuleBit))
		LogAPI("Cleared bansystem_core summary module bit %d for accountid %d.", iModuleBit, iAccountId);
}
