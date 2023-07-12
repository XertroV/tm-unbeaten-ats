[Setting hidden]
bool g_showWindow = false;

[Setting hidden]
int S_MainSelectedTab = 0;

TabGroup@ RootTabGroup = CreateRootTabGroup();

void UI_Main_Render() {
    if (!g_showWindow) return;

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

        DrawTable();
    }

    void DrawRefreshButton() {
        UI::SameLine();
        UI::BeginDisabled(g_UnbeatenATs.LoadingDoneTime + (5 * 60 * 1000) > Time::Now);
        if (UI::Button("Refresh")) {
            g_UnbeatenATs.StartRefreshData();
        }
        UI::EndDisabled();
    }

    void DrawTable() {
        g_UnbeatenATs.DrawFilters();

        UI::AlignTextToFramePadding();
        UI::Text("Nb Unbeaten Tracks: " + g_UnbeatenATs.maps.Length + " (Filtered: "+g_UnbeatenATs.filteredMaps.Length+")");
        DrawRefreshButton();

        if (UI::BeginTable("unbeaten-ats", 9, UI::TableFlags::SizingStretchProp | UI::TableFlags::Resizable)) {

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
                    g_UnbeatenATs.filteredMaps[i].DrawUnbeatenTableRow();
                }
            }

            UI::EndTable();
        }
    }
}

class RecentlyBeatenMapsTab : ListMapsTab {

    RecentlyBeatenMapsTab(TabGroup@ parent) {
        super(parent, "Recently Beaten ATs", "");
    }

    void DrawTable() override {
        UI::AlignTextToFramePadding();
        UI::Text("Recently Beaten ATs:");
        DrawRefreshButton();

        if (UI::BeginTable("unbeaten-ats", 8, UI::TableFlags::SizingStretchProp | UI::TableFlags::Resizable)) {

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

            UI::ListClipper clip(g_UnbeatenATs.recentlyBeaten.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    g_UnbeatenATs.recentlyBeaten[i].DrawBeatenTableRow();
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

    void DrawInner() override {

    }
}


class AboutTab : TodoTab {
    AboutTab(TabGroup@ parent) {
        super(parent, "About", "");
    }
}
