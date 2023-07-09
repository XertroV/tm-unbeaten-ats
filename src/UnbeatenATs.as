bool updatingATs = false;

// main coro to get and set info
void GetUnbeatenATsInfo() {
    if (updatingATs) return;
    updatingATs = true;

    await(startnew(_GetUnbeatenATsInfo));

    updatingATs = false;
}

UnbeatenATsData@ g_UnbeatenATs = null;

void _GetUnbeatenATsInfo() {
    @g_UnbeatenATs = UnbeatenATsData();
    while (!g_UnbeatenATs.LoadingDone) yield();
}


class UnbeatenATsData {
    Json::Value@ mainData;
    string[] keys;
    private bool doneLoading = false;

    UnbeatenATMap@[] maps;
    UnbeatenATMap@[] filteredMaps;

    UnbeatenATsData() {
        startnew(CoroutineFunc(this.RunInit));
    }

    protected void RunInit() {
        RunGetQuery();
        LoadMapsFromJson();
        doneLoading = true;
    }

    protected void RunGetQuery() {
        @mainData = MapMonitor::GetUnbeatenATsInfo();
        print(Json::Write(mainData));
    }

    protected void LoadMapsFromJson() {
        auto tracks = mainData['tracks'];
        auto keysJ = mainData['keys'];
        for (uint i = 0; i < keysJ.Length; i++) {
            keys.InsertLast(keysJ[i]);
        }
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            maps.InsertLast(UnbeatenATMap(track, keys));
        }
    }

    bool get_LoadingDone() {
        return doneLoading;
    }

    UnbeatenATFilters@ filters = UnbeatenATFilters();
    UnbeatenATSorting@ sorting = UnbeatenATSorting();
    void DrawFilters() {
        auto origFilters = UnbeatenATFilters(filters);
        filters.Draw();
        if (origFilters != filters) {
            startnew(CoroutineFunc(UpdateFiltered));
        }
        auto origSorting = UnbeatenATSorting(sorting);
        sorting.Draw();
        if (origSorting != sorting) {
            startnew(CoroutineFunc(UpdateSortOrder));
        }
    }

    void UpdateFiltered() {
        filteredMaps.RemoveRange(0, filteredMaps.Length);
        for (uint i = 0; i < maps.Length; i++) {
            auto item = maps[i];
            if (filters.Matches(item)) {
                filteredMaps.InsertLast(item);
            }
        }
        UpdateSortOrder();
    }

    void UpdateSortOrder() {

    }
}

enum Ord {
    EQ, LT, GT, LTE, GTE
}

class UnbeatenATFilters {

    bool First100KOnly = false;
    bool FilterNbPlayers = false;
    int NbPlayers = 0;
    uint NbPlayersOrd = Ord::LTE;

    UnbeatenATFilters() {}
    UnbeatenATFilters(UnbeatenATFilters@ other) {
        First100KOnly = other.First100KOnly;
        FilterNbPlayers = other.FilterNbPlayers;
        NbPlayers = other.NbPlayers;
        NbPlayersOrd = other.NbPlayersOrd;
    }

    bool opEquals(const UnbeatenATFilters@ other) {
        return true
            && First100KOnly == other.First100KOnly
            && FilterNbPlayers == other.FilterNbPlayers
            && NbPlayers == other.NbPlayers
            && NbPlayersOrd == other.NbPlayersOrd
            ;
    }

    bool Matches(const UnbeatenATMap@ map) {
        if (First100KOnly && map.TrackID > 100000) return false;
        if (FilterNbPlayers) {
            if (NbPlayersOrd == Ord::EQ && NbPlayers != map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::LT && NbPlayers >= map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::GT && NbPlayers <= map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::LTE && NbPlayers > map.NbPlayers) return false;
            if (NbPlayersOrd == Ord::GTE && NbPlayers < map.NbPlayers) return false;
        }

        return true;
    }

    void Draw() {

    }
}

enum UnbeatenTableSort {
    TMX_ID, Name, Author_Name, Nb_Players, AT //, Missing_Time
}

class UnbeatenATSorting {
    UnbeatenTableSort order = UnbeatenTableSort::TMX_ID;

    UnbeatenATSorting() {}
    UnbeatenATSorting(const UnbeatenATSorting@ other) {
        order = other.order;
    }

    bool opEquals(const UnbeatenATSorting@ other) {
        return true
            && order == other.order
            ;
    }

    int less(const UnbeatenATMap@ a, const UnbeatenATMap@ b) {
        if (order == UnbeatenTableSort::TMX_ID) {
            return intLess(a.TrackID, b.TrackID);
        }
        if (order == UnbeatenTableSort::Name) {
            return stringLess(a.Track_Name, b.Track_Name);
        }
        if (order == UnbeatenTableSort::Author_Name) {
            return stringLess(a._AuthorDisplayName, b._AuthorDisplayName);
        }
        if (order == UnbeatenTableSort::Nb_Players) {
            return intLess(a.NbPlayers, b.NbPlayers);
        }
        if (order == UnbeatenTableSort::AT) {
            return intLess(a.AuthorTime, b.AuthorTime);
        }
        return intLess(a.TrackID, b.TrackID);
    }

