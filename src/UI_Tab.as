class Tab {
    string idNonce = "tab-" + Math::Rand(0, TWO_BILLION);

    // bool canCloseTab = false;
    TabGroup@ Parent = null;
    TabGroup@ Children = null;
    TabGroup@ WindowChildren = null;

    string tabName;
    string fullName;
    uint windowExtraId = Math::Rand(0, TWO_BILLION);
    string tabIcon;
    string tabIconAndName;

    bool removable = false;
    bool canPopOut = false;
    bool tabOpen = true;
    bool get_windowOpen() { return !tabOpen; }
    void set_windowOpen(bool value) { tabOpen = !value; }
    bool expandWindowNextFrame = false;
    bool windowExpanded = false;

    Tab(TabGroup@ parent, const string &in tabName, const string &in icon) {
        this.tabName = tabName;
        // .Parent set here
        parent.AddTab(this);
        fullName = parent.fullName + " > " + tabName;
        tabIcon = " " + icon;
        tabIconAndName = tabIcon + " " + tabName;
        @Children = TabGroup(tabName, this);
        @WindowChildren = TabGroup(tabName, this);
    }

    const string get_DisplayIconAndName() {
        return tabIconAndName;
    }

    const string get_DisplayIcon() {
        return tabIcon;
    }

    int get_TabFlags() {
        return UI::TabItemFlags::NoCloseWithMiddleMouseButton
            | UI::TabItemFlags::NoReorder
            ;
    }

    int get_WindowFlags() {
        return UI::WindowFlags::AlwaysAutoResize
            // | UI::WindowFlags::NoCollapse
            ;
    }

    void DrawTogglePop() {
        if (UI::Button((tabOpen ? Icons::Expand : Icons::Compress) + "##" + fullName)) {
            windowOpen = !windowOpen;
        }
        if (removable) {
            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(20, 0));
            if (UI::Button(Icons::Trash + "##" + fullName)) {
                Parent.RemoveTab(this);
            }
        }
    }

    void DrawMenuItem() {
        if (UI::MenuItem(DisplayIconAndName, "", windowOpen)) {
            windowOpen = !windowOpen;
        }
    }

    void DrawTab(bool withItem = true) {
        if (!withItem) {
            DrawTabWrapInner();
            return;
        }
        if (UI::BeginTabItem(tabName, TabFlags)) {
            if (UI::BeginChild(fullName))
                DrawTabWrapInner();
            UI::EndChild();
            UI::EndTabItem();
        }
    }

    void DrawTabWrapInner() {
        DrawInnerWrapID();
        return;

        // UX::LayoutLeftRight("tabHeader|"+fullName,
        //     CoroutineFunc(_HeadingLeft),
        //     CoroutineFunc(_HeadingRight)
        // );
        // UI::Indent();
        // if (!tabOpen) {
        //     UI::Text("Currently popped out.");
        // } else {
        //     DrawInnerWrapID();
        // }
        // UI::Unindent();
    }

    void _HeadingLeft() {
        UI::AlignTextToFramePadding();
        UI::Text(tabName + ": ");
    }

    void _HeadingRight() {
        if (!tabOpen) {
            if (!windowExpanded) {
                if (UI::Button("Expand Window##"+fullName)) {
                    expandWindowNextFrame = true;
                }
                UI::SameLine();
            }
            if (UI::Button("Return to Tab##"+fullName)) {
                windowOpen = !windowOpen;
            }
        } else {
            if (canPopOut) {
                DrawTogglePop();
            }
        }
    }

    void DrawInner() {
        UI::Text("Tab Inner: " + tabName);
        UI::Text("Overload `DrawInner()`");
    }

    void DrawInnerWrapID() {
        UI::PushID(idNonce);
        DrawInner();
        UI::PopID();
    }

    vec2 lastWindowPos;
    bool DrawWindow() {
        Children.DrawWindows();
        WindowChildren.DrawWindowsAndRemoveTabsWhenClosed();
        if (!windowOpen) return false;
        if (expandWindowNextFrame && windowOpen) {
            UI::SetNextWindowPos(int(lastWindowPos.x), int(lastWindowPos.y));
            windowExtraId = Math::Rand(0, TWO_BILLION);
        }
        expandWindowNextFrame = false;
        windowExpanded = false;
        if (UI::Begin(fullName + "##" + windowExtraId, windowOpen, WindowFlags)) {
            windowExpanded = true;
            // DrawTogglePop();
            DrawInnerWrapID();
        }
        lastWindowPos = UI::GetWindowPos();
        UI::End();
        return true;
    }
}




class TodoTab : Tab {
    string description;

    TodoTab(TabGroup@ parent, const string&in tabName, const string&in icon, const string &in desc = "??") {
        super(parent, "\\$888" + tabName, icon);
        description = desc;
        canPopOut = false;
    }

    void DrawInner() override {
        UI::TextWrapped("Todo. This tab will " + description);
        UI::TextWrapped("Request features in the `Help > Plugin Support Thread` on the openplanet discord! It helps with prioritization and provides ideas for new features.");
        // creates some min width:
        // UI::Text("This tab full name is: " + fullName);
    }
}
