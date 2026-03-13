#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <steamidtools>

#define BANSYSTEM_SPRAYS_VIEW_VERSION "0.1.0-dev"
#define BANSYSTEM_SPRAYS_VIEW_LOG "logs/BanSystem_SpraysView.log"

enum eBSSpraysViewInfoMask
{
	kBSSpraysViewInfo_None = 0,
	kBSSpraysViewInfo_Name = 1,
	kBSSpraysViewInfo_AccountId = 2,
	kBSSpraysViewInfo_Steam2 = 4,
	kBSSpraysViewInfo_Steam64 = 8,
	kBSSpraysViewInfo_Ip = 16
}

enum eBSSpraysViewTextLoc
{
	kBSSpraysViewTextLoc_Disabled = 0,
	kBSSpraysViewTextLoc_KeyHint = 1,
	kBSSpraysViewTextLoc_Hint = 2,
	kBSSpraysViewTextLoc_Center = 3,
	kBSSpraysViewTextLoc_Hud = 4,
	kBSSpraysViewTextLoc_TopLeft = 5
}

ConVar g_cvBSSpraysViewEnabled;
ConVar g_cvBSSpraysViewTextLoc;
ConVar g_cvBSSpraysViewInfoMask;
ConVar g_cvBSSpraysViewDistance;
ConVar g_cvBSSpraysViewDebugMask;

char g_szBSSpraysViewLogPath[PLATFORM_MAX_PATH];
float g_vecBSSpraysViewPosition[MAXPLAYERS + 1][3];
char g_szBSSpraysViewInfo[MAXPLAYERS + 1][256];
Handle g_hBSSpraysViewHud;

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
	BuildPath(Path_SM, g_szBSSpraysViewLogPath, sizeof(g_szBSSpraysViewLogPath), BANSYSTEM_SPRAYS_VIEW_LOG);
	LoadTranslations("bansystem_modular.phrases");

	g_cvBSSpraysViewEnabled = CreateConVar("sm_bs_sprays_view_enabled", "1", "Enable BanSystem spray owner display.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBSSpraysViewTextLoc = CreateConVar("sm_bs_sprays_view_textloc", "1", "Where spray owner info is displayed. 0=disabled, 1=keyhint, 2=hint, 3=center, 4=hud, 5=top-left.", FCVAR_NONE, true, 0.0, true, 5.0);
	g_cvBSSpraysViewInfoMask = CreateConVar("sm_bs_sprays_view_info_mask", "3", "Spray owner info bitmask. 1=name, 2=accountid, 4=steam2, 8=steamid64, 16=ip.", FCVAR_NONE, true, 1.0);
	g_cvBSSpraysViewDistance = CreateConVar("sm_bs_sprays_view_distance", "50.0", "Distance in units for detecting an aimed spray owner.", FCVAR_NONE, true, 1.0);
	g_cvBSSpraysViewDebugMask = CreateConVar("sm_bs_sprays_view_debug_mask", "0", "Debug bitmask: 1=general.", FCVAR_NONE, true, 0.0);

	RegAdminCmd("sm_bs_sprays_view_status", Command_BSSpraysViewStatus, ADMFLAG_ROOT, "Show BanSystem Sprays View status.");

	AddTempEntHook("Player Decal", BSSpraysView_OnPlayerDecal);
	CreateTimer(0.5, Timer_BSSpraysViewShowOwners, _, TIMER_REPEAT);

	g_hBSSpraysViewHud = CreateHudSynchronizer();
	if (g_hBSSpraysViewHud == null && g_cvBSSpraysViewTextLoc.IntValue == view_as<int>(kBSSpraysViewTextLoc_Hud))
	{
		g_cvBSSpraysViewTextLoc.SetInt(view_as<int>(kBSSpraysViewTextLoc_KeyHint), true);
		BSSpraysView_Debug("HUD messages are unavailable in this game. Falling back to keyhint display.");
	}
}

public void OnClientDisconnect(int iClient)
{
	BSSpraysView_ResetClient(iClient);
}

Action Command_BSSpraysViewStatus(int iClient, int iArgs)
{
	CReplyToCommand(
		iClient,
		"%t",
		"BSSpraysViewStatus",
		g_cvBSSpraysViewEnabled.BoolValue ? 1 : 0,
		g_cvBSSpraysViewTextLoc.IntValue,
		g_cvBSSpraysViewInfoMask.IntValue,
		g_cvBSSpraysViewDistance.FloatValue,
		g_hBSSpraysViewHud != null ? 1 : 0
	);

	return Plugin_Handled;
}

public Action BSSpraysView_OnPlayerDecal(const char[] szName, const int[] iClients, int iCount, float flDelay)
{
	if (!g_cvBSSpraysViewEnabled.BoolValue)
		return Plugin_Continue;

	int iClient = TE_ReadNum("m_nPlayer");
	if (!BSSpraysView_IsUsableClient(iClient))
		return Plugin_Continue;

	TE_ReadVector("m_vecOrigin", g_vecBSSpraysViewPosition[iClient]);
	BSSpraysView_BuildClientInfoString(iClient, g_szBSSpraysViewInfo[iClient], sizeof(g_szBSSpraysViewInfo[]));
	BSSpraysView_Debug("Stored spray owner info for client=%d accountid=%d", iClient, GetClientAccountID(iClient));

	return Plugin_Continue;
}

