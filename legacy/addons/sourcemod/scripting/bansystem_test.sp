#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <bansystem>
#include <steamidtools>

#define SERVER_INDEX 0
#define NO_INDEX -1
#define TEST_REASON_COMM_CHAT "[TEST] comm chat"
#define TEST_REASON_COMM_MIC "[TEST] comm mic"
#define TEST_REASON_ACCESS "[TEST] access"
#define HARNESS_DB_CONFIG "bansystem"
#define HARNESS_CACHE_CONFIG "bansystemcache"

enum eHarnessOperation
{
	kHarnessOp_None = 0,
	kHarnessOp_CommChatBan,
	kHarnessOp_CommChatUnban,
	kHarnessOp_CommMicBan,
	kHarnessOp_CommMicUnban,
	kHarnessOp_AccessBan,
	kHarnessOp_AccessUnban
}

enum struct TestSession
{
	bool active;
	bool singleUserMode;
	int adminUserId;
	int playerAUserId;
	int playerBUserId;
	char playerAAuthId[64];
	char playerBAuthId[64];
	char playerAName[MAX_NAME_LENGTH];
	char playerBName[MAX_NAME_LENGTH];
	bool accessBanForwardSeen;
	bool accessUnbanForwardSeen;
	bool chatBanForwardSeen;
	bool chatUnbanForwardSeen;
	bool micBanForwardSeen;
	bool micUnbanForwardSeen;
	bool accessDisconnectSeen;
	bool commSuiteStarted;
	bool accessSuiteStarted;
	bool accessAttemptSuiteStarted;
	int expectedChecks;
	int completedChecks;
	int failedChecks;
}

TestSession g_eSession;
StringMap g_smPendingRequests;
Database g_dbHarness;
Database g_dbHarnessCache;
bool g_bHarnessDbReady;
bool g_bHarnessCacheReady;

public Plugin myinfo =
{
	name = "BanSystem Test",
	author = "lechuga",
	description = "Integration test harness for BanSystem with real players",
	version = "1.0.0",
	url = "https://github.com/AoC-Gamers/AoC-L4D2-Competitive"
};

public void OnPluginStart()
{
	g_smPendingRequests = new StringMap();
	g_bHarnessDbReady = false;
	g_bHarnessCacheReady = false;

	if (SQL_CheckConfig(HARNESS_DB_CONFIG))
		Database.Connect(OnHarnessDbConnected, HARNESS_DB_CONFIG);
	if (SQL_CheckConfig(HARNESS_CACHE_CONFIG))
		Database.Connect(OnHarnessCacheConnected, HARNESS_CACHE_CONFIG);

	RegAdminCmd("sm_bs_test_begin", Command_TestBegin, ADMFLAG_ROOT, "Start a BanSystem test session with two real players.");
	RegAdminCmd("sm_bs_test_status", Command_TestStatus, ADMFLAG_ROOT, "Show current BanSystem test session status.");
	RegAdminCmd("sm_bs_test_comm", Command_TestComm, ADMFLAG_ROOT, "Run communication integration tests over the current session.");
	RegAdminCmd("sm_bs_test_access", Command_TestAccess, ADMFLAG_ROOT, "Run access integration test over player A.");
	RegAdminCmd("sm_bs_test_access_unban", Command_TestAccessUnban, ADMFLAG_ROOT, "Unban player A after reconnecting.");
	RegAdminCmd("sm_bs_test_access_attempt", Command_TestAccessAttempt, ADMFLAG_ROOT, "Validate attempts_access after reconnecting a banned player.");
	RegAdminCmd("sm_bs_test_cleanup", Command_TestCleanup, ADMFLAG_ROOT, "Cleanup any active test bans for the current session.");
	RegAdminCmd("sm_bs_test_report", Command_TestReport, ADMFLAG_ROOT, "Show PASS/FAIL summary for the current test session.");
	RegAdminCmd("sm_bs_test_sqlite_status", Command_TestSQLiteStatus, ADMFLAG_ROOT, "Show SQLite harness connection status.");
	RegAdminCmd("sm_bs_test_sqlite_ls", Command_TestSQLiteList, ADMFLAG_ROOT, "List current SQLite BanCache_Valid rows.");
	RegAdminCmd("sm_bs_test_sqlite_a", Command_TestSQLitePlayerA, ADMFLAG_ROOT, "Validate SQLite cache entry for player A.");
	RegAdminCmd("sm_bs_test_sqlite_b", Command_TestSQLitePlayerB, ADMFLAG_ROOT, "Validate SQLite cache entry for player B.");
	RegAdminCmd("sm_bs_test_perm_comm", Command_TestPermanentComm, ADMFLAG_ROOT, "Create a permanent comm ban for SQLite validation.");
	RegAdminCmd("sm_bs_test_perm_access", Command_TestPermanentAccess, ADMFLAG_ROOT, "Create a permanent access ban for SQLite validation.");
	RegAdminCmd("sm_bs_test_reset", Command_TestReset, ADMFLAG_ROOT, "Reset the current test session.");
}

public void OnHarnessDbConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		g_bHarnessDbReady = false;
		delete db;
		PrintToServer("[BanSystem Test] MySQL validation disabled: %s", szError);
		return;
	}

	g_dbHarness = db;
	g_bHarnessDbReady = true;
	PrintToServer("[BanSystem Test] MySQL validation enabled using config '%s'.", HARNESS_DB_CONFIG);
}

public void OnHarnessCacheConnected(Database db, const char[] szError, any data)
{
	if (db == null || szError[0] != '\0')
	{
		g_bHarnessCacheReady = false;
		delete db;
		PrintToServer("[BanSystem Test] SQLite validation disabled: %s", szError);
		return;
	}

	g_dbHarnessCache = db;
	g_bHarnessCacheReady = true;
	PrintToServer("[BanSystem Test] SQLite validation enabled using config '%s'.", HARNESS_CACHE_CONFIG);
}

