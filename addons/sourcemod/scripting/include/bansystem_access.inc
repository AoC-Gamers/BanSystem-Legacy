#if defined _bansystem_access_included
	#endinput
#endif
#define _bansystem_access_included

/**
 * Queues an access ban mutation using an already resolved accountid.
 *
 * This native is synchronous from the caller perspective only in the sense that it returns
 * whether the request was accepted by the module. The actual database mutation is async.
 */
native bool BSAccess_AddBanByAccountId(int iAdmin, int iAccountId, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues an access unban mutation using an already resolved accountid.
 *
 * This native is synchronous from the caller perspective only in the sense that it returns
 * whether the request was accepted by the module. The actual database mutation is async.
 */
native bool BSAccess_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved access detail for a connected client.
 */
native bool BSAccess_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved access ban state loaded.
 */
native bool BSAccess_IsClientBanned(int iClient);

/**
 * Returns the resolved accountid cached for a connected client, or 0 when unresolved.
 */
native int BSAccess_GetResolvedAccountId(int iClient);
