namespace Core {
    // Do not keep handles to these objects around
    CNadeoServicesMap@ GetMapFromUid(const string &in mapUid) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto userId = app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr.Users[0].Id;
        auto resp = app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.Map_NadeoServices_GetFromUid(userId, mapUid);
        WaitAndClearTaskLater(resp, app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr);
        if (resp.HasFailed || !resp.HasSucceeded) {
            warn('GetMapFromUid failed: ' + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription);
            return null;
        }
        return resp.Map;
    }

    CWebServicesTaskResult_GetDisplayNameScriptResult@ WSIDsToNames(string[]@ wsids) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto userId = app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr.Users[0].Id;
        MwFastBuffer<wstring> wsidList;
        for (uint i = 0; i < wsids.Length; i++) {
            wsidList.Add(wsids[i]);
        }
        auto resp = app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr.RetrieveDisplayName(userId, wsidList);
        WaitAndClearTaskLater(resp, app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr);
        if (resp.HasFailed || !resp.HasSucceeded) {
            warn('LoginsToNames failed: ' + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription);
            return null;
        }
        return resp;
    }
}


void LoadMapNow(const string &in url, const string &in mode = "", const string &in settingsXml = "") {
    if (!Permissions::PlayLocalMap()) {
        NotifyError("Refusing to load map because you lack the necessary permissions. Standard or Club access required");
        return;
    }
    // change the menu page to avoid main menu bug where 3d scene not redrawn correctly (which can lead to a script error and `recovery restart...`)
    auto app = cast<CGameManiaPlanet>(GetApp());
    ReturnToMenu(true);
    app.ManiaTitleControlScriptAPI.PlayMap(url, mode, settingsXml);
}


void ReturnToMenu(bool yieldTillReady = false) {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed) {
        app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
    }
    app.BackToMainMenu();
    while (yieldTillReady && !app.ManiaTitleControlScriptAPI.IsReady) yield();
}
