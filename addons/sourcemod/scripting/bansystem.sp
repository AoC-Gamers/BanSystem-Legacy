#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <adminmenu>
#include <sdktools>

#undef REQUIRE_PLUGIN
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define DEBUG 		1
#define DEBUG_SQL 	1
#define DEBUG_API 	1
#define DEBUG_MENU 	0
#define PATCH_DEBUG	"logs/BanSystem.log"

#define PLUGIN_VERSION	"1.0"

int g_iTimeDurations[] = {0, 10, 20, 40, 60, 120, 240, 480, 1440, 2880, 5760, 10080, 20160, 43200, 86400, 172800, 345600};
char g_sTimeDurationsChat[][4] = {"0", "10", "20", "40", "1", "2", "4", "8", "1", "2", "4", "1", "2", "1", "2", "4", "8"};
char g_sDatabase[][32] = {"bansystem", "bansystemcache"};

enum eTypeBan
{
    kAccess = 0,
    kComm   = 1,
    kRegData  = 2
}
enum eDatabase
{
	kNoDB		= 0,
	kPrimary	= 1,
	kCache 		= 2
}

Database
	g_dbDatabase,
	g_dbCache;

GlobalForward
	g_gfOnBanAccess,
	g_gfOnUnbanAcess,
	g_gfOnBanMic,
	g_gfOnUnBanMic,
	g_gfOnBanChat,
	g_gfOnUnBanChat;

KeyValues g_kvReasons;

#if DEBUG
char g_sLogPath[PLATFORM_MAX_PATH];
#endif

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

ConVar
	g_cvSQLCache,
	g_cvLocalCache;

