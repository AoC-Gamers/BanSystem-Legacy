#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#define REQUIRE_PLUGIN

#include <bansystem_core>
#include <bansystem_access>
#include <bansystem_comm>
#include <bansystem_sprays>

#define BANSYSTEM_MODULAR_TEST_VERSION "0.1.0-dev"

enum eBSModularTestStep
{
	kBSModularTestStep_None = 0,
	kBSModularTestStep_CommBanCheck,
	kBSModularTestStep_CommUnbanCheck,
	kBSModularTestStep_SpraysBanCheck,
	kBSModularTestStep_SpraysUnbanCheck,
	kBSModularTestStep_AccessBanCheck,
	kBSModularTestStep_AccessUnbanCheck
}

enum struct eBSModularTestSession
{
	bool m_bActive;
	int m_iAdminUserId;
	int m_iTargetUserId;
	int m_iAccountId;
	char m_szTargetName[MAX_NAME_LENGTH];
	int m_iExpectedChecks;
	int m_iPassedChecks;
	int m_iFailedChecks;
	bool m_bSawAccessDisconnect;
}

Database g_dbBSModularTest;
ConVar g_cvBSModularTestMysqlConfig;
eBSModularTestSession g_eBSModularTestSession;

public Plugin myinfo =
{
	name = "BanSystem Modular Test",
	author = "lechuga",
	description = "Test harness for BanSystem Core modular plugins.",
	version = BANSYSTEM_MODULAR_TEST_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public void OnPluginStart()
{
	g_cvBSModularTestMysqlConfig = CreateConVar("sm_bs_modtest_mysql_config", "bansystem", "MySQL config used by BanSystem Modular Test.", FCVAR_NONE);

	RegAdminCmd("sm_bs_modtest_begin", Command_BSModularTestBegin, ADMFLAG_ROOT, "Start a modular BanSystem test session.");
	RegAdminCmd("sm_bs_modtest_status", Command_BSModularTestStatus, ADMFLAG_ROOT, "Show modular BanSystem test session status.");
	RegAdminCmd("sm_bs_modtest_comm", Command_BSModularTestComm, ADMFLAG_ROOT, "Run the communication modular test.");
	RegAdminCmd("sm_bs_modtest_sprays", Command_BSModularTestSprays, ADMFLAG_ROOT, "Run the sprays modular test.");
	RegAdminCmd("sm_bs_modtest_access", Command_BSModularTestAccess, ADMFLAG_ROOT, "Run the access modular test.");
	RegAdminCmd("sm_bs_modtest_cleanup", Command_BSModularTestCleanup, ADMFLAG_ROOT, "Remove modular test bans for the active session.");
	RegAdminCmd("sm_bs_modtest_report", Command_BSModularTestReport, ADMFLAG_ROOT, "Show modular test PASS/FAIL report.");
}

public void OnConfigsExecuted()
{
	char szConfig[64];
	g_cvBSModularTestMysqlConfig.GetString(szConfig, sizeof(szConfig));
	SQL_TConnect(BSModularTest_OnConnect, szConfig);
}

public void OnClientAuthorized(int iClient, const char[] szAuth)
{
	if (!g_eBSModularTestSession.m_bActive || iClient <= 0 || !IsClientConnected(iClient) || IsFakeClient(iClient))
		return;

	int iAccountId = GetClientAccountID(iClient);
	if (iAccountId <= 0 || iAccountId != g_eBSModularTestSession.m_iAccountId)
		return;

	g_eBSModularTestSession.m_iTargetUserId = GetClientUserId(iClient);
	GetClientName(iClient, g_eBSModularTestSession.m_szTargetName, sizeof(g_eBSModularTestSession.m_szTargetName));
}

public void OnClientDisconnect(int iClient)
{
	if (!g_eBSModularTestSession.m_bActive || iClient <= 0 || iClient > MaxClients)
		return;

	if (GetClientUserId(iClient) != g_eBSModularTestSession.m_iTargetUserId)
		return;

	g_eBSModularTestSession.m_iTargetUserId = 0;
	g_eBSModularTestSession.m_bSawAccessDisconnect = true;
}

Action Command_BSModularTestBegin(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} Uso: sm_bs_modtest_begin <target>");
		return Plugin_Handled;
	}

	char szTarget[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));

	int iTarget = FindTarget(iClient, szTarget, true, false);
	if (iTarget <= 0)
		return Plugin_Handled;

	int iAccountId = GetClientAccountID(iTarget);
	if (iAccountId <= 0)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} No se pudo resolver accountid para el objetivo.");
		return Plugin_Handled;
	}

	g_eBSModularTestSession.m_bActive = true;
	g_eBSModularTestSession.m_iAdminUserId = GetClientUserId(iClient);
	g_eBSModularTestSession.m_iTargetUserId = GetClientUserId(iTarget);
	g_eBSModularTestSession.m_iAccountId = iAccountId;
	GetClientName(iTarget, g_eBSModularTestSession.m_szTargetName, sizeof(g_eBSModularTestSession.m_szTargetName));
	g_eBSModularTestSession.m_iExpectedChecks = 0;
	g_eBSModularTestSession.m_iPassedChecks = 0;
	g_eBSModularTestSession.m_iFailedChecks = 0;
	g_eBSModularTestSession.m_bSawAccessDisconnect = false;

	BSModularTest_Reply(
		iClient,
		"{olive}[BS Modular Test]{default} session started: target=%N accountid=%d. next steps: sm_bs_modtest_comm, sm_bs_modtest_sprays, sm_bs_modtest_access, sm_bs_modtest_report, sm_bs_modtest_cleanup",
		iTarget,
		iAccountId
	);
	return Plugin_Handled;
}