public void OnClientDisconnect(int iClient)
{
	if (!g_eSession.active || iClient <= SERVER_INDEX || iClient > MaxClients)
		return;

	int iUserId = GetClientUserId(iClient);
	if (iUserId == g_eSession.playerAUserId)
	{
		g_eSession.accessDisconnectSeen = true;
		g_eSession.playerAUserId = 0;
		return;
	}

	if (iUserId == g_eSession.playerBUserId)
		g_eSession.playerBUserId = 0;
}

public void OnClientAuthorized(int iClient, const char[] szAuth)
{
	if (!g_eSession.active || !bIsRealHuman(iClient))
		return;

	if (StrEqual(szAuth, g_eSession.playerAAuthId, false))
	{
		g_eSession.playerAUserId = GetClientUserId(iClient);
		GetClientName(iClient, g_eSession.playerAName, sizeof(g_eSession.playerAName));
		return;
	}

	if (StrEqual(szAuth, g_eSession.playerBAuthId, false))
	{
		g_eSession.playerBUserId = GetClientUserId(iClient);
		GetClientName(iClient, g_eSession.playerBName, sizeof(g_eSession.playerBName));
	}
}

bool bIsRealHuman(int iClient)
{
	return (iClient > SERVER_INDEX && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

int iResolveHarnessReplyClient()
{
	if (g_eSession.adminUserId == SERVER_INDEX)
		return SERVER_INDEX;

	int iClient = GetClientOfUserId(g_eSession.adminUserId);
	if (iClient > SERVER_INDEX)
		return iClient;

	return SERVER_INDEX;
}

void vRefreshSessionBindings()
{
	if (!g_eSession.active)
		return;

	int iPlayerA = FindClientBySteamID2(g_eSession.playerAAuthId);
	if (bIsRealHuman(iPlayerA))
	{
		g_eSession.playerAUserId = GetClientUserId(iPlayerA);
		GetClientName(iPlayerA, g_eSession.playerAName, sizeof(g_eSession.playerAName));
	}

	if (g_eSession.singleUserMode || g_eSession.playerBAuthId[0] == '\0')
		return;

	int iPlayerB = FindClientBySteamID2(g_eSession.playerBAuthId);
	if (bIsRealHuman(iPlayerB))
	{
		g_eSession.playerBUserId = GetClientUserId(iPlayerB);
		GetClientName(iPlayerB, g_eSession.playerBName, sizeof(g_eSession.playerBName));
	}
}

void vHarnessReply(const char[] szMessage, any ...)
{
	char szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);

	int iClient = iResolveHarnessReplyClient();
	if (iClient == SERVER_INDEX)
		PrintToServer("[BanSystem Test] %s", szBuffer);
	else
		ReplyToCommand(iClient, "[BanSystem Test] %s", szBuffer);
}

void vResetTestSession()
{
	g_eSession.active = false;
	g_eSession.singleUserMode = false;
	g_eSession.adminUserId = SERVER_INDEX;
	g_eSession.playerAUserId = 0;
	g_eSession.playerBUserId = 0;
	g_eSession.playerAAuthId[0] = '\0';
	g_eSession.playerBAuthId[0] = '\0';
	g_eSession.playerAName[0] = '\0';
	g_eSession.playerBName[0] = '\0';
	g_eSession.accessBanForwardSeen = false;
	g_eSession.accessUnbanForwardSeen = false;
	g_eSession.chatBanForwardSeen = false;
	g_eSession.chatUnbanForwardSeen = false;
	g_eSession.micBanForwardSeen = false;
	g_eSession.micUnbanForwardSeen = false;
	g_eSession.accessDisconnectSeen = false;
	g_eSession.commSuiteStarted = false;
	g_eSession.accessSuiteStarted = false;
	g_eSession.accessAttemptSuiteStarted = false;
	g_eSession.expectedChecks = 0;
	g_eSession.completedChecks = 0;
	g_eSession.failedChecks = 0;
	g_smPendingRequests.Clear();
}

void vRegisterExpectedChecks(int iCount)
{
	g_eSession.expectedChecks += iCount;
}

void vRecordCheckResult(const char[] szLabel, bool bOk)
{
	g_eSession.completedChecks++;
	if (!bOk)
		g_eSession.failedChecks++;

	vHarnessReply("check %s: %s", szLabel, bOk ? "PASS" : "FAIL");
}

void vSchedulePhaseVerification(eHarnessOperation eOperation)
{
	float flDelay = 0.5;
	if (eOperation == kHarnessOp_AccessBan)
		flDelay = 1.0;

	CreateTimer(flDelay, Timer_HarnessPhaseVerification, view_as<any>(eOperation), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_HarnessPhaseVerification(Handle hTimer, any data)
{
	if (!g_eSession.active)
		return Plugin_Stop;

	vRefreshSessionBindings();

	eHarnessOperation eOperation = view_as<eHarnessOperation>(data);

	switch (eOperation)
	{
		case kHarnessOp_CommChatBan:
		{
			int iPlayerA = GetClientOfUserId(g_eSession.playerAUserId);
			bool bStateOk = bIsRealHuman(iPlayerA) && bBSBannedComm(iPlayerA, kChat);
			vRecordCheckResult("state-comm-chat-ban", bStateOk);
			vRecordCheckResult("forward-comm-chat-ban", g_eSession.chatBanForwardSeen);
			vValidateCommBanDb(g_eSession.playerAAuthId, view_as<int>(kChat), TEST_REASON_COMM_CHAT, iGetHarnessAdminAccountId(), kHarnessOp_CommChatBan);

			int iRequestIdNext = iBSUnbanCommAsync(iResolveHarnessReplyClient(), iPlayerA, g_eSession.playerAAuthId, OnBanSystemHarnessAsyncFinished, 0);
			vTrackRequest(iRequestIdNext, kHarnessOp_CommChatUnban);
		}

		case kHarnessOp_CommChatUnban:
		{
			int iPlayerA = GetClientOfUserId(g_eSession.playerAUserId);
			bool bStateOk = (iPlayerA <= SERVER_INDEX) ? true : !bBSBannedComm(iPlayerA, kChat);
			vRecordCheckResult("state-comm-chat-unban", bStateOk);
			vRecordCheckResult("forward-comm-chat-unban", g_eSession.chatUnbanForwardSeen);
			vValidateCommUnbanDb(g_eSession.playerAAuthId, kHarnessOp_CommChatUnban);

			if (g_eSession.singleUserMode)
			{
				int iRequestIdNext = iBSBanCommAsync(iResolveHarnessReplyClient(), iPlayerA, g_eSession.playerAAuthId, kMic, 10, TEST_REASON_COMM_MIC, OnBanSystemHarnessAsyncFinished, 0);
				vTrackRequest(iRequestIdNext, kHarnessOp_CommMicBan);
			}
		}

		case kHarnessOp_CommMicBan:
		{
			int iPlayerB = g_eSession.singleUserMode ? GetClientOfUserId(g_eSession.playerAUserId) : GetClientOfUserId(g_eSession.playerBUserId);
			char szTargetAuthId[64];
			strcopy(szTargetAuthId, sizeof(szTargetAuthId), g_eSession.singleUserMode ? g_eSession.playerAAuthId : g_eSession.playerBAuthId);
			bool bStateOk = bIsRealHuman(iPlayerB) && bBSBannedComm(iPlayerB, kMic);
			vRecordCheckResult("state-comm-mic-ban", bStateOk);
			vRecordCheckResult("forward-comm-mic-ban", g_eSession.micBanForwardSeen);
			vValidateCommBanDb(szTargetAuthId, view_as<int>(kMic), TEST_REASON_COMM_MIC, iGetHarnessAdminAccountId(), kHarnessOp_CommMicBan);

			int iRequestIdNext = iBSUnbanCommAsync(iResolveHarnessReplyClient(), iPlayerB, szTargetAuthId, OnBanSystemHarnessAsyncFinished, 0);
			vTrackRequest(iRequestIdNext, kHarnessOp_CommMicUnban);
		}

		case kHarnessOp_CommMicUnban:
		{
			int iPlayerB = g_eSession.singleUserMode ? GetClientOfUserId(g_eSession.playerAUserId) : GetClientOfUserId(g_eSession.playerBUserId);
			char szTargetAuthId[64];
			strcopy(szTargetAuthId, sizeof(szTargetAuthId), g_eSession.singleUserMode ? g_eSession.playerAAuthId : g_eSession.playerBAuthId);
			bool bStateOk = (iPlayerB <= SERVER_INDEX) ? true : !bBSBannedComm(iPlayerB, kMic);
			vRecordCheckResult("state-comm-mic-unban", bStateOk);
			vRecordCheckResult("forward-comm-mic-unban", g_eSession.micUnbanForwardSeen);
			vValidateCommUnbanDb(szTargetAuthId, kHarnessOp_CommMicUnban);
		}

		case kHarnessOp_AccessBan:
		{
			vRecordCheckResult("forward-access-ban", g_eSession.accessBanForwardSeen);
			vRecordCheckResult("disconnect-access-ban", g_eSession.accessDisconnectSeen);
			vValidateAccessBanDb(g_eSession.playerAAuthId, TEST_REASON_ACCESS, iGetHarnessAdminAccountId(), kHarnessOp_AccessBan);
		}

		case kHarnessOp_AccessUnban:
		{
			vRecordCheckResult("forward-access-unban", g_eSession.accessUnbanForwardSeen);
			vValidateAccessUnbanDb(g_eSession.playerAAuthId, kHarnessOp_AccessUnban);
		}
	}

	return Plugin_Stop;
}

bool bCapturePlayerIdentity(int iClient, char[] szAuthId, int iAuthIdMaxLength, char[] szName, int iNameMaxLength)
{
	if (!bIsRealHuman(iClient))
		return false;

	if (!GetClientAuthId(iClient, AuthId_Steam2, szAuthId, iAuthIdMaxLength))
		return false;

	if (!GetClientName(iClient, szName, iNameMaxLength))
		strcopy(szName, iNameMaxLength, "unknown");

	return true;
}

void vTrackRequest(int iRequestId, eHarnessOperation eOperation)
{
	if (iRequestId <= 0)
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_smPendingRequests.SetValue(szRequestId, view_as<int>(eOperation));
}

bool bPopRequestOperation(int iRequestId, eHarnessOperation &eOperation)
{
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	int iOperation;
	if (!g_smPendingRequests.GetValue(szRequestId, iOperation))
		return false;

	g_smPendingRequests.Remove(szRequestId);
	eOperation = view_as<eHarnessOperation>(iOperation);
	return true;
}

int iGetHarnessAdminAccountId()
{
	int iAdmin = iResolveHarnessReplyClient();
	if (!bIsRealHuman(iAdmin))
		return 0;

	char szAuthId[64];
	if (!GetClientAuthId(iAdmin, AuthId_Steam2, szAuthId, sizeof(szAuthId)))
		return 0;

	return SteamID2ToAccountID(szAuthId);
}

bool bGetAccountIdFromSteam2(const char[] szAuthId, int &iAccountId)
{
	iAccountId = SteamID2ToAccountID(szAuthId);
	return (iAccountId > 0);
}

bool bTryResolveSessionAccountId(bool bPlayerA, int &iAccountId, char[] szName, int iNameMaxLength)
{
	char szAuthId[64];
	strcopy(szAuthId, sizeof(szAuthId), bPlayerA ? g_eSession.playerAAuthId : g_eSession.playerBAuthId);
	strcopy(szName, iNameMaxLength, bPlayerA ? g_eSession.playerAName : g_eSession.playerBName);
	return bGetAccountIdFromSteam2(szAuthId, iAccountId);
}

void vScheduleSQLiteVerification(int iAccountId, int iExpectedBanId, const char[] szLabel)
{
	DataPack pData = new DataPack();
	pData.WriteCell(iAccountId);
	pData.WriteCell(iExpectedBanId);
	pData.WriteString(szLabel);
	CreateTimer(1.0, Timer_HarnessSQLiteVerification, pData, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_HarnessSQLiteVerification(Handle hTimer, any data)
{
	DataPack pData = view_as<DataPack>(data);
	pData.Reset();
	int iAccountId = pData.ReadCell();
	int iExpectedBanId = pData.ReadCell();
	char szLabel[64];
	pData.ReadString(szLabel, sizeof(szLabel));
	delete pData;

	if (!g_bHarnessCacheReady || g_dbHarnessCache == null)
	{
		vSQLiteReply("sqlite validation skipped for %s: cache DB not ready", szLabel);
		return Plugin_Stop;
	}

	char szQuery[256];
	g_dbHarnessCache.Format(szQuery, sizeof(szQuery), "SELECT `ban_id`, `date_cache` FROM `BanCache_Valid` WHERE `account_id` = %d;", iAccountId);

	DataPack pQueryData = new DataPack();
	pQueryData.WriteCell(iAccountId);
	pQueryData.WriteCell(iExpectedBanId);
	pQueryData.WriteString(szLabel);
	SQL_TQuery(g_dbHarnessCache, OnHarnessSQLiteVerifyQuery, szQuery, pQueryData);
	return Plugin_Stop;
}

public void OnHarnessSQLiteVerifyQuery(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pData = view_as<DataPack>(data);
	pData.Reset();
	int iAccountId = pData.ReadCell();
	int iExpectedBanId = pData.ReadCell();
	char szLabel[64];
	pData.ReadString(szLabel, sizeof(szLabel));
	delete pData;

	if (rsResult == null || szError[0] != '\0')
	{
		vSQLiteReply("sqlite verify error for %s (%d): %s", szLabel, iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		vSQLiteReply("sqlite %s: FAIL empty", szLabel);
		delete rsResult;
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	char szDate[64];
	rsResult.FetchString(1, szDate, sizeof(szDate));
	vSQLiteReply("sqlite %s: %s ban_id=%d expected=%d account_id=%d date_cache=%s",
		szLabel,
		(iBanId == iExpectedBanId) ? "PASS" : "FAIL",
		iBanId,
		iExpectedBanId,
		iAccountId,
		szDate);
	delete rsResult;
}

void vStartDbValidation(const char[] szQuery, eHarnessOperation eOperation)
{
	if (!g_bHarnessDbReady || g_dbHarness == null)
	{
		vHarnessReply("db validation skipped: harness DB not ready");
		return;
	}

	DataPack pData = new DataPack();
	pData.WriteCell(view_as<int>(eOperation));
	SQL_TQuery(g_dbHarness, OnHarnessValidationQuery, szQuery, pData);
}

public void OnHarnessValidationQuery(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pData = view_as<DataPack>(data);
	pData.Reset();
	eHarnessOperation eOperation = view_as<eHarnessOperation>(pData.ReadCell());
	delete pData;

	if (rsResult == null || szError[0] != '\0')
	{
		vHarnessReply("db validation error on op %d: %s", view_as<int>(eOperation), szError);
		delete rsResult;
		return;
	}

	switch (eOperation)
	{
		case kHarnessOp_CommChatBan:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) > 0;
			vRecordCheckResult("db-comm-chat-ban", bOk);
		}
		case kHarnessOp_CommChatUnban:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) == 0;
			vRecordCheckResult("db-comm-chat-unban", bOk);
		}
		case kHarnessOp_CommMicBan:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) > 0;
			vRecordCheckResult("db-comm-mic-ban", bOk);
		}
		case kHarnessOp_CommMicUnban:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) == 0;
			vRecordCheckResult("db-comm-mic-unban", bOk);
		}
		case kHarnessOp_AccessBan:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) > 0;
			vRecordCheckResult("db-access-ban", bOk);
		}
		case kHarnessOp_AccessUnban:
		{
			bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) == 0;
			vRecordCheckResult("db-access-unban", bOk);
		}
	}

	delete rsResult;
}

