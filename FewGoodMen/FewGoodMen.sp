#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

//new Handle:sm_myslap_damage = INVALID_HANDLE;

// Global Definitions;
#define PLUGIN_VERSION "0.3.0"

#define TEAM_UNASSIGNED 0
#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLUE 3

#define MIN_PLAYERS_FOR_DUAL_CHANGE 8

#define CONVAR_COUNT 4

#define CHAT_HEADER "\x04[FewGoodMen] \x03"

//Global variables
new _playerKills[MAXPLAYERS + 1];
new _playerTeams[MAXPLAYERS + 1];
new _teamWins[4];
new bool:_isShouldBalance;
new _winningTeam;
//new _switchingPlayer;

//CVars
new Handle:_conVars[CONVAR_COUNT] = {INVALID_HANDLE, ...};
new bool:_enabled;
new _roundsDif;
new bool:_forceTeams;
new bool:_keepGoing;

// Functions;
public Plugin:myinfo =
{
	name = "Few Good Men",
	author = "yellowblood",
	description = "Moves a player from the winning team to the losing team when a round ends. Targeted for dodgeball mode.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{

	_conVars[0] = CreateConVar("sm_fgm_enabled", "1", "Enable the Few Good Men plugin", FCVAR_NONE);
	_conVars[1] = CreateConVar("sm_fgm_rounds", "2", "Number of round wins in a row to cause balance", FCVAR_NONE, true, 1.0, true, 20.0);
	_conVars[2] = CreateConVar("sm_fgm_forceteams", "1", "Set to 0 to allow players to join the winning team", FCVAR_NONE);
	_conVars[3] = CreateConVar("sm_fgm_keepgoing", "1", "If set to 1 the winning team will lose a player at the end of each round after the first sm_fgm_rounds won", FCVAR_NONE);

	_enabled = true;
	_roundsDif = 2;
	_forceTeams = true;
	_keepGoing = true;

	HookConVarChange(_conVars[0], Event_ConVar_Enabled);
	HookConVarChange(_conVars[1], Event_ConVar_Rounds);
	HookConVarChange(_conVars[2], Event_ConVar_ForceTeams);
	HookConVarChange(_conVars[3], Event_ConVar_KeepGoing);


	HookEvent("player_team", Event_TeamChanged);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("arena_win_panel", Event_arena_win_panel);
	HookEvent("teamplay_round_start", Event_RoundStart);

	AutoExecConfig(true, "fewgoodmen");
}

public Event_ConVar_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new val = StringToInt(newValue);
	if (val != 0)
	{		
		val = 1;
		SetConVarInt(convar, val);
		Enable();
	}

	_enabled = bool:val;
}

public Event_ConVar_Rounds(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new val = StringToInt(newValue);
	if ( val < 1 || val > 20)
	{
		val = 2;
		SetConVarInt(convar, val);
	}

	_roundsDif = val;
}

public Event_ConVar_ForceTeams(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new val = StringToInt(newValue);
	if (val != 0)
	{
		val = 1;
		SetConVarInt(convar, val);
	}

	_forceTeams = bool:val;
}

public Event_ConVar_KeepGoing(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new val = StringToInt(newValue);
	if (val != 0)
	{
		val = 1;
		SetConVarInt(convar, val);
	}

	_keepGoing = bool:val;
}

public OnMapStart()
{
	if (_enabled) Enable();
}

public Enable()
{
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_teams_unbalance_limit 0");
	
	_isShouldBalance = false;
	_winningTeam = 0;
	_teamWins[TEAM_RED] = 0;
	_teamWins[TEAM_BLUE] = 0;

	for (new i = 0; i < sizeof(_playerKills) ; i++)
	{
		_playerKills[i] = 0;
		_playerTeams[i] = 0;
	}
}


public OnClientDisconnect(client)
{
	HandleDisconnect(client);
}

public OnClientDisconnect_Post(client)
{
	HandleDisconnect(client);
}

public OnClientPutInServer(client)
{
	_playerKills[client] = 0;
	_playerTeams[client] = 0;
}

