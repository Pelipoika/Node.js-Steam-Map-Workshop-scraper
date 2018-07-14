#include <SteamWorks>
#include <sdktools>

bool g_bCanChangeMap = true;
int g_iSelectPos[MAXPLAYERS+1];
char g_strSelectGamemode[MAXPLAYERS+1][32];

ArrayList g_hMaps;
Menu g_hGamemodeMenu;

public Plugin myinfo = 
{
	name = "[TF2] Map Workshop Votes",
	author = "Pelipoika",
	description = "Downloads WorkshopMapData",
	version = "1.0",
	url = ""
};

//TODO Add NEW to new maps

public void OnPluginStart()
{
	g_hMaps = CreateArray(64);

	RegAdminCmd("sm_showmaps", Command_ShowMaps, ADMFLAG_BAN);
	RegAdminCmd("sm_installmap", Command_ManualMap, ADMFLAG_BAN);
}
 
public void OnMapStart() 
{
	Workshop_GetMaps();
	
	g_bCanChangeMap = true;
}

stock void Workshop_GetMaps()
{
	Handle hDLPack = CreateDataPack();
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, "https://workshopscraper.herokuapp.com/");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 10);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksHTTPComplete);
	SteamWorks_SetHTTPRequestContextValue(hRequest, hDLPack);
	SteamWorks_SendHTTPRequest(hRequest);
}

public OnSteamWorksHTTPComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any hDLPack)
{
	ResetPack(hDLPack);
	CloseHandle(hDLPack);
	
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		SteamWorks_WriteHTTPResponseBodyToFile(hRequest, "WorkshopData.txt");
		ParseMaps();
	}
	else
	{
		char sError[256];
		FormatEx(sError, sizeof(sError), "SteamWorks error (status code %i). Request successful: %s", _:eStatusCode, bRequestSuccessful ? "True" : "False");
	}
	
	CloseHandle(hRequest);
}

public Action Command_ManualMap(int client, int argc)
{
	char strID[64];
	GetCmdArgString(strID, sizeof(strID));
	
	Workshop_DownloadAndChangeMap(StringToInt(strID));
	PrintToChatAll("[WorkshopMaps] Preparing manually added map %s", strID);
}

public Action Command_ShowMaps(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(g_hGamemodeMenu != null)
		{
			g_hGamemodeMenu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			ReplyToCommand(client, "[WorkshopMaps] Menu is invalid??");
		}
	}

	return Plugin_Handled;
}