Action Command_BSModularTestStatus(int iClient, int iArgs)
{
	if (!g_eBSModularTestSession.m_bActive)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} no active session.");
		return Plugin_Handled;
	}

	int iTarget = BSModularTest_GetTargetClient();
	BSModularTest_Reply(
		iClient,
		"{olive}[BS Modular Test]{default} target=%s accountid=%d client=%d core_summary=%d access=%d comm=%d sprays=%d disconnect=%d checks=%d/%d/%d",
		g_eBSModularTestSession.m_szTargetName,
		g_eBSModularTestSession.m_iAccountId,
		iTarget,
		(iTarget > 0 && BSCore_HasResolvedSummary(iTarget)) ? 1 : 0,
		(iTarget > 0 && BSAccess_IsClientBanned(iTarget)) ? 1 : 0,
		(iTarget > 0 && BSComm_IsClientBanned(iTarget)) ? 1 : 0,
		(iTarget > 0 && BSSprays_IsClientBanned(iTarget)) ? 1 : 0,
		g_eBSModularTestSession.m_bSawAccessDisconnect ? 1 : 0,
		g_eBSModularTestSession.m_iPassedChecks,
		g_eBSModularTestSession.m_iFailedChecks,
		g_eBSModularTestSession.m_iExpectedChecks
	);
	return Plugin_Handled;
}

Action Command_BSModularTestComm(int iClient, int iArgs)
{
	if (!BSModularTest_CanRun(iClient, true))
		return Plugin_Handled;

	if (!BSComm_AddBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId, kBSCommType_Chat, 10, "[TEST] modular comm", ""))
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} failed to queue comm mutation.");
		return Plugin_Handled;
	}

	BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} queued comm test over accountid=%d", g_eBSModularTestSession.m_iAccountId);
	CreateTimer(1.0, Timer_BSModularTestCommBanCheck, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

Action Command_BSModularTestSprays(int iClient, int iArgs)
{
	if (!BSModularTest_CanRun(iClient, true))
		return Plugin_Handled;

	if (!BSSprays_AddBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId, 10, "[TEST] modular spray", ""))
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} failed to queue spray mutation.");
		return Plugin_Handled;
	}

	BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} queued sprays test over accountid=%d", g_eBSModularTestSession.m_iAccountId);
	CreateTimer(1.0, Timer_BSModularTestSpraysBanCheck, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

Action Command_BSModularTestAccess(int iClient, int iArgs)
{
	if (!BSModularTest_CanRun(iClient, false))
		return Plugin_Handled;

	g_eBSModularTestSession.m_bSawAccessDisconnect = false;
	if (!BSAccess_AddBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId, 10, "[TEST] modular access", ""))
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} failed to queue access mutation.");
		return Plugin_Handled;
	}

	BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} queued access test over accountid=%d. target should be kicked and auto-unbanned.", g_eBSModularTestSession.m_iAccountId);
	CreateTimer(1.2, Timer_BSModularTestAccessBanCheck, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

Action Command_BSModularTestCleanup(int iClient, int iArgs)
{
	if (!BSModularTest_CanRun(iClient, false))
		return Plugin_Handled;

	BSAccess_RemoveBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId);
	BSComm_RemoveBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId);
	BSSprays_RemoveBanByAccountId(iClient, g_eBSModularTestSession.m_iAccountId);
	BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} cleanup queued for accountid=%d", g_eBSModularTestSession.m_iAccountId);
	return Plugin_Handled;
}

