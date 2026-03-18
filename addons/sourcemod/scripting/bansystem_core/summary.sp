/*****************************************************************
			S U M M A R Y
*****************************************************************/

stock void BSCore_GetSummaryMysqlTableName(char[] szBuffer, int iMaxLength)
{
	strcopy(szBuffer, iMaxLength, BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
}

stock void BSCore_GetSummarySqliteTableName(char[] szBuffer, int iMaxLength)
{
	strcopy(szBuffer, iMaxLength, BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
}

stock void BSCore_GetSummarySelectQueryByAccountId(int iAccountId, char[] szQuery, int iMaxLength)
{
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "SELECT `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts` ");
	Format(szQuery[iLen], iMaxLength - iLen, "FROM `%s` WHERE `accountid` = %d LIMIT 1;", BANSYSTEM_CORE_MYSQL_VIEW_AUTH_SUMMARY, iAccountId);
}

stock void BSCore_GetActiveSummarySelectQueryByAccountId(int iAccountId, char[] szQuery, int iMaxLength)
{
	szQuery[0] = '\0';
	int iLen = 0;

	iLen += Format(szQuery[iLen], iMaxLength - iLen, "SELECT ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "((CASE WHEN access_ban.`id` IS NOT NULL THEN 1 ELSE 0 END) ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "| (CASE WHEN comm_ban.`id` IS NOT NULL THEN 2 ELSE 0 END) ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "| (CASE WHEN spray_ban.`id` IS NOT NULL THEN 4 ELSE 0 END)) AS `module_mask`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(access_ban.`id`, 0) AS `access_ban_id`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`id`, 0) AS `comm_ban_id`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(spray_ban.`id`, 0) AS `spray_ban_id`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`ban_type`, 0) AS `comm_type`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`ban_length`, 0) AS `comm_length`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`ban_reason`, '') AS `comm_reason`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`ban_context`, '') AS `comm_context`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(comm_ban.`banned_by_name`, '') AS `comm_banned_by_name`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(UNIX_TIMESTAMP(comm_ban.`date_expire`), 0) AS `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(spray_ban.`ban_length`, 0) AS `spray_length`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(spray_ban.`ban_reason`, '') AS `spray_reason`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(spray_ban.`ban_context`, '') AS `spray_context`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(spray_ban.`banned_by_name`, '') AS `spray_banned_by_name`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "IFNULL(UNIX_TIMESTAMP(spray_ban.`date_expire`), 0) AS `spray_expire_ts` ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "FROM (SELECT %d AS `accountid`) AS src ", iAccountId);
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "LEFT JOIN `view_bansystem_access_bans_active` AS access_ban ON access_ban.`accountid` = src.`accountid` ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "LEFT JOIN `view_bansystem_comm_bans_active` AS comm_ban ON comm_ban.`accountid` = src.`accountid` ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "LEFT JOIN `view_bansystem_spray_bans_active` AS spray_ban ON spray_ban.`accountid` = src.`accountid` ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "WHERE access_ban.`id` IS NOT NULL OR comm_ban.`id` IS NOT NULL OR spray_ban.`id` IS NOT NULL ");
	Format(szQuery[iLen], iMaxLength - iLen, "LIMIT 1;");
}

stock void BSCore_GetSummaryCacheSelectQueryByAccountId(int iAccountId, char[] szQuery, int iMaxLength)
{
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "SELECT `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], iMaxLength - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts` ");
	Format(szQuery[iLen], iMaxLength - iLen, "FROM `%s` WHERE `accountid` = %d LIMIT 1;", BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE, iAccountId);
}

stock bool BSCore_SummaryRequiresModuleDetails(eBSCoreModuleBit eModuleMask)
{
	return (eModuleMask != kBSCoreModule_None);
}

stock bool BSCore_SummaryDeniesAccess(eBSCoreModuleBit eModuleMask)
{
	return BSCore_HasModule(eModuleMask, kBSCoreModule_Access);
}

stock bool BSCore_SummaryHasCommState(eBSCoreModuleBit eModuleMask)
{
	return BSCore_HasModule(eModuleMask, kBSCoreModule_Communication);
}

stock bool BSCore_SummaryHasSprayState(eBSCoreModuleBit eModuleMask)
{
	return BSCore_HasModule(eModuleMask, kBSCoreModule_Sprays);
}

stock void BSCore_ScheduleCacheSummarySync(int iAccountId)
{
	if (!BSCore_CanUsePrimaryDatabase() || !BSCore_CanUseCacheDatabase() || iAccountId <= 0)
		return;

	char szQuery[256];
	BSCore_GetSummarySelectQueryByAccountId(iAccountId, szQuery, sizeof(szQuery));
	BSCore_SQL("Scheduling cache summary sync for accountid %d using query: %s", iAccountId, szQuery);

	DataPack pContext = new DataPack();
	pContext.WriteCell(iAccountId);
	SQL_TQuery(g_dbCorePrimary, BSCore_OnCacheSummarySyncLoaded, szQuery, pContext, DBPrio_Normal);
}

stock bool BSCore_UpsertCacheSummary(int iAccountId, eBSCoreModuleBit eModuleMask, int iAccessBanId, int iCommBanId, int iSprayBanId, eBSCoreCommType eCommType, int iCommLength = 0, const char[] szCommReason = "", const char[] szCommContext = "", const char[] szCommBannedByName = "", int iCommExpireTs = 0, int iSprayLength = 0, const char[] szSprayReason = "", const char[] szSprayContext = "", const char[] szSprayBannedByName = "", int iSprayExpireTs = 0)
{
	if (!BSCore_CanUseCacheDatabase() || iAccountId <= 0)
		return false;

	char szSafeCommReason[513];
	char szSafeCommContext[1025];
	char szSafeCommBannedByName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeSprayReason[513];
	char szSafeSprayContext[1025];
	char szSafeSprayBannedByName[(MAX_NAME_LENGTH * 2) + 1];
	g_dbCoreCache.Escape(szCommReason, szSafeCommReason, sizeof(szSafeCommReason));
	g_dbCoreCache.Escape(szCommContext, szSafeCommContext, sizeof(szSafeCommContext));
	g_dbCoreCache.Escape(szCommBannedByName, szSafeCommBannedByName, sizeof(szSafeCommBannedByName));
	g_dbCoreCache.Escape(szSprayReason, szSafeSprayReason, sizeof(szSafeSprayReason));
	g_dbCoreCache.Escape(szSprayContext, szSafeSprayContext, sizeof(szSafeSprayContext));
	g_dbCoreCache.Escape(szSprayBannedByName, szSafeSprayBannedByName, sizeof(szSafeSprayBannedByName));
	char szQuery[3072];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d, %d, %d, %d, %d, %d, '%s', '%s', '%s', %d, %d, '%s', '%s', '%s', %d);",
		iAccountId,
		view_as<int>(eModuleMask),
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType),
		iCommLength,
		szSafeCommReason,
		szSafeCommContext,
		szSafeCommBannedByName,
		iCommExpireTs,
		iSprayLength,
		szSafeSprayReason,
		szSafeSprayContext,
		szSafeSprayBannedByName,
		iSprayExpireTs
	);

	BSCore_SQL("SQLite summary upsert query: %s", szQuery);
	return SQL_FastQuery(g_dbCoreCache, szQuery);
}

stock bool BSCore_UpsertPrimarySummary(int iAccountId, eBSCoreModuleBit eModuleMask, int iAccessBanId, int iCommBanId, int iSprayBanId, eBSCoreCommType eCommType, int iCommLength = 0, const char[] szCommReason = "", const char[] szCommContext = "", const char[] szCommBannedByName = "", int iCommExpireTs = 0, int iSprayLength = 0, const char[] szSprayReason = "", const char[] szSprayContext = "", const char[] szSprayBannedByName = "", int iSprayExpireTs = 0)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0)
		return false;

	char szSafeCommReason[513];
	char szSafeCommContext[1025];
	char szSafeCommBannedByName[(MAX_NAME_LENGTH * 2) + 1];
	char szSafeSprayReason[513];
	char szSafeSprayContext[1025];
	char szSafeSprayBannedByName[(MAX_NAME_LENGTH * 2) + 1];
	g_dbCorePrimary.Escape(szCommReason, szSafeCommReason, sizeof(szSafeCommReason));
	g_dbCorePrimary.Escape(szCommContext, szSafeCommContext, sizeof(szSafeCommContext));
	g_dbCorePrimary.Escape(szCommBannedByName, szSafeCommBannedByName, sizeof(szSafeCommBannedByName));
	g_dbCorePrimary.Escape(szSprayReason, szSafeSprayReason, sizeof(szSafeSprayReason));
	g_dbCorePrimary.Escape(szSprayContext, szSafeSprayContext, sizeof(szSafeSprayContext));
	g_dbCorePrimary.Escape(szSprayBannedByName, szSafeSprayBannedByName, sizeof(szSafeSprayBannedByName));
	char szQuery[4096];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d, %d, %d, %d, %d, %d, '%s', '%s', '%s', %d, %d, '%s', '%s', '%s', %d) ",
		iAccountId,
		view_as<int>(eModuleMask),
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType),
		iCommLength,
		szSafeCommReason,
		szSafeCommContext,
		szSafeCommBannedByName,
		iCommExpireTs,
		iSprayLength,
		szSafeSprayReason,
		szSafeSprayContext,
		szSafeSprayBannedByName,
		iSprayExpireTs
	);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`module_mask` = VALUES(`module_mask`), `access_ban_id` = VALUES(`access_ban_id`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_ban_id` = VALUES(`comm_ban_id`), `spray_ban_id` = VALUES(`spray_ban_id`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_type` = VALUES(`comm_type`), `comm_length` = VALUES(`comm_length`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_reason` = VALUES(`comm_reason`), `comm_context` = VALUES(`comm_context`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_banned_by_name` = VALUES(`comm_banned_by_name`), `comm_expire_ts` = VALUES(`comm_expire_ts`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length` = VALUES(`spray_length`), `spray_reason` = VALUES(`spray_reason`), ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_context` = VALUES(`spray_context`), `spray_banned_by_name` = VALUES(`spray_banned_by_name`), ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_expire_ts` = VALUES(`spray_expire_ts`);");

	BSCore_SQL("Primary summary upsert query: %s", szQuery);
	return SQL_FastQuery(g_dbCorePrimary, szQuery);
}

stock bool BSCore_DeleteCacheSummary(int iAccountId)
{
	if (!BSCore_CanUseCacheDatabase() || iAccountId <= 0)
		return false;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d;", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY, iAccountId);
	BSCore_SQL("SQLite summary delete query: %s", szQuery);
	return SQL_FastQuery(g_dbCoreCache, szQuery);
}

stock bool BSCore_SetAccessSummary(int iAccountId, int iBanId)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0 || iBanId <= 0)
		return false;

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	char szQuery[512];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d, %d, 0, 0, 0) ", iAccountId, view_as<int>(kBSCoreModule_Access), iBanId);
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `access_ban_id` = %d;", view_as<int>(kBSCoreModule_Access), iBanId);

	BSCore_SQL("Set access summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

	return bResult;
}

