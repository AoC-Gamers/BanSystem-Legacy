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
	Format(szQuery, iMaxLength,
		"CALL `%s`(%d);",
		BANSYSTEM_CORE_MYSQL_PROCEDURE_GET_AUTH_SUMMARY,
		iAccountId);
}

stock void BSCore_GetSummaryCacheSelectQueryByAccountId(int iAccountId, char[] szQuery, int iMaxLength)
{
	Format(szQuery, iMaxLength,
		"SELECT `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type` FROM `%s` WHERE `accountid` = %d LIMIT 1;",
		BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE,
		iAccountId);
}

stock bool BSCore_SummaryRequiresModuleDetails(int iModuleMask)
{
	return (iModuleMask != 0);
}

stock bool BSCore_SummaryDeniesAccess(int iModuleMask)
{
	return BSCore_HasModule(iModuleMask, kBSCoreModule_Access);
}

stock bool BSCore_SummaryHasCommState(int iModuleMask)
{
	return BSCore_HasModule(iModuleMask, kBSCoreModule_Communication);
}

stock bool BSCore_SummaryHasSprayState(int iModuleMask)
{
	return BSCore_HasModule(iModuleMask, kBSCoreModule_Sprays);
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

stock bool BSCore_UpsertCacheSummary(int iAccountId, int iModuleMask, int iAccessBanId, int iCommBanId, int iSprayBanId, eBSCoreCommType eCommType)
{
	if (!BSCore_CanUseCacheDatabase() || iAccountId <= 0)
		return false;

	char szQuery[512];
	Format(
		szQuery,
		sizeof(szQuery),
		"INSERT INTO `%s` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`) VALUES (%d, %d, %d, %d, %d, %d);",
		BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY,
		iAccountId,
		iModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType)
	);

	BSCore_SQL("SQLite summary upsert query: %s", szQuery);
	return SQL_FastQuery(g_dbCoreCache, szQuery);
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
	Format(
		szQuery,
		sizeof(szQuery),
		"INSERT INTO `%s` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`) VALUES (%d, %d, %d, 0, 0, 0) ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `access_ban_id` = %d;",
		BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY,
		iAccountId,
		view_as<int>(kBSCoreModule_Access),
		iBanId,
		view_as<int>(kBSCoreModule_Access),
		iBanId
	);

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

	char szQuery[512];
	Format(
		szQuery,
		sizeof(szQuery),
		"INSERT INTO `%s` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`) VALUES (%d, %d, 0, %d, 0, %d) ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `comm_ban_id` = %d, `comm_type` = %d;",
		BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY,
		iAccountId,
		view_as<int>(kBSCoreModule_Communication),
		iBanId,
		view_as<int>(eCommType),
		view_as<int>(kBSCoreModule_Communication),
		iBanId,
		view_as<int>(eCommType)
	);

	BSCore_SQL("Set communication summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

	return bResult;
}

stock bool BSCore_SetSpraySummary(int iAccountId, int iBanId)
{
	if (!BSCore_CanUsePrimaryDatabase() || iAccountId <= 0 || iBanId <= 0)
		return false;

	BSCore_RemoveLocalCleanCacheAccountId(iAccountId);

	char szQuery[512];
	Format(
		szQuery,
		sizeof(szQuery),
		"INSERT INTO `%s` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`) VALUES (%d, %d, 0, 0, %d, 0) ON DUPLICATE KEY UPDATE `module_mask` = (`module_mask` | %d), `spray_ban_id` = %d;",
		BANSYSTEM_CORE_MYSQL_TABLE_SUMMARY,
		iAccountId,
		view_as<int>(kBSCoreModule_Sprays),
		iBanId,
		view_as<int>(kBSCoreModule_Sprays),
		iBanId
	);

	BSCore_SQL("Set spray summary query: %s", szQuery);
	bool bResult = SQL_FastQuery(g_dbCorePrimary, szQuery);
	if (bResult)
		BSCore_ScheduleCacheSummarySync(iAccountId);

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
			strcopy(szFieldReset, sizeof(szFieldReset), "`comm_ban_id` = 0, `comm_type` = 0");
		case kBSCoreModule_Sprays:
			strcopy(szFieldReset, sizeof(szFieldReset), "`spray_ban_id` = 0");
		default:
			return false;
	}

	char szQuery[512];
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

	char szQuery[1024];
	Format(
		szQuery,
		sizeof(szQuery),
		"CREATE TABLE IF NOT EXISTS `%s` (`accountid` INTEGER NOT NULL, `module_mask` INTEGER NOT NULL DEFAULT 0, `access_ban_id` INTEGER NOT NULL DEFAULT 0, `comm_ban_id` INTEGER NOT NULL DEFAULT 0, `spray_ban_id` INTEGER NOT NULL DEFAULT 0, `comm_type` INTEGER NOT NULL DEFAULT 0, `date_cache` INTEGER NOT NULL DEFAULT (strftime('%%s', 'now')), PRIMARY KEY (`accountid`));",
		BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY
	);
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

	Format(
		szQuery,
		sizeof(szQuery),
		"CREATE VIEW IF NOT EXISTS `%s` AS SELECT `accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`, `date_cache` FROM `%s` WHERE `date_cache` >= strftime('%%s', 'now') - 604800;",
		BANSYSTEM_CORE_SQLITE_VIEW_SUMMARY_ACTIVE,
		BANSYSTEM_CORE_SQLITE_TABLE_SUMMARY
	);
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

	int iModuleMask = rsResult.FetchInt(0);
	int iAccessBanId = rsResult.FetchInt(1);
	int iCommBanId = rsResult.FetchInt(2);
	int iSprayBanId = rsResult.FetchInt(3);
	eBSCoreCommType eCommType = view_as<eBSCoreCommType>(rsResult.FetchInt(4));
	delete rsResult;

	if (!BSCore_UpsertCacheSummary(iAccountId, iModuleMask, iAccessBanId, iCommBanId, iSprayBanId, eCommType))
	{
		BSCore_SQL("Failed to write synced SQLite summary row for accountid %d.", iAccountId);
		return;
	}

	BSCore_SQL(
		"Synchronized SQLite summary for accountid %d (mask=%d access=%d comm=%d spray=%d comm_type=%d).",
		iAccountId,
		iModuleMask,
		iAccessBanId,
		iCommBanId,
		iSprayBanId,
		view_as<int>(eCommType)
	);
}
