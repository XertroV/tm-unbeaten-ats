bool UserHasPermissions = false;

void Main() {
    UserHasPermissions = Permissions::PlayLocalMap();
    if (!UserHasPermissions) {
        NotifyWarning("This plugin requires permission to play local maps");
        return;
    }
    startnew(PopulateTmxTags);
    startnew(GetUnbeatenATsInfo);
    startnew(GetAuthorLoginLoop);
    startnew(GetWsidLoop);
}

void OnDestroyed() { Unload(); }
void OnDisabled() { Unload(); }
void Unload() {

}

void Render() {
}

void RenderInterface() {
    if (!UserHasPermissions) return;
    UI_Main_Render();
}

/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", g_showWindow)) {
        g_showWindow = !g_showWindow;
    }
}

void AwaitReturnToMenu() {
    auto app = cast<CTrackMania>(GetApp());
    // app.BackToMainMenu();
    while (app.Switcher.ModuleStack.Length == 0 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
        yield();
    }
    while (!app.ManiaTitleControlScriptAPI.IsReady) {
        yield();
    }
}



shared void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

shared void NotifySuccess(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(.4, .7, .1, .3), 10000);
    trace("Notified: " + msg);
}

shared void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

shared void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

shared void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
    }
}
