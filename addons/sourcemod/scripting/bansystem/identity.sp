void vNormalizeCommandInput(const char[] szInput, char[] szOutput, int iMaxLength)
{
	strcopy(szOutput, iMaxLength, szInput);
	TrimString(szOutput);
	StripQuotes(szOutput);
}

void vNormalizeIdentityInput(const char[] szInput, char[] szOutput, int iMaxLength)
{
	vNormalizeCommandInput(szInput, szOutput, iMaxLength);
}

SteamIDToolsProvider eGetSteamIdLookupProvider()
{
	if (!SteamIDTools_IsLibraryAvailable())
		return SteamIDToolsProvider_Unknown;

	char szProvider[16];
	g_cvSteamIdProvider.GetString(szProvider, sizeof(szProvider));
	TrimString(szProvider);

	if (StrEqual(szProvider, "steamworks", false))
	{
		if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks))
			return SteamIDToolsProvider_SteamWorks;
		return SteamIDToolsProvider_Unknown;
	}

	if (StrEqual(szProvider, "system2", false))
	{
		if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
			return SteamIDToolsProvider_System2;
		return SteamIDToolsProvider_Unknown;
	}

	if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_SteamWorks))
		return SteamIDToolsProvider_SteamWorks;

	if (SteamIDTools_IsProviderAvailable(SteamIDToolsProvider_System2))
		return SteamIDToolsProvider_System2;

	return SteamIDToolsProvider_Unknown;
}

eIdentityResolution eResolveIdentityToSteam2Offline(const char[] szInput, char[] szSteamId2, int iMaxLength, bool bAllowAccountId)
{
	char szNormalized[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szInput, szNormalized, sizeof(szNormalized));

	switch (DetectSteamIDFormat(szNormalized))
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			strcopy(szSteamId2, iMaxLength, szNormalized);
			return kIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			if (SteamID3ToSteamID2(szNormalized, szSteamId2, iMaxLength))
				return kIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			if (!bAllowAccountId)
				return kIdentityResolution_Invalid;

			int iAccountId = StringToInt(szNormalized);
			if (AccountIDToSteamID2(iAccountId, szSteamId2, iMaxLength))
				return kIdentityResolution_Resolved;
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			return kIdentityResolution_OnlinePending;
		}
	}

	return kIdentityResolution_Invalid;
}

bool bQueueIdentityLookupRequest(eIdentityRequestKind eKind, int iClient, ReplySource eReplySource, const char[] szInput, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "")
{
	SteamIDToolsProvider eProvider = eGetSteamIdLookupProvider();
	if (eProvider == SteamIDToolsProvider_Unknown)
	{
		vReplyCommandPhrase(iClient, "IdentityResolveUnavailable");
		return false;
	}

	char szNormalizedInput[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szInput, szNormalizedInput, sizeof(szNormalizedInput));

	int iRequestId = SteamIDTools_RequestConversion(eProvider, API_SID64toSID2, szNormalizedInput);
	if (iRequestId <= 0)
	{
		vReplyCommandPhrase(iClient, "IdentityResolveUnavailable");
		return false;
	}

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	DataPack pContext = pCreateIdentityRequestContext(eKind, iClient, eReplySource, iArg0, iArg1, szExtra);
	g_smIdentityRequestContext.SetValue(szRequestId, pContext);

	vReplyCommandPhrase(iClient, "IdentityResolvePending");
	return true;
}

eIdentityResolution eResolveCommandIdentity(const char[] szInput, bool bAllowAccountId, eIdentityRequestKind ePendingKind, int iClient, ReplySource eReplySource, char[] szResolvedSteamId2, int iMaxLength, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "")
{
	eIdentityResolution eResolution = eResolveIdentityToSteam2Offline(szInput, szResolvedSteamId2, iMaxLength, bAllowAccountId);
	if (eResolution == kIdentityResolution_OnlinePending)
	{
		bQueueIdentityLookupRequest(ePendingKind, iClient, eReplySource, szInput, iArg0, iArg1, szExtra);
	}

	return eResolution;
}

bool bResolveIdentityOnlyCommandInput(int iClient, const char[] szInput, bool bAllowAccountId, eIdentityRequestKind ePendingKind, char[] szResolvedSteamId2, int iMaxLength, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "")
{
	ReplySource eReplySource = GetCmdReplySource();
	eIdentityResolution eResolution = eResolveCommandIdentity(szInput, bAllowAccountId, ePendingKind, iClient, eReplySource, szResolvedSteamId2, iMaxLength, iArg0, iArg1, szExtra);
	if (eResolution == kIdentityResolution_Resolved)
		return true;

	if (eResolution == kIdentityResolution_OnlinePending)
		return false;

	char szNormalizedInput[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szInput, szNormalizedInput, sizeof(szNormalizedInput));
	vReplyCommandPhraseString(iClient, "AuthIdError", szNormalizedInput);
	return false;
}