stock void DisplayMapMenu(int client, const char[] gamemode, int page = 0)
{
	Menu manu = new Menu(Menu_Maps);
	manu.SetTitle("%s maps\n ", gamemode);
	
	for(int i = 0; i < g_hMaps.Length; i += 7)
	{
		char strGameMode[32]; 
		g_hMaps.GetString(i + 4, strGameMode, sizeof(strGameMode));

		bool bIgnoreGameMode = (StrEqual(gamemode, "NEW") || StrEqual(gamemode, "UPDATED"));

		if(StrEqual(gamemode, strGameMode) || StrEqual(gamemode, "") || bIgnoreGameMode)
		{
			char display[526], rating[18];
			char strID[32], strRating[32], strMaker[32], strMapname[256], strTimeCreated[32], strTimeUpdated[32];
			
			g_hMaps.GetString(i, 	 strID,	         sizeof(strID));
			g_hMaps.GetString(i + 1, strRating,      sizeof(strRating));
			g_hMaps.GetString(i + 2, strMaker,	     sizeof(strMaker));
			g_hMaps.GetString(i + 3, strMapname,     sizeof(strMapname));
			g_hMaps.GetString(i + 4, strGameMode,    sizeof(strGameMode));
			g_hMaps.GetString(i + 5, strTimeCreated, sizeof(strTimeCreated));
			g_hMaps.GetString(i + 6, strTimeUpdated, sizeof(strTimeUpdated));
			
			int time_created = StringToInt(strTimeCreated);
			int time_updated = StringToInt(strTimeUpdated);
			
			//Thanks n0name.
			
			//Maps under 30 days old are considered new.
			bool bNew = (GetTime() - time_created < 86400 * 30);
			
			//Updated if map last updated a week ago.
			bool bRecentlyUpdated = (GetTime() - time_updated < (86400 * 7));
			
			if(bNew) {
				Format(strMapname, sizeof(strMapname), "%s (NEW!)", strMapname);
			}
			
			if(bRecentlyUpdated) {
				Format(strMapname, sizeof(strMapname), "%s (UPDATED!)", strMapname);
			}
			
			switch(StringToInt(strRating))
			{
				case 0: Format(rating, sizeof(rating), "☆☆☆☆☆");
				case 1: Format(rating, sizeof(rating), "★☆☆☆☆");
				case 2: Format(rating, sizeof(rating), "★★☆☆☆");
				case 3: Format(rating, sizeof(rating), "★★★☆☆");
				case 4: Format(rating, sizeof(rating), "★★★★☆");
				case 5: Format(rating, sizeof(rating), "★★★★★");
			}
			
			Format(display, sizeof(display), "%s\nBy: %s\n%s", strMapname, strMaker, rating);
			
			if(StrEqual(gamemode, "NEW") && !bNew)
				continue;
				
			if(StrEqual(gamemode, "UPDATED") && !bRecentlyUpdated)
				continue;
				
			manu.AddItem(strID, display);
		}
	}
	
	manu.ExitBackButton = true;
	manu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMapInfoMenu(int client, char[] strID, char[] strRating, char[] strMaker, char[] strMapname, char[] strGamemode)
{
	char display[526], rating[18];
	
	switch(StringToInt(strRating))
	{
		case 0: Format(rating, sizeof(rating), "☆☆☆☆☆");
		case 1: Format(rating, sizeof(rating), "★☆☆☆☆");
		case 2: Format(rating, sizeof(rating), "★★☆☆☆");
		case 3: Format(rating, sizeof(rating), "★★★☆☆");
		case 4: Format(rating, sizeof(rating), "★★★★☆");
		case 5: Format(rating, sizeof(rating), "★★★★★");
	}
	
	Menu menu = CreateMenu(Menu_MapDo);
	Format(display, sizeof(display), "WorkshopMaps\n \nMap: %s\nGamemode: %s\nBy: %s\n%s\n ", strMapname, strGamemode, strMaker, rating);
	menu.SetTitle(display);
	menu.AddItem(strID, "Open Workshop page");
	Format(display, sizeof(display), "Change level to: %s", strMapname);
	menu.AddItem(strID, display);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuGamemodeHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char strGamemode[32];
		GetMenuItem(menu, param2, strGamemode, sizeof(strGamemode));
		
		//if(StrEqual(strGamemode, "NEW"))
			//
		
		
		DisplayMapMenu(param1, strGamemode);
	}
}