Action Command_BSModularTestReport(int iClient, int iArgs)
{
	if (!g_eBSModularTestSession.m_bActive)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} no active session.");
		return Plugin_Handled;
	}

	char szResult[16];
	strcopy(szResult, sizeof(szResult), "INCOMPLETE");
	if (g_eBSModularTestSession.m_iFailedChecks > 0)
		strcopy(szResult, sizeof(szResult), "FAIL");
	else if (g_eBSModularTestSession.m_iExpectedChecks > 0 && g_eBSModularTestSession.m_iPassedChecks == g_eBSModularTestSession.m_iExpectedChecks)
		strcopy(szResult, sizeof(szResult), "PASS");

	BSModularTest_Reply(
		iClient,
		"{olive}[BS Modular Test]{default} report=%s passed=%d failed=%d expected=%d",
		szResult,
		g_eBSModularTestSession.m_iPassedChecks,
		g_eBSModularTestSession.m_iFailedChecks,
		g_eBSModularTestSession.m_iExpectedChecks
	);
	return Plugin_Handled;
}

public void BSModularTest_OnConnect(Handle hOwner, Handle hndl, const char[] szError, any data)
{
	if (hndl == null || szError[0] != '\0')
	{
		g_dbBSModularTest = null;
		PrintToServer("[BS Modular Test] DB connect failed: %s", szError);
		return;
	}

	g_dbBSModularTest = view_as<Database>(hndl);
	PrintToServer("[BS Modular Test] DB connected.");
}

public Action Timer_BSModularTestCommBanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_CommBanCheck, iUserId);
	return Plugin_Stop;
}

public Action Timer_BSModularTestCommUnbanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_CommUnbanCheck, iUserId);
	return Plugin_Stop;
}

public Action Timer_BSModularTestSpraysBanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_SpraysBanCheck, iUserId);
	return Plugin_Stop;
}

public Action Timer_BSModularTestSpraysUnbanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_SpraysUnbanCheck, iUserId);
	return Plugin_Stop;
}

public Action Timer_BSModularTestAccessBanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_AccessBanCheck, iUserId);
	return Plugin_Stop;
}

public Action Timer_BSModularTestAccessUnbanCheck(Handle hTimer, int iUserId)
{
	BSModularTest_QueueModuleStateCheck(kBSModularTestStep_AccessUnbanCheck, iUserId);
	return Plugin_Stop;
}

stock bool BSModularTest_CanRun(int iClient, bool bRequireConnectedTarget)
{
	if (!g_eBSModularTestSession.m_bActive)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} no active session.");
		return false;
	}

	if (g_dbBSModularTest == null)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} MySQL is not connected.");
		return false;
	}

	if (bRequireConnectedTarget && BSModularTest_GetTargetClient() <= 0)
	{
		BSModularTest_Reply(iClient, "{olive}[BS Modular Test]{default} target is not connected.");
		return false;
	}

	return true;
}