#include "bansystem/install.sp"
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
	CreateNative("bBanAccess", iBanAccesNative);
	CreateNative("bBannedComm", iBannedCommNative);

    g_gfOnBanAccess  = CreateGlobalForward("OnBanAccess", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
    g_gfOnUnbanAcess = CreateGlobalForward("OnUnbanAccess", ET_Ignore, Param_Cell, Param_String);

    g_gfOnBanMic   = CreateGlobalForward("OnBanMic", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_gfOnUnBanMic = CreateGlobalForward("OnUnbanMic", ET_Ignore, Param_Cell, Param_String);

    g_gfOnBanChat = CreateGlobalForward("OnBanChat", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_gfOnUnBanChat = CreateGlobalForward("OnUnBanChat", ET_Ignore, Param_Cell, Param_String);
	
	RegPluginLibrary("bansystem");
	return APLRes_Success;
}

public void OnPluginStart()
{
#if DEBUG
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), PATCH_DEBUG);
#endif
	BuildPath(Path_SM, g_szBanReasonsPath, sizeof(g_szBanReasonsPath), "configs/bansystem_reasons.txt");

	g_arrCacheNoPunishment = new ArrayList(MAX_AUTHID_LENGTH);

	vLoadTranslation("common.phrases");
	vLoadTranslation("bansystem.phrases");
	vLoadTranslation("bansystem.reasons.phrases");
	vLoadTranslation("basebans.phrases");
	vLoadTranslation("core.phrases");

	g_cvSQLCache = CreateConVar("sm_bansystem_sqlitecache", "1", "Enables the SQL Lite cache that stores players with bans.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLocalCache = CreateConVar("sm_bansystem_localcache", "1", "Enables local cache confirming players without bans.", FCVAR_NONE, true, 0.0, true, 1.0);

	vOnPluginStart_Install();
	vOnPluginStart_Access();
	vOnPluginStart_Communication();
	vOnPluginStart_Cache();

	RegConsoleCmd("sm_abort", Command_AbortBan);
	AutoExecConfig(true, "bansystem");
}

public Action Command_AbortBan(int iClient, int iArgs)
{
	if(CheckCommandAccess(iClient, "sm_ban", ADMFLAG_BAN) || g_eProcessAccess[iClient].m_bIsWaitingChatReason)
	{
		g_eProcessAccess[iClient].m_bIsWaitingChatReason = false;
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBan applied successfully");
	}
	else if(CheckCommandAccess(iClient, "sm_comm", ADMFLAG_CHAT) || g_eProcessComm[iClient].m_bIsWaitingChatReason)
	{
		g_eProcessComm[iClient].m_bIsWaitingChatReason = false;
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBan applied successfully");
	}
	else
		CReplyToCommand(iClient, "%t %t", "Prefix", "AbortBan not waiting for custom reason");
	
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	vConnectDB(g_sDatabase[0]);

	if (g_cvSQLCache.BoolValue)
		vConnectDB(g_sDatabase[1], true);
	else if (g_dbCache != null)
		delete g_dbCache;

	vLoadReasons();
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

public void OnClientDisconnect(int iClient)
{
    g_eProcessAccess[iClient].m_bIsWaitingChatReason = false;
	g_eProcessComm[iClient].m_bIsWaitingChatReason = false;
}

public void OnClientAuthorized(int iClient, const char[] szAuth)
{
	if(iClient == SERVER_INDEX || !IsClientConnected(iClient) || IsFakeClient(iClient))
		return;

	if (g_cvLocalCache.BoolValue && bCheckLocalCache(szAuth))
	{
		LogDebug("[OnClientConnect] Client No Punishment: %N (%s)", iClient, szAuth);
		g_ePunished[iClient].m_eComms = kNone;
		return;
	}

	if (g_cvSQLCache.BoolValue)
	{
		vCheckCache(iClient, szAuth);
		return;
	}

	g_ePunished[iClient].m_eComms = kNone;
	vCheckAuthId(iClient, szAuth);
	return;
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

/*****************************************************************
			N A T I V E   F U N C T I O N S
*****************************************************************/

int iBanAccesNative(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	char szTargetAuthId[MAX_AUTHID_LENGTH];
	if (iTarget == NO_INDEX)
		GetNativeString(3, szTargetAuthId, sizeof(szTargetAuthId));
	else
		GetClientAuthId(iTarget, AuthId_Steam2, szTargetAuthId, sizeof(szTargetAuthId));
	int iLength = GetNativeCell(4);
	char szReason[MAX_MESSAGE_LENGTH];
	GetNativeString(5, szReason, sizeof(szReason));

	vRegAccess(iClient, iTarget, szTargetAuthId, iLength, szReason);
	return 0;
}

/**
 * Checks if a target client is banned from specific communication types.
 *
 * @param iTarget    The client index of the target to check.
 * @param eType      The type of communication to check for (e.g., kAll, kMic, kChat).
 *
 * @return           True if the client is banned from the specified communication type, False otherwise.    
 */
int iBannedCommNative(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	eTypeComms eComms = view_as<eTypeComms>(GetNativeCell(2));

	if (iClient == NO_INDEX)
		return 0;

	switch(eComms)
	{
		case kAll:
		{
			if (g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
		case kMic:
		{
			if (g_ePunished[iClient].m_eComms == kMic || g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
		case kChat:
		{
			if (g_ePunished[iClient].m_eComms == kChat || g_ePunished[iClient].m_eComms == kAll)
				return 1;
		}
	}

	return 0;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Establishes a connection to the database using the specified configuration name.
 *
 * @param szConfigName  The name of the SQL configuration to use for the connection.
 * @param bCache        Optional. Whether to cache the database connection. Defaults to false.
 */
void vConnectDB(char[] szConfigName, bool bCache = false)
{
	if (!SQL_CheckConfig(szConfigName))
	{
        LogError("[vConnectDB] SQL config not found: %s", szConfigName);
		return;
	}

	Database.Connect(vConnectCallback, szConfigName, bCache);
}

void vConnectCallback(Database dbDatabase, const char[] szError, any pData)
{
	if (dbDatabase == null)
	{
        LogError("[vConnectCallback] Database connection failed.");
		return;
	}

	if (szError[0] != '\0')
	{
        LogError("[vConnectCallback] %s", szError);
		return;
	}

	if(view_as<bool>(pData))
		g_dbCache = dbDatabase;
	else
		g_dbDatabase = dbDatabase;
}

/**
 * Checks the cache for a specific Steam ID within the last 7 days.
 *
 * This function constructs an SQL query to check if the given Steam ID exists
 * in the cache table (`g_szTableAccess`) with a date within the last 7 days.
 * It then logs the query and executes it asynchronously, passing the result
 * to the `vCheckCacheCallback` function.
 *
 * @param iClient The client index of the player initiating the check.
 * @param szAuthId The Steam ID of the player to check in the cache.
 */
void vCheckCache(int iClient, const char[] szAuthId)
{
	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "SELECT `ban_id` FROM `%s` ", g_szTableCache);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "WHERE date_cache >= strftime('%%s', 'now', '-7 days') ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "AND steam_id = '%s';", szAuthId);

	LogSQL("[vCheckCache] Query: %s", szQuery);

	int iUserId = GetClientUserId(iClient);

	DataPack pCheckAuthId = new DataPack();
	pCheckAuthId.WriteCell(iUserId);
	pCheckAuthId.WriteString(szAuthId);

	SQL_TQuery(g_dbCache, vCheckCacheCallback, szQuery, pCheckAuthId);
}

void vCheckCacheCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int iClient;
    char szAuthId[MAX_AUTHID_LENGTH];

    DataPack pCheckAuthId = view_as<DataPack>(pData);
    pCheckAuthId.Reset();

    int iUserId = pCheckAuthId.ReadCell();
    pCheckAuthId.ReadString(szAuthId, sizeof(szAuthId));
    delete pCheckAuthId;

    iClient = GetClientOfUserId(iUserId);

    if (rsResult == null)
    {
        logErrorSQL(dbDataBase, szError, "vCheckCacheCallback");
        return;
    }

    if (!SQL_FetchRow(rsResult))
    {
        LogDebug("[vCheckCacheCallback] No cache entry found for client: %N (%s)", iClient, szAuthId);
        g_ePunished[iClient].m_eComms = kNone;
        bRegLocalCache(szAuthId);
		vCheckAuthId(iClient, szAuthId);
        return;
    }

    int iResult = SQL_FetchInt(rsResult, 0);
    LogSQL("[vCheckCacheCallback] Cache result for client %N (%s): %d", iClient, szAuthId, iResult);

	switch (iResult)
	{
		case 1:
		{
			vAttemptAccess(iClient, szAuthId);
			KickClient(iClient, "%t", "BlockAccessPerm");
		}
		case 2,3,4:
		{
			eTypeComms eComms = view_as<eTypeComms>(iResult - 1);

			char szComms[64];
			char szDate[128] = "[SQL Error: Field is Null]";

			switch (eComms)
			{
				case kAll:
				{
					Format(szComms, sizeof(szComms), "%T", "TypeCommAll", iClient);
					g_ePunished[iClient].m_eComms = kAll;
					SetClientListeningFlags(iClient, VOICE_MUTED);
				}

				case kMic:
				{
					Format(szComms, sizeof(szComms), "%T", "TypeCommMic", iClient);
					g_ePunished[iClient].m_eComms = kMic;
					SetClientListeningFlags(iClient, VOICE_MUTED);
				}

				case kChat:
				{
					Format(szComms, sizeof(szComms), "%T", "TypeCommChat", iClient);
					g_ePunished[iClient].m_eComms = kChat;
				}

			}

			g_ePunished[iClient].m_bPerm = true;
			Format(szDate, sizeof(szDate), "%T", "Permanent", iClient);

			DataPack pAnnouncer = new DataPack();
			CreateDataTimer(10.0, AnnouncerCommTimer, pAnnouncer, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
			pAnnouncer.WriteCell(iUserId);
			pAnnouncer.WriteString(szComms);
			pAnnouncer.WriteString(szDate);
		}
		default:
		{
			g_ePunished[iClient].m_eComms = kNone;
			bRegLocalCache(szAuthId);
			LogDebug("[vCheckCacheCallback] Client No Punishment: %N (%s)", iClient, szAuthId);
			vCheckAuthId(iClient, szAuthId);
		}
	}
}

/**
 * Checks the authentication ID of a client against the database.
 *
 * @param iClient       The client index to check.
 * @param szAuthId      The authentication ID (e.g., SteamID) of the client.
 *
 * This function constructs a SQL query to check the provided authentication ID
 * in the database. It logs the query for debugging purposes and executes it
 * asynchronously. A DataPack is used to store the client user ID and the
 * authentication ID for use in the callback function.
 */
void vCheckAuthId(int iClient, const char[] szAuthId)
{
	int iUserId = GetClientUserId(iClient);

	DataPack pCheckAuthId = new DataPack();
	pCheckAuthId.WriteCell(iUserId);
	pCheckAuthId.WriteString(szAuthId);

	char szQuery[256];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "CALL CheckAuthId('%s');", szAuthId);

	LogSQL("[vCheckAuthId] Query: %s", szQuery);

	SQL_TQuery(g_dbDatabase, vCheckAuthIdCallback, szQuery, pCheckAuthId);
}

void vCheckAuthIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	char szAuthId[MAX_AUTHID_LENGTH];

	int
		iUserId,
		iClient;

	DataPack pCheckAuthId = view_as<DataPack>(pData);
	pCheckAuthId.Reset();

	iUserId = pCheckAuthId.ReadCell();
	iClient = GetClientOfUserId(iUserId);
	pCheckAuthId.ReadString(szAuthId, sizeof(szAuthId));
	delete pCheckAuthId;

	if (rsResult == null)
	{
		logErrorSQL(dbDataBase, szError, "vCheckAuthIdCallback");
        g_ePunished[iClient].m_eComms = kNone;
		PrintToServer("szAuthId(%s)", szAuthId);
        bRegLocalCache(szAuthId);
		return;
	}

	if (!SQL_FetchRow(rsResult))
	{
		logErrorSQL(dbDataBase, szError, "vCheckAuthIdCallback");
		delete rsResult;
		return;
	}

	int iResult = SQL_FetchInt(rsResult, 0);
	bool bPerm = (iResult < 0);

	LogSQL("[vCheckAuthIdCallback] iResult: %d", iResult);
	
	if (iResult == 0)
	{
		g_ePunished[iClient].m_eComms = kNone;
		bRegLocalCache(szAuthId);
	}
	else if (iResult == -1 || iResult == 1)
	{
		vAttemptAccess(iClient, szAuthId);
		
		if (bPerm)
		{
			KickClient(iClient, "%t", "BlockAccessPerm");
			bRegisterCache(szAuthId, iResult);
		}
		else
		{
			char szDate[64];
			if (SQL_IsFieldNull(rsResult, 1))
			{
				KickClient(iClient, "%t", "BlockAccessTempNoDate");
			}
			
			SQL_FetchString(rsResult, 1, szDate, sizeof(szDate));
			KickClient(iClient, "%t", "BlockAccessTemp", szDate);
		}
	}
	else
	{
		// Bloque de Communication
		// Se obtiene el tipo de comunicación (valor absoluto) restandole 1
		eTypeComms eComms = view_as<eTypeComms>(IntAbs(iResult) - 1);
		char szComms[64];
		char szDate[128] = "[SQL Error: Field is Null]";

		switch(eComms)
		{
			case kAll: // Chat y mic permanent o temporal
			{
				Format(szComms, sizeof(szComms), "%T", "TypeCommAll", iClient);
				g_ePunished[iClient].m_eComms = kAll;
				SetClientListeningFlags(iClient, VOICE_MUTED);
			}
			case kMic: // Solo mic permanent o temporal
			{
				Format(szComms, sizeof(szComms), "%T", "TypeCommMic", iClient);
				g_ePunished[iClient].m_eComms = kMic;
				SetClientListeningFlags(iClient, VOICE_MUTED);
			}
			case kChat: // Solo chat permanent o temporal
			{
				Format(szComms, sizeof(szComms), "%T", "TypeCommChat", iClient);
				g_ePunished[iClient].m_eComms = kChat;
			}
		}
		
		g_ePunished[iClient].m_bPerm = bPerm;
		if (!bPerm)
		{
			if (SQL_IsFieldNull(rsResult, 1))
				logErrorSQL(dbDataBase, szError, "vCheckAuthIdCallback");
			else
				SQL_FetchString(rsResult, 1, szDate, sizeof(szDate));
		}
		else
		{
			Format(szDate, sizeof(szDate), "%T", "Permanent", iClient);
			bRegisterCache(szAuthId, iResult);
		}
		
		DataPack pAnnouncer = new DataPack();
		CreateDataTimer(10.0, AnnouncerCommTimer, pAnnouncer, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
		pAnnouncer.WriteCell(iUserId);
		pAnnouncer.WriteString(szComms);
		pAnnouncer.WriteString(szDate);
	}
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

	DataPack pAnnouncer = view_as<DataPack>(pData);
	pAnnouncer.Reset();

	iUserId = pAnnouncer.ReadCell();
	pAnnouncer.ReadString(szComms, sizeof(szComms));
	pAnnouncer.ReadString(szDate, sizeof(szDate));

	iClient = GetClientOfUserId(iUserId); 
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
	char szSQLError[4096];
	SQL_GetError(pDb, szSQLError, sizeof(szSQLError));
	LogError("[%s] SQL failed: %s", szName, szSQLError);
	LogError("[%s] Query dump: %s", szName, szQuery);
}

/**
 * Retrieves the client index of a player based on their Steam2 Auth ID.
 *
 * @param szAuthId      The Steam2 Auth ID of the player to search for.
 * @return              The client index of the player if found, otherwise NO_INDEX.
 */
stock int GetClientOfAuthID(const char[] szAuthId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		char szClientAuthId[MAX_AUTHID_LENGTH];
		GetClientAuthId(i, AuthId_Steam2, szClientAuthId, sizeof(szClientAuthId));

		if (StrEqual(szClientAuthId, szAuthId))
			return i;
	}
	return NO_INDEX;
}

/**
 * @brief Checks if a given string is a valid Steam ID.
 *
 * This function verifies if the provided string follows the format of a Steam ID.
 * A valid Steam ID should start with "STEAM_" and contain two colons separating
 * three numerical components.
 *
 * @param szAuthId The string to be checked.
 * @return True if the string is a valid Steam ID, false otherwise.
 */
bool bIsSteamId(char[] szAuthId)
{
	if (strlen(szAuthId) == 0)
		return false;
	
	if (StrContains(szAuthId, "STEAM_", false) == -1)
		return false;

	StripQuotes(szAuthId);

	int iPos1 = FindCharInString(szAuthId, ':');
	if (iPos1 == NO_INDEX)
		return false;

	int iPos2 = FindCharInString(szAuthId, ':', view_as<bool>(iPos1 + 1));
	if (iPos2 == NO_INDEX)
		return false;

	char szUniverse[8];
	char szAuth[8];
	char szAccount[16];

	int iLenUniverse = iPos1 - 6;
	if (iLenUniverse <= 0 || iLenUniverse >= sizeof(szUniverse))
		return false;

	for (int i = 0; i < iLenUniverse; i++)
	{
		szUniverse[i] = szAuthId[6 + i];
	}
	szUniverse[iLenUniverse] = '\0';

	int iLenAuth			 = iPos2 - iPos1 - 1;
	if (iLenAuth <= 0 || iLenAuth >= sizeof(szAuth))
		return false;

	for (int i = 0; i < iLenAuth; i++)
	{
		szAuth[i] = szAuthId[iPos1 + 1 + i];
	}
	szAuth[iLenAuth] = '\0';

	int iLenAccount	 = strlen(szAuthId) - iPos2 - 1;
	if (iLenAccount <= 0 || iLenAccount >= sizeof(szAccount))
		return false;

	for (int i = 0; i < iLenAccount; i++)
	{
		szAccount[i] = szAuthId[iPos2 + 1 + i];
	}
	szAccount[iLenAccount] = '\0';

	if (!bIsInteger(szUniverse) || !bIsInteger(szAuth) || !bIsInteger(szAccount))
		return false;

	return true;
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

#if DEBUG
#if DEBUG_SQL
/**
 * Logs a formatted SQL-related message to a log file.
 *
 * @param sMessage   The format string for the message to log.
 * @param ...        Additional arguments to format into the message.
 */
void LogSQL(const char[] sMessage, any...)
{
    static char sFormat[1024];
    VFormat(sFormat, sizeof(sFormat), sMessage, 2);
    LogToFileEx(g_sLogPath, "[SQL] %s", sFormat);
}
#else
public void LogSQL(const char[] sMessage, any...) {}
#endif
#if DEBUG_MENU
/**
 * Logs a formatted message to the menu log file.
 *
 * @param sMessage   The format string for the message to log.
 * @param ...        Additional arguments to format into the message.
 */
void LogMenu(const char[] sMessage, any...)
{
    static char sFormat[1024];
    VFormat(sFormat, sizeof(sFormat), sMessage, 2);
    LogToFileEx(g_sLogPath, "[Menu] %s", sFormat);
}
#else
public void LogMenu(const char[] sMessage, any...) {}
#endif
/**
 * Logs a debug message to a specified log file.
 *
 * @param sMessage   The format string for the debug message.
 * @param ...        Additional arguments to format into the message.
 */
void LogDebug(const char[] sMessage, any...)
{
    static char sFormat[1024];
    VFormat(sFormat, sizeof(sFormat), sMessage, 2);
    LogToFileEx(g_sLogPath, "[Debug] %s", sFormat);
}
#else
/**
 * Logs function dummy.
 */
public void LogDebug(const char[] sMessage, any...) {}
/**
 * Logs function dummy.
 */
public void LogSQL(const char[] sMessage, any...) {}
/**
 * Logs function dummy.
 */
public void LogMenu(const char[] sMessage, any...) {}
#endif