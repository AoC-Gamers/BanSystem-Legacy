public void OnRebuildAdminCache(AdminCachePart part)
{
	vAdminSyncDebug("OnRebuildAdminCache part=%d backend=%d", view_as<int>(part), view_as<int>(GetSnapshotBackend()));
	switch (part)
	{
		case AdminCache_Groups:
		{
			if (GetSnapshotBackend() == Backend_SQLite)
				vLoadGroupsFromSQLiteSnapshot();
			else
				vLoadGroupsFromKvSnapshot();
		}
		case AdminCache_Admins:
		{
			if (GetSnapshotBackend() == Backend_SQLite)
				vLoadAdminsFromSQLiteSnapshot();
			else
				vLoadAdminsFromKvSnapshot();
		}
	}
}

void vApplySnapshotToAdminCache()
{
	vAdminSyncDebug("Applying local snapshot to SourceMod AdminCache.");
	DumpAdminCache(AdminCache_Groups, true);
	DumpAdminCache(AdminCache_Overrides, true);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		RunAdminCacheChecks(i);
	}
}

void vLoadGroupsFromSQLiteSnapshot()
{
	if (g_dbLocal == null)
		return;

	DBResultSet rsResult = SQL_Query(g_dbLocal, "SELECT `name`, `flags`, `immunity_level` FROM `adminsync_groups` WHERE `enabled` = 1 ORDER BY `id` ASC;");
	if (rsResult == null)
		return;

	while (rsResult.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		rsResult.FetchString(0, szName, sizeof(szName));
		rsResult.FetchString(1, szFlags, sizeof(szFlags));

		GroupId idGroup = FindAdmGroup(szName);
		if (idGroup == INVALID_GROUP_ID)
			idGroup = CreateAdmGroup(szName);
		if (idGroup == INVALID_GROUP_ID)
			continue;

		vApplyFlagsToGroup(idGroup, szFlags);
		idGroup.ImmunityLevel = rsResult.FetchInt(2);
	}

	delete rsResult;
}

void vLoadGroupsFromKvSnapshot()
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath) || !kv.JumpToKey("groups", false))
	{
		delete kv;
		return;
	}

	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			char szFlags[64];
			kv.GetString("name", szName, sizeof(szName));
			kv.GetString("flags", szFlags, sizeof(szFlags));

			GroupId idGroup = FindAdmGroup(szName);
			if (idGroup == INVALID_GROUP_ID)
				idGroup = CreateAdmGroup(szName);
			if (idGroup == INVALID_GROUP_ID)
				continue;

			vApplyFlagsToGroup(idGroup, szFlags);
			idGroup.ImmunityLevel = kv.GetNum("immunity_level", 0);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
}

void vLoadAdminsFromSQLiteSnapshot()
{
	if (g_dbLocal == null)
		return;

	DBResultSet rsAdmins = SQL_Query(g_dbLocal, "SELECT `id`, `accountid`, `name`, `flags`, `immunity` FROM `adminsync_admins` WHERE `enabled` = 1 ORDER BY `id` ASC;");
	if (rsAdmins == null)
		return;

	StringMap smAdminMap = new StringMap();
	char szKey[16];

	while (rsAdmins.FetchRow())
	{
		char szName[128];
		char szFlags[64];
		char szSteam2[32];

		int iDbId = rsAdmins.FetchInt(0);
		int iAccountId = rsAdmins.FetchInt(1);
		if (!bAccountIdToSteam2(iAccountId, szSteam2, sizeof(szSteam2)))
			continue;

		rsAdmins.FetchString(2, szName, sizeof(szName));
		rsAdmins.FetchString(3, szFlags, sizeof(szFlags));

		AdminId idAdmin = FindAdminByIdentity(AUTHMETHOD_STEAM, szSteam2);
		if (idAdmin != INVALID_ADMIN_ID)
			RemoveAdmin(idAdmin);

		idAdmin = CreateAdmin(szName);
		if (idAdmin == INVALID_ADMIN_ID || !idAdmin.BindIdentity(AUTHMETHOD_STEAM, szSteam2))
			continue;

		vApplyFlagsToAdmin(idAdmin, szFlags);
		idAdmin.ImmunityLevel = rsAdmins.FetchInt(4);

		IntToString(iDbId, szKey, sizeof(szKey));
		smAdminMap.SetValue(szKey, view_as<int>(idAdmin));
	}

	delete rsAdmins;

	DBResultSet rsMemberships = SQL_Query(g_dbLocal, "SELECT ag.`admin_id`, g.`name` FROM `adminsync_admins_groups` ag INNER JOIN `adminsync_groups` g ON g.`id` = ag.`group_id` WHERE g.`enabled` = 1 ORDER BY ag.`admin_id` ASC, ag.`inherit_order` ASC;");
	if (rsMemberships == null)
	{
		delete smAdminMap;
		return;
	}

	while (rsMemberships.FetchRow())
	{
		char szGroupName[128];
		rsMemberships.FetchString(1, szGroupName, sizeof(szGroupName));
		IntToString(rsMemberships.FetchInt(0), szKey, sizeof(szKey));

		int iAdminRef;
		if (!smAdminMap.GetValue(szKey, iAdminRef))
			continue;

		GroupId idGroup = FindAdmGroup(szGroupName);
		if (idGroup == INVALID_GROUP_ID)
			continue;

		view_as<AdminId>(iAdminRef).InheritGroup(idGroup);
	}

	delete rsMemberships;
	delete smAdminMap;
}