stock int BSModularTest_GetTargetClient()
{
	int iClient = GetClientOfUserId(g_eBSModularTestSession.m_iTargetUserId);
	if (iClient > 0 && IsClientInGame(iClient) && GetClientAccountID(iClient) == g_eBSModularTestSession.m_iAccountId)
		return iClient;

	iClient = FindClientByAccountID(g_eBSModularTestSession.m_iAccountId);
	if (iClient > 0 && IsClientInGame(iClient))
	{
		g_eBSModularTestSession.m_iTargetUserId = GetClientUserId(iClient);
		GetClientName(iClient, g_eBSModularTestSession.m_szTargetName, sizeof(g_eBSModularTestSession.m_szTargetName));
		return iClient;
	}

	return 0;
}

stock void BSModularTest_RecordCheck(int iAdminUserId, const char[] szName, bool bPass)
{
	g_eBSModularTestSession.m_iExpectedChecks++;
	if (bPass)
		g_eBSModularTestSession.m_iPassedChecks++;
	else
		g_eBSModularTestSession.m_iFailedChecks++;

	BSModularTest_ReplyByUserId(
		iAdminUserId,
		"{olive}[BS Modular Test]{default} check %s: %s",
		szName,
		bPass ? "{green}PASS{default}" : "{red}FAIL{default}"
	);
}

stock bool BSModularTest_SummaryHasModule(eBSCoreModuleBit eModuleMask, eBSCoreModuleBit eModuleBit)
{
	return ((view_as<int>(eModuleMask) & view_as<int>(eModuleBit)) != 0);
}

stock void BSModularTest_ReadModuleStateContext(DataPack pContext, int &iAdminUserId, eBSModularTestStep &eStep)
{
	pContext.Reset();
	iAdminUserId = pContext.ReadCell();
	eStep = view_as<eBSModularTestStep>(pContext.ReadCell());
}

stock void BSModularTest_QueueModuleStateCheck(eBSModularTestStep eStep, int iAdminUserId)
{
	if (g_dbBSModularTest == null || !g_eBSModularTestSession.m_bActive)
		return;

	char szQuery[768];
	int iAccountId = g_eBSModularTestSession.m_iAccountId;
	int iLen = 0;

	switch (eStep)
	{
		case kBSModularTestStep_CommBanCheck, kBSModularTestStep_CommUnbanCheck:
		{
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT ");
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "EXISTS(SELECT 1 FROM `bansystem_comm_bans` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP())) AS `module_active`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `module_mask` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `module_mask`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `comm_ban_id` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `ban_id`;", iAccountId);
		}

		case kBSModularTestStep_SpraysBanCheck, kBSModularTestStep_SpraysUnbanCheck:
		{
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT ");
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "EXISTS(SELECT 1 FROM `bansystem_spray_bans` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP())) AS `module_active`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `module_mask` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `module_mask`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `spray_ban_id` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `ban_id`;", iAccountId);
		}

		case kBSModularTestStep_AccessBanCheck, kBSModularTestStep_AccessUnbanCheck:
		{
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT ");
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "EXISTS(SELECT 1 FROM `bansystem_access_bans` WHERE `accountid` = %d AND (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP())) AS `module_active`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `module_mask` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `module_mask`, ", iAccountId);
			iLen += g_dbBSModularTest.Format(szQuery[iLen], sizeof(szQuery) - iLen, "IFNULL((SELECT `access_ban_id` FROM `bansystem_summary` WHERE `accountid` = %d LIMIT 1), 0) AS `ban_id`;", iAccountId);
		}

		default:
		{
			return;
		}
	}

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAdminUserId);
	pContext.WriteCell(view_as<int>(eStep));
	SQL_TQuery(g_dbBSModularTest, BSModularTest_OnModuleStateLoaded, szQuery, pContext, DBPrio_Normal);
}