bool bResolveTargetCommandInput(int iClient, const char[] szInput, bool bAllowAccountId, eIdentityRequestKind ePendingKind, char[] szResolvedSteamId2, int iMaxLength, int &iResolvedTarget, int iArg0 = 0, int iArg1 = 0, const char[] szExtra = "")
{
	ReplySource eReplySource = GetCmdReplySource();
	eIdentityResolution eResolution = eResolveCommandIdentity(szInput, bAllowAccountId, ePendingKind, iClient, eReplySource, szResolvedSteamId2, iMaxLength, iArg0, iArg1, szExtra);
	if (eResolution == kIdentityResolution_Resolved)
	{
		iResolvedTarget = FindClientBySteamID2(szResolvedSteamId2);
		if (iResolvedTarget <= SERVER_INDEX)
			iResolvedTarget = NO_INDEX;
		return true;
	}

	if (eResolution == kIdentityResolution_OnlinePending)
		return false;

	iResolvedTarget = FindTarget(iClient, szInput, true, false);
	if (iResolvedTarget == NO_INDEX)
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "NoMatchingClient", szInput);
		return false;
	}

	if (!GetClientAuthId(iResolvedTarget, AuthId_Steam2, szResolvedSteamId2, iMaxLength))
	{
		char szTargetName[MAX_NAME_LENGTH];
		if (!GetClientName(iResolvedTarget, szTargetName, sizeof(szTargetName)))
			strcopy(szTargetName, sizeof(szTargetName), szInput);

		vReplyCommandPhraseString(iClient, "AuthIdError", szTargetName);
		return false;
	}

	return true;
}

void vReplyIdentityLookupFailure(int iUserId, ReplySource eReplySource, const char[] szError)
{
	int iReplyClient = iResolveReplyClient(iUserId, false);
	if (iReplyClient == NO_INDEX)
		return;

	SetCmdReplySource(eReplySource);
	vReplyCommandPhraseString(iReplyClient, "IdentityResolveFailed", szError);
}

bool bGetAccountIdFromAuthId(const char[] szAuthId, int &iAccountId)
{
	char szSteamId[MAX_AUTHID_LENGTH];
	strcopy(szSteamId, sizeof(szSteamId), szAuthId);
	StripQuotes(szSteamId);

	iAccountId = SteamID2ToAccountID(szSteamId);
	return (iAccountId != 0);
}

bool bGetAuthIdFromAccountId(int iAccountId, char[] szAuthId, int iMaxLength)
{
	if (AccountIDToSteamID2(iAccountId, szAuthId, iMaxLength))
		return true;

	Format(szAuthId, iMaxLength, "account:%d", iAccountId);
	return false;
}

bool bAddDecimalStringInt(const char[] szBaseValue, int iAddValue, char[] szResult, int iMaxLength)
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

bool bGetSteamId64FromAccountId(int iAccountId, char[] szSteamId64, int iMaxLength)
{
	if (iAccountId <= 0)
		return false;

	return bAddDecimalStringInt(STEAMID64_BASE_STRING, iAccountId, szSteamId64, iMaxLength);
}

bool bResolveSteamId64(int iTarget, int iAccountId, char[] szSteamId64, int iMaxLength)
{
	if (bIsUsableClient(iTarget) && GetClientAuthId(iTarget, AuthId_SteamID64, szSteamId64, iMaxLength))
		return true;

	return bGetSteamId64FromAccountId(iAccountId, szSteamId64, iMaxLength);
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (bBatch)
		return;

	if (bHandleNativeIdentityLookupRequestResult(iRequestId, bSuccess, szResult))
		return;

	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	int pContextRef;
	if (!g_smIdentityRequestContext.GetValue(szRequestId, pContextRef))
		return;

	g_smIdentityRequestContext.Remove(szRequestId);

	eIdentityRequestKind eKind;
	int iUserId;
	ReplySource eReplySource;
	int iArg0;
	int iArg1;
	char szExtra[MAX_MESSAGE_LENGTH];
	vReadIdentityRequestContext(pContextRef, eKind, iUserId, eReplySource, iArg0, iArg1, szExtra, sizeof(szExtra));

	if (!bSuccess)
	{
		vReplyIdentityLookupFailure(iUserId, eReplySource, szResult);
		return;
	}

	char szResolvedSteamId2[MAX_AUTHID_LENGTH];
	vNormalizeIdentityInput(szResult, szResolvedSteamId2, sizeof(szResolvedSteamId2));
	if (!IsValidSteamID2(szResolvedSteamId2))
	{
		vReplyIdentityLookupFailure(iUserId, eReplySource, "Invalid SteamIDTools response");
		return;
	}

	switch (eKind)
	{
		case kIdentityRequest_AccessUnban:
		{
			vSubmitRemoveAccessByIdentity(iResolveReplyClient(iUserId, true), szResolvedSteamId2, eReplySource);
		}
		case kIdentityRequest_AccessInfo:
		{
			int iClient = iResolveReplyClient(iUserId, false);
			if (iClient != NO_INDEX)
				vSubmitAccessInfoByIdentity(iClient, szResolvedSteamId2, eReplySource);
		}
		case kIdentityRequest_AccessAttemptInfo:
		{
			int iClient = iResolveReplyClient(iUserId, false);
			if (iClient != NO_INDEX)
				vSubmitAccessAttemptInfoByIdentity(iClient, szResolvedSteamId2, eReplySource);
		}
		case kIdentityRequest_AccessBan:
		{
			vSubmitAccessRegistrationByIdentity(iResolveReplyClient(iUserId, true), szResolvedSteamId2, iArg0, szExtra, eReplySource);
		}
		case kIdentityRequest_CommInfo:
		{
			int iClient = iResolveReplyClient(iUserId, false);
			if (iClient != NO_INDEX)
				vSubmitCommInfoByIdentity(iClient, szResolvedSteamId2, eReplySource);
		}
		case kIdentityRequest_CommUnban:
		{
			vSubmitRemoveCommByIdentity(iResolveReplyClient(iUserId, true), szResolvedSteamId2, eReplySource);
		}
		case kIdentityRequest_CommBan:
		{
			vSubmitCommRegistrationByIdentity(iResolveReplyClient(iUserId, true), szResolvedSteamId2, iArg1, szExtra, view_as<eTypeComms>(iArg0), eReplySource);
		}
	}
}