stock bool BSCore_SetCommSummary(int iAccountId, int iBanId, eBSCoreCommType eCommType)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0 || iBanId <= 0)
		return false;

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	char szQuery[1024];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d, 0, %d, 0, %d, 0, '', '', '', 0) ",
		iAccountId,
		view_as<int>(kBSCoreModule_Communication),
		iBanId,
		view_as<int>(eCommType)
	);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `comm_ban_id` = %d, ",
		view_as<int>(kBSCoreModule_Communication),
		iBanId
	);
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_type` = %d, `comm_length` = 0, `comm_reason` = '', `comm_context` = '', `comm_banned_by_name` = '', `comm_expire_ts` = 0;", view_as<int>(eCommType));

	BSCore_SQL("Set communication summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

	return bResult;
}

stock void BSCore_UpdateResolvedCommDetailForAccountId(int iAccountId, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, int iExpireTs)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_iCoreResolvedAccountId[iClient] != iAccountId)
			continue;

		g_iCoreResolvedCommLength[iClient] = iLength;
		strcopy(g_szCoreResolvedCommReason[iClient], sizeof(g_szCoreResolvedCommReason[]), szReason);
		strcopy(g_szCoreResolvedCommContext[iClient], sizeof(g_szCoreResolvedCommContext[]), szContext);
		strcopy(g_szCoreResolvedCommBannedByName[iClient], sizeof(g_szCoreResolvedCommBannedByName[]), szBannedByName);
		g_iCoreResolvedCommExpireTs[iClient] = iExpireTs;
	}
}

stock bool BSCore_SetCommSummaryDetail(int iAccountId, int iBanId, eBSCoreCommType eCommType, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, int iExpireTs)
{
	bool bResult = BSCore_UpsertPrimarySummary(iAccountId, kBSCoreModule_Communication, 0, iBanId, 0, eCommType, iLength, szReason, szContext, szBannedByName, iExpireTs);
	if (bResult)
	{
		BSCore_ScheduleCacheSummarySync(iAccountId);
		BSCore_UpdateResolvedCommDetailForAccountId(iAccountId, iLength, szReason, szContext, szBannedByName, iExpireTs);
	}

	return bResult;
}

stock bool BSCore_SetSpraySummary(int iAccountId, int iBanId)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0 || iBanId <= 0)
		return false;

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	char szQuery[1024];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "INSERT INTO `%s` ", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`) ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "VALUES (%d, %d, 0, 0, %d, 0, 0, '', '', '', 0) ",
		iAccountId,
		view_as<int>(kBSCoreModule_Sprays),
		iBanId
	);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `spray_ban_id` = %d, ",
		view_as<int>(kBSCoreModule_Sprays),
		iBanId
	);
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length` = 0, `spray_reason` = '', `spray_context` = '', `spray_banned_by_name` = '', `spray_expire_ts` = 0;");

	BSCore_SQL("Set spray summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

	return bResult;
}

stock void BSCore_UpdateResolvedSprayDetailForAccountId(int iAccountId, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, int iExpireTs)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_iCoreResolvedAccountId[iClient] != iAccountId)
			continue;

		g_iCoreResolvedSprayLength[iClient] = iLength;
		strcopy(g_szCoreResolvedSprayReason[iClient], sizeof(g_szCoreResolvedSprayReason[]), szReason);
		strcopy(g_szCoreResolvedSprayContext[iClient], sizeof(g_szCoreResolvedSprayContext[]), szContext);
		strcopy(g_szCoreResolvedSprayBannedByName[iClient], sizeof(g_szCoreResolvedSprayBannedByName[]), szBannedByName);
		g_iCoreResolvedSprayExpireTs[iClient] = iExpireTs;
	}
}

stock bool BSCore_SetSpraySummaryDetail(int iAccountId, int iBanId, int iLength, const char[] szReason, const char[] szContext, const char[] szBannedByName, int iExpireTs)
{
	bool bResult = BSCore_UpsertPrimarySummary(iAccountId, kBSCoreModule_Sprays, 0, 0, iBanId, kBSCoreComm_None, 0, "", "", "", 0, iLength, szReason, szContext, szBannedByName, iExpireTs);
	if (bResult)
	{
		BSCore_ScheduleCacheSummarySync(iAccountId);
		BSCore_UpdateResolvedSprayDetailForAccountId(iAccountId, iLength, szReason, szContext, szBannedByName, iExpireTs);
	}

	return bResult;
}

stock bool BSCore_ClearSummaryModule(int iAccountId, eBSCoreModuleBit eModuleBit)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0 || eModuleBit == kBSCoreModule_None)
		return false;

	char szFieldReset[128];
	switch (eModuleBit)
	{
		case kBSCoreModule_Access:
			strcopy(szFieldReset, sizeof(szFieldReset), "`access_ban_id` = 0");
		case kBSCoreModule_Communication:
			strcopy(szFieldReset, sizeof(szFieldReset), "`comm_ban_id` = 0, `comm_type` = 0, `comm_length` = 0, `comm_reason` = '', `comm_context` = '', `comm_banned_by_name` = '', `comm_expire_ts` = 0");
		case kBSCoreModule_Sprays:
			strcopy(szFieldReset, sizeof(szFieldReset), "`spray_ban_id` = 0, `spray_length` = 0, `spray_reason` = '', `spray_context` = '', `spray_banned_by_name` = '', `spray_expire_ts` = 0");
		default:
			return false;
	}

	char szQuery[1024];
	Format(
		szQuery,
		sizeof(szQuery),
		"UPDATE `%s` SET `module_mask` = (`module_mask` & ~%d), %s WHERE `accountid` = %d;",
		BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY,
		view_as<int>(eModuleBit),
		szFieldReset,
		iAccountId
	);

	BSCore_SQL("Clear summary module query: %s", szQuery);
	if (!SQL_FastQuery(g_dbCorePrimary, szQuery))
		return false;

	Format(
		szQuery,
		sizeof(szQuery),
		"DELETE FROM `%s` WHERE `accountid` = %d AND `module_mask` = 0;",
		BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY,
		iAccountId
	);
	BSCore_SQL("Cleanup empty summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

	return bResult;
}

stock bool BSCore_ClearSummary(int iAccountId)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0)
		return false;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DELETE FROM `%s` WHERE `accountid` = %d;", BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY, iAccountId);
	BSCore_SQL("Clear full summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_DeleteCacheSummary(iAccountId);

	return bResult;
}

stock void BSCore_DropCacheSchema()
{
	if (g_dbCoreCache == null)
		return;

	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "DROP TRIGGER IF EXISTS `%s`;", BANSYSTEM_CORE_SQLITE_TRIGGER_SUMMARY_UPSERT);
	SQL_FastQuery(g_dbCoreCache, szQuery);

	Format(szQuery, sizeof(szQuery), "DROP VIEW IF EXISTS `%s`;", BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE);
	SQL_FastQuery(g_dbCoreCache, szQuery);

	Format(szQuery, sizeof(szQuery), "DROP TABLE IF EXISTS `%s`;", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	SQL_FastQuery(g_dbCoreCache, szQuery);

	g_bCoreCacheReady = false;
	BSCore_SQL("Dropped core SQLite summary cache schema.");
}

stock void BSCore_InstallCacheSchema()
{
	if (g_dbCoreCache == null)
		return;

	char szQuery[3072];
	szQuery[0] = '\0';
	int iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "(`accountid` INTEGER NOT NULL, `module_mask` INTEGER NOT NULL DEFAULT 0, `access_ban_id` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_ban_id` INTEGER NOT NULL DEFAULT 0, `spray_ban_id` INTEGER NOT NULL DEFAULT 0, `comm_type` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_length` INTEGER NOT NULL DEFAULT 0, `comm_reason` TEXT NOT NULL DEFAULT '', `comm_context` TEXT NOT NULL DEFAULT '', ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_banned_by_name` TEXT NOT NULL DEFAULT '', `comm_expire_ts` INTEGER NOT NULL DEFAULT 0, `spray_length` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_reason` TEXT NOT NULL DEFAULT '', `spray_context` TEXT NOT NULL DEFAULT '', `spray_banned_by_name` TEXT NOT NULL DEFAULT '', ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_expire_ts` INTEGER NOT NULL DEFAULT 0, `date_cache` INTEGER NOT NULL DEFAULT (strftime('%%s', 'now')), PRIMARY KEY (`accountid`));");
	SQL_FastQuery(g_dbCoreCache, szQuery);

	Format(
		szQuery,
		sizeof(szQuery),
		"CREATE TRIGGER IF NOT EXISTS `%s` BEFORE INSERT ON `%s` BEGIN DELETE FROM `%s` WHERE `accountid` = NEW.`accountid`; END;",
		BANSYSTEM_CORE_SQLITE_TRIGGER_SUMMARY_UPSERT,
		BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY,
		BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY
	);
	SQL_FastQuery(g_dbCoreCache, szQuery);

	szQuery[0] = '\0';
	iLen = 0;
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "CREATE VIEW IF NOT EXISTS `%s` AS SELECT ", BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE);
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ");
	iLen += Format(szQuery[iLen], sizeof(szQuery) - iLen, "`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`, `date_cache` ");
	Format(szQuery[iLen], sizeof(szQuery) - iLen, "FROM `%s` WHERE `date_cache` >= strftime('%%s', 'now') - 604800;", BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY);
	SQL_FastQuery(g_dbCoreCache, szQuery);

	g_bCoreCacheReady = true;
	BSCore_SQL("Installed core SQLite summary cache schema.");
}

