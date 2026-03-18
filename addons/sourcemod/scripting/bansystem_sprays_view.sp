#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <bansystem_shared>

#undef REQUIRE_PLUGIN
#include <steamidtools>
#define REQUIRE_PLUGIN

#define BANSYSTEM_SPRAYS_VIEW_VERSION "0.1.0-dev"
#define BANSYSTEM_SPRAYS_VIEW_LOG "logs/bansystem/BanSystem_SpraysView.log"

enum eBSSpraysViewInfoMask
{
	kBSSpraysViewInfo_None = 0,
	kBSSpraysViewInfo_Name = 1,
	kBSSpraysViewInfo_AccountId = 2,
	kBSSpraysViewInfo_Steam2 = 4,
	kBSSpraysViewInfo_Ip = 8
}

enum eBSSpraysViewTextLoc
{
	kBSSpraysViewTextLoc_Disabled = 0,
	kBSSpraysViewTextLoc_Hint = 1,
	kBSSpraysViewTextLoc_Center = 2
}

enum eBSSpraysViewDebugMask
{
	kBSSpraysViewDebug_None = 0,
	kBSSpraysViewDebug_General = 1,
	kBSSpraysViewDebug_Timer = 2,
	kBSSpraysViewDebug_Trace = 4,
	kBSSpraysViewDebug_Display = 8
}

ConVar g_cvBSSpraysViewEnabled;
ConVar g_cvBSSpraysViewTextLoc;
ConVar g_cvBSSpraysViewInfoMask;
ConVar g_cvBSSpraysViewDistance;
ConVar g_cvBSSpraysViewDebugMask;
ConVar g_cvBSLogMode;

char g_szBSSpraysViewLogPath[PLATFORM_MAX_PATH];
float g_vecBSSpraysViewPosition[MAXPLAYERS + 1][3];
char g_szBSSpraysViewInfo[MAXPLAYERS + 1][256];
bool g_bBSSpraysViewHasSpray[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "BanSystem Sprays View",
	author = "lechuga",
	description = "Displays spray owner information for BanSystem Sprays.",
	version = BANSYSTEM_SPRAYS_VIEW_VERSION,
	url = "https://github.com/AoC-Gamers/BanSystem"
};

public void OnPluginStart()
{
	BSEnsureLogFolder();
	BuildPath(Path_SM, g_szBSSpraysViewLogPath, sizeof(g_szBSSpraysViewLogPath), BANSYSTEM_SPRAYS_VIEW_LOG);
	LoadTranslations("common.phrases");
	LoadTranslations("bansystem_sprays_view.phrases");
	g_cvBSLogMode = BSEnsureLogModeConVar();

	g_cvBSSpraysViewEnabled = CreateConVar("sm_bs_sprays_view_enabled", "1", "Enable BanSystem spray owner display.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBSSpraysViewTextLoc = CreateConVar("sm_bs_sprays_view_textloc", "1", "Where spray owner info is displayed. 0=disabled, 1=hint, 2=center.", FCVAR_NONE, true, 0.0, true, 2.0);
	g_cvBSSpraysViewInfoMask = CreateConVar("sm_bs_sprays_view_info_mask", "3", "Spray owner info bitmask. 1=name, 2=accountid, 4=steam2, 8=ip, 15=all.", FCVAR_NONE, true, 1.0);
	g_cvBSSpraysViewDistance = CreateConVar("sm_bs_sprays_view_distance", "50.0", "Distance in units for detecting an aimed spray owner.", FCVAR_NONE, true, 1.0);
	g_cvBSSpraysViewDebugMask = CreateConVar("sm_bs_sprays_view_debug_mask", "0", "Debug bitmask. 1=general, 2=timer, 4=trace, 8=display.", FCVAR_NONE, true, 0.0);

	BSEnsureAutoExecFolder();
	AutoExecConfig(true, "bansystem_sprays_view", BANSYSTEM_AUTOEXEC_FOLDER);

	AddTempEntHook("Player Decal", BSSpraysView_OnPlayerDecal);
	CreateTimer(0.5, Timer_BSSpraysViewShowOwners, _, TIMER_REPEAT);
	BSSpraysView_NormalizeTextLocation();
	BSNormalLogToFileEx(g_cvBSLogMode, "[BanSystem SpraysView]", "startup", "Plugin started. version=%s", BANSYSTEM_SPRAYS_VIEW_VERSION);
}

public void OnMapStart()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		BSSpraysView_ResetClient(iClient);

	BSSpraysView_NormalizeTextLocation();
	BSSpraysView_Debug(kBSSpraysViewDebug_General, "Map start reset completed.");
}

