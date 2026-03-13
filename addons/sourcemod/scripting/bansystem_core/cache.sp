/*****************************************************************
			C A C H E
*****************************************************************/

stock bool BSCore_CanUseLocalCleanCache()
{
	return (g_cvCoreLocalCache != null && g_cvCoreLocalCache.BoolValue && g_alCoreLocalCleanCache != null);
}

stock bool BSCore_HasLocalCleanCacheAccountId(int iAccountId)
{
	if (!BSCore_CanUseLocalCleanCache() || iAccountId <= 0)
		return false;

	return (g_alCoreLocalCleanCache.FindValue(iAccountId) != -1);
}

stock bool BSCore_AddLocalCleanCacheAccountId(int iAccountId)
{
	if (!BSCore_CanUseLocalCleanCache() || iAccountId <= 0)
		return false;

	if (g_alCoreLocalCleanCache.FindValue(iAccountId) != -1)
		return true;

	g_alCoreLocalCleanCache.Push(iAccountId);
	BSCore_Debug("Added accountid %d to local clean cache.", iAccountId);
	return true;
}

stock bool BSCore_RemoveLocalCleanCacheAccountId(int iAccountId)
{
	if (g_alCoreLocalCleanCache == null || iAccountId <= 0)
		return false;

	int iIndex = g_alCoreLocalCleanCache.FindValue(iAccountId);
	if (iIndex == -1)
		return false;

	g_alCoreLocalCleanCache.Erase(iIndex);
	BSCore_Debug("Removed accountid %d from local clean cache.", iAccountId);
	return true;
}

stock void BSCore_ClearLocalCleanCache()
{
	if (g_alCoreLocalCleanCache == null)
		return;

	g_alCoreLocalCleanCache.Clear();
	BSCore_Debug("Cleared local clean cache.");
}

stock int BSCore_GetLocalCleanCacheSize()
{
	if (g_alCoreLocalCleanCache == null)
		return 0;

	return g_alCoreLocalCleanCache.Length;
}
