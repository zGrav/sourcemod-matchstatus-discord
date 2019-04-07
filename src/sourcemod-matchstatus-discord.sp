#include <sourcemod>
#include <SteamWorks>
#include <cstrike>

#define PLUGIN_NAME "sourcemod-matchstatus-discord"
#define PLUGIN_AUTHOR "z"
#define PLUGIN_DESCRIPTION "Basically pushes to a Discord channel when a game starts and finishes with result/stats."
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "http://github.com/zGrav/sourcemod-gameinfo-pusher-discord"

#define GOTV_URL "steam://connect/csgo.zgrav.pro:27302"

#define DISCORD_WEBHOOK "https://discordapp.com/api/webhooks/"

char DISCORD_MSG_START[2048] = "{\"content\": \"A match has started!\", \"embeds\": [{\"title\": \"Connect to GOTV by clicking here ({GOTV_URL})\", \"fields\": [{\"name\": \"Map:\", \"value\": \"{MAP_NAME}\"}, {\"name\": \"T Side:\", \"value\": \"{T_PLAYERS}\"}, {\"name\": \"CT Side:\", \"value\": \"{CT_PLAYERS}\"}]}]}"
char DISCORD_MSG_HALF[2048] = "{\"content\": \"A match has reached half-time!\", \"embeds\": [{\"title\": \"Connect to GOTV by clicking here ({GOTV_URL})\", \"fields\": [{\"name\": \"Map:\", \"value\": \"{MAP_NAME}\"}, {\"name\": \"Current result:\", \"value\": \"{RESULT}\"}]}]}"
char DISCORD_MSG_END[2048] = "{\"content\": \"A match has ended!\", \"embeds\": [{\"title\": \"This is the final data for this match:\", \"fields\": [{\"name\": \"Map:\", \"value\": \"{MAP_NAME}\"}, {\"name\": \"Final result:\", \"value\": \"{RESULT}\"}, {\"name\": \"T Side:\", \"value\": \"{T_PLAYERS}\"}, {\"name\": \"T Stats:\", \"value\": \"{T_STATS}\"}, \"name\": \"CT Side:\", \"value\": \"{CT_PLAYERS}\"}, {\"name\": \"CT Stats:\", \"value\": \"{CT_STATS}\"}]}]}"

char T_PLAYERS[512];
char CT_PLAYERS[512];
char T_STATS[512];
char CT_STATS[512];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnPluginStart()
{
	PrintToServer("sourcemod-matchstatus-discord loaded!");
	PrintToServer("Current Discord Webhook: %s", DISCORD_WEBHOOK);
	AddCommandListener(CheckForConfigLine, "say");
	HookEvent("cs_intermission", OnHalfTime, EventHookMode_PostNoCopy);
	HookEvent("cs_win_panel_match", OnFinishedMatch, EventHookMode_PostNoCopy);
}

public Action CheckForConfigLine(int client, const char[] cmd, int args)
{
	char configline[40];
	GetCmdArgString(configline, sizeof(configline));

	if (StrEqual(configline, "MR15 Match Config Loaded")) {
			PrintToChatAll(configline);

			SendToDiscord("start");

			return Plugin_Handled;
	}

  return Plugin_Continue;
}

public OnHalfTime(Handle:event, const String:name[], bool:dontBroadcast)
{
    SendToDiscord("half");
}

public OnFinishedMatch(Handle:event, const String:name[], bool:dontBroadcast)
{
    SendToDiscord("end");
}

