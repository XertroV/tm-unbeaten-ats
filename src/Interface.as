[Setting hidden]
bool g_showWindow = false;

[Setting hidden]
int S_MainSelectedTab = 0;

TabGroup@ RootTabGroup = CreateRootTabGroup();

void UI_Main_Render() {
    if (!g_showWindow) return;
    if (g_UnbeatenATs is null && !updatingATs) {
        startnew(GetUnbeatenATsInfo);
    }

    UI::SetNextWindowSize(1050, 500, UI::Cond::Appearing);
    if (UI::Begin(MenuTitle, g_showWindow, UI::WindowFlags::NoCollapse)) {
        if (g_UnbeatenATs is null || !g_UnbeatenATs.LoadingDone) {
            UI::Text("Loading Unbeaten ATs...");
        } else {
            RootTabGroup.DrawTabs();
        }
    }
    UI::End();
}

TabGroup@ CreateRootTabGroup() {
    auto root = RootTabGroupCls();
    // OverviewTab(root);
    ListMapsTab(root);
    PlayRandomTab(root);
    RecentlyBeatenMapsTab(root);
    LeaderboardTab(root);
    // LookupMapTab(root);
    AboutTab(root);
    TogetherTab(root);
    return root;
}


// class OverviewTab : Tab {
//     OverviewTab(TabGroup@ parent) {
//         super(parent, "Overview", "");
//     }

//     void DrawInner() override {
//         if (g_UnbeatenATs is null || !g_UnbeatenATs.LoadingDone) {
//             UI::Text("Loading Unbeaten ATs...");
//             return;
//         }
//         UI::Text("Number of Unbeaten Maps: " + g_UnbeatenATs.maps.Length);
//     }
// }

class ListMapsTab : Tab {
    ListMapsTab(TabGroup@ parent) {
        super(parent, "List Maps", "");
    }
    ListMapsTab(TabGroup@ parent, const string &in name, const string &in icon) {
        super(parent, name, icon);
    }

    void DrawInner() override {
        if (g_UnbeatenATs is null || !g_UnbeatenATs.LoadingDone) {
            UI::Text("Loading Unbeaten ATs...");
            return;
        }

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.25, .25, .25, .5));
        DrawTable();
        UI::PopStyleColor();
    }

    int tableFlags = UI::TableFlags::SizingStretchProp | UI::TableFlags::Resizable | UI::TableFlags::RowBg;

    void DrawTable() {
        UI::AlignTextToFramePadding();
        UI::Text("# Unbeaten Tracks: " + g_UnbeatenATs.maps.Length + " (Filtered: "+g_UnbeatenATs.filteredMaps.Length+")");
        DrawRefreshButton();

        g_UnbeatenATs.DrawFilters();

        if (UI::BeginTable("unbeaten-ats", 10, tableFlags)) {

            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 40);
            UI::TableSetupColumn("TMX ID", UI::TableColumnFlags::WidthFixed, 70 + 40);
            UI::TableSetupColumn("Map Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Mapper", UI::TableColumnFlags::WidthFixed, 120);
            UI::TableSetupColumn("Tags", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("AT", UI::TableColumnFlags::WidthFixed, 75);
            UI::TableSetupColumn("WR", UI::TableColumnFlags::WidthFixed, 75);
            UI::TableSetupColumn("Missing Time", UI::TableColumnFlags::WidthFixed, 75);
            UI::TableSetupColumn("# Players", UI::TableColumnFlags::WidthFixed, 60);
            UI::TableSetupColumn("Links", UI::TableColumnFlags::WidthFixed, 100);

            UI::TableHeadersRow();

            UI::ListClipper clip(g_UnbeatenATs.filteredMaps.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    g_UnbeatenATs.filteredMaps[i].DrawUnbeatenTableRow(i + 1);
                }
            }

            UI::EndTable();
        }
    }
}


