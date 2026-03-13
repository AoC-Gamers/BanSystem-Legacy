void vConnectLocalSnapshot()
{
	if (GetSnapshotBackend() != Backend_SQLite)
	{
		vAdminSyncDebug("Local snapshot backend is not SQLite; skipping local SQLite connection.");
		return;
	}

	char szError[256];
	if (g_dbLocal != null)
	{
		delete g_dbLocal;
		g_dbLocal = null;
	}

	g_dbLocal = SQLite_UseDatabase("bansystem_adminsync", szError, sizeof(szError));
	if (g_dbLocal == null)
	{
		LogError("[bansystem_adminsync] Failed to open local SQLite snapshot: %s", szError);
		return;
	}

	vAdminSyncDebug("Opened local SQLite snapshot successfully.");
	vEnsureLocalSQLiteSchema();
}

void vEnsureLocalSQLiteSchema()
{
	if (g_dbLocal == null)
		return;

	SQL_FastQuery(g_dbLocal, "CREATE TABLE IF NOT EXISTS `adminsync_admins` (`id` INTEGER PRIMARY KEY, `accountid` INTEGER NOT NULL, `name` TEXT NOT NULL DEFAULT 'UNKNOWN', `flags` TEXT NOT NULL DEFAULT '', `immunity` INTEGER NOT NULL DEFAULT 0, `enabled` INTEGER NOT NULL DEFAULT 1);");
	SQL_FastQuery(g_dbLocal, "CREATE UNIQUE INDEX IF NOT EXISTS `idx_adminsync_admins_accountid` ON `adminsync_admins` (`accountid`);");
	SQL_FastQuery(g_dbLocal, "CREATE TABLE IF NOT EXISTS `adminsync_groups` (`id` INTEGER PRIMARY KEY, `name` TEXT NOT NULL, `flags` TEXT NOT NULL DEFAULT '', `immunity_level` INTEGER NOT NULL DEFAULT 0, `enabled` INTEGER NOT NULL DEFAULT 1);");
	SQL_FastQuery(g_dbLocal, "CREATE UNIQUE INDEX IF NOT EXISTS `idx_adminsync_groups_name` ON `adminsync_groups` (`name`);");
	SQL_FastQuery(g_dbLocal, "CREATE TABLE IF NOT EXISTS `adminsync_admins_groups` (`admin_id` INTEGER NOT NULL, `group_id` INTEGER NOT NULL, `inherit_order` INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (`admin_id`, `group_id`));");
	vAdminSyncDebug("Ensured local SQLite snapshot schema.");
}

void vClearLocalSQLiteSnapshot()
{
	if (g_dbLocal == null)
		return;

	SQL_FastQuery(g_dbLocal, "DELETE FROM `adminsync_admins_groups`;");
	SQL_FastQuery(g_dbLocal, "DELETE FROM `adminsync_admins`;");
	SQL_FastQuery(g_dbLocal, "DELETE FROM `adminsync_groups`;");
	vAdminSyncDebug("Cleared local SQLite snapshot.");
}

void vWriteEmptyKvSnapshot()
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	kv.JumpToKey("admins", true);
	kv.GoBack();
	kv.JumpToKey("groups", true);
	kv.GoBack();
	kv.JumpToKey("memberships", true);
	kv.GoBack();
	kv.ExportToFile(g_szKvSnapshotPath);
	delete kv;
	vAdminSyncDebug("Wrote empty KV snapshot to '%s'.", g_szKvSnapshotPath);
}

