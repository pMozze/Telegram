#include <ripext>

char g_szToken[256], g_szChatID[256];
ConVar g_cvToken = null, g_cvChatID = null;
bool g_bIsHookSay[MAXPLAYERS + 1];
int g_iSuspect[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "TGReport",
	author = "Mozze",
	description = "",
	version = "1.0",
	url = "t.me/pMozze"
}

public void OnPluginStart() {
	g_cvToken = CreateConVar("sm_tgreport_token", "");
	g_cvChatID = CreateConVar("sm_tgreport_chatid", "");

	LoadTranslations("tgreport.phrases");
	AutoExecConfig(true, "TGReport");

	RegConsoleCmd("sm_report", onCommandPerform);
	AddCommandListener(onPlayerSay, "say");
}

public void OnConfigsExecuted() {
	g_cvToken.GetString(g_szToken, sizeof(g_szToken));
	g_cvChatID.GetString(g_szChatID, sizeof(g_szChatID));
}

public void OnClientConnected(int Client) {
	g_bIsHookSay[Client] = false;
	g_iSuspect[Client] = 0;
}

public Action onCommandPerform(int Client, int Args) {
	Menu hMenu = CreateMenu(menuHandler);
	hMenu.SetTitle("%t", "Menu title");
	addClientsToMenu(hMenu, Client);
	hMenu.Display(Client, 0);
}

public Action onPlayerSay(int Client, const char[] Command, int Args) {
	if (!g_bIsHookSay[Client])
		return Plugin_Continue;

	char Comment[256], reportMessage[1024];
	GetCmdArgString(Comment, sizeof(Comment));
	StripQuotes(Comment);
	TrimString(Comment);

	createReportMessage(reportMessage, sizeof(reportMessage), Client, g_iSuspect[Client], Comment);
	sendTGMessage(reportMessage, Client);
	CancelClientMenu(Client, true, null);

	g_bIsHookSay[Client] = false;
	g_iSuspect[Client] = 0;

	return Plugin_Handled;
}

public int menuHandler(Menu hMenu, MenuAction iAction, int Client, int Item) {
	if (iAction == MenuAction_Select) {
		char itemBuffer[4];
		int clientItem;

		hMenu.GetItem(Item, itemBuffer, sizeof(itemBuffer));
		clientItem = StringToInt(itemBuffer);

		if (IsClientInGame(clientItem)) {
			char Buffer[1024];
			Panel hPanel = CreatePanel(null);
			
			Format(Buffer, sizeof(Buffer), "%t", "Panel text");
			hPanel.DrawText(Buffer);
			
			Format(Buffer, sizeof(Buffer), "%t", "Panel cancel");
			hPanel.DrawItem(Buffer);
			
			hPanel.Send(Client, panelHandler, 0);

			g_bIsHookSay[Client] = true;
			g_iSuspect[Client] = clientItem;
		}
	}

	if (iAction == MenuAction_End)
		delete hMenu;
}

public int panelHandler(Menu hPanel, MenuAction iAction, int Client, int Item) {
	if (iAction == MenuAction_Select)
		g_bIsHookSay[Client] = false;

	if (iAction == MenuAction_End)
		delete hPanel;
}

public void createReportMessage(char[] reportMessage, int maxLength, int Client, int Suspect, const char[] Comment) {
	char Date[64], Time[64], authID1[32], authID2[32];

	FormatTime(Date, sizeof(Date), "%d/%m/%Y");
	FormatTime(Time, sizeof(Time), "%H:%M:%S");

	GetClientAuthId(Client, AuthId_Steam2, authID1, sizeof(authID1));
	GetClientAuthId(Suspect, AuthId_Steam2, authID2, sizeof(authID2));

	Format(reportMessage, maxLength, "<b>Жалоба от:</b> %N (%s)\n<b>Нарушитель:</b> %N (%s)\n<b>Дата:</b> %s\n<b>Время:</b> %s\n<b>Комментарий:</b> %s", Client, authID1, Suspect, authID2, Date, Time, Comment);
}

public void sendTGMessage(const char[] Message, any Data) {
	char URL[512];
	Format(URL, sizeof(URL), "https://api.telegram.org/bot%s", g_szToken);

	JSONObject hRequest = new JSONObject();
	HTTPClient httpClient = new HTTPClient(URL);
	
	hRequest.SetString("chat_id", g_szChatID);
	hRequest.SetString("text", Message);
	hRequest.SetString("parse_mode", "HTML");

	httpClient.Post("sendMessage", hRequest, onResponse, Data);
	delete hRequest;
}

public void onResponse(HTTPResponse Response, any Value) {
	if (Response.Status != HTTPStatus_OK) {
    	PrintToChat(Value, "%t%t", "Prefix", "Request failed");
        return;
    }

	PrintToChat(Value, "%t%t", "Prefix", "Request success");
}

public void addClientsToMenu(Menu hMenu, int Client) {
	for (int Index = 1; Index < MaxClients; Index++) {
		if (IsClientInGame(Index) && !GetUserFlagBits(Index) && Index != Client) {
			char clientID[4];
			char Item[MAX_NAME_LENGTH];

			IntToString(Index, clientID, sizeof(clientID));
			Format(Item, sizeof(Item), "%N", Index);

			hMenu.AddItem(clientID, Item);
		}
	}
}