void DrawRefreshButton() {
    UI::SameLine();
    UI::BeginDisabled(g_UnbeatenATs.LoadingDoneTime + (5 * 60 * 1000) > int(Time::Now));
    if (UI::Button("Refresh")) {
        g_UnbeatenATs.StartRefreshData();
    }
    UI::EndDisabled();
}

void DrawLbRefreshButton() {
    UI::SameLine();
    UI::BeginDisabled(g_UnbeatenATsLeaderboard.LoadingDoneTime + (5 * 60 * 1000) > int(Time::Now));
    if (UI::Button("Refresh")) {
        g_UnbeatenATsLeaderboard.StartRefreshData();
    }
    UI::EndDisabled();
}


enum RecentlyBeatenList {
    All,
    First_100k_Only,
    XXX_Last
}

class RecentlyBeatenMapsTab : ListMapsTab {

    RecentlyBeatenMapsTab(TabGroup@ parent) {
        super(parent, "Recently Beaten ATs", "");
    }

    RecentlyBeatenList showList = RecentlyBeatenList::First_100k_Only;

    void DrawTable() override {
        UI::AlignTextToFramePadding();
        UI::Text("Recently Beaten ATs:");
        DrawRefreshButton();

        if (UI::BeginCombo("Track List", tostring(showList))) {
            for (int i = 0; i < int(RecentlyBeatenList::XXX_Last); i++) {
                if (UI::Selectable(tostring(RecentlyBeatenList(i)), i == int(showList))) {
                    showList = RecentlyBeatenList(i);
                }
            }
            UI::EndCombo();
        }

        if (UI::BeginTable("unbeaten-ats", 9, tableFlags)) {

            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 50);
            UI::TableSetupColumn("TMX ID", UI::TableColumnFlags::WidthFixed, 70 + 40);
            UI::TableSetupColumn("Map Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Mapper", UI::TableColumnFlags::WidthFixed, 120);
            // UI::TableSetupColumn("Tags", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("AT", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("WR", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Beaten By", UI::TableColumnFlags::WidthFixed, 120);
            // UI::TableSetupColumn("Beaten Ago", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("# Players", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Links", UI::TableColumnFlags::WidthFixed, 100);

            UI::TableHeadersRow();

            auto@ theList = showList == RecentlyBeatenList::All
                ? g_UnbeatenATs.recentlyBeaten
                : g_UnbeatenATs.recentlyBeaten100k;

            UI::ListClipper clip(theList.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    theList[i].DrawBeatenTableRow(i + 1);
                }
            }

            UI::EndTable();
        }
    }
}

class PlayRandomTab : Tab {
    PlayRandomTab(TabGroup@ parent) {
        super(parent, "Play Random", "");
    }

    UnbeatenATMap@ chosen = null;

    void DrawInner() override {
        g_UnbeatenATs.DrawFilters();
        UI::AlignTextToFramePadding();
        UI::Text("Choose from " + g_UnbeatenATs.filteredMaps.Length + " maps.");

        if (chosen is null) {
            if (UI::Button("Pick a Random Map")) {
                PickRandom();
            }
        } else {
            UI::AlignTextToFramePadding();
            UI::Text("Name: " + chosen.Track_Name);
            UI::Text("Mapper: " + chosen.AuthorDisplayName);
            UI::Text("TMX: " + chosen.TrackID);
            UI::Text("Tags: " + chosen.TagNames);
            UI::Text("AT: " + chosen.ATFormatted);
            if (chosen.WR > 0)
                UI::Text("WR: " + Time::Format(chosen.WR) + " (+"+Time::Format(chosen.WR - chosen.AuthorTime)+")");
            else
                UI::Text("WR: --");
            UI::Text("# Players: " + chosen.NbPlayers);
            if (UI::Button("Play Now")) {
                startnew(CoroutineFunc(chosen.OnClickPlayMapCoro));
            }
            UI::SameLine();
            if (UI::ButtonColored("Reroll", 0.3)) {
                startnew(CoroutineFunc(PickRandom));
            }
            if (chosen is null) return;

            UI::Separator();
            Together::DrawPlayTogetherButton(chosen);
#if DEV
            UI::Text("Curr Rules Time: " + GetServerCurrentRulesElapsedMillis());
            UI::Text("Rules Start: " + GetRulesStartTime());
            UI::Text("Rules Now: " + PlaygroundNow());
            UI::Text("Rules End: " + GetRulesEndTime());
#endif

            UI::Separator();
            UI::Text("Links:");
            chosen.DrawLinkButtons();
        }
    }