void vPersistAdminsToSQLite(DBResultSet rsResult)
{
	if (g_dbLocal == null)
		return;

	while (rsResult.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		char szSafeName[257];
		char szSafeFlags[129];
		char szQuery[512];

		int iId = rsResult.FetchInt(0);
		int iAccountId = rsResult.FetchInt(1);
		int iImmunity = rsResult.FetchInt(4);
		int iEnabled = rsResult.FetchInt(5);

		rsResult.FetchString(2, szName, sizeof(szName));
		rsResult.FetchString(3, szFlags, sizeof(szFlags));
		g_dbLocal.Escape(szName, szSafeName, sizeof(szSafeName));
		g_dbLocal.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

		Format(szQuery, sizeof(szQuery), "INSERT INTO `adminsync_admins` (`id`, `accountid`, `name`, `flags`, `immunity`, `enabled`) VALUES (%d, %d, '%s', '%s', %d, %d);",
			iId, iAccountId, szSafeName, szSafeFlags, iImmunity, iEnabled);
		SQL_FastQuery(g_dbLocal, szQuery);
		g_iLastAdminCount++;
	}
}

void vPersistAdminsToKeyValues(DBResultSet rsResult)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	kv.ImportFromFile(g_szKvSnapshotPath);
	kv.JumpToKey("admins", true);

	while (rsResult.FetchRow())
	{
		char szSection[32];
		char szName[128];
		char szFlags[64];

		IntToString(rsResult.FetchInt(1), szSection, sizeof(szSection));
		kv.JumpToKey(szSection, true);
		rsResult.FetchString(2, szName, sizeof(szName));
		rsResult.FetchString(3, szFlags, sizeof(szFlags));
		kv.SetNum("id", rsResult.FetchInt(0));
		kv.SetNum("accountid", rsResult.FetchInt(1));
		kv.SetString("name", szName);
		kv.SetString("flags", szFlags);
		kv.SetNum("immunity", rsResult.FetchInt(4));
		kv.SetNum("enabled", rsResult.FetchInt(5));
		kv.GoBack();
		g_iLastAdminCount++;
	}

	kv.Rewind();
	kv.ExportToFile(g_szKvSnapshotPath);
	delete kv;
}

void vPersistGroupsToSQLite(DBResultSet rsResult)
{
	if (g_dbLocal == null)
		return;

	while (rsResult.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		char szSafeName[257];
		char szSafeFlags[129];
		char szQuery[512];

		int iId = rsResult.FetchInt(0);
		int iImmunity = rsResult.FetchInt(3);
		int iEnabled = rsResult.FetchInt(4);

		rsResult.FetchString(1, szName, sizeof(szName));
		rsResult.FetchString(2, szFlags, sizeof(szFlags));
		g_dbLocal.Escape(szName, szSafeName, sizeof(szSafeName));
		g_dbLocal.Escape(szFlags, szSafeFlags, sizeof(szSafeFlags));

		Format(szQuery, sizeof(szQuery), "INSERT INTO `adminsync_groups` (`id`, `name`, `flags`, `immunity_level`, `enabled`) VALUES (%d, '%s', '%s', %d, %d);",
			iId, szSafeName, szSafeFlags, iImmunity, iEnabled);
		SQL_FastQuery(g_dbLocal, szQuery);
		g_iLastGroupCount++;
	}
}

void vPersistGroupsToKeyValues(DBResultSet rsResult)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	kv.ImportFromFile(g_szKvSnapshotPath);
	kv.JumpToKey("groups", true);

	while (rsResult.FetchRow())
	{
		char szSection[32];
		char szName[128];
		char szFlags[64];

		IntToString(rsResult.FetchInt(0), szSection, sizeof(szSection));
		kv.JumpToKey(szSection, true);
		rsResult.FetchString(1, szName, sizeof(szName));
		rsResult.FetchString(2, szFlags, sizeof(szFlags));
		kv.SetNum("id", rsResult.FetchInt(0));
		kv.SetString("name", szName);
		kv.SetString("flags", szFlags);
		kv.SetNum("immunity_level", rsResult.FetchInt(3));
		kv.SetNum("enabled", rsResult.FetchInt(4));
		kv.GoBack();
		g_iLastGroupCount++;
	}

	kv.Rewind();
	kv.ExportToFile(g_szKvSnapshotPath);
	delete kv;
}

