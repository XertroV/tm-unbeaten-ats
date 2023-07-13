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
    AboutTab(root);
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
        UI::Text("Nb Unbeaten Tracks: " + g_UnbeatenATs.maps.Length + " (Filtered: "+g_UnbeatenATs.filteredMaps.Length+")");
        DrawRefreshButton();

        g_UnbeatenATs.DrawFilters();

        if (UI::BeginTable("unbeaten-ats", 10, tableFlags)) {

            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 50);
            UI::TableSetupColumn("TMX ID", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Map Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Mapper", UI::TableColumnFlags::WidthFixed, 120);
            UI::TableSetupColumn("Tags", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("AT", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("WR", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Missing Time", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Nb Players", UI::TableColumnFlags::WidthFixed, 70);
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
    UI::BeginDisabled(g_UnbeatenATs.LoadingDoneTime + (5 * 60 * 1000) > Time::Now);
    if (UI::Button("Refresh")) {
        g_UnbeatenATs.StartRefreshData();
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

        if (UI::BeginCombo("Track Filter", tostring(showList))) {
            for (int i = 0; i < int(RecentlyBeatenList::XXX_Last); i++) {
                if (UI::Selectable(tostring(RecentlyBeatenList(i)), i == int(showList))) {
                    showList = RecentlyBeatenList(i);
                }
            }
            UI::EndCombo();
        }

        if (UI::BeginTable("unbeaten-ats", 9, tableFlags)) {

            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 50);
            UI::TableSetupColumn("TMX ID", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Map Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Mapper", UI::TableColumnFlags::WidthFixed, 120);
            // UI::TableSetupColumn("Tags", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("AT", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("WR", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Beaten By", UI::TableColumnFlags::WidthFixed, 120);
            // UI::TableSetupColumn("Beaten Ago", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Nb Players", UI::TableColumnFlags::WidthFixed, 70);
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
            UI::Text("Nb Players: " + chosen.NbPlayers);
            if (UI::Button("Play Now")) {
                startnew(CoroutineFunc(chosen.OnClickPlayMapCoro));
            }
            UI::SameLine();
            if (UI::ButtonColored("Reroll", 0.3)) {
                PickRandom();
            }
            UI::Separator();
            UI::Text("Links:");
            chosen.DrawLinkButtons();
        }
    }

    void PickRandom() {
        auto ix = Math::Rand(0, g_UnbeatenATs.filteredMaps.Length);
        @chosen = g_UnbeatenATs.filteredMaps[ix];
    }
}


class AboutTab : Tab {
    AboutTab(TabGroup@ parent) {
        super(parent, "About", "");
    }

    void DrawInner() override {
        UI::Markdown("## Unbeaten ATs");
        UI::TextWrapped("A plugin by XertroV in collaboration with Satamari.");
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("Time since refresh: " + Time::Format(Time::Now - g_UnbeatenATs.LoadingDoneTime));
        DrawRefreshButton();
        UI::Separator();
        if (UI::Button("Export CSVs")) {
            startnew(ExportCSVs);
        }
        UI::TextDisabled("Note: You might want to refresh, first");
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