void vValidateCommBanDb(const char[] szAuthId, int iExpectedType, const char[] szReason, int iExpectedAdminAccountId, eHarnessOperation eOperation)
{
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		vHarnessReply("db validation skipped: invalid auth id %s", szAuthId);
		return;
	}

	char szReasonEscaped[512];
	g_dbHarness.Escape(szReason, szReasonEscaped, sizeof(szReasonEscaped));

	char szQuery[512];
	g_dbHarness.Format(szQuery, sizeof(szQuery),
		"SELECT COUNT(*) FROM `bans_communication` WHERE `accountid` = %d AND `ban_type` = %d AND `ban_reason` = '%s' AND `banned_by` = %d;",
		iAccountId, iExpectedType, szReasonEscaped, iExpectedAdminAccountId);
	vStartDbValidation(szQuery, eOperation);
}

void vValidateCommUnbanDb(const char[] szAuthId, eHarnessOperation eOperation)
{
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		vHarnessReply("db validation skipped: invalid auth id %s", szAuthId);
		return;
	}

	char szQuery[256];
	g_dbHarness.Format(szQuery, sizeof(szQuery), "SELECT COUNT(*) FROM `bans_communication` WHERE `accountid` = %d;", iAccountId);
	vStartDbValidation(szQuery, eOperation);
}