void vPersistMembershipsToSQLite(DBResultSet rsResult)
{
	if (g_dbLocal == null)
		return;

	while (rsResult.FetchRow())
	{
		char szQuery[256];
		Format(szQuery, sizeof(szQuery), "INSERT INTO `adminsync_admins_groups` (`admin_id`, `group_id`, `inherit_order`) VALUES (%d, %d, %d);",
			rsResult.FetchInt(0), rsResult.FetchInt(1), rsResult.FetchInt(2));
		SQL_FastQuery(g_dbLocal, szQuery);
		g_iLastMembershipCount++;
	}
}

void vPersistMembershipsToKeyValues(DBResultSet rsResult)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	kv.ImportFromFile(g_szKvSnapshotPath);
	kv.JumpToKey("memberships", true);

	int iIndex = 0;
	while (rsResult.FetchRow())
	{
		char szSection[16];
		IntToString(iIndex, szSection, sizeof(szSection));
		kv.JumpToKey(szSection, true);
		kv.SetNum("admin_id", rsResult.FetchInt(0));
		kv.SetNum("group_id", rsResult.FetchInt(1));
		kv.SetNum("inherit_order", rsResult.FetchInt(2));
		kv.GoBack();
		iIndex++;
		g_iLastMembershipCount++;
	}

	kv.Rewind();
	kv.ExportToFile(g_szKvSnapshotPath);
	delete kv;
}

void vVerifySQLiteSnapshot(int iClient)
{
	if (g_dbLocal == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] verify: local SQLite snapshot is not available.");
		return;
	}

	DBResultSet rsAdmins = SQL_Query(g_dbLocal, "SELECT COUNT(*), COUNT(DISTINCT `accountid`) FROM `adminsync_admins` WHERE `enabled` = 1;");
	DBResultSet rsGroups = SQL_Query(g_dbLocal, "SELECT COUNT(*) FROM `adminsync_groups` WHERE `enabled` = 1;");
	DBResultSet rsMemberships = SQL_Query(g_dbLocal, "SELECT COUNT(*) FROM `adminsync_admins_groups`;");
	DBResultSet rsOrphans = SQL_Query(g_dbLocal, "SELECT COUNT(*) FROM `adminsync_admins_groups` ag LEFT JOIN `adminsync_admins` a ON a.`id` = ag.`admin_id` LEFT JOIN `adminsync_groups` g ON g.`id` = ag.`group_id` WHERE a.`id` IS NULL OR g.`id` IS NULL;");

	int iAdmins = 0;
	int iDistinctAdmins = 0;
	int iGroups = 0;
	int iMemberships = 0;
	int iOrphans = 0;

	if (rsAdmins != null && rsAdmins.FetchRow())
	{
		iAdmins = rsAdmins.FetchInt(0);
		iDistinctAdmins = rsAdmins.FetchInt(1);
	}
	if (rsGroups != null && rsGroups.FetchRow())
		iGroups = rsGroups.FetchInt(0);
	if (rsMemberships != null && rsMemberships.FetchRow())
		iMemberships = rsMemberships.FetchInt(0);
	if (rsOrphans != null && rsOrphans.FetchRow())
		iOrphans = rsOrphans.FetchInt(0);

	delete rsAdmins;
	delete rsGroups;
	delete rsMemberships;
	delete rsOrphans;

	ReplyToCommand(iClient, "[BS AdminSync] verify sqlite: admins=%d distinct_accountid=%d groups=%d memberships=%d orphan_memberships=%d",
		iAdmins, iDistinctAdmins, iGroups, iMemberships, iOrphans);
}