public void OnClientPutInServer(int iClient)
{
	BSSpraysView_ResetClient(iClient);
	BSSpraysView_Debug(kBSSpraysViewDebug_General, "Client %d entered server; spray cache reset.", iClient);
}

public void OnClientDisconnect(int iClient)
{
	BSSpraysView_Debug(kBSSpraysViewDebug_General, "Client %d disconnected; spray cache cleared.", iClient);
	BSSpraysView_ResetClient(iClient);
}

stock eBSSpraysViewTextLoc BSSpraysView_GetTextLocation()
{
	return view_as<eBSSpraysViewTextLoc>(g_cvBSSpraysViewTextLoc.IntValue);
}

stock bool BSSpraysView_HasInfoFlag(int iMask, eBSSpraysViewInfoMask eFlag)
{
	return ((iMask & view_as<int>(eFlag)) != 0);
}

public Action BSSpraysView_OnPlayerDecal(const char[] szName, const int[] iClients, int iCount, float flDelay)
{
	if (!g_cvBSSpraysViewEnabled.BoolValue)
		return Plugin_Continue;

	int iClient = TE_ReadNum("m_nPlayer");
	if (!BSSpraysView_IsUsableClient(iClient))
		return Plugin_Continue;

	TE_ReadVector("m_vecOrigin", g_vecBSSpraysViewPosition[iClient]);
	g_bBSSpraysViewHasSpray[iClient] = true;
	BSSpraysView_BuildClientInfoString(iClient, g_szBSSpraysViewInfo[iClient], sizeof(g_szBSSpraysViewInfo[]));
	BSSpraysView_Debug(
		kBSSpraysViewDebug_General,
		"Stored spray owner info for client=%d accountid=%d pos=(%.2f, %.2f, %.2f) text=\"%s\"",
		iClient,
		GetClientAccountID(iClient),
		g_vecBSSpraysViewPosition[iClient][0],
		g_vecBSSpraysViewPosition[iClient][1],
		g_vecBSSpraysViewPosition[iClient][2],
		g_szBSSpraysViewInfo[iClient]
	);

	return Plugin_Continue;
}

public Action Timer_BSSpraysViewShowOwners(Handle hTimer)
{
	if (!g_cvBSSpraysViewEnabled.BoolValue)
		return Plugin_Continue;

	if (BSSpraysView_GetTextLocation() == kBSSpraysViewTextLoc_Disabled)
		return Plugin_Continue;

	float vecEnd[3];
	float flDistance = g_cvBSSpraysViewDistance.FloatValue;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!BSSpraysView_IsUsableClient(iClient) || IsFakeClient(iClient))
			continue;

		if (!BSSpraysView_GetClientEyeEndLocation(iClient, vecEnd))
		{
			BSSpraysView_Debug(kBSSpraysViewDebug_Timer, "Timer: viewer=%d has no valid eye trace.", iClient);
			continue;
		}

		BSSpraysView_Debug(
			kBSSpraysViewDebug_Timer,
			"Timer: viewer=%d trace_end=(%.2f, %.2f, %.2f) max_distance=%.2f",
			iClient,
			vecEnd[0],
			vecEnd[1],
			vecEnd[2],
			flDistance
		);

		bool bDisplayed = false;

		for (int iOwner = 1; iOwner <= MaxClients; iOwner++)
		{
			if (!BSSpraysView_IsUsableClient(iOwner))
				continue;

			if (!g_bBSSpraysViewHasSpray[iOwner])
				continue;

			float flOwnerDistance = GetVectorDistance(vecEnd, g_vecBSSpraysViewPosition[iOwner]);
			BSSpraysView_Debug(
				kBSSpraysViewDebug_Timer,
				"Timer: viewer=%d owner=%d spray_pos=(%.2f, %.2f, %.2f) distance=%.2f",
				iClient,
				iOwner,
				g_vecBSSpraysViewPosition[iOwner][0],
				g_vecBSSpraysViewPosition[iOwner][1],
				g_vecBSSpraysViewPosition[iOwner][2],
				flOwnerDistance
			);

			if (flOwnerDistance > flDistance)
				continue;

			char szOwnerInfo[256];
			BSSpraysView_BuildClientInfoString(iOwner, szOwnerInfo, sizeof(szOwnerInfo), true);

			char szText[384];
			Format(szText, sizeof(szText), "%T: %s", "BSSpraysViewSprayedBy", iClient, szOwnerInfo);
			BSSpraysView_PrintOwnerText(iClient, szText);
			BSSpraysView_Debug(kBSSpraysViewDebug_Timer, "Timer: viewer=%d matched owner=%d.", iClient, iOwner);
			bDisplayed = true;
			break;
		}

		if (!bDisplayed)
			BSSpraysView_Debug(kBSSpraysViewDebug_Timer, "Timer: viewer=%d no spray matched current trace.", iClient);
	}

	return Plugin_Continue;
}