    void Draw() {

    }
}

int intLess(int a, int b) {
    if (a < b) return -1;
    if (a == b) return 0;
    return 1;
}
int stringLess(const string &in a, const string &in b) {
    if (a < b) return -1;
    if (a == b) return 0;
    return 1;
}


class UnbeatenATMap {
    Json::Value@ row;
    string[]@ keys;
    int TrackID = -1;
    int AuthorTime = -1;
    int WR = -1;
    int NbPlayers = -1;
    float LastChecked = -1.;
    string TrackUID;
    string Track_Name;
    string AuthorLogin;
    string Tags;
    string MapType;
    string TagNames;

    UnbeatenATMap(Json::Value@ row, string[]@ keys) {
        @this.row = row;
        @this.keys = keys;
        PopulateData();
    }

    void PopulateData () {
        TrackID = GetData('TrackID', TrackID);
        AuthorTime = GetData('AuthorTime', AuthorTime);
        WR = GetData('WR', WR);
        NbPlayers = GetData('NbPlayers', NbPlayers);
        LastChecked = GetData('LastChecked', LastChecked);
        TrackUID = GetData('TrackUID', TrackUID);
        Track_Name = GetData('Track_Name', Track_Name);
        AuthorLogin = GetData('AuthorLogin', AuthorLogin);
        Tags = GetData('Tags', Tags);
        MapType = GetData('MapType', MapType);
        SetTags();
        QueueAuthorLoginCache(AuthorLogin);
    }

    string _AuthorDisplayName;
    string get_AuthorDisplayName() {
        return GetDisplayNameForLogin(AuthorLogin);
        // if (_AuthorDisplayName.Length > 0) return _AuthorDisplayName;
        // if (loginCache.HasKey(AuthorLogin)) _AuthorDisplayName = GetDisplayNameForLogin(AuthorLogin);
    }

    void SetTags() {
        while (g_TmxTags is null) yield();
        auto parts = Tags.Split(",");
        for (uint i = 0; i < parts.Length; i++) {
            auto item = parts[i];
            if (parts[i].Length == 0) continue;
            int tagId;
            try {
                tagId = Text::ParseInt(parts[i]);
            } catch {
                warn("exception parsing tag ID: " + parts[i] + "; exception: " + getExceptionInfo());
                continue;
            }
            if (tagId >= int(tagLookup.Length)) {
                warn("Unexpected tag ID: " + tagId);
                continue;
            }
            if (i > 0) TagNames += ", ";
            TagNames += tagLookup[tagId];
            // TagNames.InsertLast(tagLookup[tagId]);
        }
    }

    int GetData(const string &in name, int _) {
        return GetData(name);
    }
    float GetData(const string &in name, float _) {
        return GetData(name);
    }
    string GetData(const string &in name, const string &in _) {
        auto j = GetData(name);
        // print("GetDataStr: " + Json::Write(j));
        if (j is null || j.GetType() == Json::Type::Null) return "";
        return j;
    }
    Json::Value@ GetData(const string &in name) {
        return row[keys.Find(name)];
    }



    void DrawTableRow() {
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text("" + TrackID);

        UI::TableNextColumn();
        UI::Text(Track_Name);

        UI::TableNextColumn();
        UI::Text(AuthorDisplayName);

        UI::TableNextColumn();
        UI::Text(TagNames);
        AddSimpleTooltip(TagNames);

        UI::TableNextColumn();
        UI::Text(Time::Format(AuthorTime));

        UI::TableNextColumn();
        UI::Text(WR >= 0 ? Time::Format(WR) : "--");

        // missing time
        UI::TableNextColumn();
        UI::Text(WR < 0 ? "--" : Time::Format(WR - AuthorTime));

        // player count
        UI::TableNextColumn();
        UI::Text("" + NbPlayers);

        // links
        UI::TableNextColumn();
        // tmx + tm.io
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        if (UI::Button("TM.io##" + TrackID)) {
            OpenBrowserURL("https://trackmania.io/#/leaderboard/"+TrackUID+"?utm_source=unbeated-ats-plugin");
        }
        UI::SameLine();
        if (UI::Button("TMX##" + TrackID)) {
            OpenBrowserURL("https://trackmania.exchange/maps/"+TrackID+"?utm_source=unbeated-ats-plugin");
        }
        UI::PopStyleVar();
    }
}

Json::Value@ g_TmxTags = null;
string[] tagLookup;

void PopulateTmxTags() {
    @g_TmxTags = TMX::GetTmxTags();
    tagLookup.Resize(g_TmxTags.Length + 1);
    for (uint i = 0; i < g_TmxTags.Length; i++) {
        // {Color, ID, Name}
        auto tag = g_TmxTags[i];
        int ix = tag['ID'];
        tagLookup[ix] = tag['Name'];
    }
}