void vVerifyKvSnapshot(int iClient)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath))
	{
		delete kv;
		ReplyToCommand(iClient, "[BS AdminSync] verify: KV snapshot file is missing or unreadable.");
		return;
	}

	int iAdmins = 0;
	int iGroups = 0;
	int iMemberships = 0;

	if (kv.JumpToKey("admins", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			iAdmins++;
		}
		while (kv.GotoNextKey(false));
	}

	kv.Rewind();
	if (kv.JumpToKey("groups", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			iGroups++;
		}
		while (kv.GotoNextKey(false));
	}

	kv.Rewind();
	if (kv.JumpToKey("memberships", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			iMemberships++;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	ReplyToCommand(iClient, "[BS AdminSync] verify kv: admins=%d groups=%d memberships=%d file=%s",
		iAdmins, iGroups, iMemberships, g_szKvSnapshotPath);
}

void vListSQLiteAdmins(int iClient)
{
	if (g_dbLocal == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list admins: local SQLite snapshot is not available.");
		return;
	}

	DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `accountid`, `name`, `flags`, `immunity` FROM `adminsync_admins` WHERE `enabled` = 1 ORDER BY `id` ASC;");
	if (rsResult == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list admins: failed to query local SQLite snapshot.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Admins from local SQLite snapshot");

	int iCount = 0;
	while (rsResult.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		char szGroups[256];
		int iAccountId = rsResult.FetchInt(0);
		rsResult.FetchString(1, szName, sizeof(szName));
		rsResult.FetchString(2, szFlags, sizeof(szFlags));
		vBuildSnapshotAdminGroupsString(iAccountId, szGroups, sizeof(szGroups));
		PrintToConsole(iClient, "accountid=%d | name=%s | flags=%s | immunity=%d | groups=%s",
			iAccountId, szName, szFlags, rsResult.FetchInt(3), szGroups);
		iCount++;
	}

	delete rsResult;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d admins to console.", iCount);
}

void vListSQLiteGroups(int iClient)
{
	if (g_dbLocal == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list groups: local SQLite snapshot is not available.");
		return;
	}

	DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `name`, `flags`, `immunity_level` FROM `adminsync_groups` WHERE `enabled` = 1 ORDER BY `id` ASC;");
	if (rsResult == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list groups: failed to query local SQLite snapshot.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Groups from local SQLite snapshot");

	int iCount = 0;
	while (rsResult.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		rsResult.FetchString(0, szName, sizeof(szName));
		rsResult.FetchString(1, szFlags, sizeof(szFlags));
		PrintToConsole(iClient, "name=%s | flags=%s | immunity=%d",
			szName, szFlags, rsResult.FetchInt(2));
		iCount++;
	}

	delete rsResult;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d groups to console.", iCount);
}

void vListKvAdmins(int iClient)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("admins", false))
	{
		delete kv;
		ReplyToCommand(iClient, "[BS AdminSync] list admins: KV snapshot file is missing or unreadable.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Admins from local KV snapshot");

	int iCount = 0;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			char szFlags[64];
			char szGroups[256];
			int iAccountId = kv.GetNum("accountid", 0);
			kv.GetString("name", szName, sizeof(szName));
			kv.GetString("flags", szFlags, sizeof(szFlags));
			vBuildSnapshotAdminGroupsString(iAccountId, szGroups, sizeof(szGroups));
			PrintToConsole(iClient, "accountid=%d | name=%s | flags=%s | immunity=%d | groups=%s",
				iAccountId, szName, szFlags, kv.GetNum("immunity", 0), szGroups);
			iCount++;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d admins to console.", iCount);
}

void vListKvGroups(int iClient)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("groups", false))
	{
		delete kv;
		ReplyToCommand(iClient, "[BS AdminSync] list groups: KV snapshot file is missing or unreadable.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Groups from local KV snapshot");

	int iCount = 0;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			char szFlags[64];
			kv.GetString("name", szName, sizeof(szName));
			kv.GetString("flags", szFlags, sizeof(szFlags));
			PrintToConsole(iClient, "name=%s | flags=%s | immunity=%d",
				szName, szFlags, kv.GetNum("immunity_level", 0));
			iCount++;
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d groups to console.", iCount);
}

void vListSQLiteMemberships(int iClient)
{
	if (g_dbLocal == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list memberships: local SQLite snapshot is not available.");
		return;
	}

	DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT a.`accountid`, a.`name`, g.`name`, ag.`inherit_order` FROM `adminsync_admins_groups` ag INNER JOIN `adminsync_admins` a ON a.`id` = ag.`admin_id` INNER JOIN `adminsync_groups` g ON g.`id` = ag.`group_id` WHERE a.`enabled` = 1 AND g.`enabled` = 1 ORDER BY a.`id` ASC, ag.`inherit_order` ASC, g.`id` ASC;");
	if (rsResult == null)
	{
		ReplyToCommand(iClient, "[BS AdminSync] list memberships: failed to query local SQLite snapshot.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Admin-group memberships from local SQLite snapshot");

	int iCount = 0;
	while (rsResult.FetchRow())
	{
		char szAdminName[128];
		char szGroupName[128];
		rsResult.FetchString(1, szAdminName, sizeof(szAdminName));
		rsResult.FetchString(2, szGroupName, sizeof(szGroupName));
		PrintToConsole(iClient, "accountid=%d | admin=%s | group=%s | inherit_order=%d",
			rsResult.FetchInt(0), szAdminName, szGroupName, rsResult.FetchInt(3));
		iCount++;
	}

	delete rsResult;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d memberships to console.", iCount);
}

void vListKvMemberships(int iClient)
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath))
	{
		delete kv;
		ReplyToCommand(iClient, "[BS AdminSync] list memberships: KV snapshot file is missing or unreadable.");
		return;
	}

	PrintToConsole(iClient, " ");
	PrintToConsole(iClient, "[BS AdminSync] Admin-group memberships from local KV snapshot");

	int iCount = 0;
	if (kv.JumpToKey("memberships", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			int iAdminId = kv.GetNum("admin_id", 0);
			int iGroupId = kv.GetNum("group_id", 0);
			int iInheritOrder = kv.GetNum("inherit_order", 0);
			char szAdminId[16];
			char szGroupId[16];
			char szAdminName[128];
			char szGroupName[128];
			int iAccountId = 0;

			IntToString(iAdminId, szAdminId, sizeof(szAdminId));
			IntToString(iGroupId, szGroupId, sizeof(szGroupId));

			kv.Rewind();
			if (kv.JumpToKey("admins", false) && kv.JumpToKey(szAdminId, false))
			{
				kv.GetString("name", szAdminName, sizeof(szAdminName));
				iAccountId = kv.GetNum("accountid", 0);
			}
			else
			{
				strcopy(szAdminName, sizeof(szAdminName), "<missing-admin>");
			}

			kv.Rewind();
			if (kv.JumpToKey("groups", false) && kv.JumpToKey(szGroupId, false))
			{
				kv.GetString("name", szGroupName, sizeof(szGroupName));
			}
			else
			{
				strcopy(szGroupName, sizeof(szGroupName), "<missing-group>");
			}

			PrintToConsole(iClient, "accountid=%d | admin=%s | group=%s | inherit_order=%d",
				iAccountId, szAdminName, szGroupName, iInheritOrder);
			iCount++;

			kv.Rewind();
			kv.JumpToKey("memberships", false);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	ReplyToCommand(iClient, "[BS AdminSync] printed %d memberships to console.", iCount);
}

bool bSnapshotAdminHasGroup(int iAccountId, const char[] szGroupName)
{
	if (iAccountId <= 0 || szGroupName[0] == '\0')
		return false;

	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		char szSafeGroup[257];
		char szQuery[768];
		g_dbLocal.Escape(szGroupName, szSafeGroup, sizeof(szSafeGroup));
		Format(szQuery, sizeof(szQuery),
			"SELECT 1 FROM `adminsync_admins_groups` ag INNER JOIN `adminsync_admins` a ON a.`id` = ag.`admin_id` INNER JOIN `adminsync_groups` g ON g.`id` = ag.`group_id` WHERE a.`accountid` = %d AND g.`name` = '%s' LIMIT 1;",
			iAccountId, szSafeGroup);

		DBResultSet rsResult = SQL_Query(g_dbLocal, szQuery);
		bool bHasGroup = (rsResult != null && rsResult.FetchRow());
		delete rsResult;
		return bHasGroup;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("memberships", false))
	{
		delete kv;
		return false;
	}

	bool bHasGroup = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			int iAdminId = kv.GetNum("admin_id", 0);
			int iGroupId = kv.GetNum("group_id", 0);
			char szGroupId[16];
			char szFoundName[128];

			kv.Rewind();
			if (!kv.JumpToKey("admins", false) || !kv.GotoFirstSubKey(false))
			{
				kv.Rewind();
				kv.JumpToKey("memberships", false);
				continue;
			}

			bool bMatchedAdmin = false;
			do
			{
				if (kv.GetNum("id", 0) == iAdminId && kv.GetNum("accountid", 0) == iAccountId)
				{
					bMatchedAdmin = true;
					break;
				}
			}
			while (kv.GotoNextKey(false));

			if (!bMatchedAdmin)
			{
				kv.Rewind();
				kv.JumpToKey("memberships", false);
				continue;
			}

			IntToString(iGroupId, szGroupId, sizeof(szGroupId));
			kv.Rewind();
			if (kv.JumpToKey("groups", false) && kv.JumpToKey(szGroupId, false))
			{
				kv.GetString("name", szFoundName, sizeof(szFoundName));
				if (StrEqual(szFoundName, szGroupName, false))
				{
					bHasGroup = true;
					break;
				}
			}

			kv.Rewind();
			kv.JumpToKey("memberships", false);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bHasGroup;
}