stock bool BSSpraysView_IsUsableClient(int iClient)
{
	return (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient));
}

stock void BSSpraysView_ResetClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_vecBSSpraysViewPosition[iClient] = view_as<float>({0.0, 0.0, 0.0});
	g_szBSSpraysViewInfo[iClient][0] = '\0';
	g_bBSSpraysViewHasSpray[iClient] = false;
}

stock void BSSpraysView_NormalizeTextLocation()
{
	eBSSpraysViewTextLoc eTextLoc = BSSpraysView_GetTextLocation();
	if (eTextLoc == kBSSpraysViewTextLoc_Disabled
		|| eTextLoc == kBSSpraysViewTextLoc_Hint
		|| eTextLoc == kBSSpraysViewTextLoc_Center)
	{
		return;
	}

	g_cvBSSpraysViewTextLoc.SetInt(view_as<int>(kBSSpraysViewTextLoc_Hint), true);
	BSSpraysView_Debug(kBSSpraysViewDebug_General, "Unsupported textloc=%d; forcing hint display.", view_as<int>(eTextLoc));
}

stock bool BSSpraysView_IsDebugEnabled(eBSSpraysViewDebugMask iMask)
{
	return BSDebugMaskEnabled(g_cvBSLogMode, g_cvBSSpraysViewDebugMask, view_as<int>(iMask));
}

stock void BSSpraysView_Debug(eBSSpraysViewDebugMask iMask, const char[] szMessage, any ...)
{
	if (!BSSpraysView_IsDebugEnabled(iMask))
		return;

	static char szBuffer[512];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
	BSLogToFileEx(g_szBSSpraysViewLogPath, "[Debug] %s", szBuffer);
}

