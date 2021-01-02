#include <ripext>
#include <materialadmin>

enum struct Complaint {
	bool m_bIsSayHooked;
	int m_iSuspect;

	void Set(bool bIsSayHooked, int iSuspect) {
		this.m_bIsSayHooked = bIsSayHooked;
		this.m_iSuspect = iSuspect;
	}

	void Clear() {
		this.m_bIsSayHooked = false;
		this.m_iSuspect = -1;
	}
}

enum struct TelegramSettings {
	char m_szToken[256];
	char m_szChatID[256];
}

ConVar g_cvToken, g_cvChatID;
TelegramSettings g_TelegramSettings;
Complaint g_Complaints[66];

public Plugin myinfo = {
	name = "Telegram",
	author = "Mozze",
	description = "",
	version = "1.1",
	url = "t.me/pMozze"
}

public void OnPluginStart() {
	g_cvToken = CreateConVar("sm_telegram_token", "");
	g_cvChatID = CreateConVar("sm_telegram_chatid", "");

	g_cvToken.AddChangeHook(onTokenConVarChanged);
	g_cvChatID.AddChangeHook(onChatIDConVarChanged);

	LoadTranslations("telegram.phrases");
	AutoExecConfig(true, "Telegram");

	RegConsoleCmd("sm_report", reportCommand);
	RegConsoleCmd("sm_voteban", reportCommand);

	AddCommandListener(onPlayerSay, "say");
	AddCommandListener(onPlayerSay, "say_team");
}

public void OnConfigsExecuted() {
	g_cvToken.GetString(g_TelegramSettings.m_szToken, sizeof(g_TelegramSettings.m_szToken));
	g_cvChatID.GetString(g_TelegramSettings.m_szChatID, sizeof(g_TelegramSettings.m_szChatID));
}

public void onTokenConVarChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue) {
	hConVar.GetString(g_TelegramSettings.m_szToken, sizeof(g_TelegramSettings.m_szToken));
}

public void onChatIDConVarChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue) {
	hConVar.GetString(g_TelegramSettings.m_szChatID, sizeof(g_TelegramSettings.m_szChatID));
}

public void OnClientConnected(int iClient) {
	g_Complaints[iClient].Clear();
}

public void MAOnClientMuted(int iClient, int iTarget, char[] szIP, char[] szSteamID, char[] szName, int iType, int iTime, char[] szReason) {
	char szMessage[512], szAdminAuthID[32], szTargetAuthID[32], szExpires[64], szType[64];
	
	GetClientAuthId(iClient, 1, szAdminAuthID, sizeof(szAdminAuthID), true);
	GetClientAuthId(iTarget, 1, szTargetAuthID, sizeof(szTargetAuthID), true);

	if (iTime) {
		FormatTime(szExpires, sizeof(szExpires), "%d/%m/%Y %H:%M:%S", GetTime() + iTime * 60);
	} else {
		strcopy(szExpires, sizeof(szExpires), "Никогда");
	}

	switch (iType) {
		case 1: {
			strcopy(szType, sizeof(szType), "Голосовой");
		}

		case 2: {
			strcopy(szType, sizeof(szType), "Текстовый");
		}

		case 3: {
			strcopy(szType, sizeof(szType), "Весь");
		}
	}
	
	Format(szMessage, sizeof(szMessage), "<b>Администратор:</b> %N (%s)\n<b>Отключит чат:</b> %s (%s)\n<b>Тип:</b> %s\n<b>Дата разблокировки:</b> %s", iClient, szAdminAuthID, szName, szTargetAuthID, szType, szExpires);
	sendTelegramMessage(szMessage);
}

public void MAOnClientBanned(int iClient, int iTarget, char[] szIP, char[] szSteamID, char[] szName, int iTime, char[] szReason) {
	char szMessage[512], szAdminAuthID[32], szTargetAuthID[32], szExpires[64];

	GetClientAuthId(iClient, 1, szAdminAuthID, sizeof(szAdminAuthID), true);
	GetClientAuthId(iTarget, 1, szTargetAuthID, sizeof(szTargetAuthID), true);

	if (iTime) {
		FormatTime(szExpires, sizeof(szExpires), "%d/%m/%Y %H:%M:%S", GetTime() + iTime * 60);
	} else {
		strcopy(szExpires, sizeof(szExpires), "Никогда");
	}

	Format(szMessage, sizeof(szMessage), "<b>Администратор:</b> %N (%s)\n<b>Заблокировал:</b> %s (%s)\n<b>Причина:</b> %s\n<b>Дата разблокировки:</b> %s", iClient, szAdminAuthID, szName, szTargetAuthID, szReason, szExpires);
	sendTelegramMessage(szMessage);
}