    void PickRandom() {
        if (g_UnbeatenATs.filteredMaps.Length == 0) {
            @chosen = null;
        } else {
            auto ix = Math::Rand(0, g_UnbeatenATs.filteredMaps.Length);
            @chosen = g_UnbeatenATs.filteredMaps[ix];
        }
    }
}

class LeaderboardTab : Tab {
    LeaderboardTab(TabGroup@ parent) {
        super(parent, "Leaderboard", "");
    }

    void DrawInner() override {
        if (g_UnbeatenATsLeaderboard is null) {
            startnew(GetUnbeatenLeaderboard);
            UI::Text("Loading Unbeaten ATs Leaderboard...");
            return;
        }

        if (!g_UnbeatenATsLeaderboard.LoadingDone) {
            UI::Text("Loading Unbeaten ATs Leaderboard...");
            UI::Text(g_UnbeatenATsLeaderboard.LoadProgress);
            return;
        }

        UI::Markdown("## Unbeaten ATs Leaderboard");
        UI::AlignTextToFramePadding();
        UI::Text("Number of Players: " + g_UnbeatenATsLeaderboard.nbPlayers);
        DrawLbRefreshButton();

        UI::Text("Your Rank: #" + g_UnbeatenATsLeaderboard.GetPlayerRankStr(NadeoServices::GetAccountID()));

        if (UI::CollapsingHeader("About the LB")) {
            UI::TextWrapped("Scores are only added when you are the \\$<\\$isole\\$> player to first get the AT of a map, when the backend checks it.");
            UI::TextWrapped("This is not perfect, obviously, as many maps were not checked at the right time to know who was the first player to get the AT.");
            UI::TextWrapped("Currently, you can be the first to get the AT of your own maps. If this is abused, XertroV will code up a prevention and re-process the entire LB to remove these cases.");
            UI::Text("");
        }

        UI::Markdown("## Top 100");

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.25, .25, .25, .5));
        DrawTable();
        UI::PopStyleColor();
    }

    int tableFlags = UI::TableFlags::SizingStretchProp | UI::TableFlags::Resizable | UI::TableFlags::RowBg;

    void DrawTable() {
        if (UI::BeginTable("unbeaten-ats-lb", 4, tableFlags)) {
            UI::TableSetupColumn("Rank", UI::TableColumnFlags::WidthFixed, 40);
            UI::TableSetupColumn("Score (# 1st ATs)", UI::TableColumnFlags::WidthFixed, 80);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Links", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableHeadersRow();

            for (uint i = 0; i < g_UnbeatenATsLeaderboard.top100.Length; i++) {
                g_UnbeatenATsLeaderboard.top100[i].DrawUnbeatenLBRow();
            }

            UI::EndTable();
        }
    }
}

class AboutTab : Tab {
    AboutTab(TabGroup@ parent) {
        super(parent, "About", "");
    }