void vValidateAccessBanDb(const char[] szAuthId, const char[] szReason, int iExpectedAdminAccountId, eHarnessOperation eOperation)
{
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		vHarnessReply("db validation skipped: invalid auth id %s", szAuthId);
		return;
	}

	char szReasonEscaped[512];
	g_dbHarness.Escape(szReason, szReasonEscaped, sizeof(szReasonEscaped));

	char szQuery[512];
	g_dbHarness.Format(szQuery, sizeof(szQuery),
		"SELECT COUNT(*) FROM `bans_access` WHERE `accountid` = %d AND `ban_reason` = '%s' AND `banned_by` = %d;",
		iAccountId, szReasonEscaped, iExpectedAdminAccountId);
	vStartDbValidation(szQuery, eOperation);
}

void vValidateAccessUnbanDb(const char[] szAuthId, eHarnessOperation eOperation)
{
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		vHarnessReply("db validation skipped: invalid auth id %s", szAuthId);
		return;
	}

	char szQuery[256];
	g_dbHarness.Format(szQuery, sizeof(szQuery), "SELECT COUNT(*) FROM `bans_access` WHERE `accountid` = %d;", iAccountId);
	vStartDbValidation(szQuery, eOperation);
}

void vValidateAccessAttemptDb(const char[] szAuthId)
{
	if (!g_bHarnessDbReady || g_dbHarness == null)
	{
		vHarnessReply("db validation skipped: harness DB not ready");
		return;
	}

	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		vHarnessReply("db validation skipped: invalid auth id %s", szAuthId);
		return;
	}

	char szQuery[256];
	g_dbHarness.Format(szQuery, sizeof(szQuery), "SELECT COUNT(*) FROM `attempts_access` WHERE `accountid` = %d;", iAccountId);

	DataPack pData = new DataPack();
	pData.WriteCell(9999);
	SQL_TQuery(g_dbHarness, OnHarnessAttemptValidationQuery, szQuery, pData);
}