bool bSnapshotAdminExists(int iAccountId)
{
	if (iAccountId <= 0)
		return false;

	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		char szQuery[256];
		Format(szQuery, sizeof(szQuery), "SELECT 1 FROM `adminsync_admins` WHERE `accountid` = %d AND `enabled` = 1 LIMIT 1;", iAccountId);
		DBResultSet rsResult = SQL_Query(g_dbLocal, szQuery);
		bool bExists = (rsResult != null && rsResult.FetchRow());
		delete rsResult;
		return bExists;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("admins", false))
	{
		delete kv;
		return false;
	}

	bool bExists = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			if (kv.GetNum("accountid", 0) == iAccountId && kv.GetNum("enabled", 1) != 0)
			{
				bExists = true;
				break;
			}
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bExists;
}

bool bSnapshotGetAdminFlags(int iAccountId, char[] szFlags, int iMaxLength)
{
	szFlags[0] = '\0';

	if (iAccountId <= 0)
		return false;

	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		char szQuery[256];
		Format(szQuery, sizeof(szQuery), "SELECT `flags` FROM `adminsync_admins` WHERE `accountid` = %d AND `enabled` = 1 LIMIT 1;", iAccountId);
		DBResultSet rsResult = SQL_Query(g_dbLocal, szQuery);
		if (rsResult == null || !rsResult.FetchRow())
		{
			delete rsResult;
			return false;
		}

		rsResult.FetchString(0, szFlags, iMaxLength);
		delete rsResult;
		return true;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("admins", false))
	{
		delete kv;
		return false;
	}

	bool bFound = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			if (kv.GetNum("accountid", 0) == iAccountId && kv.GetNum("enabled", 1) != 0)
			{
				kv.GetString("flags", szFlags, iMaxLength);
				bFound = true;
				break;
			}
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bFound;
}

