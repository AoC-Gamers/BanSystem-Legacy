/*****************************************************************
			T R A N S I T I O N
*****************************************************************/

stock void BSCore_BeginMapTransition()
{
	g_bCoreMapTransitionActive = true;
	BSCore_TransitionLog("Map transition started.");
}

stock void BSCore_MaybeFinalizeMapTransition()
{
	if (!g_bCoreMapTransitionActive)
		return;

	if (!BSCore_CanUsePrimaryDatabase() && !BSCore_CanUseCacheDatabase())
		return;

	g_bCoreMapTransitionActive = false;
	BSCore_TransitionLog("Map transition completed. Processing queued core auth states.");
	BSCore_ProcessQueuedAuthorizationChecks();
}

stock void BSCore_OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "l4d2_changelevel", false))
	{
		g_bCoreHasL4D2ChangeLevel = true;
		BSCore_TransitionLog("Detected l4d2_changelevel library.");
	}
}

stock void BSCore_OnLibraryRemoved(const char[] szName)
{
	if (StrEqual(szName, "l4d2_changelevel", false))
	{
		g_bCoreHasL4D2ChangeLevel = false;
		BSCore_TransitionLog("l4d2_changelevel library removed.");
	}
}