stock void BSSpraysView_BuildClientInfoString(int iClient, char[] szBuffer, int iMaxLength, bool bCompact = false)
{
	szBuffer[0] = '\0';

	int iMask = g_cvBSSpraysViewInfoMask.IntValue;
	int iFieldCount = 0;

	if (BSSpraysView_HasInfoFlag(iMask, kBSSpraysViewInfo_Name))
	{
		BSSpraysView_AppendInfoSeparator(szBuffer, iMaxLength, bCompact, iFieldCount);

		char szName[MAX_NAME_LENGTH];
		GetClientName(iClient, szName, sizeof(szName));
		StrCat(szBuffer, iMaxLength, szName);
		iFieldCount++;
	}

	if (BSSpraysView_HasInfoFlag(iMask, kBSSpraysViewInfo_AccountId))
	{
		BSSpraysView_AppendInfoSeparator(szBuffer, iMaxLength, bCompact, iFieldCount);

		char szAccountId[64];
		Format(szAccountId, sizeof(szAccountId), bCompact ? "AID:%d" : "AccountId: %d", GetClientAccountID(iClient));
		StrCat(szBuffer, iMaxLength, szAccountId);
		iFieldCount++;
	}

	if (BSSpraysView_HasInfoFlag(iMask, kBSSpraysViewInfo_Steam2))
	{
		BSSpraysView_AppendInfoSeparator(szBuffer, iMaxLength, bCompact, iFieldCount);

		char szSteam2[32];
		GetClientAuthId(iClient, AuthId_Steam2, szSteam2, sizeof(szSteam2), true);

		if (bCompact)
		{
			char szSteam2Label[40];
			Format(szSteam2Label, sizeof(szSteam2Label), "S2:%s", szSteam2);
			StrCat(szBuffer, iMaxLength, szSteam2Label);
		}
		else
		{
			StrCat(szBuffer, iMaxLength, szSteam2);
		}
		iFieldCount++;
	}

	if (BSSpraysView_HasInfoFlag(iMask, kBSSpraysViewInfo_Ip))
	{
		BSSpraysView_AppendInfoSeparator(szBuffer, iMaxLength, bCompact, iFieldCount);

		char szIp[64];
		GetClientIP(iClient, szIp, sizeof(szIp), true);

		if (bCompact)
		{
			char szIpLabel[72];
			Format(szIpLabel, sizeof(szIpLabel), "IP:%s", szIp);
			StrCat(szBuffer, iMaxLength, szIpLabel);
		}
		else
		{
			StrCat(szBuffer, iMaxLength, szIp);
		}
	}
}

stock void BSSpraysView_AppendInfoSeparator(char[] szBuffer, int iMaxLength, bool bCompact, int iFieldCount)
{
	if (iFieldCount <= 0)
		return;

	if (!bCompact)
	{
		StrCat(szBuffer, iMaxLength, "\n");
		return;
	}

	StrCat(szBuffer, iMaxLength, (iFieldCount % 2 == 0) ? "\n" : " | ");
}

stock void BSSpraysView_PrintOwnerText(int iClient, const char[] szText)
{
	BSSpraysView_Debug(
		kBSSpraysViewDebug_Display,
		"Display: client=%d textloc=%d text=\"%s\"",
		iClient,
		g_cvBSSpraysViewTextLoc.IntValue,
		szText
	);

	switch (view_as<eBSSpraysViewTextLoc>(g_cvBSSpraysViewTextLoc.IntValue))
	{
		case kBSSpraysViewTextLoc_Hint:
		{
			BSSpraysView_PrintHintText(iClient, szText);
		}

		case kBSSpraysViewTextLoc_Center:
		{
			PrintCenterText(iClient, szText);
		}
	}
}

stock bool BSSpraysView_GetClientEyeEndLocation(int iClient, float vecPosition[3])
{
	float vecOrigin[3];
	float vecAngles[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);

	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, BSSpraysView_ValidSprayTrace);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(vecPosition, hTrace);
		BSSpraysView_Debug(
			kBSSpraysViewDebug_Trace,
			"Trace: client=%d hit entity=%d fraction=%.4f end=(%.2f, %.2f, %.2f)",
			iClient,
			TR_GetEntityIndex(hTrace),
			TR_GetFraction(hTrace),
			vecPosition[0],
			vecPosition[1],
			vecPosition[2]
		);
		delete hTrace;
		return true;
	}

	BSSpraysView_Debug(kBSSpraysViewDebug_Trace, "Trace: client=%d did not hit a valid surface.", iClient);
	delete hTrace;
	return false;
}

public bool BSSpraysView_ValidSprayTrace(int iEntity, int iContentsMask)
{
	return (iEntity == 0 || iEntity > MaxClients);
}

stock bool BSSpraysView_PrintHintText(int iClient, const char[] szFormat, any ...)
{
	Handle hMessage = StartMessageOne("HintText", iClient);
	if (hMessage == null)
		return false;

	char szBuffer[254];
	SetGlobalTransTarget(iClient);
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);

	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
		PbSetString(hMessage, "text", szBuffer);
	else
	{
		BfWriteByte(hMessage, 1);
		BfWriteString(hMessage, szBuffer);
	}

	EndMessage();
	return true;
}

