#if defined _bansystem_adminsync_included
	#endinput
#endif
#define _bansystem_adminsync_included

/**
 * Trigger a full reload of the local admin snapshot from MySQL.
 *
 * @return    True if a new reload was started, false if a sync is already in progress.
 */
native bool bBSASReload();

/**
 * Check whether a snapshot sync is currently running.
 *
 * @return    True while the plugin is synchronizing from MySQL.
 */
native bool bBSASIsSyncInProgress();

/**
 * Get the last snapshot version detected from `adminsync_meta`.
 *
 * @return    The last known snapshot version, or 0 if not loaded yet.
 */
native int iBSASGetSnapshotVersion();

/**
 * Get the number of enabled admins currently available in the local snapshot.
 *
 * @return              Snapshot admin count, or 0 if unavailable.
 */
native int iBSASGetAdminCount();

/**
 * Fetch an enabled admin from the local snapshot by zero-based display index.
 *
 * @param iIndex        Zero-based snapshot index ordered by local display order.
 * @param iAccountId    Receives the admin accountid.
 * @param szName        Buffer receiving the admin display name.
 * @param iMaxLength    Maximum buffer length.
 *
 * @return              True if the index exists in the snapshot.
 */
native bool bBSASGetAdminByIndex(int iIndex, int &iAccountId, char[] szName, int iMaxLength);

/**
 * Get the number of enabled groups currently available in the local snapshot.
 *
 * @return              Snapshot group count, or 0 if unavailable.
 */
native int iBSASGetGroupCount();

/**
 * Fetch an enabled group from the local snapshot by zero-based display index.
 *
 * @param iIndex        Zero-based snapshot index ordered by local display order.
 * @param szName        Buffer receiving the group name.
 * @param iMaxLength    Maximum buffer length.
 *
 * @return              True if the index exists in the snapshot.
 */
native bool bBSASGetGroupByIndex(int iIndex, char[] szName, int iMaxLength);

/**
 * Check whether an admin exists in the local snapshot.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 *
 * @return              True if the admin exists and is enabled in the snapshot.
 */
native bool bBSASIsAdmin(int iAccountId);

/**
 * Check whether an admin currently inherits a group in the local snapshot.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szGroupName   Group name to look for.
 *
 * @return              True if the membership exists in the snapshot.
 */
native bool bBSASAdminHasGroup(int iAccountId, const char[] szGroupName);

/**
 * Fetch the flags of an admin from the local snapshot.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szFlags       Buffer receiving the flags string.
 * @param iMaxLength    Maximum buffer length.
 *
 * @return              True if the admin exists in the snapshot.
 */
native bool bBSASGetAdminFlags(int iAccountId, char[] szFlags, int iMaxLength);

/**
 * Fetch the immunity of an admin from the local snapshot.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 *
 * @return              Immunity value, or -1 if the admin is not present in the snapshot.
 */
native int iBSASGetAdminImmunity(int iAccountId);

/**
 * Add or enable an admin entry.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szName        Display name stored in MySQL.
 * @param szSteamId64   SteamID64 stored in MySQL for web interoperability.
 * @param iImmunity     Admin immunity level.
 * @param szFlags       SourceMod admin flags string.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASAddAdmin(int iAccountId, const char[] szName, const char[] szSteamId64, int iImmunity, const char[] szFlags);

/**
 * Delete an admin and its memberships.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASDeleteAdmin(int iAccountId);

/**
 * Update the flags of an admin.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szFlags       New SourceMod admin flags string.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASSetAdminFlags(int iAccountId, const char[] szFlags);

/**
 * Update the immunity of an admin.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param iImmunity     New immunity level.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASSetAdminImmunity(int iAccountId, int iImmunity);

/**
 * Add a group entry.
 *
 * @param szName        Group name.
 * @param szFlags       SourceMod flags assigned to the group.
 * @param iImmunity     Group immunity level.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASAddGroup(const char[] szName, const char[] szFlags, int iImmunity = 0);

/**
 * Delete a group and its memberships.
 *
 * @param szName        Group name.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASDeleteGroup(const char[] szName);

/**
 * Update the flags of a group.
 *
 * @param szName        Group name.
 * @param szFlags       New SourceMod flags string for the group.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASSetGroupFlags(const char[] szName, const char[] szFlags);

/**
 * Update the immunity of a group.
 *
 * @param szName        Group name.
 * @param iImmunity     New immunity level.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASSetGroupImmunity(const char[] szName, int iImmunity);

/**
 * Assign a group to an admin.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szGroupName   Group name to assign.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASAddAdminGroup(int iAccountId, const char[] szGroupName);

/**
 * Remove a group from an admin.
 *
 * @param iAccountId    Internal Steam account id of the admin.
 * @param szGroupName   Group name to remove.
 *
 * @return              True if the mutation was accepted and queued.
 */
native bool bBSASRemoveAdminGroup(int iAccountId, const char[] szGroupName);

public SharedPlugin __pl_bansystem_adminsync =
{
	name = "bansystem_adminsync",
	file = "bansystem_adminsync.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_adminsync_SetNTVOptional()
{
	MarkNativeAsOptional("bBSASReload");
	MarkNativeAsOptional("bBSASIsSyncInProgress");
	MarkNativeAsOptional("iBSASGetSnapshotVersion");
	MarkNativeAsOptional("iBSASGetAdminCount");
	MarkNativeAsOptional("bBSASGetAdminByIndex");
	MarkNativeAsOptional("iBSASGetGroupCount");
	MarkNativeAsOptional("bBSASGetGroupByIndex");
	MarkNativeAsOptional("bBSASIsAdmin");
	MarkNativeAsOptional("bBSASAdminHasGroup");
	MarkNativeAsOptional("bBSASGetAdminFlags");
	MarkNativeAsOptional("iBSASGetAdminImmunity");
	MarkNativeAsOptional("bBSASAddAdmin");
	MarkNativeAsOptional("bBSASDeleteAdmin");
	MarkNativeAsOptional("bBSASSetAdminFlags");
	MarkNativeAsOptional("bBSASSetAdminImmunity");
	MarkNativeAsOptional("bBSASAddGroup");
	MarkNativeAsOptional("bBSASDeleteGroup");
	MarkNativeAsOptional("bBSASSetGroupFlags");
	MarkNativeAsOptional("bBSASSetGroupImmunity");
	MarkNativeAsOptional("bBSASAddAdminGroup");
	MarkNativeAsOptional("bBSASRemoveAdminGroup");
}
#endif
