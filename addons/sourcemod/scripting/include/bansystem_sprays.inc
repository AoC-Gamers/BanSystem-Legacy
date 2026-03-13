#if defined _bansystem_sprays_included
	#endinput
#endif
#define _bansystem_sprays_included

/**
 * Queues a spray ban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 */
native bool BSSprays_AddBanByAccountId(int iAdmin, int iAccountId, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues a spray unban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 */
native bool BSSprays_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved spray detail for a connected client.
 */
native bool BSSprays_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved spray ban state loaded.
 */
native bool BSSprays_IsClientBanned(int iClient);
