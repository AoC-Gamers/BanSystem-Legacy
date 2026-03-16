#if defined _bansystem_core_included
	#endinput
#endif
#define _bansystem_core_included

enum eBSCoreModuleBit
{
	kBSCoreModule_None = 0,
	kBSCoreModule_Access = 1,
	kBSCoreModule_Communication = 2,
	kBSCoreModule_Sprays = 4
}

enum eBSCoreCommType
{
	kBSCoreComm_None = 0,
	kBSCoreComm_Mic = 1,
	kBSCoreComm_Chat = 2,
	kBSCoreComm_All = 3
}

/**
 * Returns true if the BanSystem Core is currently in map transition mode.
 *
 * @return              True if the core is currently in transition mode.
 */
native bool BSCore_IsMapTransitionActive();

/**
 * Returns true if the given client currently has a pending auth state inside the core.
 *
 * @param client        Client index.
 * @return              True if the client still has pending auth work in the core.
 */
native bool BSCore_IsClientAuthPending(int client);

/**
 * Returns true if the given accountid exists in the local clean cache.
 *
 * @param accountid     Internal Steam account id.
 * @return              True if the accountid is cached as clean.
 */
native bool BSCore_IsLocalCleanCached(int accountid);

/**
 * Adds an accountid to the local clean cache.
 *
 * @param accountid     Internal Steam account id.
 * @return              True if the accountid was added.
 */
native bool BSCore_AddLocalCleanCache(int accountid);

/**
 * Removes an accountid from the local clean cache.
 *
 * @param accountid     Internal Steam account id.
 * @return              True if the accountid was removed.
 */
native bool BSCore_RemoveLocalCleanCache(int accountid);

/**
 * Clears the local clean cache.
 */
native void BSCore_ClearLocalCleanCache();

/**
 * Returns the amount of accountids currently cached as clean.
 *
 * @return              Amount of cached clean accountids.
 */
native int BSCore_GetLocalCleanCacheSize();

/**
 * Registers a module in the core module registry.
 *
 * @param name          Module name.
 * @param moduleBit     Module bitmask used in summary state.
 * @return              True if the module registration was accepted.
 */
native bool BSCore_RegisterModule(const char[] name, eBSCoreModuleBit moduleBit);

/**
 * Returns true if the named module is registered.
 *
 * @param name          Module name.
 * @return              True if the module is registered.
 */
native bool BSCore_IsModuleRegistered(const char[] name);

/**
 * Returns the registered module bitmask.
 *
 * @return              Combined bitmask of all registered modules.
 */
native eBSCoreModuleBit BSCore_GetRegisteredModuleMask();

/**
 * Returns true if the client has a resolved core summary state.
 *
 * @param client        Client index.
 * @return              True if the client summary is resolved.
 */
native bool BSCore_HasResolvedSummary(int client);

/**
 * Returns the resolved accountid for a client, or 0 when unresolved.
 *
 * @param client        Client index.
 * @return              Resolved accountid, or 0 if unresolved.
 */
native int BSCore_GetResolvedAccountId(int client);

/**
 * Returns the resolved module bitmask for a client, or 0 when unresolved.
 *
 * @param client        Client index.
 * @return              Resolved module mask, or `kBSCoreModule_None` if unresolved.
 */
native eBSCoreModuleBit BSCore_GetResolvedModuleMask(int client);

/**
 * Returns the resolved communication type for a client, or 0 when none.
 *
 * @param client        Client index.
 * @return              Resolved communication type, or `kBSCoreComm_None` when none.
 */
native eBSCoreCommType BSCore_GetResolvedCommType(int client);

/**
 * Returns the resolved ban id stored in the summary for the requested module bit.
 *
 * @param client        Client index.
 * @param moduleBit     Module bitmask to query.
 * @return              Resolved ban id, or 0 if unavailable.
 */
native int BSCore_GetResolvedBanId(int client, eBSCoreModuleBit moduleBit);

/**
 * Returns the current pending detail bitmask for a client.
 *
 * @param client        Client index.
 * @return              Pending detail bitmask for the client.
 */
native eBSCoreModuleBit BSCore_GetPendingDetailMask(int client);

/**
 * Writes or updates the access summary state for an accountid.
 *
 * @param accountid     Internal Steam account id.
 * @param banId         Active access ban id.
 * @return              True if the summary mutation was accepted.
 */
