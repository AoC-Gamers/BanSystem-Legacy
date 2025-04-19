/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/


/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/
void vOnPluginStart_Cache()
{
    RegAdminCmd("sm_bs_cache", aCacheRegCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_bs_cache_ls", aCacheListCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_bs_cache_clear", aCacheClearCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_bs_cache_steamid", aCacheSteamIdCmd, ADMFLAG_GENERIC);

    RegAdminCmd("sm_bs_localcache_ls", aLocalaCacheListCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_bs_localcache_clear", aLocalaCacheClearCmd, ADMFLAG_GENERIC);
    RegAdminCmd("sm_bs_localcache_steamid", aLocalCacheSteamIdCmd, ADMFLAG_GENERIC);
}

Action aCacheRegCmd(int iClient, int iArgs)
{
    if (iArgs != 2)
    {
        CReplyToCommand(iClient, "%t %t: sm_bs_cache <\"steamid\"> <TypeBan>", "Prefix", "Use");
        CReplyToCommand(iClient, "%t TypeBan: <1:Access> <2:Mic> <3:chat> <4:All>", "Prefix");

        return Plugin_Handled;
    }

    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

    if (!bIsSteamId(szSteamID))
    {
        CReplyToCommand(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    int iTypeBan = GetCmdArgInt(2);
    if (iTypeBan < 1 || iTypeBan > 4)
    {
        CReplyToCommand(iClient, "%t %t: sm_bs_cache <\"steamid\"> <TypeBan>", "Prefix", "Use");
        CReplyToCommand(iClient, "%t TypeBan: <1:Access> <2:Mic> <3:chat> <4:All>", "Prefix");
        return Plugin_Handled;
    }

    bRegisterCache(szSteamID, iTypeBan);
    CReplyToCommand(iClient, "%t %t", "Prefix", "LocalCachePlayerAdded", szSteamID);
    return Plugin_Handled;
}

/**
 * Saves a ban record to the SQL cache if caching is enabled.
 *
 * @param szAuthId  The Steam ID of the user being banned.
 * @param iResult   The ban ID or result associated with the ban.
 *
 * This function constructs an SQL query to insert a ban record into the cache table.
 * The query includes the ban ID and Steam ID of the user. If SQL caching is disabled
 * (as determined by the `g_cvSQLCache` ConVar), the function exits early without
 * performing any operations. The constructed query is logged for debugging purposes
 * and then executed asynchronously using `SQL_TQuery`.
 */
void bRegisterCache(const char[] szAuthId, int iResult)
{
	if (!g_cvSQLCache.BoolValue)
		return;

	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", TABLE_CACHE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(ban_id, steam_id) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES ('%d', '%s');", iResult, szAuthId);

	LogSQL("[bRegisterCache] Query: %s", szQuery);

	SQL_TQuery(g_dbCache, bRegisterCacheCallback, szQuery);

}

void bRegisterCacheCallback(Handle dbDatabase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (dbDatabase == null)
	{
		LogError("[bRegisterCacheCallback] Database connection failed.");
		return;
	}

	if (szError[0] != '\0')
	{
		LogError("[bRegisterCacheCallback] %s", szError);
		return;
	}

	LogSQL("[bRegisterCacheCallback] Cache saved successfully.");
}

Action aCacheListCmd(int iClient, int iArgs)
{
    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT * FROM BanCache;");

    int iUserid;
    if (iClient == SERVER_INDEX)
        iUserid = SERVER_INDEX;
    else
        iUserid = GetClientUserId(iClient);

	DataPack dpCacheList = new DataPack();
	dpCacheList.WriteCell(iUserid);
	dpCacheList.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbCache, vCacheListCallback, szQuery, dpCacheList);
    return Plugin_Handled;
}

void vCacheListCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int
        iClient,
        iUserId;

    DataPack dpCacheList  = view_as<DataPack>(pData);
	dpCacheList.Reset();

    iUserId = dpCacheList.ReadCell();
    ReplySource eRsCmd = view_as<ReplySource>(dpCacheList.ReadCell());

    if (iUserId == SERVER_INDEX)
        iClient = SERVER_INDEX;
    else
        iClient = GetClientOfUserId(iUserId);

    SetCmdReplySource(eRsCmd);
    if (rsResult == null || szError[0])
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheListCallback");
		delete rsResult;
        return;
    }

	PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
	while (rsResult.FetchRow())
	{
		char szAutchId[MAX_AUTHID_LENGTH];
		rsResult.FetchString(1, szAutchId, sizeof(szAutchId));

        char szDate[64];
        rsResult.FetchString(2, szDate, sizeof(szDate));

		PrintToConsole(iClient, "> BanID %d | AuthID: %s | Date: %s", rsResult.FetchInt(0), szAutchId, szDate);
	}

	if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

    delete rsResult;
}