    void DrawInner() override {
        UI::Markdown("## Unbeaten ATs");
        UI::AlignTextToFramePadding();
        UI::TextWrapped("A plugin by XertroV in collaboration with Satamari.");
        UI::AlignTextToFramePadding();
        UI::TextWrapped("For the 100k project, please use Satamari's spreadsheet as the authoritative list. This plugin should be consided a \\$f80beta\\$z. Please report issues on the openplanet discord.");
        if (UI::Button("Open Satamari's Unbeaten ATs Spreadsheet")) {
            OpenBrowserURL("https://docs.google.com/spreadsheets/d/1YNJDa9u6LM34Rrf5BzJGj9IHkxG1nLIJZNu4DntdHb8/edit#gid=988833527");
        }
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::TextWrapped("Caveats with this plugin:");
        UI::AlignTextToFramePadding();
        UI::TextWrapped("Unbeaten maps are re-checked once every 2 hours or so.\nImpossible maps, cheated ATs, broken maps may be included in these lists (in future they'll be removed based on a TMX map pack + manual flagging).\nSome maps with old TMX records incorrectly report being beaten by the first person to beat it on the Nadeo LBs.\nA map won't show up in recently beaten if multiple people beat it at once.");
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("Time since refresh: " + Time::Format(Time::Now - g_UnbeatenATs.LoadingDoneTime, false));
        DrawRefreshButton();
        UI::Separator();
        if (UI::Button("Export CSVs")) {
            startnew(ExportCSVs);
        }
        UI::TextDisabled("Note: You might want to refresh, first");
        // todo: raw links
    }
}

void ExportCSVs() {
    string unbeaten = IO::FromStorageFolder(tostring(Time::Stamp) + "-UnbeatenATs.csv");
    string recentAll = IO::FromStorageFolder(tostring(Time::Stamp) + "-RecentATs-All.csv");
    string recent100k = IO::FromStorageFolder(tostring(Time::Stamp) + "-RecentATs-100k.csv");

    ExportMapList(unbeaten, g_UnbeatenATs.maps);
    ExportMapList(recentAll, g_UnbeatenATs.recentlyBeaten);
    ExportMapList(recent100k, g_UnbeatenATs.recentlyBeaten100k);

    OpenExplorerPath(IO::FromStorageFolder("/"));
}

void ExportMapList(const string &in path, UnbeatenATMap@[] maps) {
    string ret = maps[0].CSVHeader();
    for (uint i = 0; i < maps.Length; i++) {
        ret += maps[i].CSVRow();
    }
    IO::File f(path, IO::FileMode::Write);
    f.Write(ret);
    NotifySuccess("Exported "+maps.Length+" maps to: " + path);
}


class TogetherTab : Tab {
    TogetherTab(TabGroup@ parent) {
        super(parent, "Together", "");
    }

    void DrawInner() override {
        UI::AlignTextToFramePadding();
        UI::Text("Together Mode (Club Room)");
        UI::SeparatorText("Instructions");
        UI::AlignTextToFramePadding();
        UI::TextWrapped("A button will appear next to the Play button when you are in a club room. \\$f80You must be an admin for that club.");

        UI::SeparatorText("Status");
        UI::AlignTextToFramePadding();
        UI::TextWrapped("Here you can see room status info and reset things if you need.");

        if (Together::IsReadyForMapChange) {
            UI::Text("No room change in progress");
        }

        if (Together::HasMapChangerTimedOut) {
            UI::Text("Map changer has timed out.");
            if (UI::Button("Hard Reset Map Changer")) {
                Together::ForceResetMapChanger();
            }
        }

        UI::SeparatorText("Fix Room Helper");

        UI::BeginDisabled(!UI::IsKeyDown(UI::Key::LeftShift));
        auto @changer = Together::mapChanger;
        UI::AlignTextToFramePadding();
        if (changer !is null) {
            auto params = changer.changeRoomParams;
            if (params !is null) {
                UI::Text("To enable, hold left shift");
                if (UI::Button("Run Room Error Correction Tool")) {
                    startnew(OnFailedToLoadCorrectMapCoro, params);
                }
            } else {
                UI::Text("No map change params found.");
            }
        } else {
            UI::Text("No map changer found.");
        }

        if (RoomErrorCorrection::HasActiveMsg) {
            UI::Text("Last Error Correction Msg: ");
            RoomErrorCorrection::Render();
        }
        UI::EndDisabled();

        UI::SeparatorText("Debug Info");

        UI::Text("Rules Elapsed: " + GetServerCurrentRulesElapsedMillis());
        UI::Text("Rules Start: " + GetRulesStartTime());
        UI::Text("Rules Now: " + PlaygroundNow());
        UI::Text("Rules End: " + GetRulesEndTime());
    }
}
