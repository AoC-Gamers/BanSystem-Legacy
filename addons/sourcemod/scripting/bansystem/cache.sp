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
	if (!bCanUseSQLiteCache())
	{
		vReplyCommandPhrase(iClient, "CacheSQLDisabled");
		return Plugin_Handled;
	}

    if (iArgs != 2)
    {
        vReplyCommandUsage(iClient, "sm_bs_cache <\"steamid\"> <TypeBan>");
        CReplyToCommand(iClient, "%t TypeBan: <1:Access> <2:Mic> <3:chat> <4:All>", "Prefix");

        return Plugin_Handled;
    }

    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

    int iAccountId;
    if (!bGetAccountIdFromAuthId(szSteamID, iAccountId))
    {
        vReplyCommandPhraseString(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    int iTypeBan = GetCmdArgInt(2);
    if (iTypeBan < 1 || iTypeBan > 4)
    {
        vReplyCommandUsage(iClient, "sm_bs_cache <\"steamid\"> <TypeBan>");
        CReplyToCommand(iClient, "%t TypeBan: <1:Access> <2:Mic> <3:chat> <4:All>", "Prefix");
        return Plugin_Handled;
    }

    bRegisterCacheAccountId(iAccountId, iTypeBan);
    vReplyCommandPhraseString(iClient, "CachePlayerAdded", szSteamID);
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
	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
		return;

	bRegisterCacheAccountId(iAccountId, iResult);
}

void bRegisterCacheAccountId(int iAccountId, int iResult)
{
	if (!bCanUseSQLiteCache())
		return;

	char szQuery[256];
	int iLen = 0;

	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", TABLE_CACHE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(ban_id, account_id) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d);", iResult, iAccountId);

	LogSQL("[bRegisterCacheAccountId] Query: %s", szQuery);

	SQL_TQuery(g_dbCache, bRegisterCacheCallback, szQuery);
}

void vDisableSQLiteCache(const char[] szContext)
{
	g_bSQLiteCacheReady = false;
	if (g_dbCache != null)
	{
		delete g_dbCache;
		g_dbCache = null;
	}

	LogError("[%s] SQLite cache disabled until the next reconnect/reload.", szContext);
}

void bRegisterCacheCallback(Handle dbDatabase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (dbDatabase == null)
	{
		LogError("[bRegisterCacheCallback] Database connection failed.");
		vDisableSQLiteCache("bRegisterCacheCallback");
		return;
	}

	if (szError[0] != '\0')
	{
		LogError("[bRegisterCacheCallback] %s", szError);
		vDisableSQLiteCache("bRegisterCacheCallback");
		return;
	}

	LogSQL("[bRegisterCacheCallback] Cache saved successfully.");
}

void vRemoveSQLCache(const char[] szAuthId)
{
	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
		return;

	vRemoveSQLCacheAccountId(iAccountId);
}

void vRemoveSQLCacheAccountId(int iAccountId)
{
	if (!bCanUseSQLiteCache())
		return;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE account_id = %d;", TABLE_CACHE, iAccountId);

	LogSQL("[vRemoveSQLCacheAccountId] Query: %s", szQuery);
	SQL_TQuery(g_dbCache, vRemoveSQLCacheCallback, szQuery);
}

void vRemoveSQLCacheCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
	if (rsResult == null || szError[0])
	{
		logErrorSQL(dbDataBase, szError, "vRemoveSQLCacheCallback");
		vDisableSQLiteCache("vRemoveSQLCacheCallback");
		delete rsResult;
		return;
	}

	delete rsResult;
}

Action aCacheListCmd(int iClient, int iArgs)
{
    if (!bCanUseSQLiteCache())
    {
        vReplyCommandPhrase(iClient, "CacheSQLDisabled");
        return Plugin_Handled;
    }

    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT * FROM BanCache_Valid;");

	DataPack dpCacheList = pCreateReplyContext(iClient, GetCmdReplySource());

	SQL_TQuery(g_dbCache, vCacheListCallback, szQuery, dpCacheList);
    return Plugin_Handled;
}

void vCacheListCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int iUserId;

	ReplySource eRsCmd;
	vReadReplyContext(pData, iUserId, eRsCmd);
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
    if (rsResult == null || szError[0])
    {
        vReplyCommandPhrase(iClient, "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheListCallback");
		delete rsResult;
        return;
    }

	vPrintInfoHeader(iClient);
	while (rsResult.FetchRow())
	{
		int iAccountId = rsResult.FetchInt(1);
		char szAutchId[MAX_AUTHID_LENGTH];
		bGetAuthIdFromAccountId(iAccountId, szAutchId, sizeof(szAutchId));

        char szDate[64];
        rsResult.FetchString(2, szDate, sizeof(szDate));

		PrintToConsole(iClient, "> BanID %d | AccountID: %d | AuthID: %s | Date: %s", rsResult.FetchInt(0), iAccountId, szAutchId, szDate);
	}

	vNotifyInfoPrinted(iClient, eRsCmd);

    delete rsResult;
}

Action aCacheClearCmd(int iClient, int iArgs)
{
    if (!bCanUseSQLiteCache())
    {
        vReplyCommandPhrase(iClient, "CacheSQLDisabled");
        return Plugin_Handled;
    }

    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "DELETE FROM BanCache;");

	DataPack dpCacheClear = pCreateReplyContext(iClient, GetCmdReplySource());

	SQL_TQuery(g_dbCache, vCacheClearCallback, szQuery, dpCacheClear);
    return Plugin_Handled;
}

void vCacheClearCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int iUserId;

	ReplySource eRsCmd;
	vReadReplyContext(pData, iUserId, eRsCmd);
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
    if (rsResult == null || szError[0])
    {
        vReplyCommandPhrase(iClient, "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheClearCallback");
		delete rsResult;
        return;
    }

    if (rsResult.AffectedRows > 0)
        vReplyCommandPhrase(iClient, "CacheCleared");
    else
        vReplyCommandPhrase(iClient, "CacheAlreadyEmpty");

    delete rsResult;
}

Action aCacheSteamIdCmd(int iClient, int iArgs)
{
    if (!bCanUseSQLiteCache())
    {
        vReplyCommandPhrase(iClient, "CacheSQLDisabled");
        return Plugin_Handled;
    }

    if (iArgs < 1 || iArgs == 0)
    {
        vReplyCommandUsage(iClient, "sm_bs_cache_steamid <\"steamid\">");
        return Plugin_Handled;
    }

    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

	int iAccountId;
    if (!bGetAccountIdFromAuthId(szSteamID, iAccountId))
    {
        vReplyCommandPhraseString(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    char szQuery[256];
    Format(szQuery, sizeof(szQuery), "SELECT * FROM BanCache_Valid WHERE account_id = %d;", iAccountId);

	DataPack dpCacheSteamId = pCreateReplyContext(iClient, GetCmdReplySource());

    SQL_TQuery(g_dbCache, vCacheSteamIdCallback, szQuery, dpCacheSteamId);
    return Plugin_Handled;
}

void vCacheSteamIdCallback(Database dbDataBase, DBResultSet rsResult, const char[] szError, any pData)
{
    int iUserId;

	ReplySource eRsCmd;
	vReadReplyContext(pData, iUserId, eRsCmd);
	int iClient = iResolveReplyClientForCommand(iUserId, eRsCmd, false);
	if (iClient == NO_INDEX)
	{
		delete rsResult;
		return;
	}
    if (rsResult == null || szError[0])
    {
        vReplyCommandPhrase(iClient, "SQLError");
        logErrorSQL(dbDataBase, szError, "vCacheSteamIdCallback");
        delete rsResult;
        return;
    }

    vPrintInfoHeader(iClient);
    while (rsResult.FetchRow())
    {
        int iAccountId = rsResult.FetchInt(1);
        char szAutchId[MAX_AUTHID_LENGTH];
        bGetAuthIdFromAccountId(iAccountId, szAutchId, sizeof(szAutchId));

        char szDate[64];
        rsResult.FetchString(2, szDate, sizeof(szDate));

        PrintToConsole(iClient, "> BanID %d | AccountID: %d | AuthID: %s | Date: %s", rsResult.FetchInt(0), iAccountId, szAutchId, szDate);
    }

    vNotifyInfoPrinted(iClient, eRsCmd);

    delete rsResult;
}

Action aLocalaCacheListCmd(int iClient, int iArgs)
{
    vPrintInfoHeader(iClient);
    int iFound = 0;
    for (int i = 0; i < g_arrCacheNoPunishment.Length; i++)
    {
        int iAccountId = g_arrCacheNoPunishment.Get(i);
        char szAutchId[MAX_AUTHID_LENGTH];
        bGetAuthIdFromAccountId(iAccountId, szAutchId, sizeof(szAutchId));
        PrintToConsole(iClient, "> #%d: %d | %s", i, iAccountId, szAutchId);
        iFound++;
    }

    if (iFound == 0)
        PrintToConsole(iClient, "%t", "NoUsersFound");

	vNotifyInfoPrinted(iClient, GetCmdReplySource());

    return Plugin_Handled;
}

Action aLocalaCacheClearCmd(int iClient, int iArgs)
{
    g_arrCacheNoPunishment.Clear();
    vReplyCommandPhrase(iClient, "LocalcacheCleared");
    return Plugin_Handled;
}

Action aLocalCacheSteamIdCmd(int iClient, int iArgs)
{
    if (iArgs < 1 || iArgs == 0)
    {
        vReplyCommandUsage(iClient, "sm_bs_localcache_steamid <\"steamid\">");
        return Plugin_Handled;
    }
    char szSteamID[MAX_AUTHID_LENGTH];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));

	int iAccountId;
    if (!bGetAccountIdFromAuthId(szSteamID, iAccountId))
    {
        vReplyCommandPhraseString(iClient, "AuthIdError", szSteamID);
        return Plugin_Handled;
    }

    if (bCheckLocalCacheAccountId(iAccountId))
        vReplyCommandPhraseString(iClient, "LocalCachePlayerFound", szSteamID);
    else
        vReplyCommandPhraseString(iClient, "LocalCachePlayerNotFound", szSteamID);
    return Plugin_Handled;
}

bool bRegLocalCacheAccountId(int iAccountId)
{
    if (!g_cvLocalCache.BoolValue || iAccountId == 0)
        return false;

    if (g_arrCacheNoPunishment.FindValue(iAccountId) == -1)
        g_arrCacheNoPunishment.Push(iAccountId);

    return true;
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
	int iAccountId;
	if (!bGetAccountIdFromAuthId(szAuthId, iAccountId))
		return false;

	return bRemoveLocalCacheAccountId(iAccountId);
}

bool bRemoveLocalCacheAccountId(int iAccountId)
{
    if (!g_cvLocalCache.BoolValue || iAccountId == 0)
        return false;

    int iIndex = g_arrCacheNoPunishment.FindValue(iAccountId);
    if (iIndex == -1)
        return false;

    g_arrCacheNoPunishment.Erase(iIndex);
    return true;
}

bool bCheckLocalCacheAccountId(int iAccountId)
{
    if (iAccountId == 0)
        return false;

    return (g_arrCacheNoPunishment.FindValue(iAccountId) != -1);
}
