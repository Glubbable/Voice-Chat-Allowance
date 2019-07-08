// Requires Voice Announce EX! THIS CODE WILL NOT WORK WITHOUT IT!

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <basecomm>
#include <voiceannounce_ex>

#define PLUGIN_VERSION	"1.0"
#define PLUGIN_DESC	"Controls the amount of Mic Time a client is allowed."
#define PLUGIN_NAME	"[ANY] Voice Chat Allowance"
#define PLUGIN_AUTH	"Glubbable"
#define PLUGIN_URL	"https://steamcommunity.com/groups/GlubsServers"

public const Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTH,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL,
};

ConVar g_cvEnable;
ConVar g_cvAdminImmunity;
ConVar g_cvDefaultAllowance;
ConVar g_cvMaxAllowance;

bool g_bEnabled;
bool g_bAdminImmune;
float g_flDefaultAllowance;
float g_flMaxAllowance;

float g_flClientAllowance[MAXPLAYERS + 1];
Handle g_hClientAllowanceTimer[MAXPLAYERS + 1];
bool g_bClientAlreadyMuted[MAXPLAYERS + 1];
bool g_bClientLoaded[MAXPLAYERS + 1];
bool g_bClientIsAdmin[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_cvEnable = CreateConVar("sm_voice_allowance_enable", "1", "Determins if players voice chat time should be regulated.", _, true, _, true, 1.0);
	g_cvAdminImmunity = CreateConVar("sm_voice_allowance_admin_immune", "1", "Determins if voice chat time should apply to Admins.", _, true, _, true, 1.0);
	g_cvDefaultAllowance = CreateConVar("sm_voice_allowance_time", "12.0", "Determins the default starting time for clients.", _, true, 12.0);
	g_cvMaxAllowance = CreateConVar("sm_voice_allowance_max_time", "60.0", "Determins the max amount of allowance a client can have.", _, true, 30.0);
	
	g_cvEnable.AddChangeHook(OnConVarChange);
	g_cvAdminImmunity.AddChangeHook(OnConVarChange);
	g_cvDefaultAllowance.AddChangeHook(OnConVarChange);
	g_cvMaxAllowance.AddChangeHook(OnConVarChange);
	
	for (int i = MaxClients; i > 0; i--)
	{
		if (!IsClientInGame(i))
			continue;
		
		OnClientPostAdminCheck(i);
	}
}

public void OnConfigsExecuted()
{
	g_bEnabled = g_cvEnable.BoolValue;
	g_bAdminImmune = g_cvAdminImmunity.BoolValue;
	g_flDefaultAllowance = g_cvDefaultAllowance.FloatValue;
	g_flMaxAllowance = g_cvMaxAllowance.FloatValue;
}

