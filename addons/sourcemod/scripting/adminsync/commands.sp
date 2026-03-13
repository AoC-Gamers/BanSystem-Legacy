void vOnPluginStart_Commands()
{
	RegAdminCmd("sm_bs_adminsync_reload", Command_AdminSyncReload, ADMFLAG_ROOT, "Reload the local admin snapshot from MySQL.");
	RegAdminCmd("sm_bs_adminsync_status", Command_AdminSyncStatus, ADMFLAG_ROOT, "Show BanSystem Admin Sync status.");
	RegAdminCmd("sm_bs_adminsync_verify", Command_AdminSyncVerify, ADMFLAG_ROOT, "Verify the local admin snapshot consistency.");
	RegAdminCmd("sm_bs_adminsync_ls_admins", Command_AdminSyncListAdmins, ADMFLAG_ROOT, "List admins from the local snapshot.");
	RegAdminCmd("sm_bs_adminsync_ls_groups", Command_AdminSyncListGroups, ADMFLAG_ROOT, "List groups from the local snapshot.");
	RegAdminCmd("sm_bs_adminsync_ls_memberships", Command_AdminSyncListMemberships, ADMFLAG_ROOT, "List admin-group memberships from the local snapshot.");
	RegAdminCmd("sm_bs_admin_add", Command_AdminAdd, ADMFLAG_ROOT, "Add an admin: sm_bs_admin_add <target|steamid|accountid> <flags> [immunity] [name]");
	RegAdminCmd("sm_bs_admin_del", Command_AdminDelete, ADMFLAG_ROOT, "Delete an admin: sm_bs_admin_del <target|steamid|accountid>");
	RegAdminCmd("sm_bs_admin_set_flags", Command_AdminSetFlags, ADMFLAG_ROOT, "Set admin flags: sm_bs_admin_set_flags <target|steamid|accountid> <flags>");
	RegAdminCmd("sm_bs_admin_set_immunity", Command_AdminSetImmunity, ADMFLAG_ROOT, "Set admin immunity: sm_bs_admin_set_immunity <target|steamid|accountid> <immunity>");
	RegAdminCmd("sm_bs_admin_add_group", Command_AdminAddGroup, ADMFLAG_ROOT, "Assign a group to an admin: sm_bs_admin_add_group <target|steamid|accountid> <group>");
	RegAdminCmd("sm_bs_admin_remove_group", Command_AdminRemoveGroup, ADMFLAG_ROOT, "Remove a group from an admin: sm_bs_admin_remove_group <target|steamid|accountid> <group>");
	RegAdminCmd("sm_bs_group_add", Command_GroupAdd, ADMFLAG_ROOT, "Add a group: sm_bs_group_add <name> <flags> [immunity]");
	RegAdminCmd("sm_bs_group_del", Command_GroupDelete, ADMFLAG_ROOT, "Delete a group: sm_bs_group_del <name>");
	RegAdminCmd("sm_bs_group_set_flags", Command_GroupSetFlags, ADMFLAG_ROOT, "Set group flags: sm_bs_group_set_flags <name> <flags>");
	RegAdminCmd("sm_bs_group_set_immunity", Command_GroupSetImmunity, ADMFLAG_ROOT, "Set group immunity: sm_bs_group_set_immunity <name> <immunity>");
}

public Action Command_AdminSyncReload(int iClient, int iArgs)
{
	vStartAdminSync(iClient);
	return Plugin_Handled;
}

public Action Command_AdminSyncStatus(int iClient, int iArgs)
{
	char szBackend[16];
	char szLastSync[64];
	float flInterval = g_cvCheckInterval.FloatValue;

	g_cvBackend.GetString(szBackend, sizeof(szBackend));
	if (g_iLastSyncAt > 0)
		FormatTime(szLastSync, sizeof(szLastSync), "%Y-%m-%d %H:%M:%S", g_iLastSyncAt);
	else
		strcopy(szLastSync, sizeof(szLastSync), "never");

	ReplyToCommand(iClient, "[BS AdminSync] backend=%s syncing=%d admins=%d groups=%d memberships=%d version=%d poll=%.0fs last_sync=%s local_sqlite=%d kv=%s",
		szBackend,
		g_bSyncInProgress ? 1 : 0,
		g_iLastAdminCount,
		g_iLastGroupCount,
		g_iLastMembershipCount,
		g_iLastSnapshotVersion,
		flInterval,
		szLastSync,
		(g_dbLocal != null) ? 1 : 0,
		g_szKvSnapshotPath);

	return Plugin_Handled;
}

public Action Command_AdminSyncVerify(int iClient, int iArgs)
{
	if (GetSnapshotBackend() == Backend_SQLite)
		vVerifySQLiteSnapshot(iClient);
	else
		vVerifyKvSnapshot(iClient);

	return Plugin_Handled;
}

public Action Command_AdminSyncListAdmins(int iClient, int iArgs)
{
	if (GetSnapshotBackend() == Backend_SQLite)
		vListSQLiteAdmins(iClient);
	else
		vListKvAdmins(iClient);

	return Plugin_Handled;
}

public Action Command_AdminSyncListGroups(int iClient, int iArgs)
{
	if (GetSnapshotBackend() == Backend_SQLite)
		vListSQLiteGroups(iClient);
	else
		vListKvGroups(iClient);

	return Plugin_Handled;
}

public Action Command_AdminSyncListMemberships(int iClient, int iArgs)
{
	if (GetSnapshotBackend() == Backend_SQLite)
		vListSQLiteMemberships(iClient);
	else
		vListKvMemberships(iClient);

	return Plugin_Handled;
}

