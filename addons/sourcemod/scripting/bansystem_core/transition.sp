/*****************************************************************
			T R A N S I T I O N
*****************************************************************/

stock bool BSCore_ComputeAuthReadyState()
{
	return (!g_bCoreMapTransitionActive && (BSCore_CanUsePrimaryDatabase() || BSCore_CanUseCacheDatabase()));
}

stock void BSCore_UpdateAuthReadyState()
{
	bool bReady = BSCore_ComputeAuthReadyState();
	if (g_bCoreAuthReady == bReady)
		return;

	g_bCoreAuthReady = bReady;
	BSCore_TransitionLog("Core auth ready state changed: ready=%d primary=%d cache=%d transition=%d", g_bCoreAuthReady ? 1 : 0, BSCore_CanUsePrimaryDatabase() ? 1 : 0, BSCore_CanUseCacheDatabase() ? 1 : 0, g_bCoreMapTransitionActive ? 1 : 0);

	if (g_gfBSCoreOnAuthReadyChanged != null)
	{
		Call_StartForward(g_gfBSCoreOnAuthReadyChanged);
		Call_PushCell(g_bCoreAuthReady ? 1 : 0);
		Call_Finish();
	}
}

stock void BSCore_BeginMapTransition()
{
	g_bCoreMapTransitionActive = true;
	BSCore_TransitionLog("Map transition started.");
	BSCore_UpdateAuthReadyState();
}

stock void BSCore_MaybeFinalizeMapTransition()
{
	if (!g_bCoreMapTransitionActive)
		return;

	if (!BSCore_CanUsePrimaryDatabase() && !BSCore_CanUseCacheDatabase())
		return;

	g_bCoreMapTransitionActive = false;
	BSCore_UpdateAuthReadyState();
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