public void OnHarnessAttemptValidationQuery(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	delete view_as<DataPack>(data);

	if (rsResult == null || szError[0] != '\0')
	{
		vHarnessReply("db validation error on attempts_access: %s", szError);
		delete rsResult;
		return;
	}

	bool bOk = rsResult.FetchRow() && rsResult.FetchInt(0) > 0;
	vRecordCheckResult("db-access-attempt", bOk);
	delete rsResult;
}

void vSQLiteReply(const char[] szMessage, any ...)
{
	char szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	vHarnessReply("%s", szBuffer);
}

void vQuerySQLiteByAccountId(int iAccountId, const char[] szLabel)
{
	if (!g_bHarnessCacheReady || g_dbHarnessCache == null)
	{
		vSQLiteReply("sqlite validation skipped: cache DB not ready");
		return;
	}

	char szQuery[256];
	g_dbHarnessCache.Format(szQuery, sizeof(szQuery), "SELECT `ban_id`, `account_id`, `date_cache` FROM `BanCache_Valid` WHERE `account_id` = %d;", iAccountId);

	DataPack pData = new DataPack();
	pData.WriteCell(iAccountId);
	pData.WriteString(szLabel);
	SQL_TQuery(g_dbHarnessCache, OnHarnessSQLiteAccountQuery, szQuery, pData);
}