native bool BSCore_SetAccessSummary(int accountid, int banId);

/**
 * Writes or updates the communication summary state for an accountid.
 *
 * @param accountid     Internal Steam account id.
 * @param banId         Active communication ban id.
 * @param commType      Communication ban type stored in summary.
 * @return              True if the summary mutation was accepted.
 */
native bool BSCore_SetCommSummary(int accountid, int banId, eBSCoreCommType commType);

/**
 * Writes or updates the sprays summary state for an accountid.
 *
 * @param accountid     Internal Steam account id.
 * @param banId         Active spray ban id.
 * @return              True if the summary mutation was accepted.
 */
native bool BSCore_SetSpraySummary(int accountid, int banId);

/**
 * Clears one module bit from the summary state of an accountid.
 *
 * @param accountid     Internal Steam account id.
 * @param moduleBit     Module bit to clear.
 * @return              True if the summary mutation was accepted.
 */
native bool BSCore_ClearSummaryModule(int accountid, eBSCoreModuleBit moduleBit);

/**
 * Clears the full summary state for an accountid.
 *
 * @param accountid     Internal Steam account id.
 * @return              True if the summary mutation was accepted.
 */
native bool BSCore_ClearSummary(int accountid);

/**
 * Marks one module detail request as resolved for a client.
 *
 * @param client        Client index.
 * @param moduleBit     Module bit that finished resolving detail.
 * @return              True if the state was updated.
 */
native bool BSCore_MarkModuleDetailResolved(int client, eBSCoreModuleBit moduleBit);

/**
 * Fired when the core needs access detail for a client with an active access summary bit.
 *
 * @param client        Client index.
 * @param accountid     Internal Steam account id.
 * @param banId         Active access ban id from summary.
 */
forward void BSCore_OnAccessDetailRequested(int client, int accountid, int banId);

/**
 * Fired when the core needs communication detail for a client with an active communication summary bit.
 *
 * @param client        Client index.
 * @param accountid     Internal Steam account id.
 * @param banId         Active communication ban id from summary.
 * @param commType      Communication type stored in summary.
 */
forward void BSCore_OnCommDetailRequested(int client, int accountid, int banId, eBSCoreCommType commType);

/**
 * Fired when the core needs spray detail for a client with an active sprays summary bit.
 *
 * @param client        Client index.
 * @param accountid     Internal Steam account id.
 * @param banId         Active spray ban id from summary.
 */
forward void BSCore_OnSprayDetailRequested(int client, int accountid, int banId);

public SharedPlugin __pl_bansystem_core =
{
	name = "bansystem_core",
	file = "bansystem_core.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_core_SetNTVOptional()
{
	MarkNativeAsOptional("BSCore_IsMapTransitionActive");
	MarkNativeAsOptional("BSCore_IsClientAuthPending");
	MarkNativeAsOptional("BSCore_IsLocalCleanCached");
	MarkNativeAsOptional("BSCore_AddLocalCleanCache");
	MarkNativeAsOptional("BSCore_RemoveLocalCleanCache");
	MarkNativeAsOptional("BSCore_ClearLocalCleanCache");
	MarkNativeAsOptional("BSCore_GetLocalCleanCacheSize");
	MarkNativeAsOptional("BSCore_RegisterModule");
	MarkNativeAsOptional("BSCore_IsModuleRegistered");
	MarkNativeAsOptional("BSCore_GetRegisteredModuleMask");
	MarkNativeAsOptional("BSCore_HasResolvedSummary");
	MarkNativeAsOptional("BSCore_GetResolvedAccountId");
	MarkNativeAsOptional("BSCore_GetResolvedModuleMask");
	MarkNativeAsOptional("BSCore_GetResolvedCommType");
	MarkNativeAsOptional("BSCore_GetResolvedBanId");
	MarkNativeAsOptional("BSCore_GetPendingDetailMask");
	MarkNativeAsOptional("BSCore_SetAccessSummary");
	MarkNativeAsOptional("BSCore_SetCommSummary");
	MarkNativeAsOptional("BSCore_SetSpraySummary");
	MarkNativeAsOptional("BSCore_ClearSummaryModule");
	MarkNativeAsOptional("BSCore_ClearSummary");
	MarkNativeAsOptional("BSCore_MarkModuleDetailResolved");
}
#endif