void vLoadAdminsFromKvSnapshot()
{
	KeyValues kv = new KeyValues("BanSystemAdminSync");
	if (!kv.ImportFromFile(g_szKvSnapshotPath))
	{
		delete kv;
		return;
	}

	StringMap smAdminMap = new StringMap();
	char szKey[16];

	if (kv.JumpToKey("admins", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			char szName[128];
			char szFlags[64];
			char szSteam2[32];

			int iDbId = kv.GetNum("id", 0);
			int iAccountId = kv.GetNum("accountid", 0);
			if (!bAccountIdToSteam2(iAccountId, szSteam2, sizeof(szSteam2)))
				continue;

			kv.GetString("name", szName, sizeof(szName));
			kv.GetString("flags", szFlags, sizeof(szFlags));

			AdminId idAdmin = FindAdminByIdentity(AUTHMETHOD_STEAM, szSteam2);
			if (idAdmin != INVALID_ADMIN_ID)
				RemoveAdmin(idAdmin);

			idAdmin = CreateAdmin(szName);
			if (idAdmin == INVALID_ADMIN_ID || !idAdmin.BindIdentity(AUTHMETHOD_STEAM, szSteam2))
				continue;

			vApplyFlagsToAdmin(idAdmin, szFlags);
			idAdmin.ImmunityLevel = kv.GetNum("immunity", 0);

			IntToString(iDbId, szKey, sizeof(szKey));
			smAdminMap.SetValue(szKey, view_as<int>(idAdmin));
		}
		while (kv.GotoNextKey(false));
	}

	kv.Rewind();
	if (kv.JumpToKey("memberships", false) && kv.GotoFirstSubKey(false))
	{
		do
		{
			char szGroupKey[16];
			char szGroupName[128];

			IntToString(kv.GetNum("admin_id", 0), szKey, sizeof(szKey));
			IntToString(kv.GetNum("group_id", 0), szGroupKey, sizeof(szGroupKey));

			int iAdminRef;
			if (!smAdminMap.GetValue(szKey, iAdminRef))
				continue;

			kv.GoBack();
			if (!kv.JumpToKey("groups", false) || !kv.JumpToKey(szGroupKey, false))
			{
				kv.Rewind();
				kv.JumpToKey("memberships", false);
				continue;
			}

			kv.GetString("name", szGroupName, sizeof(szGroupName));
			GroupId idGroup = FindAdmGroup(szGroupName);
			if (idGroup != INVALID_GROUP_ID)
				view_as<AdminId>(iAdminRef).InheritGroup(idGroup);

			kv.Rewind();
			kv.JumpToKey("memberships", false);
		}
		while (kv.GotoNextKey(false));
	}

	delete smAdminMap;
	delete kv;
}