public void OnClientPutInServer(int iClient)
{
	if (!g_bEnabled || IsFakeClient(iClient))
		return;
	
	g_flClientAllowance[iClient] = g_flDefaultAllowance;
	g_bClientIsAdmin[iClient] = false;
	g_bClientLoaded[iClient] = false;
	g_bClientAlreadyMuted[iClient] = false;
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!g_bEnabled || IsFakeClient(iClient))
		return;
	
	AdminId iAdmin = GetUserAdmin(iClient);
	if (iAdmin != INVALID_ADMIN_ID)
	{
		bool bIsAdmin = (GetAdminFlag(iAdmin, Admin_Generic, Access_Real) || GetAdminFlag(iAdmin, Admin_Generic, Access_Effective));
		if (bIsAdmin && g_bAdminImmune)
		{
			g_bClientIsAdmin[iClient] = true;
			g_bClientLoaded[iClient] = true;
			return;
		}
	}
	
	CreateTimer(0.3, Timer_CheckClientForMute, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void BaseComm_OnClientMute(int iClient, bool bMuteState)
{
	// Prevent false positive on loading in clients.
	if (!g_bEnabled || !g_bClientLoaded[iClient] || g_bClientIsAdmin[iClient])
		return;
	
	if (!bMuteState)
	{
		if (!g_bClientAlreadyMuted[iClient])
			return;
			
		// Their punishment was lifted. We must assign them an allowance for voice chat.
		g_bClientAlreadyMuted[iClient] = false;
		g_flClientAllowance[iClient] = g_flDefaultAllowance;
		g_hClientAllowanceTimer[iClient] = CreateTimer(1.0, Timer_VoiceChatAllowance, GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		if (g_bClientAlreadyMuted[iClient])
			return;
			
		// Client was punished by an external system. Remove them from the allowance.
		if (g_flClientAllowance[iClient] > 0.0)
		{
			g_bClientAlreadyMuted[iClient] = true;
			g_flClientAllowance[iClient] = g_flDefaultAllowance;
			g_hClientAllowanceTimer[iClient] = INVALID_HANDLE;
		}
	}
}

public Action Timer_CheckClientForMute(Handle hTimer, int iUserid)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(iUserid);
	if (!iClient)
		return;
	
	bool bMuted = BaseComm_IsClientMuted(iClient);
	g_bClientAlreadyMuted[iClient] = bMuted;
	
	if (!bMuted) // Muted clients get no allowance.
		g_hClientAllowanceTimer[iClient] = CreateTimer(1.0, Timer_VoiceChatAllowance, GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	g_bClientLoaded[iClient] = true;
}

public Action Timer_VoiceChatAllowance(Handle hTimer, int iUserid)
{
	if (!g_bEnabled)
		return Plugin_Stop;
	
	int iClient = GetClientOfUserId(iUserid);
	if (!iClient)
		return Plugin_Stop;
	
	if (hTimer != g_hClientAllowanceTimer[iClient] || !IsClientInGame(iClient))
		return Plugin_Stop;
	
	float flAllowance = g_flClientAllowance[iClient];	
	if (IsClientSpeaking(iClient))
	{
		if (flAllowance > 0.0)
		{
			flAllowance -= 1.0;
			PrintCenterText(iClient, "You have %i secs left for voice.", RoundToCeil(flAllowance));
		}
		else if (flAllowance <= 0.0 && !BaseComm_IsClientMuted(iClient))
		{
			PrintToChat(iClient, "[SM] You have used up your time for voice chat. You have been muted for %i seconds!", RoundToCeil(g_flDefaultAllowance));
			BaseComm_SetClientMute(iClient, true);
		}
	}
	else
	{
		if (flAllowance < g_flMaxAllowance)
			flAllowance += 1.0;
		
		if (BaseComm_IsClientMuted(iClient) && flAllowance > g_flDefaultAllowance)
		{
			PrintToChat(iClient, "[SM] You now have enough time for voice chat. Your mute has been lifted!");
			BaseComm_SetClientMute(iClient, false);
		}
	}
	
	g_flClientAllowance[iClient] = flAllowance;
	return Plugin_Continue;
}

public void OnConVarChange(ConVar cvConVar, const char[] sOld, const char[] sNew)
{
	if (strcmp(sOld, sNew) == 0)
		return;
		
	if (cvConVar == g_cvEnable)
	{
		g_bEnabled = g_cvEnable.BoolValue;
		
		if (!g_bEnabled)
			return;
		
		for (int i = MaxClients; i > 0; i--)
		{
			if (!IsClientInGame(i))
				continue;
			
			OnClientPostAdminCheck(i);
		}
	}	
	else if (cvConVar == g_cvAdminImmunity)
	{
		g_bAdminImmune = g_cvAdminImmunity.BoolValue;
		
		if (!g_bEnabled)
			return;
			
		for (int i = MaxClients; i > 0; i--)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
				
			AdminId iAdmin = GetUserAdmin(i);
			if (iAdmin != INVALID_ADMIN_ID)
			{
				if (GetAdminFlag(iAdmin, Admin_Generic, Access_Real) || GetAdminFlag(iAdmin, Admin_Generic, Access_Effective))
				{
					if (StringToInt(sOld) && !StringToInt(sNew))
					{
						g_flClientAllowance[i] = g_flDefaultAllowance;
						g_hClientAllowanceTimer[i] = CreateTimer(1.0, Timer_VoiceChatAllowance, GetClientUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
					else
					{
						g_hClientAllowanceTimer[i] = INVALID_HANDLE;
					}
				}
			}
		}
	}
	else if (cvConVar == g_cvDefaultAllowance)
	{
		g_flDefaultAllowance = g_cvDefaultAllowance.FloatValue;
		
		if (!g_bEnabled)
			return;
			
		for (int i = MaxClients; i > 0; i--)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
			
			float flAllowance = g_flClientAllowance[i];
			if (flAllowance != 0.0 && flAllowance == StringToFloat(sOld))
				g_flClientAllowance[i] = g_flDefaultAllowance;
		}
	}	
	else if (cvConVar == g_cvMaxAllowance)
	{
		g_flMaxAllowance = g_cvMaxAllowance.FloatValue;
		
		if (!g_bEnabled)
			return;
			
		for (int i = MaxClients; i > 0; i--)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
			
			float flAllowance = g_flClientAllowance[i];
			if (flAllowance != 0.0 && flAllowance > StringToFloat(sOld))
				g_flClientAllowance[i] = g_flMaxAllowance;
		}
	}
}