public Action reportCommand(int iClient, int iArgs) {
	Menu hMenu = CreateMenu(menuHandler);
	hMenu.SetTitle("%t", "Menu title");
	addClientsToMenu(hMenu, iClient);
	hMenu.Display(iClient, 0);
}

public Action onPlayerSay(int iClient, const char[] szCommand, int iArgs) {
	if (!IsClientInGame(iClient) || !g_Complaints[iClient].m_bIsSayHooked)
		return Plugin_Continue;

	char szComment[256], szReportMessage[1024];
	GetCmdArgString(szComment, sizeof(szComment));
	StripQuotes(szComment);
	TrimString(szComment);

	createReportMessage(szReportMessage, sizeof(szReportMessage), iClient, g_Complaints[iClient].m_iSuspect, szComment);
	sendTelegramMessage(szReportMessage);
	CancelClientMenu(iClient, true, null);

	PrintToChat(iClient, "%t%t", "Prefix", "Complaint sent");
	g_Complaints[iClient].Clear();
	return Plugin_Handled;
}

public int menuHandler(Menu hMenu, MenuAction iAction, int iClient, int iItem) {
	switch (iAction) {
		case MenuAction_Select: {
			char szItemInfo[4];
			int iItemClient;

			hMenu.GetItem(iItem, szItemInfo, sizeof(szItemInfo));
			iItemClient = StringToInt(szItemInfo);

			if (IsClientInGame(iItemClient)) {
				char szBuffer[1024];
				Panel hPanel = CreatePanel(null);
				
				Format(szBuffer, sizeof(szBuffer), "%t", "Panel text");
				hPanel.DrawText(szBuffer);
				
				Format(szBuffer, sizeof(szBuffer), "%t", "Panel cancel");
				hPanel.DrawItem(szBuffer);
				
				hPanel.Send(iClient, panelHandler, 0);
				g_Complaints[iClient].Set(true, iItemClient);
			}
		}

		case MenuAction_End: {
			delete hMenu;
		}
	}
}

public int panelHandler(Menu hPanel, MenuAction iAction, int iClient, int iItem) {
	switch (iAction) {
		case MenuAction_Select: {
			g_Complaints[iClient].Clear();
		}

		case MenuAction_End: {
			delete hPanel;
		}
	}
}

public void createReportMessage(char[] szReportMessage, int iMaxLength, int iClient, int iSuspect, const char[] szComment) {
	char szDate[64], szTime[64], szClientAuthID[32], szSuspectAuthID[32];

	FormatTime(szDate, sizeof(szDate), "%d/%m/%Y");
	FormatTime(szTime, sizeof(szTime), "%H:%M:%S");

	GetClientAuthId(iClient, 1, szClientAuthID, sizeof(szClientAuthID), true);
	GetClientAuthId(iSuspect, 1, szSuspectAuthID, sizeof(szSuspectAuthID), true);

	Format(szReportMessage, iMaxLength, "<b>Жалоба от:</b> %N (%s)\n<b>Нарушитель:</b> %N (%s)\n<b>Дата:</b> %s\n<b>Время:</b> %s\n<b>Комментарий:</b> %s", iClient, szClientAuthID, iSuspect, szSuspectAuthID, szDate, szTime, szComment);
}

public void sendTelegramMessage(const char[] szMessage) {
	char szURL[512];
	Format(szURL, sizeof(szURL), "https://api.telegram.org/bot%s", g_TelegramSettings.m_szToken);

	JSONObject hRequest = new JSONObject();
	HTTPClient hHTTPClient = new HTTPClient(szURL);
	
	hRequest.SetString("chat_id", g_TelegramSettings.m_szChatID);
	hRequest.SetString("text", szMessage);
	hRequest.SetString("parse_mode", "HTML");

	hHTTPClient.Post("sendMessage", hRequest, onResponse);
	delete hRequest;
}

public void onResponse(HTTPResponse hResponse, any value, const char[] szError) {
	if (hResponse.Status != HTTPStatus_OK)
		PrintToServer("[Telegram] > Request failed. Status code: %d", hResponse.Status);
}

public void addClientsToMenu(Menu hMenu, int iClient) {
	for (int index = 1; index < MaxClients; index++) {
		if (IsClientInGame(index) && !GetUserFlagBits(index) && index != iClient) {
			char szClientID[4], szItem[128];
			IntToString(index, szClientID, sizeof(szClientID));
			Format(szItem, sizeof(szItem), "%N", index);
			hMenu.AddItem(szClientID, szItem);
		}
	}
}