public void OnHarnessSQLiteAccountQuery(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	DataPack pData = view_as<DataPack>(data);
	pData.Reset();
	int iAccountId = pData.ReadCell();
	char szLabel[64];
	pData.ReadString(szLabel, sizeof(szLabel));
	delete pData;

	if (rsResult == null || szError[0] != '\0')
	{
		vSQLiteReply("sqlite query error for %s (%d): %s", szLabel, iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		vSQLiteReply("sqlite %s: empty", szLabel);
		delete rsResult;
		return;
	}

	int iBanId = rsResult.FetchInt(0);
	char szDate[64];
	rsResult.FetchString(2, szDate, sizeof(szDate));
	vSQLiteReply("sqlite %s: ban_id=%d account_id=%d date_cache=%s", szLabel, iBanId, iAccountId, szDate);
	delete rsResult;
}

Action Command_TestSQLiteStatus(int iClient, int iArgs)
{
	ReplyToCommand(iClient, "[BanSystem Test] sqlite ready=%d config=%s", g_bHarnessCacheReady, HARNESS_CACHE_CONFIG);
	return Plugin_Handled;
}

Action Command_TestSQLiteList(int iClient, int iArgs)
{
	if (!g_bHarnessCacheReady || g_dbHarnessCache == null)
	{
		ReplyToCommand(iClient, "[BanSystem Test] sqlite cache DB not ready");
		return Plugin_Handled;
	}

	char szQuery[256];
	strcopy(szQuery, sizeof(szQuery), "SELECT `ban_id`, `account_id`, `date_cache` FROM `BanCache_Valid` ORDER BY `date_cache` DESC;");
	SQL_TQuery(g_dbHarnessCache, OnHarnessSQLiteListQuery, szQuery, iResolveHarnessReplyClient());
	return Plugin_Handled;
}

public void OnHarnessSQLiteListQuery(Database db, DBResultSet rsResult, const char[] szError, any data)
{
	if (rsResult == null || szError[0] != '\0')
	{
		vHarnessReply("sqlite list error: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		vHarnessReply("sqlite list: empty");
		delete rsResult;
		return;
	}

	vHarnessReply("sqlite list:");
	do
	{
		char szDate[64];
		rsResult.FetchString(2, szDate, sizeof(szDate));
		vHarnessReply("row ban_id=%d account_id=%d date_cache=%s", rsResult.FetchInt(0), rsResult.FetchInt(1), szDate);
	} while (rsResult.FetchRow());

	delete rsResult;
}

Action Command_TestSQLitePlayerA(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	int iAccountId;
	char szName[MAX_NAME_LENGTH];
	if (!bTryResolveSessionAccountId(true, iAccountId, szName, sizeof(szName)))
	{
		ReplyToCommand(iClient, "[BanSystem Test] invalid session player A");
		return Plugin_Handled;
	}

	vQuerySQLiteByAccountId(iAccountId, szName);
	return Plugin_Handled;
}

Action Command_TestSQLitePlayerB(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	int iAccountId;
	char szName[MAX_NAME_LENGTH];
	if (!bTryResolveSessionAccountId(false, iAccountId, szName, sizeof(szName)))
	{
		ReplyToCommand(iClient, "[BanSystem Test] invalid session player B");
		return Plugin_Handled;
	}

	vQuerySQLiteByAccountId(iAccountId, szName);
	return Plugin_Handled;
}

Action Command_TestPermanentComm(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BanSystem Test] Usage: sm_bs_test_perm_comm <a|b> <mic|chat|all>");
		return Plugin_Handled;
	}

	char szPlayer[8];
	char szType[16];
	GetCmdArg(1, szPlayer, sizeof(szPlayer));
	GetCmdArg(2, szType, sizeof(szType));

	bool bPlayerA = StrEqual(szPlayer, "a", false);
	bool bPlayerB = StrEqual(szPlayer, "b", false);
	if (!bPlayerA && !bPlayerB)
	{
		ReplyToCommand(iClient, "[BanSystem Test] first arg must be a or b");
		return Plugin_Handled;
	}

	eTypeComms eType;
	if (StrEqual(szType, "mic", false))
		eType = kMic;
	else if (StrEqual(szType, "chat", false))
		eType = kChat;
	else if (StrEqual(szType, "all", false))
		eType = kAll;
	else
	{
		ReplyToCommand(iClient, "[BanSystem Test] second arg must be mic, chat or all");
		return Plugin_Handled;
	}

	int iTarget = GetClientOfUserId(bPlayerA ? g_eSession.playerAUserId : g_eSession.playerBUserId);
	char szAuthId[64];
	strcopy(szAuthId, sizeof(szAuthId), bPlayerA ? g_eSession.playerAAuthId : g_eSession.playerBAuthId);
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		ReplyToCommand(iClient, "[BanSystem Test] failed to resolve account_id for target");
		return Plugin_Handled;
	}

	if (iTarget <= SERVER_INDEX)
		iTarget = NO_INDEX;

	int iRequestId = iBSBanCommAsync(iClient, iTarget, szAuthId, eType, 0, "[TEST] sqlite perm comm", OnBanSystemHarnessAsyncFinished, 0);
	if (iRequestId <= 0)
	{
		ReplyToCommand(iClient, "[BanSystem Test] failed to queue permanent comm ban");
		return Plugin_Handled;
	}

	int iExpectedBanId = view_as<int>(eType) + 1;
	vScheduleSQLiteVerification(iAccountId, iExpectedBanId, bPlayerA ? g_eSession.playerAName : g_eSession.playerBName);
	vHarnessReply("queued permanent comm ban for %s (%s); SQLite will be checked automatically and can be listed with sm_bs_test_sqlite_%s", bPlayerA ? g_eSession.playerAName : g_eSession.playerBName, szType, bPlayerA ? "a" : "b");
	return Plugin_Handled;
}

Action Command_TestPermanentAccess(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[BanSystem Test] Usage: sm_bs_test_perm_access <a|b>");
		return Plugin_Handled;
	}

	char szPlayer[8];
	GetCmdArg(1, szPlayer, sizeof(szPlayer));

	bool bPlayerA = StrEqual(szPlayer, "a", false);
	bool bPlayerB = StrEqual(szPlayer, "b", false);
	if (!bPlayerA && !bPlayerB)
	{
		ReplyToCommand(iClient, "[BanSystem Test] arg must be a or b");
		return Plugin_Handled;
	}

	int iTarget = GetClientOfUserId(bPlayerA ? g_eSession.playerAUserId : g_eSession.playerBUserId);
	char szAuthId[64];
	strcopy(szAuthId, sizeof(szAuthId), bPlayerA ? g_eSession.playerAAuthId : g_eSession.playerBAuthId);
	int iAccountId;
	if (!bGetAccountIdFromSteam2(szAuthId, iAccountId))
	{
		ReplyToCommand(iClient, "[BanSystem Test] failed to resolve account_id for target");
		return Plugin_Handled;
	}

	if (iTarget <= SERVER_INDEX)
		iTarget = NO_INDEX;

	int iRequestId = iBSBanAccessAsync(iClient, iTarget, szAuthId, 0, "[TEST] sqlite perm access", OnBanSystemHarnessAsyncFinished, 0);
	if (iRequestId <= 0)
	{
		ReplyToCommand(iClient, "[BanSystem Test] failed to queue permanent access ban");
		return Plugin_Handled;
	}

	vScheduleSQLiteVerification(iAccountId, 1, bPlayerA ? g_eSession.playerAName : g_eSession.playerBName);
	vHarnessReply("queued permanent access ban for %s; SQLite will be checked automatically and can be listed with sm_bs_test_sqlite_%s", bPlayerA ? g_eSession.playerAName : g_eSession.playerBName, bPlayerA ? "a" : "b");
	return Plugin_Handled;
}

int iResolveTargetForHarness(int iAdmin, const char[] szTargetArg)
{
	return FindTarget(iAdmin, szTargetArg, true, false);
}

