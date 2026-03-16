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
	char szCheckMode[32];

	g_cvBackend.GetString(szBackend, sizeof(szBackend));
	if (g_iLastSyncAt > 0)
		FormatTime(szLastSync, sizeof(szLastSync), "%Y-%m-%d %H:%M:%S", g_iLastSyncAt);
	else
		FormatEx(szLastSync, sizeof(szLastSync), "%T", "BSAdminSyncNever", iClient);
	FormatEx(szCheckMode, sizeof(szCheckMode), "%T", "BSAdminSyncCheckModeMapChange", iClient);

	CReplyToCommand(iClient, "%t", "BSAdminSyncStatus",
		szBackend,
		g_bSyncInProgress ? 1 : 0,
		g_iLastAdminCount,
		g_iLastGroupCount,
		g_iLastMembershipCount,
		g_iLastSnapshotVersion,
		szCheckMode,
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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminAdd");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szNormalizedTarget[64];
	char szFlags[64];
	char szName[128];
	char szSteamId64[32];
	char szNameArg[128];
	char szImmunity[16];
	int iAccountId = 0;
	int iImmunity = 0;
	int iNextArg = 0;

	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);
	if (!SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szFlags, sizeof(szFlags)))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminAdd");
		return Plugin_Handled;
	}

	if (!bAdminSyncHasText(szFlags))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminAdd");
		return Plugin_Handled;
	}

	if (SteamIDTools_GetCmdArgNormalized(iNextArg + 1, iArgs, szImmunity, sizeof(szImmunity)) && SteamIDTools_IsNumericString(szImmunity))
	{
		iImmunity = StringToInt(szImmunity);
		SteamIDTools_JoinCmdArgs(iNextArg + 2, iArgs, szNameArg, sizeof(szNameArg));
	}
	else
	{
		iImmunity = 0;
		SteamIDTools_JoinCmdArgs(iNextArg + 1, iArgs, szNameArg, sizeof(szNameArg));
	}

	strcopy(szNormalizedTarget, sizeof(szNormalizedTarget), szTarget);
	TrimString(szNormalizedTarget);
	StripQuotes(szNormalizedTarget);

	SteamIDFormat eFormat = DetectSteamIDFormat(szNormalizedTarget);
	vAdminSyncDebug(
		"Command_AdminAdd input. raw=%s normalized=%s format=%d flags=%s immunity=%d namearg=%s",
		szTarget,
		szNormalizedTarget,
		view_as<int>(eFormat),
		szFlags,
		iImmunity,
		szNameArg
	);

	switch (eFormat)
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			if (szNameArg[0] == '\0')
				strcopy(szNameArg, sizeof(szNameArg), "UNKNOWN");

			bQueueAdminIdentityLookup(iClient, szNormalizedTarget, IdentityAction_AdminAdd, szFlags, iImmunity, szNameArg);
			return Plugin_Handled;
		}
	}

	if (!bTryResolveAccountIdTarget(iClient, szNormalizedTarget, iAccountId, szName, sizeof(szName), szSteamId64, sizeof(szSteamId64)))
		return Plugin_Handled;

	if (iAccountId <= 0)
		return Plugin_Handled;

	if (szNameArg[0] != '\0')
		strcopy(szName, sizeof(szName), szNameArg);

	vAdminSyncDebug(
		"Command_AdminAdd resolved. normalized=%s accountid=%d name=%s steamid64=%s",
		szNormalizedTarget,
		iAccountId,
		szName,
		szSteamId64
	);

	if (szSteamId64[0] == '\0' && (eFormat == STEAMID_FORMAT_STEAMID2 || eFormat == STEAMID_FORMAT_STEAMID3))
	{
		if (bQueueAdminAddSteamId64Enrichment(iClient, szNormalizedTarget, eFormat, iAccountId, szName, szFlags, iImmunity))
		{
			return Plugin_Handled;
		}

		vAdminSyncDebug("Command_AdminAdd could not enrich offline SteamID64. Falling back to direct insert. accountid=%d format=%d", iAccountId, view_as<int>(eFormat));
	}

	vStartAdminMutationAdd(iClient, iAccountId, szName, szSteamId64, szFlags, iImmunity);
	return Plugin_Handled;
}

