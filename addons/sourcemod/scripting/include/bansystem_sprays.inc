#if defined _bansystem_sprays_included
	#endinput
#endif
#define _bansystem_sprays_included

/**
 * Queues a spray ban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to punish.
 * @param iLength       Ban length in minutes. 0 means permanent.
 * @param szReason      Ban reason.
 * @param szContext     Optional ban context.
 * @return              True if the request was accepted by the module.
 */
native bool BSSprays_AddBanByAccountId(int iAdmin, int iAccountId, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues a spray unban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 *
 * @param iAdmin        Admin client index, or 0 for server console.
 * @param iAccountId    Internal Steam account id to unban.
 * @return              True if the request was accepted by the module.
 */
native bool BSSprays_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved spray detail for a connected client.
 *
 * @param iClient       Client index.
 * @return              True if spray detail is resolved for the client.
 */
native bool BSSprays_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved spray ban state loaded.
 *
 * @param iClient       Client index.
 * @return              True if the client has an active resolved spray ban.
 */
native bool BSSprays_IsClientBanned(int iClient);

public SharedPlugin __pl_bansystem_sprays =
{
	name = "bansystem_sprays",
	file = "bansystem_sprays.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_bansystem_sprays_SetNTVOptional()
{
	MarkNativeAsOptional("BSSprays_AddBanByAccountId");
	MarkNativeAsOptional("BSSprays_RemoveBanByAccountId");
	MarkNativeAsOptional("BSSprays_HasResolvedDetail");
	MarkNativeAsOptional("BSSprays_IsClientBanned");
}
#endif