Action Command_TestBegin(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[BanSystem Test] Usage: sm_bs_test_begin <playerA> [playerB]");
		return Plugin_Handled;
	}

	char szTargetA[64];
	char szTargetB[64];
	GetCmdArg(1, szTargetA, sizeof(szTargetA));

	int iPlayerA = iResolveTargetForHarness(iClient, szTargetA);
	int iPlayerB = NO_INDEX;
	bool bSingleUserMode = (iArgs < 2);
	if (!bSingleUserMode)
	{
		GetCmdArg(2, szTargetB, sizeof(szTargetB));
		iPlayerB = iResolveTargetForHarness(iClient, szTargetB);
	}

	if (!bIsRealHuman(iPlayerA))
	{
		ReplyToCommand(iClient, "[BanSystem Test] Player A must be a real connected player.");
		return Plugin_Handled;
	}

	if (!bSingleUserMode && (!bIsRealHuman(iPlayerB) || iPlayerA == iPlayerB))
	{
		ReplyToCommand(iClient, "[BanSystem Test] Two different real players are required for two-player mode.");
		return Plugin_Handled;
	}

	vResetTestSession();
	g_eSession.active = true;
	g_eSession.singleUserMode = bSingleUserMode;
	g_eSession.adminUserId = (iClient == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(iClient);
	g_eSession.playerAUserId = GetClientUserId(iPlayerA);

	if (!bCapturePlayerIdentity(iPlayerA, g_eSession.playerAAuthId, sizeof(g_eSession.playerAAuthId), g_eSession.playerAName, sizeof(g_eSession.playerAName)))
	{
		vResetTestSession();
		ReplyToCommand(iClient, "[BanSystem Test] Failed to capture player identity.");
		return Plugin_Handled;
	}

	if (!bSingleUserMode)
	{
		g_eSession.playerBUserId = GetClientUserId(iPlayerB);
		if (!bCapturePlayerIdentity(iPlayerB, g_eSession.playerBAuthId, sizeof(g_eSession.playerBAuthId), g_eSession.playerBName, sizeof(g_eSession.playerBName)))
		{
			vResetTestSession();
			ReplyToCommand(iClient, "[BanSystem Test] Failed to capture player identity.");
			return Plugin_Handled;
		}
	}

	if (g_eSession.singleUserMode)
		vHarnessReply("session started: A=%s (%s) [single-user mode]", g_eSession.playerAName, g_eSession.playerAAuthId);
	else
		vHarnessReply("session started: A=%s (%s), B=%s (%s)", g_eSession.playerAName, g_eSession.playerAAuthId, g_eSession.playerBName, g_eSession.playerBAuthId);
	vHarnessReply("next steps: sm_bs_test_comm, sm_bs_test_access, sm_bs_test_cleanup");
	return Plugin_Handled;
}

Action Command_TestStatus(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] no active session");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();

	if (g_eSession.singleUserMode)
	{
		ReplyToCommand(iClient, "[BanSystem Test] mode=single | A=%s (%s) | access-ban=%d access-unban=%d disconnect=%d | chat-ban=%d chat-unban=%d | mic-ban=%d mic-unban=%d",
			g_eSession.playerAName,
			g_eSession.playerAAuthId,
			g_eSession.accessBanForwardSeen,
			g_eSession.accessUnbanForwardSeen,
			g_eSession.accessDisconnectSeen,
			g_eSession.chatBanForwardSeen,
			g_eSession.chatUnbanForwardSeen,
			g_eSession.micBanForwardSeen,
			g_eSession.micUnbanForwardSeen);
	}
	else
	{
		ReplyToCommand(iClient, "[BanSystem Test] mode=dual | A=%s (%s) | B=%s (%s) | access-ban=%d access-unban=%d disconnect=%d | chat-ban=%d chat-unban=%d | mic-ban=%d mic-unban=%d",
			g_eSession.playerAName,
			g_eSession.playerAAuthId,
			g_eSession.playerBName,
			g_eSession.playerBAuthId,
			g_eSession.accessBanForwardSeen,
			g_eSession.accessUnbanForwardSeen,
			g_eSession.accessDisconnectSeen,
			g_eSession.chatBanForwardSeen,
			g_eSession.chatUnbanForwardSeen,
			g_eSession.micBanForwardSeen,
			g_eSession.micUnbanForwardSeen);
	}
	return Plugin_Handled;
}

Action Command_TestComm(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();

	int iPlayerA = GetClientOfUserId(g_eSession.playerAUserId);
	int iPlayerB = GetClientOfUserId(g_eSession.playerBUserId);
	if (!bIsRealHuman(iPlayerA))
	{
		ReplyToCommand(iClient, "[BanSystem Test] player A must still be connected");
		return Plugin_Handled;
	}

	if (!g_eSession.singleUserMode && !bIsRealHuman(iPlayerB))
	{
		ReplyToCommand(iClient, "[BanSystem Test] player B must still be connected in two-player mode");
		return Plugin_Handled;
	}

	if (!g_eSession.commSuiteStarted)
	{
		g_eSession.commSuiteStarted = true;
		vRegisterExpectedChecks(12);
	}

	int iRequestId;
	iRequestId = iBSBanCommAsync(iClient, iPlayerA, g_eSession.playerAAuthId, kChat, 10, TEST_REASON_COMM_CHAT, OnBanSystemHarnessAsyncFinished, 0);
	vTrackRequest(iRequestId, kHarnessOp_CommChatBan);

	if (!g_eSession.singleUserMode)
	{
		iRequestId = iBSBanCommAsync(iClient, iPlayerB, g_eSession.playerBAuthId, kMic, 10, TEST_REASON_COMM_MIC, OnBanSystemHarnessAsyncFinished, 0);
		vTrackRequest(iRequestId, kHarnessOp_CommMicBan);
	}

	if (g_eSession.singleUserMode)
		vHarnessReply("queued communication tests over A(chat -> mic, serial single-user mode)");
	else
		vHarnessReply("queued communication tests over A(chat) and B(mic)");
	return Plugin_Handled;
}