Action aCacheClearCmd(int iClient, int iArgs)
{
    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "DELETE FROM BanCache;");

    int iUserid;
    if (iClient == SERVER_INDEX)
        iUserid = SERVER_INDEX;
    else
        iUserid = GetClientUserId(iClient);

	DataPack dpCacheClear = new DataPack();
	dpCacheClear.WriteCell(iUserid);
	dpCacheClear.WriteCell(GetCmdReplySource());

	SQL_TQuery(g_dbCache, vCacheClearCallback, szQuery, dpCacheClear);
    return Plugin_Handled;
}

void vCacheClearCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int
        iClient,
        iUserId;

    DataPack dpCacheClear  = view_as<DataPack>(pData);
	dpCacheClear.Reset();

    iUserId = dpCacheClear.ReadCell();
    ReplySource eRsCmd = view_as<ReplySource>(dpCacheClear.ReadCell());

    if (iUserId == SERVER_INDEX)
        iClient = SERVER_INDEX;
    else
        iClient = GetClientOfUserId(iUserId);

    SetCmdReplySource(eRsCmd);
    if (rsResult == null || szError[0])
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheClearCallback");
		delete rsResult;
        return;
    }

    if (rsResult.AffectedRows > 0)
        CReplyToCommand(iClient, "%t %t", "Prefix", "CacheCleared");
    else
        CReplyToCommand(iClient, "%t %t", "Prefix", "CacheAlreadyEmpty");

    delete rsResult;
}