public Action Command_AdminDelete(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminDelete");
		return Plugin_Handled;
	}

	char szTarget[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);

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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetFlags");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szFlags[64];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);
	if (!SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szFlags, sizeof(szFlags)))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetFlags");
		return Plugin_Handled;
	}

	if (!bAdminSyncHasText(szFlags))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetFlags");
		return Plugin_Handled;
	}

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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetImmunity");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szImmunity[16];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);
	if (!SteamIDTools_GetCmdArgNormalized(iNextArg, iArgs, szImmunity, sizeof(szImmunity)))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetImmunity");
		return Plugin_Handled;
	}
	int iImmunity;
	if (!bTryParseAdminSyncNonNegativeInt(szImmunity, iImmunity))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminSetImmunity");
		return Plugin_Handled;
	}

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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminAddGroup");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szGroup[128];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);
	SteamIDTools_JoinCmdArgs(iNextArg, iArgs, szGroup, sizeof(szGroup));
	if (szGroup[0] == '\0')
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminAddGroup");
		return Plugin_Handled;
	}
	vNormalizeAdminSyncText(szGroup, szGroup, sizeof(szGroup));

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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminRemoveGroup");
		return Plugin_Handled;
	}

	char szTarget[64];
	char szGroup[128];
	int iNextArg = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, iArgs, szTarget, sizeof(szTarget), iNextArg);
	SteamIDTools_JoinCmdArgs(iNextArg, iArgs, szGroup, sizeof(szGroup));
	if (szGroup[0] == '\0')
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageAdminRemoveGroup");
		return Plugin_Handled;
	}
	vNormalizeAdminSyncText(szGroup, szGroup, sizeof(szGroup));

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
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupAdd");
		return Plugin_Handled;
	}

	char szName[128];
	char szFlags[64];
	SteamIDTools_GetCmdArgNormalized(1, iArgs, szName, sizeof(szName));
	SteamIDTools_GetCmdArgNormalized(2, iArgs, szFlags, sizeof(szFlags));
	if (!bAdminSyncHasText(szName) || !bAdminSyncHasText(szFlags))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupAdd");
		return Plugin_Handled;
	}
	int iImmunity = 0;
	if (iArgs >= 3)
	{
		char szImmunity[16];
		SteamIDTools_GetCmdArgNormalized(3, iArgs, szImmunity, sizeof(szImmunity));
		if (!bTryParseAdminSyncNonNegativeInt(szImmunity, iImmunity))
		{
			CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupAdd");
			return Plugin_Handled;
		}
	}

	vStartGroupMutationAdd(iClient, szName, szFlags, iImmunity);
	return Plugin_Handled;
}

public Action Command_GroupDelete(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupDelete");
		return Plugin_Handled;
	}

	char szName[128];
	SteamIDTools_GetCmdArgNormalized(1, iArgs, szName, sizeof(szName));
	if (!bAdminSyncHasText(szName))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupDelete");
		return Plugin_Handled;
	}
	vStartGroupMutationDelete(iClient, szName);
	return Plugin_Handled;
}

public Action Command_GroupSetFlags(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupSetFlags");
		return Plugin_Handled;
	}

	char szName[128];
	char szFlags[64];
	SteamIDTools_GetCmdArgNormalized(1, iArgs, szName, sizeof(szName));
	SteamIDTools_GetCmdArgNormalized(2, iArgs, szFlags, sizeof(szFlags));
	if (!bAdminSyncHasText(szName) || !bAdminSyncHasText(szFlags))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupSetFlags");
		return Plugin_Handled;
	}
	vStartGroupMutationSetFlags(iClient, szName, szFlags);
	return Plugin_Handled;
}

public Action Command_GroupSetImmunity(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupSetImmunity");
		return Plugin_Handled;
	}

	char szName[128];
	char szImmunity[16];
	SteamIDTools_GetCmdArgNormalized(1, iArgs, szName, sizeof(szName));
	SteamIDTools_GetCmdArgNormalized(2, iArgs, szImmunity, sizeof(szImmunity));
	int iImmunity;
	if (!bAdminSyncHasText(szName) || !bTryParseAdminSyncNonNegativeInt(szImmunity, iImmunity))
	{
		CReplyToCommand(iClient, "%t", "BSAdminSyncUsageGroupSetImmunity");
		return Plugin_Handled;
	}
	vStartGroupMutationSetImmunity(iClient, szName, iImmunity);
	return Plugin_Handled;
}
