/*****************************************************************
			M O D U L E S
*****************************************************************/

stock bool BSCore_RegisterModule(const char[] szName, eBSCoreModuleBit eModuleBit)
{
	if (szName[0] == '\0' || eModuleBit == kBSCoreModule_None)
		return false;

	if (!BSCore_IsValidModuleMask(eModuleBit))
		return false;

	if (g_smCoreRegisteredModules == null)
		return false;

	int iExistingBit;
	if (g_smCoreRegisteredModules.GetValue(szName, iExistingBit))
		return (iExistingBit == view_as<int>(eModuleBit));

	g_smCoreRegisteredModules.SetValue(szName, view_as<int>(eModuleBit));
	BSCore_AddModule(g_eCoreRegisteredModuleMask, eModuleBit);
	BSCore_Debug("Registered core module '%s' with bit %d.", szName, view_as<int>(eModuleBit));
	return true;
}

stock bool BSCore_IsModuleRegistered(const char[] szName)
{
	if (g_smCoreRegisteredModules == null || szName[0] == '\0')
		return false;

	int iValue;
	return g_smCoreRegisteredModules.GetValue(szName, iValue);
}

stock void BSCore_BuildRegisteredModulesString(char[] szBuffer, int iMaxLength)
{
	if (g_smCoreRegisteredModules == null)
	{
		strcopy(szBuffer, iMaxLength, "<none>");
		return;
	}

	StringMapSnapshot smSnapshot = g_smCoreRegisteredModules.Snapshot();
	if (smSnapshot == null || smSnapshot.Length == 0)
	{
		delete smSnapshot;
		strcopy(szBuffer, iMaxLength, "<none>");
		return;
	}

	szBuffer[0] = '\0';

	char szKey[64];
	for (int i = 0; i < smSnapshot.Length; i++)
	{
		smSnapshot.GetKey(i, szKey, sizeof(szKey));
		if (szBuffer[0] != '\0')
			StrCat(szBuffer, iMaxLength, ",");
		StrCat(szBuffer, iMaxLength, szKey);
	}

	delete smSnapshot;
}
