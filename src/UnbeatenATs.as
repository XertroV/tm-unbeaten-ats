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
    Json::Value@ recentData;
    string[] keys;
    string[] keysRB;
    private bool doneLoading = false;
    private bool doneLoadingRecent = false;
    int LoadingDoneTime = -1;

    UnbeatenATMap@[] maps;
    UnbeatenATMap@[] filteredMaps;

    UnbeatenATMap@[] recentlyBeaten;
    UnbeatenATMap@[] recentlyBeaten100k;

    UnbeatenATsData() {
        StartRefreshData();
    }

    void StartRefreshData() {
        doneLoading = false;
        doneLoadingRecent = false;
        maps = {};
        filteredMaps = {};
        recentlyBeaten = {};
        recentlyBeaten100k = {};
        startnew(CoroutineFunc(this.RunInit));
        startnew(CoroutineFunc(this.RunRecentInit));
    }

    protected void RunInit() {
        RunGetQuery();
        yield();
        LoadMapsFromJson();
        yield();
        UpdateFiltered();
        doneLoading = true;
        if (LoadingDone)
            LoadingDoneTime = Time::Now;
    }

    protected void RunRecentInit() {
        RunGetRecent();
        yield();
        LoadRecentFromJson();
        yield();
        doneLoadingRecent = true;
        if (LoadingDone)
            LoadingDoneTime = Time::Now;
    }

    protected void RunGetQuery() {
        @mainData = MapMonitor::GetUnbeatenATsInfo();
    }

    protected void RunGetRecent() {
        @recentData = MapMonitor::GetRecentlyBeatenATsInfo();
    }

    protected void LoadMapsFromJson() {
        auto tracks = mainData['tracks'];
        auto keysJ = mainData['keys'];
        for (uint i = 0; i < keysJ.Length; i++) {
            keys.InsertLast(keysJ[i]);
            if ((i+1) % 100 == 0) yield();
        }
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            maps.InsertLast(UnbeatenATMap(track, keys));
            if ((i+1) % 100 == 0) yield();
        }
    }

    protected void LoadRecentFromJson() {
        auto keysJ = recentData['keys'];
        for (uint i = 0; i < keysJ.Length; i++) {
            keysRB.InsertLast(keysJ[i]);
            if ((i+1) % 100 == 0) yield();
        }

        auto tracks = recentData['all']['tracks'];
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            recentlyBeaten.InsertLast(UnbeatenATMap(track, keysRB, true));
            if ((i+1) % 100 == 0) yield();
        }

        auto tracks100k = recentData['below100k']['tracks'];
        for (uint i = 0; i < tracks100k.Length; i++) {
            auto track = tracks100k[i];
            recentlyBeaten100k.InsertLast(UnbeatenATMap(track, keysRB, true));
            if ((i+1) % 100 == 0) yield();
        }
    }

    bool get_LoadingDone() {
        return doneLoading && doneLoadingRecent;
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
        filters.OnBeforeUpdate();
        uint lastPause = Time::Now;
        for (uint i = 0; i < maps.Length; i++) {
            if (lastPause + 4 < Time::Now) {
                yield();
                lastPause = Time::Now;
            }
            auto item = maps[i];
            if (filters.Matches(item)) {
                filteredMaps.InsertLast(item);
            }
        }
        UpdateSortOrder();
    }

    void UpdateSortOrder() {
        // too slow!
        // sorting.sort(filteredMaps);
    }
}

enum Ord {
    EQ, LT, GT, LTE, GTE
}

class UnbeatenATFilters {

    bool First100KOnly = true;
    bool ReverseOrder = false;
    bool FilterNbPlayers = false;
    int NbPlayers = 0;
    uint NbPlayersOrd = Ord::LTE;
    string AuthorFilter;
    string MapNameFilter;
    string BeatenByFilter;

    UnbeatenATFilters() {}
    UnbeatenATFilters(UnbeatenATFilters@ other) {
        First100KOnly = other.First100KOnly;
        FilterNbPlayers = other.FilterNbPlayers;
        NbPlayers = other.NbPlayers;
        NbPlayersOrd = other.NbPlayersOrd;
        ReverseOrder = other.ReverseOrder;
        AuthorFilter = other.AuthorFilter;
        MapNameFilter = other.MapNameFilter;
        BeatenByFilter = other.BeatenByFilter;
    }