Action Command_TestAccess(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();

	int iPlayerA = GetClientOfUserId(g_eSession.playerAUserId);
	if (!bIsRealHuman(iPlayerA))
	{
		ReplyToCommand(iClient, "[BanSystem Test] player A must be connected to run access test");
		return Plugin_Handled;
	}

	if (!g_eSession.accessSuiteStarted)
	{
		g_eSession.accessSuiteStarted = true;
		vRegisterExpectedChecks(5);
	}

	g_eSession.accessBanForwardSeen = false;
	g_eSession.accessDisconnectSeen = false;

	int iRequestId = iBSBanAccessAsync(iClient, iPlayerA, g_eSession.playerAAuthId, 10, TEST_REASON_ACCESS, OnBanSystemHarnessAsyncFinished, 0);
	vTrackRequest(iRequestId, kHarnessOp_AccessBan);

	vHarnessReply("queued access test over A=%s. Expect ban forward + kick/disconnect. After reconnect run sm_bs_test_access_unban.", g_eSession.playerAName);
	return Plugin_Handled;
}

Action Command_TestAccessUnban(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();

	int iRequestId = iBSUnbanAccessAsync(iClient, g_eSession.playerAAuthId, OnBanSystemHarnessAsyncFinished, 0);
	vTrackRequest(iRequestId, kHarnessOp_AccessUnban);
	vHarnessReply("queued access unban for A=%s", g_eSession.playerAName);
	return Plugin_Handled;
}

Action Command_TestAccessAttempt(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] start a session first with sm_bs_test_begin");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();

	if (!g_eSession.accessAttemptSuiteStarted)
	{
		g_eSession.accessAttemptSuiteStarted = true;
		vRegisterExpectedChecks(1);
	}

	vValidateAccessAttemptDb(g_eSession.playerAAuthId);
	return Plugin_Handled;
}

Action Command_TestCleanup(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] no active session");
		return Plugin_Handled;
	}

	vRefreshSessionBindings();
	iBSUnbanCommAsync(iClient, NO_INDEX, g_eSession.playerAAuthId);
	if (!g_eSession.singleUserMode && g_eSession.playerBAuthId[0] != '\0')
		iBSUnbanCommAsync(iClient, NO_INDEX, g_eSession.playerBAuthId);
	iBSUnbanAccessAsync(iClient, g_eSession.playerAAuthId);

	vHarnessReply("queued cleanup for current session");
	return Plugin_Handled;
}

Action Command_TestReset(int iClient, int iArgs)
{
	vResetTestSession();
	ReplyToCommand(iClient, "[BanSystem Test] session reset");
	return Plugin_Handled;
}

Action Command_TestReport(int iClient, int iArgs)
{
	if (!g_eSession.active)
	{
		ReplyToCommand(iClient, "[BanSystem Test] no active session");
		return Plugin_Handled;
	}

	int iPending = g_eSession.expectedChecks - g_eSession.completedChecks;
	if (iPending < 0)
		iPending = 0;

	char szStatus[16];
	strcopy(szStatus, sizeof(szStatus), "INCOMPLETE");
	if (g_eSession.completedChecks > 0 && iPending == 0)
		strcopy(szStatus, sizeof(szStatus), (g_eSession.failedChecks == 0) ? "PASS" : "FAIL");
	else if (g_eSession.failedChecks > 0)
		strcopy(szStatus, sizeof(szStatus), "FAIL");

	ReplyToCommand(iClient, "[BanSystem Test] summary=%s expected=%d completed=%d failed=%d pending=%d",
		szStatus,
		g_eSession.expectedChecks,
		g_eSession.completedChecks,
		g_eSession.failedChecks,
		iPending);
	return Plugin_Handled;
}

public void OnBanSystemHarnessAsyncFinished(int iRequestId, bool bAccepted, const char[] szResolvedAuthId, const char[] szError, any data)
{
	eHarnessOperation eOperation;
	if (!bPopRequestOperation(iRequestId, eOperation))
		return;

	if (!bAccepted)
	{
		vHarnessReply("request %d failed: %s", iRequestId, szError);
		return;
	}

	vSchedulePhaseVerification(eOperation);
}

public void vBSOnBanAccess(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason)
{
	if (!g_eSession.active)
		return;

	if (StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
		g_eSession.accessBanForwardSeen = true;
}

public void vBSOnUnbanAccess(int iAdmin, const char[] szTargetAuthId)
{
	if (!g_eSession.active)
		return;

	if (StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
		g_eSession.accessUnbanForwardSeen = true;
}

public void vBSOnBanMic(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason)
{
	if (!g_eSession.active)
		return;

	if ((g_eSession.singleUserMode && StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
	 || StrEqual(szTargetAuthId, g_eSession.playerBAuthId, false))
		g_eSession.micBanForwardSeen = true;
}

public void vBSOnUnbanMic(int iAdmin, int iTarget, const char[] szTargetAuthId)
{
	if (!g_eSession.active)
		return;

	if ((g_eSession.singleUserMode && StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
	 || StrEqual(szTargetAuthId, g_eSession.playerBAuthId, false))
		g_eSession.micUnbanForwardSeen = true;
}

public void vBSOnBanChat(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason)
{
	if (!g_eSession.active)
		return;

	if (StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
		g_eSession.chatBanForwardSeen = true;
}

public void vBSOnUnBanChat(int iAdmin, int iTarget, const char[] szTargetAuthId)
{
	if (!g_eSession.active)
		return;

	if (StrEqual(szTargetAuthId, g_eSession.playerAAuthId, false))
		g_eSession.chatUnbanForwardSeen = true;
}
