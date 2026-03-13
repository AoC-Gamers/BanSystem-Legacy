void vRegisterAdminSyncApi()
{
	CreateNative("bBSASReload", iBSASReloadNative);
	CreateNative("bBSASIsSyncInProgress", iBSASIsSyncInProgressNative);
	CreateNative("iBSASGetSnapshotVersion", iBSASGetSnapshotVersionNative);
	CreateNative("bBSASIsAdmin", iBSASIsAdminNative);
	CreateNative("bBSASAdminHasGroup", iBSASAdminHasGroupNative);
	CreateNative("bBSASGetAdminFlags", iBSASGetAdminFlagsNative);
	CreateNative("iBSASGetAdminImmunity", iBSASGetAdminImmunityNative);
	CreateNative("bBSASAddAdmin", iBSASAddAdminNative);
	CreateNative("bBSASDeleteAdmin", iBSASDeleteAdminNative);
	CreateNative("bBSASSetAdminFlags", iBSASSetAdminFlagsNative);
	CreateNative("bBSASSetAdminImmunity", iBSASSetAdminImmunityNative);
	CreateNative("bBSASAddGroup", iBSASAddGroupNative);
	CreateNative("bBSASDeleteGroup", iBSASDeleteGroupNative);
	CreateNative("bBSASSetGroupFlags", iBSASSetGroupFlagsNative);
	CreateNative("bBSASSetGroupImmunity", iBSASSetGroupImmunityNative);
	CreateNative("bBSASAddAdminGroup", iBSASAddAdminGroupNative);
	CreateNative("bBSASRemoveAdminGroup", iBSASRemoveAdminGroupNative);

	RegPluginLibrary("bansystem_adminsync");
}

public int iBSASReloadNative(Handle hPlugin, int iNumParams)
{
	if (!g_bSyncInProgress)
		vStartAdminSync();
	return !g_bSyncInProgress;
}

public int iBSASIsSyncInProgressNative(Handle hPlugin, int iNumParams)
{
	return g_bSyncInProgress;
}

public int iBSASGetSnapshotVersionNative(Handle hPlugin, int iNumParams)
{
	return g_iLastSnapshotVersion;
}

public int iBSASIsAdminNative(Handle hPlugin, int iNumParams)
{
	return bSnapshotAdminExists(GetNativeCell(1));
}

public int iBSASAdminHasGroupNative(Handle hPlugin, int iNumParams)
{
	char szGroupName[128];
	GetNativeString(2, szGroupName, sizeof(szGroupName));
	return bSnapshotAdminHasGroup(GetNativeCell(1), szGroupName);
}

public int iBSASGetAdminFlagsNative(Handle hPlugin, int iNumParams)
{
	int iAccountId = GetNativeCell(1);
	int iBufferLength = GetNativeCell(3);
	char szFlags[64];

	if (!bSnapshotGetAdminFlags(iAccountId, szFlags, sizeof(szFlags)))
	{
		SetNativeString(2, "", iBufferLength, true);
		return false;
	}

	SetNativeString(2, szFlags, iBufferLength, true);
	return true;
}

public int iBSASGetAdminImmunityNative(Handle hPlugin, int iNumParams)
{
	int iImmunity;
	if (!bSnapshotGetAdminImmunity(GetNativeCell(1), iImmunity))
		return -1;

	return iImmunity;
}

public int iBSASAddAdminNative(Handle hPlugin, int iNumParams)
{
	int iAccountId = GetNativeCell(1);
	int iImmunity = GetNativeCell(4);
	char szName[128];
	char szSteamId64[32];
	char szFlags[64];
	GetNativeString(2, szName, sizeof(szName));
	GetNativeString(3, szSteamId64, sizeof(szSteamId64));
	GetNativeString(5, szFlags, sizeof(szFlags));

	vStartAdminMutationAdd(0, iAccountId, szName, szSteamId64, szFlags, iImmunity);
	return true;
}

public int iBSASDeleteAdminNative(Handle hPlugin, int iNumParams)
{
	vStartAdminMutationDelete(0, GetNativeCell(1));
	return true;
}

public int iBSASSetAdminFlagsNative(Handle hPlugin, int iNumParams)
{
	char szFlags[64];
	GetNativeString(2, szFlags, sizeof(szFlags));
	vStartAdminMutationSetFlags(0, GetNativeCell(1), szFlags);
	return true;
}

public int iBSASSetAdminImmunityNative(Handle hPlugin, int iNumParams)
{
	vStartAdminMutationSetImmunity(0, GetNativeCell(1), GetNativeCell(2));
	return true;
}

public int iBSASAddGroupNative(Handle hPlugin, int iNumParams)
{
	char szName[128];
	char szFlags[64];
	GetNativeString(1, szName, sizeof(szName));
	GetNativeString(2, szFlags, sizeof(szFlags));
	vStartGroupMutationAdd(0, szName, szFlags, GetNativeCell(3));
	return true;
}

public int iBSASDeleteGroupNative(Handle hPlugin, int iNumParams)
{
	char szName[128];
	GetNativeString(1, szName, sizeof(szName));
	vStartGroupMutationDelete(0, szName);
	return true;
}

public int iBSASSetGroupFlagsNative(Handle hPlugin, int iNumParams)
{
	char szName[128];
	char szFlags[64];
	GetNativeString(1, szName, sizeof(szName));
	GetNativeString(2, szFlags, sizeof(szFlags));
	vStartGroupMutationSetFlags(0, szName, szFlags);
	return true;
}

public int iBSASSetGroupImmunityNative(Handle hPlugin, int iNumParams)
{
	char szName[128];
	GetNativeString(1, szName, sizeof(szName));
	vStartGroupMutationSetImmunity(0, szName, GetNativeCell(2));
	return true;
}

public int iBSASAddAdminGroupNative(Handle hPlugin, int iNumParams)
{
	char szGroup[128];
	GetNativeString(2, szGroup, sizeof(szGroup));
	vStartAdminMutationAddGroup(0, GetNativeCell(1), szGroup);
	return true;
}

public int iBSASRemoveAdminGroupNative(Handle hPlugin, int iNumParams)
{
	char szGroup[128];
	GetNativeString(2, szGroup, sizeof(szGroup));
	vStartAdminMutationRemoveGroup(0, GetNativeCell(1), szGroup);
	return true;
}
