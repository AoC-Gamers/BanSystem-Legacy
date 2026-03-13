#if defined _bansystem_comm_included
	#endinput
#endif
#define _bansystem_comm_included

/**
 * Queues a communication ban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 */
native bool BSComm_AddBanByAccountId(int iAdmin, int iAccountId, int iCommType, int iLength = 0, const char[] szReason = "", const char[] szContext = "");

/**
 * Queues a communication unban mutation using an already resolved accountid.
 *
 * The mutation itself is asynchronous; this native only reports whether the module accepted the request.
 */
native bool BSComm_RemoveBanByAccountId(int iAdmin, int iAccountId);

/**
 * Returns true when the module has resolved communication detail for a connected client.
 */
native bool BSComm_HasResolvedDetail(int iClient);

/**
 * Returns true when the connected client currently has resolved communication ban state loaded.
 */
native bool BSComm_IsClientBanned(int iClient);

/**
 * Returns the resolved communication type cached for a connected client.
 */
native int BSComm_GetResolvedCommType(int iClient);