public int Menu_Maps(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_bCanChangeMap)
		{
			char strID[64], strRating[64], strMaker[64], strGamemode[64], strMapname[256]; 
			GetMenuItem(menu, param2, strID, sizeof(strID));
			
			FindRating(strID, strRating, sizeof(strRating));
			FindMaker(strID, strMaker, sizeof(strMaker));
			FindMapname(strID, strMapname, sizeof(strMapname));
			FindGamemode(strID, strGamemode, sizeof(strGamemode));

			g_iSelectPos[param1] = GetMenuSelectionPosition();
			
			Format(g_strSelectGamemode[param1], 32, "%s", strGamemode);
			
			DisplayMapInfoMenu(param1, strID, strRating, strMaker, strMapname, strGamemode);
		}
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		g_hGamemodeMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_MapDo(Handle menu, MenuAction action, int param1, int param2)
{
	char strID[32], strRating[32], strMaker[32], strGamemode[32], strMapname[256]; 

	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, strID, sizeof(strID));
		
		FindRating(strID, strRating, sizeof(strRating));
		FindMaker(strID, strMaker, sizeof(strMaker));
		FindMapname(strID, strMapname, sizeof(strMapname));
		FindGamemode(strID, strGamemode, sizeof(strGamemode));
	
		switch(param2)
		{
			case 0:
			{
				char url[256];
				Format(url, 255, "http://steamcommunity.com/sharedfiles/filedetails/?id=%s", strID);
				
				KeyValues kv = CreateKeyValues("motd");
				kv.SetString("title", "Profile");
				kv.SetNum("type", MOTDPANEL_TYPE_URL);
				kv.SetString("msg", url);
				kv.SetNum("customsvr", 1);
		
				ShowVGUIPanel(param1, "info", kv);
				delete kv;
			}
			case 1:
			{
				Workshop_DownloadAndChangeMap(StringToInt(strID));
				PrintToChatAll("[WorkshopMaps] Preparing map %s rated %s stars by %s", strMapname, strRating, strMaker);
			}
		}

		DisplayMapInfoMenu(param1, strID, strRating, strMaker, strMapname, strGamemode);
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayMapMenu(param1, g_strSelectGamemode[param1], g_iSelectPos[param1]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

stock void Workshop_DownloadAndChangeMap(int iWorkshopID)
{
	ServerCommand("tf_workshop_map_sync %i", iWorkshopID);
	
	CreateTimer(2.0, Timer_CheckDownload, iWorkshopID, TIMER_FLAG_NO_MAPCHANGE);

	g_bCanChangeMap = false;
}

public Action Timer_CheckDownload(Handle timer, any data)
{
	char strStatus[4098];
	ServerCommandEx(strStatus, sizeof(strStatus), "tf_workshop_map_status");

	if(StrContains(strStatus, "downloading") != -1 || StrContains(strStatus, "refreshing") != -1)
	{
		CreateTimer(1.0, Timer_CheckDownload, data, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChatAll("[WorkshopMaps] Download Finished, Changing map...");
		CreateTimer(3.0, Timer_ChangeMap, data, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ChangeMap(Handle timer, any data)
{
	char map[PLATFORM_MAX_PATH];
	Format(map, PLATFORM_MAX_PATH, "workshop/%i", data);
	ForceChangeLevel(map, "[WorkshopMaps] Map change");
}

stock bool FindRating(char[] id, char[] rating, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 1, rating, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindMaker(char[] id, char[] maker, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 2, maker, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindMapname(char[] id, char[] mapname, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 3, mapname, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindGamemode(char[] id, char[] gamemode, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 4, gamemode, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindTimeCreated(char[] id, char[] time_created, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 5, time_created, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindTimeUpdated(char[] id, char[] time_updated, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 6, time_updated, maxlength);
		
		return true;
	}

	return false;
}

stock void ParseMaps()
{
	g_hMaps.Clear();

	KeyValues kvConfig = new KeyValues("WorkshopData");
	
	if (!FileToKeyValues(kvConfig, "WorkshopData.txt")) 
		SetFailState("Error while parsing the workshop file.");
		
	kvConfig.SetEscapeSequences(true);
	kvConfig.GotoFirstSubKey(true);
	
	int iCount = 0, iBadCount = 0, iUpdated = 0, iNew = 0;
	
	ArrayList hGameModes = new ArrayList(64);
	
	do
	{
		char strID[32], strRating[32], strMaker[32], strMapname[256], strGameMode[32], strTimeCreated[32], strTimeUpdated[32]; 
		kvConfig.GetString("id",		    strID, 		    sizeof(strID));          //0
		kvConfig.GetString("rating",	    strRating,    	sizeof(strRating));      //1
		kvConfig.GetString("maker",		    strMaker,    	sizeof(strMaker));       //2
		kvConfig.GetString("mapname",	    strMapname,    	sizeof(strMapname));     //3
		kvConfig.GetString("gamemode",	    strGameMode,    sizeof(strGameMode));    //4
		kvConfig.GetString("time_created",	strTimeCreated, sizeof(strTimeCreated)); //5
		kvConfig.GetString("time_updated",  strTimeUpdated, sizeof(strTimeUpdated)); //6
		
		if(!StrEqual(strRating, "0"))
		{
			g_hMaps.PushString(strID);
			g_hMaps.PushString(strRating);
			g_hMaps.PushString(strMaker);
			g_hMaps.PushString(strMapname);
			g_hMaps.PushString(strGameMode);
			g_hMaps.PushString(strTimeCreated);
			g_hMaps.PushString(strTimeUpdated);
			
			int i = hGameModes.FindString(strGameMode);
			if(i == -1){
				hGameModes.PushString(strGameMode);
			}
			
			int time_created = StringToInt(strTimeCreated);
			int time_updated = StringToInt(strTimeUpdated);
			
			//Maps under 30 days old are considered new.
			bool bNew = (GetTime() - time_created < 86400 * 30);
			if(bNew)
				iNew++;
				
			//Updated if map last updated a week ago.
			bool bRecentlyUpdated = (GetTime() - time_updated < (86400 * 7));
			if(bRecentlyUpdated)
				iUpdated++;
			
			iCount++;
		}
		else
			iBadCount++;
	}
	while (KvGotoNextKey(kvConfig));
	
	
	g_hGamemodeMenu = CreateMenu(MenuGamemodeHandler);
	g_hGamemodeMenu.SetTitle("[WorkshopMaps] Select Gamemode\n ");
	
	
	g_hGamemodeMenu.AddItem("NEW", " - NEW maps", (iNew > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	g_hGamemodeMenu.AddItem("UPDATED", " - Recently updated maps\n ", (iUpdated > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	
	
	for (int i = 0; i < hGameModes.Length; i++)
	{
		char string[64];
		hGameModes.GetString(i, string, sizeof(string));
		
		if(StrEqual(string, "PL", false))         g_hGamemodeMenu.AddItem("PL", "Payload");
		if(StrEqual(string, "PLR", false))        g_hGamemodeMenu.AddItem("PLR", "Payload Race");
		if(StrEqual(string, "CP", false))         g_hGamemodeMenu.AddItem("CP", "Control Point");
		if(StrEqual(string, "AD", false))         g_hGamemodeMenu.AddItem("AD", "Attack/Defence");
		if(StrEqual(string, "CTF", false))        g_hGamemodeMenu.AddItem("CTF", "Capture the Flag");
		if(StrEqual(string, "ARENA", false))      g_hGamemodeMenu.AddItem("ARENA", "Arena");
		if(StrEqual(string, "KOTH", false))       g_hGamemodeMenu.AddItem("KOTH", "King of the Hill");
		if(StrEqual(string, "SD", false))         g_hGamemodeMenu.AddItem("SD", "Special Delivery");
		if(StrEqual(string, "MEDIEVAL", false))   g_hGamemodeMenu.AddItem("MEDIEVAL", "Medieval");
		if(StrEqual(string, "SPECIALITY", false)) g_hGamemodeMenu.AddItem("SPECIALITY", "Speciality");
		if(StrEqual(string, "PASS", false))       g_hGamemodeMenu.AddItem("PASS", "Pass Time");
		if(StrEqual(string, "MANNPOWER", false))  g_hGamemodeMenu.AddItem("MANNPOWER", "Mannpower");
		if(StrEqual(string, "MVM", false))        g_hGamemodeMenu.AddItem("MVM", "Mann vs. Machine");
		if(StrEqual(string, "RD", false))         g_hGamemodeMenu.AddItem("RD", "Robot Destruction");
	}
	
	g_hGamemodeMenu.ExitButton = true;
	
	PrintToServer("[WorkshopData] Got %i good maps (%i newly added, %i recently updated), left out %i bad maps", iCount, iNew, iUpdated, iBadCount);
	
	delete hGameModes;
	delete kvConfig;
}