#if DEPENDENCY_BETTERROOMMANAGER

namespace Together {
    bool CanUse() {
        auto plugin = Meta::GetPluginFromID("BetterRoomManager");
        return plugin !is null && plugin.Enabled;
    }

    bool ServerInTimeAttackAndAdmin() {
        auto app = GetApp();
        auto server = BRM::GetCurrentServerInfo(app, false);
        if (server is null || !server.isAdmin) return false;
        auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
        return si !is null && string(si.CurGameModeStr) == "TM_TimeAttack_Online";
    }


    // Note: check IsReadyForMapChange first.
    // Use HasMapChangerTimedOut and ForceResetMapChanger() to fix
    void SetRoomMap_Async(const string &in uid) {
        lastServerMapChange = Time::Now;
        if (mapChanger is null) @mapChanger = RoomMapChanger();
        mapChanger.WithNextMap(uid, GameModeFlavor::TimeAttack).RunChangeMap_InBg();
    }
}

#else

namespace Together {
    bool CanUse() {
        return false;
    }
    bool ServerInTimeAttackAndAdmin() {
        return false;
    }
    void SetRoomMap_Async(const string &in uid) {
        // no-op
    }
}

#endif



// SAME IMPL REGARDLESS OF BRM

namespace Together {
    int64 lastServerMapChange;
    RoomMapChanger@ mapChanger;

    bool get_IsReadyForMapChange() {
        return mapChanger is null
            || mapChanger.IsMapChangeOkay();
    }

    void ForceResetMapChanger() {
        @mapChanger = null;
    }

    bool get_HasMapChangerTimedOut() {
        return mapChanger !is null
            && !IsReadyForMapChange
            && (Time::Now - lastServerMapChange) > 15000;
    }

    // Note: if showDisabledStatus == false, UI::SameLine() will be called after the button since the alternative branches are no-ops.
    // returns true if the button was drawn
    bool DrawPlayTogetherButton(UnbeatenATMap@ chosen, const string &in label = "Play Together (This Server)", bool showDisabledStatus = true) {
        if (Together::CanUse()) {
            if (chosen is null) {
                if (showDisabledStatus) {
                    UI::AlignTextToFramePadding();
                    UI::Text("You must select a map to play together.");
                }
            } else if (Together::ServerInTimeAttackAndAdmin()) {
                UI::BeginDisabled(!Together::IsReadyForMapChange);
                if (UI::ButtonColored(label, 43.0 / 360.0, .75, .5)) {
                    startnew(CoroutineFunc(chosen.OnClickPlayTogetherCoro));
                }
                if (!showDisabledStatus) UI::SameLine();
                UI::EndDisabled();
                return true;
            } else {
                if (showDisabledStatus) {
                    UI::AlignTextToFramePadding();
                    UI::Text("Join a TA room \\$<\\$iin your club\\$>. (You must be admin)");
                }
            }
        } else if (showDisabledStatus) {
            UI::AlignTextToFramePadding();
            UI::Text("\\$i\\$999Server Play disabled. Install Better Room Manager to enable.");
        }
        return false;
    }
}