public Action:Event_arena_win_panel(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!_enabled) return Plugin_Continue;

	new winner = GetEventInt(event, "winning_team");

	if (winner <= 1)
		return Plugin_Continue;

				
	new loser = GetOtherTeam(winner);

	_teamWins[loser] = 0;
	_teamWins[winner]++;

	if (_teamWins[winner] >= _roundsDif)
	{		
		if (!_keepGoing)
			_teamWins[winner] = 0;
		
		//new teamName[3] = 
		
		PrintToChatAll("\x04[FewGoodMen] \x03Team %s has %d straight wins!", winner == TEAM_RED ? "RED" : "BLUE", _teamWins[winner]);
		
		_isShouldBalance = true;
		_winningTeam = winner;
	}
	/*else 
	{
		PrintToChatAll("\x04[FewGoodMen] \x03The difference is lower than %d, players will not be moved.", _roundsDif);
	}*/

	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!_enabled || !_isShouldBalance) return Plugin_Continue;

	new count = GetTeamClientCount(_winningTeam);
	//PrintToChatAll("Team %d has %d Players", _winningTeam, count);
	if (count <= 1)
		return Plugin_Continue;
	
	if (count < MIN_PLAYERS_FOR_DUAL_CHANGE) 
	{
		PrintToChatAll("\x04[FewGoodMen] \x03Moving a player to the losing team.");
		ChangeNoobTeam()			;
	}		
	else 
	{
		PrintToChatAll("\x04[FewGoodMen] \x03Moving 2 players to the losing team.");
		ChangeNoobTeam();
		ChangeNoobTeam();
	}
			
	_isShouldBalance = false;


	return Plugin_Continue;
}

public ChangeNoobTeam() 
{
	new noob;

	for(new c = 1; c <= MaxClients; c++)
	{
		if (IsClientInGame(c) && GetClientTeam(c) == _winningTeam && ( noob == 0 || _playerKills[c] < _playerKills[noob]))
		{
			noob = c;
		}
	}

	//PrintToChatAll("noob is %d", noob);
	if (noob == 0) 
	{
		PrintToChatAll("\x04[FewGoodMen] \x03ERROR while trying to move a player to the losing team.");			
		return;
	}
	
	//PrintToChatAll("Chosen client is %d, moving to team %d", noob, GetOtherTeam(_winningTeam));
	
	PrintToChat(noob, "\x04[FewGoodMen] \x03You were moved to the other team for some balance.");		
	new losingTeam = GetOtherTeam(_winningTeam);
	_playerTeams[noob] = losingTeam;
	ChangeClientTeam(noob, losingTeam);
}

public Action:Event_TeamChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetEventInt(event, "team");

	//PrintToChatAll("Client %d changed from team %d to team %d", client, oldTeam, team);

	if (team != TEAM_RED && team != TEAM_BLUE) {
		return Plugin_Continue;
	}

	new teamCount = GetTeamClientCount(team);
//	new otherTeamCount = GetTeamClientCount(GetOtherTeam(team));		
	
	if ( 
			_enabled && _forceTeams && teamCount > 0
			&&
			( (team == _winningTeam && _playerTeams[client] != team)
			  || 
			  (_playerTeams[client] == GetOtherTeam(team))
//			  ||
//			  (_playerTeams[client] != TEAM_RED && playerTeams[client] != TEAM_BLUE && teamCount > otherTeamCount)
			)		
		)
	{

	    _playerTeams[client] = GetOtherTeam(team);
		CreateTimer(0.5, ForceClientTeam, client);
	}
	else {
	    _playerTeams[client] = team;
	}

	return Plugin_Continue;
}



public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToChatAll("enabled=%d rounds=%d force=%d", _enabled, _roundsDif, _forceTeams);

	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (killer && killer <= MaxClients && killer != victim)
	{
		_playerKills[killer]++;
		//PrintToChatAll("Killer %d has %d kills", killer, _playerKills[killer]);
	}

	return Plugin_Continue;
}

public Action:ForceClientTeam(Handle:timer, any:client)
{
	new team = GetClientTeam(client);
	new otherTeam = GetOtherTeam(team);

	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x04[FewGoodMen] \x03No, not this team.");
		ChangeClientTeam(client, otherTeam);
	}
}

public GetOtherTeam(team)
{
	return team == TEAM_RED ? TEAM_BLUE : TEAM_RED;
}

public HandleDisconnect(client)
{
	if (_enabled)
	{
		_playerKills[client] = 0;
		_playerTeams[client] = 0;

		new redCount = GetTeamClientCount(TEAM_RED);
		new blueCount = GetTeamClientCount(TEAM_BLUE);
		if ((redCount == 0 && blueCount > 1) || (blueCount == 0 && redCount > 1))
		{
			_winningTeam = redCount == 0 ? TEAM_BLUE : TEAM_RED;
			_isShouldBalance = true;
		}
	}
}