Action aCacheSteamIdCmd(int iClient, int iArgs)
{
    if (iArgs < 1 || iArgs == 0)
    {
        CReplyToCommand(iClient, "%t %t: sm_bs_cache_steamid <\"steamid\">", "Prefix", "Use");
        return Plugin_Handled;
    }

    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

    if (!bIsSteamId(szSteamID))
    {
        CReplyToCommand(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT * FROM BanCache WHERE AuthID = '%s';", szSteamID);

    int iUserid;
    if (iClient == SERVER_INDEX)
        iUserid = SERVER_INDEX;
    else
        iUserid = GetClientUserId(iClient);

	DataPack dpCacheSteamId = new DataPack();
	dpCacheSteamId.WriteCell(iUserid);
	dpCacheSteamId.WriteCell(GetCmdReplySource());

    SQL_TQuery(g_dbCache, vCacheSteamIdCallback, szQuery, dpCacheSteamId);
    return Plugin_Handled;
}

void vCacheSteamIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int
        iClient,
        iUserId;

    DataPack dpCacheSteamId  = view_as<DataPack>(pData);
	dpCacheSteamId.Reset();

    iUserId = dpCacheSteamId.ReadCell();
    ReplySource eRsCmd = view_as<ReplySource>(dpCacheSteamId.ReadCell());

    if (iUserId == SERVER_INDEX)
        iClient = SERVER_INDEX;
    else
        iClient = GetClientOfUserId(iUserId);

    SetCmdReplySource(eRsCmd);
    if (rsResult == null || szError[0])
    {
        CReplyToCommand(iClient, "%t %t", "Prefix", "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheSteamIdCallback");
        delete rsResult;
        return;
    }

    PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
    while (rsResult.FetchRow())
    {
        char szAutchId[MAX_AUTHID_LENGTH];
        rsResult.FetchString(1, szAutchId, sizeof(szAutchId));

        char szDate[64];
        rsResult.FetchString(2, szDate, sizeof(szDate));

        PrintToConsole(iClient, "> BanID %d | AuthID: %s | Date: %s", rsResult.FetchInt(0), szAutchId, szDate);
    }

    if (eRsCmd == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
        CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

    delete rsResult;
}

Action aLocalaCacheListCmd(int iClient, int iArgs)
{

    PrintToConsole(iClient, "/***********[%t]***********\\", "TitleInfo");
    char szAutchId[MAX_AUTHID_LENGTH];
    int iFound = 0;
    for (int i = 0; i < g_arrCacheNoPunishment.Length; i++)
    {
        g_arrCacheNoPunishment.GetString(i, szAutchId, sizeof(szAutchId));
        PrintToConsole(iClient, "> #%d: %s", i, szAutchId);
        iFound++;
    }

    if (iFound == 0)
        PrintToConsole(iClient, "%t", "NoUsersFound");

	if (GetCmdReplySource() == SM_REPLY_TO_CHAT && iClient != SERVER_INDEX)
		CPrintToChat(iClient, "%t %t", "Prefix", "InfoPrinted");

    return Plugin_Handled;
}

Action aLocalaCacheClearCmd(int iClient, int iArgs)
{
    g_arrCacheNoPunishment.Clear();
    CReplyToCommand(iClient, "LocalcacheCleared");
    return Plugin_Handled;
}

Action aLocalCacheSteamIdCmd(int iClient, int iArgs)
{
    if (iArgs < 1 || iArgs == 0)
    {
        CReplyToCommand(iClient, "%t %t: sm_bs_localcache_steamid <\"steamid\">", "Prefix", "Use");
        return Plugin_Handled;
    }
    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

    if (!bIsSteamId(szSteamID))
    {
        CReplyToCommand(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    if (g_arrCacheNoPunishment.FindString(szSteamID) != -1)
        CReplyToCommand(iClient, "%t %t", "Prefix", "LocalCachePlayerFound", szSteamID);
    else
        CReplyToCommand(iClient, "%t %t", "Prefix", "LocalCachePlayerNotFound", szSteamID);
    return Plugin_Handled;
}

/**
 * Registers a local cache entry for the given authentication ID.
 *
 * @param szAuthId        The authentication ID to register in the local cache.
 * @return                False if the authentication ID is already in the cache or after adding it to the cache.
 */
bool bRegLocalCache(const char[] szAuthId)
{
    if (!g_cvLocalCache.BoolValue)
        return false;

    if (g_arrCacheNoPunishment.FindString(szAuthId) != -1)
        return false;

    g_arrCacheNoPunishment.PushString(szAuthId);
    return false;
}

/**
 * Unregisters a local cache entry for a given authentication ID.
 *
 * This function searches for the specified authentication ID in the 
 * `g_arrCacheNoPunishment` array. If found, it removes the entry from 
 * the array and returns true. If the authentication ID is not found, 
 * it returns false.
 *
 * @param szAuthId The authentication ID to be unregistered.
 * @return True if the authentication ID was successfully unregistered, 
 *         false if it was not found in the cache.
 */
bool bRemoveLocalCache(const char[] szAuthId)
{
    if (!g_cvLocalCache.BoolValue)
        return false;

    int iIndex = g_arrCacheNoPunishment.FindString(szAuthId);
    if (iIndex == -1)
        return false;

    g_arrCacheNoPunishment.Erase(iIndex);
    return true;
}

/**
 * Checks if the given authentication ID exists in the local cache of players
 * who should not be punished.
 *
 * @param szAuthId The authentication ID to check (e.g., SteamID or similar identifier).
 * @return True if the authentication ID is found in the cache, false otherwise.
 */
bool bCheckLocalCache(const char[] szAuthId)
{
    return (g_arrCacheNoPunishment.FindString(szAuthId) != -1);
}