public SendToDiscord(char type[10]) {
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, DISCORD_WEBHOOK);

	if (StrEqual(type, "start")) {
		char mapName[256];

		GetCurrentMap(mapName, sizeof(mapName));

		getTs();
		getCTs();

		if (StrEqual(T_PLAYERS, "")) {
			T_PLAYERS = "No players";
		}

		if (StrEqual(CT_PLAYERS, "")) {
			CT_PLAYERS = "No players";
		}

		ReplaceString(DISCORD_MSG_START, sizeof(DISCORD_MSG_START), "{GOTV_URL}", GOTV_URL, true);
		ReplaceString(DISCORD_MSG_START, sizeof(DISCORD_MSG_START), "{MAP_NAME}", mapName, true);
		ReplaceString(DISCORD_MSG_START, sizeof(DISCORD_MSG_START), "{T_PLAYERS}", T_PLAYERS, true);
		ReplaceString(DISCORD_MSG_START, sizeof(DISCORD_MSG_START), "{CT_PLAYERS}", CT_PLAYERS, true);

		if(!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete))
					|| !SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", DISCORD_MSG_START, strlen(DISCORD_MSG_START))
					|| !SteamWorks_SendHTTPRequest(hRequest))
		{
			delete hRequest;
		}
	} else if (StrEqual(type, "end")) {
		char mapName[256];

		GetCurrentMap(mapName, sizeof(mapName));

		getTs();
		getTsStats();
		getCTs();
		getCTsStats();

		if (StrEqual(T_PLAYERS, "")) {
			T_PLAYERS = "No players";
		}
		if (StrEqual(T_STATS, "")) {
			T_STATS = "No stats";
		}

		if (StrEqual(CT_PLAYERS, "")) {
			CT_PLAYERS = "No players";
		}
		if (StrEqual(CT_STATS, "")) {
			CT_STATS = "No stats";
		}

		int ctScore = CS_GetTeamScore(CS_TEAM_CT);
		int tScore = CS_GetTeamScore(CS_TEAM_T);

		char endResult[512];

		if (ctScore > tScore) {
			Format(endResult, sizeof(endResult), "CTs won the game %d to %d over the Ts", ctScore, tScore);
		} else if (ctScore < tScore) {
			Format(endResult, sizeof(endResult), "Ts won the game %d to %d over the CTs", tScore, ctScore);
		}

		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{GOTV_URL}", GOTV_URL, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{MAP_NAME}", mapName, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{RESULT}", endResult, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{T_PLAYERS}", T_PLAYERS, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{CT_PLAYERS}", CT_PLAYERS, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{T_STATS}", T_STATS, true);
		ReplaceString(DISCORD_MSG_END, sizeof(DISCORD_MSG_END), "{CT_STATS}", CT_STATS, true);

		if(!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete))
					|| !SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", DISCORD_MSG_END, strlen(DISCORD_MSG_END))
					|| !SteamWorks_SendHTTPRequest(hRequest))
		{
			delete hRequest;
		}
	} else if (StrEqual(type, "half")) {
		char mapName[256];

		GetCurrentMap(mapName, sizeof(mapName));

		int ctScore = CS_GetTeamScore(CS_TEAM_CT);
		int tScore = CS_GetTeamScore(CS_TEAM_T);

		char halfTime[512];

		if (ctScore > tScore) {
			Format(halfTime, sizeof(halfTime), "CTs are winning %d to %d over the Ts", ctScore, tScore);
		} else if (ctScore < tScore) {
			Format(halfTime, sizeof(halfTime), "Ts are winning %d to %d over the CTs", tScore, ctScore);
		}

		ReplaceString(DISCORD_MSG_HALF, sizeof(DISCORD_MSG_HALF), "{GOTV_URL}", GOTV_URL, true);
		ReplaceString(DISCORD_MSG_HALF, sizeof(DISCORD_MSG_HALF), "{MAP_NAME}", mapName, true);
		ReplaceString(DISCORD_MSG_HALF, sizeof(DISCORD_MSG_HALF), "{RESULT}", halfTime, true);

		if(!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete))
					|| !SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", DISCORD_MSG_HALF, strlen(DISCORD_MSG_HALF))
					|| !SteamWorks_SendHTTPRequest(hRequest))
		{
			delete hRequest;
		}
	}
}