bool bSnapshotGetAdminImmunity(int iAccountId, int &iImmunity)
{
	iImmunity = 0;

	if (iAccountId <= 0)
		return false;

	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
			return false;

		char szQuery[256];
		Format(szQuery, sizeof(szQuery), "SELECT `immunity` FROM `adminsync_admins` WHERE `accountid` = %d AND `enabled` = 1 LIMIT 1;", iAccountId);
		DBResultSet rsResult = SQL_Query(g_dbLocal, szQuery);
		if (rsResult == null || !rsResult.FetchRow())
		{
			delete rsResult;
			return false;
		}

		iImmunity = rsResult.FetchInt(0);
		delete rsResult;
		return true;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("admins", false))
	{
		delete kv;
		return false;
	}

	bool bFound = false;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			if (kv.GetNum("accountid", 0) == iAccountId && kv.GetNum("enabled", 1) != 0)
			{
				iImmunity = kv.GetNum("immunity", 0);
				bFound = true;
				break;
			}
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	return bFound;
}

void vBuildSnapshotAdminGroupsString(int iAccountId, char[] szBuffer, int iMaxLength)
{
	szBuffer[0] = '\0';

	if (GetSnapshotBackend() == Backend_SQLite)
	{
		if (g_dbLocal == null)
		{
			strcopy(szBuffer, iMaxLength, "-");
			return;
		}

		char szQuery[768];
		Format(szQuery, sizeof(szQuery),
			"SELECT g.`name` FROM `adminsync_admins_groups` ag INNER JOIN `adminsync_admins` a ON a.`id` = ag.`admin_id` INNER JOIN `adminsync_groups` g ON g.`id` = ag.`group_id` WHERE a.`accountid` = %d AND a.`enabled` = 1 AND g.`enabled` = 1 ORDER BY ag.`inherit_order` ASC, g.`id` ASC;",
			iAccountId);

		DBResultSet rsResult = SQL_Query(g_dbLocal, szQuery);
		if (rsResult == null)
		{
			strcopy(szBuffer, iMaxLength, "-");
			return;
		}

		bool bFirst = true;
		while (rsResult.FetchRow())
		{
			char szGroupName[128];
			rsResult.FetchString(0, szGroupName, sizeof(szGroupName));

			if (!bFirst)
				StrCat(szBuffer, iMaxLength, ",");
			StrCat(szBuffer, iMaxLength, szGroupName);
			bFirst = false;
		}

		delete rsResult;
		if (szBuffer[0] == '\0')
			strcopy(szBuffer, iMaxLength, "-");
		return;
	}

	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("memberships", false))
	{
		delete kv;
		strcopy(szBuffer, iMaxLength, "-");
		return;
	}

	bool bFirst = true;
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			int iAdminId = kv.GetNum("admin_id", 0);
			int iGroupId = kv.GetNum("group_id", 0);
			char szGroupId[16];
			char szGroupName[128];

			kv.Rewind();
			if (!kv.JumpToKey("admins", false) || !kv.GotoFirstSubKey(false))
			{
				kv.Rewind();
				kv.JumpToKey("memberships", false);
				continue;
			}

			bool bMatchedAdmin = false;
			do
			{
				if (kv.GetNum("id", 0) == iAdminId && kv.GetNum("accountid", 0) == iAccountId)
				{
					bMatchedAdmin = true;
					break;
				}
			}
			while (kv.GotoNextKey(false));

			if (!bMatchedAdmin)
			{
				kv.Rewind();
				kv.JumpToKey("memberships", false);
				continue;
			}

			IntToString(iGroupId, szGroupId, sizeof(szGroupId));
			kv.Rewind();
			if (kv.JumpToKey("groups", false) && kv.JumpToKey(szGroupId, false))
			{
				kv.GetString("name", szGroupName, sizeof(szGroupName));
				if (!bFirst)
					StrCat(szBuffer, iMaxLength, ",");
				StrCat(szBuffer, iMaxLength, szGroupName);
				bFirst = false;
			}

			kv.Rewind();
			kv.JumpToKey("memberships", false);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	if (szBuffer[0] == '\0')
		strcopy(szBuffer, iMaxLength, "-");
}
