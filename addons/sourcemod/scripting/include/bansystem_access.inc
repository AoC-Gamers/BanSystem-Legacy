#if defined _bansystem_access_included
	#endinput
#endif
#define _bansystem_access_included

/**
 * Queues an access ban mutation using an already resolved accountid.
 *
 * This native is synchronous from the caller perspective only in the sense that it returns
 * whether the request was accepted by the module. The actual database mutation is async.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to punish.
 * @param iLength       Ban length in minutes. 0 means permanent.
 * @param szReason      Ban reason.
 * @param szContext     Optional ban context.
 * @return              True if the request was accepted by the module.
 */
native bool BSAccess_AddBanByAccountId(int iAdmin, int iAccountId, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues an access unban mutation using an already resolved accountid.
 *
 * This native is synchronous from the caller perspective only in the sense that it returns
 * whether the request was accepted by the module. The actual database mutation is async.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to unban.
 * @return              True if the request was accepted by the module.
 */
native bool BSAccess_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved access detail for a connected client.
 *
 * @param iClient       Client index.
 * @return              True if access detail is resolved for the client.
 */
native bool BSAccess_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved access ban state loaded.
 *
 * @param iClient       Client index.
 * @return              True if the client has an active resolved access ban.
 */
native bool BSAccess_IsClientBanned(int iClient);

/**
 * Returns the resolved accountid cached for a connected client, or 0 when unresolved.
 *
 * @param iClient       Client index.
 * @return              Resolved accountid, or 0 if unresolved.
 */
native int BSAccess_GetResolvedAccountId(int iClient);

public SharedPlugin __pl_bansystem_access =
{
	name = "bansystem_access",
	file = "bansystem_access.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_access_SetNTVOptional()
{
	MarkNativeAsOptional("BSAccess_AddBanByAccountId");
	MarkNativeAsOptional("BSAccess_RemoveBanByAccountId");
	MarkNativeAsOptional("BSAccess_HasResolvedDetail");
	MarkNativeAsOptional("BSAccess_IsClientBanned");
	MarkNativeAsOptional("BSAccess_GetResolvedAccountId");
}
#endif
