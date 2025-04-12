bool updatingLB = false;

void GetUnbeatenLeaderboard() {
    if (updatingLB) return;
    updatingLB = true;
    await(startnew(_GetUnbeatenLeaderboard));
    updatingLB = false;
}

void _GetUnbeatenLeaderboard() {
    @g_UnbeatenATsLeaderboard = UnbeatenLB();
    while (!g_UnbeatenATsLeaderboard.LoadingDone) yield();
}

UnbeatenLB@ g_UnbeatenATsLeaderboard = null;

class UnbeatenLB {
    Json::Value@ data;
    private bool doneLoading = false;
    int64 LoadingDoneTime = -1;
    int64 nbPlayers;
    // score -> (rank, nb_tied_players)
    int2[] scoreToRank;
    dictionary lookup;
    LbPlayer[] top100 = array<LbPlayer>(100);

    UnbeatenLB() {
        StartRefreshData();
    }

    void StartRefreshData() {
        doneLoading = false;
        lookup.DeleteAll();
        nbPlayers = 0;
        @data = null;
        scoreToRank.RemoveRange(0, scoreToRank.Length);
        startnew(CoroutineFunc(RunGetData));
    }

    void RunGetData() {
        print("UnbeatenLB: Loading");
        @data = MapMonitor::GetUnbeatenLeaderboard();
        auto startTime = Time::Now;
        print("UnbeatenLB: Loading... starting parsing at " + startTime);
        yield();
        LoadFromJson();
        yield();
        doneLoading = true;
        LoadingDoneTime = Time::Now;
        print("UnbeatenLB: Loading done in " + (LoadingDoneTime - startTime) + "ms");
    }

    void LoadFromJson() {
        nbPlayers = data["nb_players"];
        // list of [wsid, score] tuples
        auto playersJ = data["players"];
        // dict of score => [rank, nb_tied_players]
        auto scoreToRankJ = data["count_to_pos"];
        // prep s->rank array
        int64 maxScore = playersJ[0][1];
        scoreToRank.Resize(maxScore + 1);
        // populate s->rank array
        auto keys = scoreToRankJ.GetKeys();
        for (int i = 0; i < keys.Length; i++) {
            auto k = keys[i];
            int score = Text::ParseInt(k);
            int rank = scoreToRankJ[k][0];
            int nbTiedPlayers = scoreToRankJ[k][1];
            scoreToRank[score] = int2(rank, nbTiedPlayers);
        }
        yield();
        // populate top 100 and lookup
        for (int i = 0; i < playersJ.Length; i++) {
            int score = playersJ[i][1];
            LbPlayer@ p;
            if (i < 100) {
                top100[i] = LbPlayer(playersJ[i][0], score, scoreToRank[score].x);
                @p = top100[i];
            } else {
                @p = LbPlayer(playersJ[i][0], score, scoreToRank[score].x);
            }
            @lookup[p.wsid] = p;
            if (i % 200 == 0) {
                yield();
            }
        }
    }


    bool get_LoadingDone() {
        return doneLoading;
    }

    string get_LoadProgress() {
        if (nbPlayers == 0) return "0 / 0 (0.0 %)";
        float nb = lookup.GetSize();
        float total = nbPlayers;
        float percent = nb / total * 100;
        return "" + nb + " / " + total + " (" + Math::Round(percent, 1) + "%)";
    }

    string GetPlayerRankStr(const string &in wsid) {
        if (lookup.Exists(wsid)) {
            LbPlayer@ p = cast<LbPlayer>(lookup[wsid]);
            auto rtw = scoreToRank[p.score];
            auto bestRank = rtw.x;
            auto tiedWith = rtw.y;
            return "" + bestRank + " (" + p.score + ")" + (tiedWith > 1 ? " tied with " + (tiedWith - 1) + " other players" : "");
        }
        return "N/A";
    }
}


class LbPlayer {
    string wsid;
    // string name;
    int score;
    int rank;

    LbPlayer() {}

    LbPlayer(string wsid, int score, int rank) {
        this.wsid = wsid;
        this.score = score;
        this.rank = rank;
        QueueWsidNameCache(wsid);
    }

    string get_name() {
        return GetDisplayNameForWsid(wsid);
    }

    void DrawUnbeatenLBRow() {
        UI::PushID(wsid);

        UI::TableNextColumn();
        UI::Text("# " + rank);
        UI::TableNextColumn();
        UI::Text(tostring(score) + " 1st ATs");
        UI::TableNextColumn();
        UI::Text(name);
        UI::TableNextColumn();

        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        // tmx + tm.io
        if (UI::Button("TM.io")) {
            OpenBrowserURL("https://trackmania.io/#/player/"+wsid+"?utm_source=unbeaten-ats-plugin");
        }
        UI::PopStyleVar();


        UI::PopID();
    }
}