public Action Timer_BSSpraysViewShowOwners(Handle hTimer)
{
	if (!g_cvBSSpraysViewEnabled.BoolValue)
		return Plugin_Continue;

	if (g_cvBSSpraysViewTextLoc.IntValue == view_as<int>(kBSSpraysViewTextLoc_Disabled))
		return Plugin_Continue;

	float vecEnd[3];
	float flDistance = g_cvBSSpraysViewDistance.FloatValue;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!BSSpraysView_IsUsableClient(iClient) || IsFakeClient(iClient))
			continue;

		if (!BSSpraysView_GetClientEyeEndLocation(iClient, vecEnd))
			continue;

		for (int iOwner = 1; iOwner <= MaxClients; iOwner++)
		{
			if (!BSSpraysView_IsUsableClient(iOwner))
				continue;

			if (g_szBSSpraysViewInfo[iOwner][0] == '\0')
				continue;

			if (GetVectorDistance(vecEnd, g_vecBSSpraysViewPosition[iOwner]) > flDistance)
				continue;

			char szText[320];
			Format(szText, sizeof(szText), "%T:\n%s", "BSSpraysViewSprayedBy", iClient, g_szBSSpraysViewInfo[iOwner]);
			BSSpraysView_PrintOwnerText(iClient, szText);
			break;
		}
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
}

stock void BSSpraysView_Debug(const char[] szMessage, any ...)
{
	if (g_cvBSSpraysViewDebugMask == null || (g_cvBSSpraysViewDebugMask.IntValue & 1) == 0)
		return;

	static char szBuffer[512];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	LogToFileEx(g_szBSSpraysViewLogPath, "[Debug] %s", szBuffer);
}

stock void BSSpraysView_BuildClientInfoString(int iClient, char[] szBuffer, int iMaxLength)
{
	szBuffer[0] = '\0';

	int iMask = g_cvBSSpraysViewInfoMask.IntValue;
	bool bHasAny = false;

	if ((iMask & view_as<int>(kBSSpraysViewInfo_Name)) != 0)
	{
		char szName[MAX_NAME_LENGTH];
		GetClientName(iClient, szName, sizeof(szName));
		Format(szBuffer, iMaxLength, "%s", szName);
		bHasAny = true;
	}

	if ((iMask & view_as<int>(kBSSpraysViewInfo_AccountId)) != 0)
	{
		Format(szBuffer, iMaxLength, "%s%sAccountId: %d", szBuffer, bHasAny ? "\n" : "", GetClientAccountID(iClient));
		bHasAny = true;
	}

	if ((iMask & view_as<int>(kBSSpraysViewInfo_Steam2)) != 0)
	{
		char szSteam2[32];
		GetClientAuthId(iClient, AuthId_Steam2, szSteam2, sizeof(szSteam2), true);
		Format(szBuffer, iMaxLength, "%s%s%s", szBuffer, bHasAny ? "\n" : "", szSteam2);
		bHasAny = true;
	}

	if ((iMask & view_as<int>(kBSSpraysViewInfo_Steam64)) != 0)
	{
		char szSteamId64[32];
		GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64), true);
		Format(szBuffer, iMaxLength, "%s%s%s", szBuffer, bHasAny ? "\n" : "", szSteamId64);
		bHasAny = true;
	}

	if ((iMask & view_as<int>(kBSSpraysViewInfo_Ip)) != 0)
	{
		char szIp[64];
		GetClientIP(iClient, szIp, sizeof(szIp), true);
		Format(szBuffer, iMaxLength, "%s%s%s", szBuffer, bHasAny ? "\n" : "", szIp);
	}
}

stock void BSSpraysView_PrintOwnerText(int iClient, const char[] szText)
{
	switch (view_as<eBSSpraysViewTextLoc>(g_cvBSSpraysViewTextLoc.IntValue))
	{
		case kBSSpraysViewTextLoc_KeyHint:
		{
			BSSpraysView_PrintKeyHintText(iClient, szText);
		}

		case kBSSpraysViewTextLoc_Hint:
		{
			BSSpraysView_PrintHintText(iClient, szText);
		}

		case kBSSpraysViewTextLoc_Center:
		{
			PrintCenterText(iClient, szText);
		}

		case kBSSpraysViewTextLoc_Hud:
		{
			if (g_hBSSpraysViewHud != null)
			{
				SetHudTextParams(0.04, 0.8, 0.55, 125, 75, 100, 255);
				ShowSyncHudText(iClient, g_hBSSpraysViewHud, szText);
			}
		}

		case kBSSpraysViewTextLoc_TopLeft:
		{
			BSSpraysView_TopText(iClient, szText);
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
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

public bool BSSpraysView_ValidSprayTrace(int iEntity, int iContentsMask)
{
	return (iEntity > MaxClients);
}

stock void BSSpraysView_TopText(int iClient, const char[] szMessage)
{
	KeyValues kv = new KeyValues("Stuff", "title", szMessage);
	kv.SetColor("color", 255, 255, 255, 255);
	kv.SetNum("level", 1);
	kv.SetNum("time", 1);
	CreateDialog(iClient, kv, DialogType_Msg);
	delete kv;
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

stock bool BSSpraysView_PrintKeyHintText(int iClient, const char[] szFormat, any ...)
{
	Handle hMessage = StartMessageOne("KeyHintText", iClient);
	if (hMessage == null)
		return false;

	char szBuffer[254];
	SetGlobalTransTarget(iClient);
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);

	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
		PbAddString(hMessage, "hints", szBuffer);
	else
	{
		BfWriteByte(hMessage, 1);
		BfWriteString(hMessage, szBuffer);
	}

	EndMessage();
	return true;
}