    bool opEquals(const UnbeatenATFilters@ other) {
        return true
            && First100KOnly == other.First100KOnly
            && FilterNbPlayers == other.FilterNbPlayers
            && NbPlayers == other.NbPlayers
            && NbPlayersOrd == other.NbPlayersOrd
            && ReverseOrder == other.ReverseOrder
            && AuthorFilter == other.AuthorFilter
            && MapNameFilter == other.MapNameFilter
            && BeatenByFilter == other.BeatenByFilter
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
        if (!MatchString(authorSParts, map.AuthorDisplayName)) return false;
        if (!MatchString(mapNameSParts, map.Track_Name)) return false;
        if (!MatchString(beatenBySParts, map.ATBeatenUserDisplayName)) return false;

        return true;
    }

    void Draw(bool includeBeatenFilters = false) {
        First100KOnly = UI::Checkbox("IDs <= 100k", First100KOnly);
        bool afChanged, mnfChanged, bbfChanged;
        AuthorFilter = UI::InputText("Author", AuthorFilter, afChanged);
        MapNameFilter = UI::InputText("Map Name", MapNameFilter, mnfChanged);
        if (includeBeatenFilters) {
            BeatenByFilter = UI::InputText("Beaten By", BeatenByFilter, bbfChanged);
        }
        // UI::SameLine();
        // ReverseOrder = UI::Checkbox("Reverse Order", ReverseOrder);
    }

    // for the ReverseOrder option, but not sure I want to do it this way
    // int TransformIx(int ix) {}

    string[]@ authorSParts = {};
    string[]@ mapNameSParts = {};
    string[]@ beatenBySParts = {};

    void OnBeforeUpdate() {
        @authorSParts = AuthorFilter.ToLower().Split("*");
        // authorSParts.InsertAt(0, '');
        @mapNameSParts = MapNameFilter.ToLower().Split("*");
        // mapNameSParts.InsertAt(0, '');
        @beatenBySParts = BeatenByFilter.ToLower().Split("*");
        // beatenBySParts.InsertAt(0, '');
    }


