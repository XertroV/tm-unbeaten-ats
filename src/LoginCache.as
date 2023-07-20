string[] loginQueue;
string[] wsidQueue;
Json::Value@ loginCache = Json::Object();
Json::Value@ wsidCache = Json::Object();
Json::Value@ loginQueued = Json::Object();
Json::Value@ wsidQueued = Json::Object();

string GetDisplayNameForLogin(const string &in login) {
    if (!loginCache.HasKey(login)) {
        return "?? " + login;
    }
    // string ret;
    return loginCache.Get(login, login);
    // return ret;
}
string GetDisplayNameForWsid(const string &in wsid) {
    if (!wsidCache.HasKey(wsid)) {
        return "?? " + wsid;
    }
    // string ret;
    return wsidCache.Get(wsid, wsid);
    // return ret;
}

void QueueAuthorLoginCache(const string &in login) {
    if (loginCache.HasKey(login) || loginQueued.HasKey(login)) return;
    loginQueued[login] = true;
    loginQueue.InsertLast(login);
}
void QueueWsidNameCache(const string &in wsid) {
    if (wsidCache.HasKey(wsid) || wsidQueued.HasKey(wsid)) return;
    wsidQueued[wsid] = true;
    wsidQueue.InsertLast(wsid);
}

bool startedAuthorLoginLoop = false;
void GetAuthorLoginLoop() {
    if (startedAuthorLoginLoop) return;
    startedAuthorLoginLoop = true;

    while (true) {
        yield();
        if (loginQueue.Length > 0) {
            string[] wsids;
            string[] logins;
            while (wsids.Length < 50 && loginQueue.Length > 0) {
                int last = loginQueue.Length - 1;
                wsids.InsertLast(LoginToWSID(loginQueue[last]));
                logins.InsertLast(loginQueue[last]);
                loginQueue.RemoveLast();
            }
            auto resp = Core::WSIDsToNames(wsids);
            // trace("Got display names: " + wsids.Length);
            for (uint i = 0; i < wsids.Length; i++) {
                loginCache[logins[i]] = resp.GetDisplayName(wsids[i]);
                wsidCache[wsids[i]] = resp.GetDisplayName(wsids[i]);
                // print("Login: " + logins[i] + " = " + string(loginCache[logins[i]]));
            }
        } else {
            sleep(250);
        }
    }
}

bool startedWsidLoop = false;
void GetWsidLoop() {
    if (startedWsidLoop) return;
    startedWsidLoop = true;

    while (true) {
        yield();
        if (wsidQueue.Length > 0) {
            string[] wsids;
            while (wsids.Length < 50 && wsidQueue.Length > 0) {
                int last = wsidQueue.Length - 1;
                wsids.InsertLast(wsidQueue[last]);
                wsidQueue.RemoveLast();
            }
            auto resp = Core::WSIDsToNames(wsids);
            trace("Got display names: " + wsids.Length);
            for (uint i = 0; i < wsids.Length; i++) {
                wsidCache[wsids[i]] = StrOrDefault(resp.GetDisplayName(wsids[i]), wsids[i]);
            }
        } else {
            sleep(250);
        }
    }
}

const string StrOrDefault(const string &in a, const string &in d) {
    return a.Length == 0 ? d : a;
}

string LoginToWSID(const string &in login) {
    try {
        auto buf = MemoryBuffer();
        buf.WriteFromBase64(login, true);
        auto hex = BufferToHex(buf);
        return hex.SubStr(0, 8)
            + "-" + hex.SubStr(8, 4)
            + "-" + hex.SubStr(12, 4)
            + "-" + hex.SubStr(16, 4)
            + "-" + hex.SubStr(20)
            ;
    } catch {
        warn("Login failed to convert: " + login);
        return login;
    }
}

string BufferToHex(MemoryBuffer@ buf) {
    buf.Seek(0);
    auto size = buf.GetSize();
    string ret;
    for (uint i = 0; i < size; i++) {
        ret += Uint8ToHex(buf.ReadUInt8());
    }
    return ret;
}

string Uint8ToHex(uint8 val) {
    return Uint4ToHex(val >> 4) + Uint4ToHex(val & 0xF);
}

string Uint4ToHex(uint8 val) {
    if (val > 0xF) throw('val out of range: ' + val);
    string ret = " ";
    if (val < 10) {
        ret[0] = val + 0x30;
    } else {
        // 0x61 = a
        ret[0] = val - 10 + 0x61;
    }
    return ret;
}