public getTs() {
	char playerName[512];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) { // T
			GetClientName(i, playerName, sizeof(playerName));

			if (StrEqual(T_PLAYERS, "")) {
				Format(T_PLAYERS, sizeof(T_PLAYERS), "%s", playerName);
			} else if (i != 1 && i != MaxClients) {
				Format(T_PLAYERS, sizeof(T_PLAYERS), "%s, %s, ", T_PLAYERS, playerName);
			} else if (i != 1 && i == MaxClients) {
				Format(T_PLAYERS, sizeof(T_PLAYERS), "%s%s", T_PLAYERS, playerName);
			}
		}
	}
}

public getTsStats() {
	char playerName[512];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) { // T
			GetClientName(i, playerName, sizeof(playerName));

			new Deaths = GetClientDeaths(i);
			new Frags = GetClientFrags(i);
			new Float:KDRate = float(Frags)/float(Deaths);

			if (StrEqual(T_STATS, "")) {
				Format(T_STATS, sizeof(T_STATS), "%s: K: %d / D: %d - %f", playerName, Frags, Deaths, KDRate);
			} else if (i != 1 && i != MaxClients) {
				Format(T_STATS, sizeof(T_STATS), "%s, %s: K: %d / D: %d - %f, ", T_STATS, playerName, Frags, Deaths, KDRate);
			} else if (i != 1 && i == MaxClients) {
				Format(T_STATS, sizeof(T_STATS), "%s%s: K: %d / D: %d - %f", T_STATS, playerName, Frags, Deaths, KDRate);
			}
		}
	}
}

public getCTs() {
	char playerName[512];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_CT) { // CT
			GetClientName(i, playerName, sizeof(playerName));

			if (StrEqual(CT_PLAYERS, "")) {
				Format(CT_PLAYERS, sizeof(CT_PLAYERS), "%s", playerName);
			} else if (i != 1 && i != MaxClients) {
				Format(CT_PLAYERS, sizeof(CT_PLAYERS), "%s, %s, ", T_PLAYERS, playerName);
			} else if (i != 1 && i == MaxClients) {
				Format(CT_PLAYERS, sizeof(CT_PLAYERS), "%s%s", T_PLAYERS, playerName);
			}
		}
	}
}

public getCTsStats() {
	char playerName[512];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_CT) { // CT
			GetClientName(i, playerName, sizeof(playerName));

			new Deaths = GetClientDeaths(i);
			new Frags = GetClientFrags(i);
			new Float:KDRate = float(Frags)/float(Deaths);

			if (StrEqual(CT_STATS, "")) {
				Format(CT_STATS, sizeof(CT_STATS), "%s: K: %d / D: %d - %f", playerName, Frags, Deaths, KDRate);
			} else if (i != 1 && i != MaxClients) {
				Format(CT_STATS, sizeof(CT_STATS), "%s, %s: K: %d / D: %d - %f, ", CT_STATS, playerName, Frags, Deaths, KDRate);
			} else if (i != 1 && i == MaxClients) {
				Format(CT_STATS, sizeof(CT_STATS), "%s%s: K: %d / D: %d - %f", CT_STATS, playerName, Frags, Deaths, KDRate);
			}
		}
	}
}

public int OnRequestComplete(Handle hRequest, bool bFailed, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	// This should not happen!
	if(bFailed || !bRequestSuccessful)
	{
		LogError("[OnRequestComplete] Request to %s not successful.", DISCORD_WEBHOOK);
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, Print_Response);
	}
	else if (bRequestSuccessful)
	{
		LogMessage("[OnRequestComplete] Request to %s successful", DISCORD_WEBHOOK);
	}
	// Unknown error
	else
	{
		LogError("[OnRequestComplete] Error Code: [%d]", eStatusCode);
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, Print_Response);
	}

	delete hRequest;
}

public Print_Response(const char[] sData)
{
    PrintToServer("[Print_Response] %s", sData);
}
