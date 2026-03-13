#if defined _bansystem_core_included
	#endinput
#endif
#define _bansystem_core_included

/**
 * Returns true if the BanSystem Core is currently in map transition mode.
 */
native bool BSCore_IsMapTransitionActive();

/**
 * Returns true if the given client currently has a pending auth state inside the core.
 */
native bool BSCore_IsClientAuthPending(int client);

/**
 * Returns true if the given accountid exists in the local clean cache.
 */
native bool BSCore_IsLocalCleanCached(int accountid);

/**
 * Adds an accountid to the local clean cache.
 */
native bool BSCore_AddLocalCleanCache(int accountid);

/**
 * Removes an accountid from the local clean cache.
 */
native bool BSCore_RemoveLocalCleanCache(int accountid);

/**
 * Clears the local clean cache.
 */
native void BSCore_ClearLocalCleanCache();

/**
 * Returns the amount of accountids currently cached as clean.
 */
native int BSCore_GetLocalCleanCacheSize();

/**
 * Registers a module in the core module registry.
 */
native bool BSCore_RegisterModule(const char[] name, int moduleBit);

/**
 * Returns true if the named module is registered.
 */
native bool BSCore_IsModuleRegistered(const char[] name);

/**
 * Returns the registered module bitmask.
 */
native int BSCore_GetRegisteredModuleMask();

/**
 * Returns true if the client has a resolved core summary state.
 */
native bool BSCore_HasResolvedSummary(int client);

/**
 * Returns the resolved accountid for a client, or 0 when unresolved.
 */
native int BSCore_GetResolvedAccountId(int client);

/**
 * Returns the resolved module bitmask for a client, or 0 when unresolved.
 */
native int BSCore_GetResolvedModuleMask(int client);

/**
 * Returns the resolved communication type for a client, or 0 when none.
 */
native int BSCore_GetResolvedCommType(int client);

/**
 * Returns the resolved ban id stored in the summary for the requested module bit.
 */
native int BSCore_GetResolvedBanId(int client, int moduleBit);

/**
 * Returns the current pending detail bitmask for a client.
 */
native int BSCore_GetPendingDetailMask(int client);

/**
 * Writes or updates the access summary state for an accountid.
 */
native bool BSCore_SetAccessSummary(int accountid, int banId);

/**
 * Writes or updates the communication summary state for an accountid.
 */
native bool BSCore_SetCommSummary(int accountid, int banId, int commType);

/**
 * Writes or updates the sprays summary state for an accountid.
 */
native bool BSCore_SetSpraySummary(int accountid, int banId);

/**
 * Clears one module bit from the summary state of an accountid.
 */
native bool BSCore_ClearSummaryModule(int accountid, int moduleBit);

/**
 * Clears the full summary state for an accountid.
 */
native bool BSCore_ClearSummary(int accountid);

/**
 * Marks one module detail request as resolved for a client.
 */
native bool BSCore_MarkModuleDetailResolved(int client, int moduleBit);

/**
 * Fired when the core needs access detail for a client with an active access summary bit.
 */
forward void BSCore_OnAccessDetailRequested(int client, int accountid, int banId);

/**
 * Fired when the core needs communication detail for a client with an active communication summary bit.
 */
forward void BSCore_OnCommDetailRequested(int client, int accountid, int banId, int commType);

/**
 * Fired when the core needs spray detail for a client with an active sprays summary bit.
 */
forward void BSCore_OnSprayDetailRequested(int client, int accountid, int banId);
