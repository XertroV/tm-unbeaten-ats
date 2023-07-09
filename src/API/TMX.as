const string TmxBaseUrl = "https://map-monitor.xk.io";

namespace TMX {
    const string getMapByUidEndpoint = "https://trackmania.exchange/api/maps/get_map_info/uid/{id}";

    // <https://api2.mania.exchange/Method/Index/37>
    Json::Value@ GetMapFromUid(const string &in uid) {
        string url = getMapByUidEndpoint.Replace("{id}", uid);
        auto req = PluginGetRequest(url);
        req.Start();
        while (!req.Finished()) yield();
        if (req.ResponseCode() >= 400 || req.ResponseCode() < 200 || req.Error().Length > 0) {
            warn("[status:" + req.ResponseCode() + "] Error getting map by UID from TMX: " + req.Error());
            return null;
        }
        // log_info("Debug tmx get map by uid: " + req.String());
        return Json::Parse(req.String());
    }

    Json::Value@ GetTmxTags() {
        auto req = PluginGetRequest("https://map-monitor.xk.io/api/tags/gettags");
        req.Start();
        yield();
        while (!req.Finished()) yield();
        if (req.ResponseCode() == 200) {
            return req.Json();
        }
        warn("[status:" + req.ResponseCode() + "] Error getting api/tags/gettags: " + req.Error());
        return GetTmxTags_Direct();
    }

    Json::Value@ GetTmxTags_Direct() {
        auto req = PluginGetRequest("https://trackmania.exchange/api/tags/gettags");
        req.Start();
        yield();
        while (!req.Finished()) yield();
        if (req.ResponseCode() == 200) {
            return req.Json();
        }
        warn("[status:" + req.ResponseCode() + "] Error getting api/tags/gettags: " + req.Error());
        return null;
    }

    void OpenTmxTrack(int TrackID) {
#if DEPENDENCY_MANIAEXCHANGE
        try {
            if (S_OpenTmxInManiaExchange && Meta::GetPluginFromID("ManiaExchange").Enabled) {
                ManiaExchange::ShowMapInfo(TrackID);
                return;
            }
        } catch {}
#endif
        OpenBrowserURL("https://trackmania.exchange/s/tr/" + TrackID);
    }

    void OpenTmxAuthor(int TMXAuthorID) {
#if DEPENDENCY_MANIAEXCHANGE
        try {
            if (S_OpenTmxInManiaExchange && Meta::GetPluginFromID("ManiaExchange").Enabled) {
                ManiaExchange::ShowUserInfo(TMXAuthorID);
                return;
            }
        } catch {}
#endif
        OpenBrowserURL("https://trackmania.exchange/user/profile/" + TMXAuthorID);
    }
}
