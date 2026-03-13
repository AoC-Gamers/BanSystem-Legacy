/*****************************************************************
			I D E N T I T Y
*****************************************************************/

stock void BSCore_NormalizeIdentityInput(const char[] szInput, char[] szOutput, int iMaxLength)
{
	BSCore_NormalizeInput(szInput, szOutput, iMaxLength);
}

stock bool BSCore_GetAccountIdFromSteam2(const char[] szSteamId2, int &iAccountId)
{
	char szNormalized[MAX_AUTHID_LENGTH];
	BSCore_NormalizeIdentityInput(szSteamId2, szNormalized, sizeof(szNormalized));

	iAccountId = SteamID2ToAccountID(szNormalized);
	return (iAccountId > 0);
}

stock bool BSCore_GetSteam2FromAccountId(int iAccountId, char[] szSteamId2, int iMaxLength)
{
	return AccountIDToSteamID2(iAccountId, szSteamId2, iMaxLength);
}

stock bool BSCore_AddDecimalStringInt(const char[] szBaseValue, int iAddValue, char[] szResult, int iMaxLength)
{
	if (iAddValue < 0 || iMaxLength <= 1)
		return false;

	char szAddValue[16];
	char szReversed[32];
	IntToString(iAddValue, szAddValue, sizeof(szAddValue));

	int iBasePos = strlen(szBaseValue) - 1;
	int iAddPos = strlen(szAddValue) - 1;
	int iCarry = 0;
	int iReversedLength = 0;

	while (iBasePos >= 0 || iAddPos >= 0 || iCarry != 0)
	{
		if (iReversedLength >= sizeof(szReversed) - 1)
			return false;

		int iDigit = iCarry;
		if (iBasePos >= 0)
			iDigit += szBaseValue[iBasePos--] - '0';
		if (iAddPos >= 0)
			iDigit += szAddValue[iAddPos--] - '0';

		szReversed[iReversedLength++] = view_as<char>('0' + (iDigit % 10));
		iCarry = iDigit / 10;
	}

	if (iReversedLength + 1 > iMaxLength)
		return false;

	for (int i = 0; i < iReversedLength; i++)
	{
		szResult[i] = szReversed[iReversedLength - i - 1];
	}

	szResult[iReversedLength] = '\0';
	return true;
}

stock bool BSCore_GetSteam64FromAccountId(int iAccountId, char[] szSteamId64, int iMaxLength)
{
	if (iAccountId <= 0)
		return false;

	return BSCore_AddDecimalStringInt(BANSYSTEM_CORE_STEAMID64_BASE_STRING, iAccountId, szSteamId64, iMaxLength);
}

stock eBSCoreIdentityResolution BSCore_ResolveSteam2Offline(const char[] szInput, char[] szSteamId2, int iMaxLength, bool bAllowAccountId = true)
{
	char szNormalized[MAX_AUTHID_LENGTH];
	BSCore_NormalizeIdentityInput(szInput, szNormalized, sizeof(szNormalized));

	switch (DetectSteamIDFormat(szNormalized))
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			strcopy(szSteamId2, iMaxLength, szNormalized);
			return kBSCoreIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			if (SteamID3ToSteamID2(szNormalized, szSteamId2, iMaxLength))
				return kBSCoreIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			if (!bAllowAccountId)
				return kBSCoreIdentityResolution_Invalid;

			int iAccountId = StringToInt(szNormalized);
			if (AccountIDToSteamID2(iAccountId, szSteamId2, iMaxLength))
				return kBSCoreIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			return kBSCoreIdentityResolution_OnlinePending;
		}
	}

	return kBSCoreIdentityResolution_Invalid;
}

stock bool BSCore_TryResolveAccountIdOffline(const char[] szInput, int &iAccountId)
{
	char szNormalized[MAX_AUTHID_LENGTH];
	char szSteamId2[MAX_AUTHID_LENGTH];
	BSCore_NormalizeIdentityInput(szInput, szNormalized, sizeof(szNormalized));

	switch (DetectSteamIDFormat(szNormalized))
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			iAccountId = SteamID2ToAccountID(szNormalized);
			return (iAccountId > 0);
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			if (!SteamID3ToSteamID2(szNormalized, szSteamId2, sizeof(szSteamId2)))
				return false;

			iAccountId = SteamID2ToAccountID(szSteamId2);
			return (iAccountId > 0);
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			iAccountId = StringToInt(szNormalized);
			return (iAccountId > 0);
		}
	}

	iAccountId = 0;
	return false;
}

stock bool BSCore_TryResolveSteam64Offline(const char[] szInput, char[] szSteamId64, int iMaxLength)
{
	char szNormalized[MAX_AUTHID_LENGTH];
	int iAccountId;
	BSCore_NormalizeIdentityInput(szInput, szNormalized, sizeof(szNormalized));

	switch (DetectSteamIDFormat(szNormalized))
	{
		case STEAMID_FORMAT_STEAMID64:
		{
			if (!IsValidSteamID64(szNormalized))
				return false;

			strcopy(szSteamId64, iMaxLength, szNormalized);
			return true;
		}
		case STEAMID_FORMAT_STEAMID2, STEAMID_FORMAT_STEAMID3, STEAMID_FORMAT_ACCOUNTID:
		{
			if (!BSCore_TryResolveAccountIdOffline(szNormalized, iAccountId))
				return false;

			return BSCore_GetSteam64FromAccountId(iAccountId, szSteamId64, iMaxLength);
		}
	}

	return false;
}