public void BSModularTest_OnModuleStateLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	int iAdminUserId;
	eBSModularTestStep eStep;
	BSModularTest_ReadModuleStateContext(pContext, iAdminUserId, eStep);
	delete pContext;

	if (rsResult == null || szError[0] != '\0')
	{
		BSModularTest_ReplyByUserId(iAdminUserId, "{olive}[BS Modular Test]{default} state query failed: %s", szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		delete rsResult;
		BSModularTest_ReplyByUserId(iAdminUserId, "{olive}[BS Modular Test]{default} state query returned no row.");
		return;
	}

	bool bModuleActive = rsResult.FetchInt(0) != 0;
	eBSCoreModuleBit eModuleMask = view_as<eBSCoreModuleBit>(rsResult.FetchInt(1));
	int iBanId = rsResult.FetchInt(2);
	delete rsResult;

	int iTarget = BSModularTest_GetTargetClient();

	switch (eStep)
	{
		case kBSModularTestStep_CommBanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "state-comm-ban", iTarget > 0 && BSComm_IsClientBanned(iTarget));
			BSModularTest_RecordCheck(iAdminUserId, "db-comm-ban", bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-comm-ban", BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Communication) && iBanId > 0);
			BSComm_RemoveBanByAccountId(0, g_eBSModularTestSession.m_iAccountId);
			CreateTimer(1.0, Timer_BSModularTestCommUnbanCheck, iAdminUserId, TIMER_FLAG_NO_MAPCHANGE);
		}

		case kBSModularTestStep_CommUnbanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "state-comm-unban", iTarget <= 0 || !BSComm_IsClientBanned(iTarget));
			BSModularTest_RecordCheck(iAdminUserId, "db-comm-unban", !bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-comm-unban", !BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Communication) && iBanId == 0);
		}

		case kBSModularTestStep_SpraysBanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "state-sprays-ban", iTarget > 0 && BSSprays_IsClientBanned(iTarget));
			BSModularTest_RecordCheck(iAdminUserId, "db-sprays-ban", bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-sprays-ban", BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Sprays) && iBanId > 0);
			BSSprays_RemoveBanByAccountId(0, g_eBSModularTestSession.m_iAccountId);
			CreateTimer(1.0, Timer_BSModularTestSpraysUnbanCheck, iAdminUserId, TIMER_FLAG_NO_MAPCHANGE);
		}

		case kBSModularTestStep_SpraysUnbanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "state-sprays-unban", iTarget <= 0 || !BSSprays_IsClientBanned(iTarget));
			BSModularTest_RecordCheck(iAdminUserId, "db-sprays-unban", !bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-sprays-unban", !BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Sprays) && iBanId == 0);
		}

		case kBSModularTestStep_AccessBanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "disconnect-access-ban", g_eBSModularTestSession.m_bSawAccessDisconnect);
			BSModularTest_RecordCheck(iAdminUserId, "db-access-ban", bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-access-ban", BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Access) && iBanId > 0);
			BSAccess_RemoveBanByAccountId(0, g_eBSModularTestSession.m_iAccountId);
			CreateTimer(1.0, Timer_BSModularTestAccessUnbanCheck, iAdminUserId, TIMER_FLAG_NO_MAPCHANGE);
		}

		case kBSModularTestStep_AccessUnbanCheck:
		{
			BSModularTest_RecordCheck(iAdminUserId, "db-access-unban", !bModuleActive);
			BSModularTest_RecordCheck(iAdminUserId, "summary-access-unban", !BSModularTest_SummaryHasModule(eModuleMask, kBSCoreModule_Access) && iBanId == 0);
		}
	}
}

stock void BSModularTest_Reply(int iClient, const char[] szMessage, any ...)
{
	if (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient))
	{
		static char szBuffer[512];
		VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
		CReplyToCommand(iClient, "%s", szBuffer);
		return;
	}

	static char szServerBuffer[512];
	VFormat(szServerBuffer, sizeof(szServerBuffer), szMessage, 3);
	PrintToServer("%s", szServerBuffer);
}

stock void BSModularTest_ReplyByUserId(int iUserId, const char[] szMessage, any ...)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient > 0)
	{
		static char szBuffer[512];
		VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
		CReplyToCommand(iClient, "%s", szBuffer);
		return;
	}

	static char szServerBuffer[512];
	VFormat(szServerBuffer, sizeof(szServerBuffer), szMessage, 3);
	PrintToServer("%s", szServerBuffer);
}