    bool MatchString(string[]@ searchParts, const string &in text) {
        if (searchParts.Length > 0) {
            string rem = text.ToLower();
            int _ix = 0;
            for (uint i = 0; i < searchParts.Length; i++) {
                if (searchParts[i].Length == 0) continue;
                // if (i == 0 && searchParts[i].Length > 0 && !rem.StartsWith(searchParts[i])) {
                //     return false;
                // } else {
                // }
                _ix = rem.IndexOf(searchParts[i]);
                if (_ix < 0) return false;
                rem = rem.SubStr(_ix + searchParts[i].Length);
            }
        }
        return true;
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

    void sort(UnbeatenATMap@[]@ maps) {
        _g_sortingOrder = order;
        maps.Sort(_g_sortingLess);
    }

    void Draw() {

    }
}

UnbeatenTableSort _g_sortingOrder = UnbeatenTableSort::TMX_ID;


bool _g_sortingLess(const UnbeatenATMap@ &in a, const UnbeatenATMap@ &in b) {
    if (_g_sortingOrder == UnbeatenTableSort::TMX_ID) {
        return a.TrackID < b.TrackID;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Name) {
        return a.Track_Name < b.Track_Name;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Author_Name) {
        return a._AuthorDisplayName < b._AuthorDisplayName;
    }
    if (_g_sortingOrder == UnbeatenTableSort::Nb_Players) {
        return a.NbPlayers < b.NbPlayers;
    }
    if (_g_sortingOrder == UnbeatenTableSort::AT) {
        return a.AuthorTime < b.AuthorTime;
    }
    return a.TrackID < b.TrackID;
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

int lastPickedTrackID;

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
    int ATBeatenTimestamp;
    string ATBeatenUser;

    bool hasPlayed = false;
    bool isBeaten = false;

    UnbeatenATMap(Json::Value@ row, string[]@ keys, bool isBeaten = false) {
        @this.row = row;
        @this.keys = keys;
        this.isBeaten = isBeaten;
        PopulateData();
    }

    void PopulateData () {
        TrackID = GetData('TrackID', TrackID);
        AuthorTime = GetData('AuthorTime', AuthorTime);
        ATFormatted = Time::Format(AuthorTime);
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
        if (isBeaten) {
            ATBeatenTimestamp = GetData('ATBeatenTimestamp', ATBeatenTimestamp);
            ATBeatenUser = GetData('ATBeatenUsers', ATBeatenUser);
            QueueWsidNameCache(ATBeatenUser);
        }
        hasPlayed = HasPlayedTrack(TrackID);
    }

    string CSVHeader() {
        return string::Join(keys, ",") + "\n";
    }

    string CSVRow() {
        auto rowStr = Json::Write(row);
        return rowStr.SubStr(1, rowStr.Length - 2) + "\n";
    }

    string _AuthorDisplayName;
    string get_AuthorDisplayName() const {
        return GetDisplayNameForLogin(AuthorLogin);
        // if (_AuthorDisplayName.Length > 0) return _AuthorDisplayName;
        // if (loginCache.HasKey(AuthorLogin)) _AuthorDisplayName = GetDisplayNameForLogin(AuthorLogin);
    }

    string get_ATBeatenUserDisplayName() const {
        return GetDisplayNameForWsid(ATBeatenUser);
    }

    string ATFormatted;

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

    void OnClickPlayMapCoro() {
        try {
            MarkTrackPlayed(TrackID);
            this.hasPlayed = true;
        } catch {
            NotifyWarning("Failed to mark track as played D:\nException: " + getExceptionInfo());
        }
        LoadMapNow(MapMonitor::MapUrl(TrackID));
    }

    void DrawUnbeatenTableRow(int i) {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        UI::TableNextRow();

        DrawTableStartCols(i);

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

        DrawTableEndCols();
        UI::PopStyleVar();
    }

    void DrawBeatenTableRow(int i) {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        UI::TableNextRow();

        DrawTableStartCols(i);

        UI::TableNextColumn();
        UI::Text(Time::Format(AuthorTime));

        UI::TableNextColumn();
        UI::Text(WR >= 0 ? Time::Format(WR) : "--");

        // missing time
        UI::TableNextColumn();
        UI::Text(ATBeatenUserDisplayName);

        DrawTableEndCols();
        UI::PopStyleVar();
    }

    // 3 cols
    void DrawTableStartCols(int i) {
        UI::TableNextColumn();
        UI::Text(tostring(i) + ".");

        UI::TableNextColumn();
        auto btnLab = Icons::Play + " " + TrackID;
        if (lastPickedTrackID == TrackID ? UI::ButtonColored(btnLab, .3) :
            hasPlayed ? UI::ButtonColored(btnLab, S_PlayedMapColor) : UI::Button(btnLab)) {
            lastPickedTrackID = TrackID;
            startnew(CoroutineFunc(OnClickPlayMapCoro));
        }
        AddSimpleTooltip("Load Map " + TrackID + ": " + Track_Name);

        UI::TableNextColumn();
        UI::Text(Track_Name);

        UI::TableNextColumn();
        UI::Text(AuthorDisplayName);
    }

    // 2 cols
    void DrawTableEndCols() {
        // player count
        UI::TableNextColumn();
        UI::Text("" + NbPlayers);

        // links
        UI::TableNextColumn();
        DrawLinkButtons();
    }

    void DrawLinkButtons() {
        // tmx + tm.io
        if (UI::Button("TM.io##" + TrackID)) {
            OpenBrowserURL("https://trackmania.io/#/leaderboard/"+TrackUID+"?utm_source=unbeated-ats-plugin");
        }
        UI::SameLine();
        if (UI::Button("TMX##" + TrackID)) {
            OpenBrowserURL("https://trackmania.exchange/maps/"+TrackID+"?utm_source=unbeated-ats-plugin");
        }
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