public Action Command_AdminAdd(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_add <target|steamid|accountid> <flags> [immunity] [name]");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szFlags[64];
	char szName[128];
	char szSteamId64[32];
	char szNameArg[128];
	int iAccountId = 0;
	int iImmunity = 0;

	GetCmdArg(1, szTarget, sizeof(szTarget));
	GetCmdArg(2, szFlags, sizeof(szFlags));
	if (iArgs >= 3)
	{
		char szImmunity[16];
		GetCmdArg(3, szImmunity, sizeof(szImmunity));
		iImmunity = StringToInt(szImmunity);
	}

	if (iArgs >= 4)
	{
		GetCmdArg(4, szNameArg, sizeof(szNameArg));
		TrimString(szNameArg);
		StripQuotes(szNameArg);
	}
	else
	{
		szNameArg[0] = '\0';
	}

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			if (szNameArg[0] == '\0')
				strcopy(szNameArg, sizeof(szNameArg), "UNKNOWN");

			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminAdd, szFlags, iImmunity, szNameArg);
			return Plugin_Handled;
		}
	}

	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId <= 0)
		return Plugin_Handled;

	if (szNameArg[0] != '\0')
		strcopy(szName, sizeof(szName), szNameArg);

	vStartAdminMutationAdd(iClient, iAccountId, szName, szSteamId64, szFlags, iImmunity);
	return Plugin_Handled;
}

public Action Command_AdminDelete(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_del <target|steamid|accountid>");
		return Plugin_Handled;
	}

	char szTarget[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminDelete, "", 0);
			return Plugin_Handled;
		}
	}

	int iAccountId = 0;
	char szName[128];
	char szSteamId64[32];
	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId > 0)
		vStartAdminMutationDelete(iClient, iAccountId);
	return Plugin_Handled;
}

public Action Command_AdminSetFlags(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_set_flags <target|steamid|accountid> <flags>");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szFlags[64];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	GetCmdArg(2, szFlags, sizeof(szFlags));

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminSetFlags, szFlags, 0);
			return Plugin_Handled;
		}
	}

	int iAccountId = 0;
	char szName[128];
	char szSteamId64[32];
	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId > 0)
		vStartAdminMutationSetFlags(iClient, iAccountId, szFlags);
	return Plugin_Handled;
}

public Action Command_AdminSetImmunity(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_set_immunity <target|steamid|accountid> <immunity>");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szImmunity[16];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	GetCmdArg(2, szImmunity, sizeof(szImmunity));
	int iImmunity = StringToInt(szImmunity);

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminSetImmunity, "", iImmunity);
			return Plugin_Handled;
		}
	}

	int iAccountId = 0;
	char szName[128];
	char szSteamId64[32];
	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId > 0)
		vStartAdminMutationSetImmunity(iClient, iAccountId, iImmunity);
	return Plugin_Handled;
}

public Action Command_AdminAddGroup(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_add_group <target|steamid|accountid> <group>");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szGroup[128];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	GetCmdArg(2, szGroup, sizeof(szGroup));

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminAddGroup, szGroup, 0);
			return Plugin_Handled;
		}
	}

	int iAccountId = 0;
	char szName[128];
	char szSteamId64[32];
	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId > 0)
		vStartAdminMutationAddGroup(iClient, iAccountId, szGroup);
	return Plugin_Handled;
}

public Action Command_AdminRemoveGroup(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_admin_remove_group <target|steamid|accountid> <group>");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szGroup[128];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	GetCmdArg(2, szGroup, sizeof(szGroup));

	switch (DetectSteamIDFormat(szTarget))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			bQueueAdminIdentityLookup(iClient, szTarget, IdentityAction_AdminRemoveGroup, szGroup, 0);
			return Plugin_Handled;
		}
	}

	int iAccountId = 0;
	char szName[128];
	char szSteamId64[32];
	if (!bTryResolveAccountIdTarget(iClient, szTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId > 0)
		vStartAdminMutationRemoveGroup(iClient, iAccountId, szGroup);
	return Plugin_Handled;
}

public Action Command_GroupAdd(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_group_add <name> <flags> [immunity]");
		return Plugin_Handled;
	}

	char szName[128];
	char szFlags[64];
	GetCmdArg(1, szName, sizeof(szName));
	GetCmdArg(2, szFlags, sizeof(szFlags));
	int iImmunity = 0;
	if (iArgs >= 3)
	{
		char szImmunity[16];
		GetCmdArg(3, szImmunity, sizeof(szImmunity));
		iImmunity = StringToInt(szImmunity);
	}

	vStartGroupMutationAdd(iClient, szName, szFlags, iImmunity);
	return Plugin_Handled;
}

public Action Command_GroupDelete(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_group_del <name>");
		return Plugin_Handled;
	}

	char szName[128];
	GetCmdArg(1, szName, sizeof(szName));
	vStartGroupMutationDelete(iClient, szName);
	return Plugin_Handled;
}

public Action Command_GroupSetFlags(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_group_set_flags <name> <flags>");
		return Plugin_Handled;
	}

	char szName[128];
	char szFlags[64];
	GetCmdArg(1, szName, sizeof(szName));
	GetCmdArg(2, szFlags, sizeof(szFlags));
	vStartGroupMutationSetFlags(iClient, szName, szFlags);
	return Plugin_Handled;
}

public Action Command_GroupSetImmunity(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "[BS AdminSync] Use: sm_bs_group_set_immunity <name> <immunity>");
		return Plugin_Handled;
	}

	char szName[128];
	char szImmunity[16];
	GetCmdArg(1, szName, sizeof(szName));
	GetCmdArg(2, szImmunity, sizeof(szImmunity));
	vStartGroupMutationSetImmunity(iClient, szName, StringToInt(szImmunity));
	return Plugin_Handled;
}
