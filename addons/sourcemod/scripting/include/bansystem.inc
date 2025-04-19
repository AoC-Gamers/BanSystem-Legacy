#if defined _bansystem_included
	#endinput
#endif
#define _bansystem_included

enum eTypeComms
{
	kNone = 0,
	kMic  = 1,
	kChat = 2,
	kAll  = 3,
}

/**
 * Execute an access ban.
 *
 * @param iAdmin            The client index of the admin initiating the ban. If it is an automatic ban use 0.
 * @param iTarget           The client index of the target being banned. If the user is in the game use iTarget, otherwise send -1.
 * @param szTargetAuthId    The SteamID/AuthID of the target being banned. If iTarget is not defined, add the steamid.
 * @param iLength           The duration of the ban in minutes. Use 0 for a permanent ban.
 * @param szReason          The reason for the ban.
 *
 * @return                 True if the ban was successfully executed, False otherwise.
 */
native bool bBSBanAccess(int iAdmin = 0, int iTarget = -1, const char[] szTargetAuthId, int iLength = 0, const char[] szReason);

/**
 * Checks if a target client is banned from specific communication types.
 *
 * @param iTarget    The client index of the target to check.
 * @param eType      The type of communication to check.
 *
 * @return           True if the client is banned from the specified communication type, False otherwise.
 */
native bool	 bBSBannedComm(int iTarget, eTypeComms eType);

/**
 * Called when an Access prohibition is executed.
 *
 * @param iAdmin            The client index of the admin initiating the ban. If banned by console the value will be 0.
 * @param iTarget           The client index of the target being banned. If you were banned via steamid the value will be -1.
 * @param szTargetAuthId    The SteamID/AuthID of the target being banned.
 * @param iLength           The duration of the ban in minutes. Use 0 for a permanent ban.
 * @param szReason          The reason for the ban.
 */
forward void vBSOnBanAccess(int iAdmin, int iTarget, const char[] szTargetAuthId, int iLength, const char[] szReason);

/**
 * Called when an Access prohibition is removed.
 *
 * @param iAdmin            The client index of the admin performing the unban. If unbanned by console the value will be 0.
 * @param szTargetAuthId    The authentication ID of the target being unbanned.
 */
forward void vBSOnUnbanAccess(int iAdmin, const char[] szTargetAuthId);

/**
 * Call when executing a microphone communication ban.
 *
 * @param iAdmin            The client index of the admin issuing the ban. If banned by console the value will be 0.
 * @param iTarget           The client index of the target being banned. If you were banned via steamid the value will be -1.
 * @param szTargetAuthId    The SteamID/AuthID of the target being banned.
 * @param iLength           The duration of the ban in minutes. Use 0 for a permanent ban.
 * @param szReason          The reason for the ban.
 */
forward void vBSOnBanMic(int iAdmin, int iTarget, const char[] szTargetAuthId, iLength, const char[] szReason);

/**
 * Call when a communication ban is removed from the microphone.
 *
 * @param iAdmin            The client index of the admin who performed the unban. If unbanned by console the value will be 0.
 * @param iTarget           The client index of the player whose microphone ban was lifted. If you were unbanned via steamid the value will be -1.
 * @param szTargetAuthId    The SteamID/AuthID of the player whose microphone ban was lifted.
 */
forward void vBSOnUnbanMic(int iAdmin, int iTarget, const char[] szTargetAuthId);

/**
 * Call when executing a chat communication ban.
 *
 * @param iAdmin            The client index of the admin issuing the ban. If banned by console the value will be 0.
 * @param iTarget           The client index of the target being banned. If you were banned via steamid the value will be -1.
 * @param szTargetAuthId    The SteamID/AuthID of the target being banned.
 * @param iLength           The length of the ban in minutes. Use 0 for a permanent ban.
 * @param szReason          The reason for the ban.
 */
forward void vBSOnBanChat(int iAdmin, int iTarget, const char[] szTargetAuthId, iLength, const char[] szReason);

/**
 * Call when a communication ban is removed from the chat.
 *
 * @param iAdmin            The client index of the admin performing the unban. If unbanned by console the value will be 0.
 * @param iTarget           The client index of the target being unbanned. If you were unbanned via steamid the value will be -1.
 * @param szTargetAuthId    The SteamID/AuthID of the target being unbanned.
 */
forward void vBSOnUnBanChat(int iAdmin, int iTarget, const char[] szTargetAuthId);

public SharedPlugin __pl_bansystem = {
	name = "bansystem",
	file = "bansystem.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_bansystem_SetNTVOptional()
{
	MarkNativeAsOptional("bBanAccess");
	MarkNativeAsOptional("bBannedComm");
	MarkNativeAsOptional("OnBanAccess");
	MarkNativeAsOptional("OnUnbanAccess");
	MarkNativeAsOptional("OnBanMic");
	MarkNativeAsOptional("OnUnbanMic");
	MarkNativeAsOptional("OnBanChat");
	MarkNativeAsOptional("OnUnBanChat");
}
#endif