public void BSCore_OnCacheSummarySyncLoaded(Database db, DBResultSet rsResult, const char[] szError, any pData)
{
	DataPack pContext = view_as<DataPack>(pData);
	pContext.Reset();
	int iAccountId = pContext.ReadCell();
	delete pContext;

	if (!BSCore_CanUseCacheDatabase())
	{
		delete rsResult;
		return;
	}

	if (rsResult == null || szError[0] != '\0')
	{
		BSCore_SQL("Cache summary sync source query failed for accountid %d: %s", iAccountId, szError);
		delete rsResult;
		return;
	}

	if (!rsResult.FetchRow())
	{
		BSCore_SQL("Cache summary sync found no source row for accountid %d. Removing local cache row.", iAccountId);
		BSCore_DeleteCacheSummary(iAccountId);
		delete rsResult;
		return;
	}

	eBSCoreModuleBit eModuleMask = view_as<eBSCoreModuleBit>(rsResult.FetchInt(0));
	int iAccessBanId = rsResult.FetchInt(1);
	int iCommBanId = rsResult.FetchInt(2);
	int iSprayBanId = rsResult.FetchInt(3);
	eBSCoreCommType eCommType = view_as<eBSCoreCommType>(rsResult.FetchInt(4));
	int iCommLength = rsResult.FetchInt(5);
	char szCommReason[256];
	char szCommContext[512];
	char szCommBannedByName[MAX_NAME_LENGTH];
	int iCommExpireTs = rsResult.FetchInt(9);
	int iSprayLength = rsResult.FetchInt(10);
	char szSprayReason[256];
	char szSprayContext[512];
	char szSprayBannedByName[MAX_NAME_LENGTH];
	int iSprayExpireTs = rsResult.FetchInt(14);
	rsResult.FetchString(6, szCommReason, sizeof(szCommReason));
	rsResult.FetchString(7, szCommContext, sizeof(szCommContext));
	rsResult.FetchString(8, szCommBannedByName, sizeof(szCommBannedByName));
	rsResult.FetchString(11, szSprayReason, sizeof(szSprayReason));
	rsResult.FetchString(12, szSprayContext, sizeof(szSprayContext));
	rsResult.FetchString(13, szSprayBannedByName, sizeof(szSprayBannedByName));
	delete rsResult;

	if (!BSCore_UpsertCacheSummary(iAccountId, eModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType, iCommLength, szCommReason, szCommContext, szCommBannedByName, iCommExpireTs, iSprayLength, szSprayReason, szSprayContext, szSprayBannedByName, iSprayExpireTs))
	{
		BSCore_SQL("Failed to write synced SQLite summary row for accountid %d.", iAccountId);
		return;
	}

	BSCore_SQL(
		"Synchronized SQLite summary for accountid %d (mask=%d access=%d comm=%d spray=%d comm_type=%d).",
		iAccountId,
		view_as<int>(eModuleMask),
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType)
	);
}
