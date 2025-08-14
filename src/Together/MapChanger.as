#if DEPENDENCY_BETTERROOMMANAGER
// original source: bosslike/src/GameS/State/MapChanger.as
// original author: XertroV

// Flavors of game mode that the map changer supports. Note: TA could be Online or PlayMap_Local. Similar for Royal.
enum GameModeFlavor {
	TimeAttack,
	Royal,
	Unknown
}

GameModeFlavor GameModeFlavor_FromBrmMode(BRM::GameMode brmMode) {
	switch (brmMode) {
		case BRM::GameMode::TimeAttack:
			return GameModeFlavor::TimeAttack;
		case BRM::GameMode::RoyalTimeAttack:
			return GameModeFlavor::Royal;
	}
	return GameModeFlavor::Unknown;
}

// Class to manage changing maps (e.g., for solo or in a server)
abstract class MapChanger {
	protected string nextMap;
	string[] mapHist;
	protected GameModeFlavor nextModeFlavor;

	MapChanger() {}

	// MARK: Implementations Needed

	// Actually change the map. Can block. Returns when the next map has been loaded.
	void RunChangeMap_Async() {
		throw("Implemented elsewhere");
	}

	// MARK: Provided

	MapChanger@ WithNextMap(const string &in mapUidOrUrl, GameModeFlavor mode) {
		// Set the next map to change to
		nextMap = mapUidOrUrl;
		mapHist.InsertLast(mapUidOrUrl);
		nextModeFlavor = mode;
		return this;
	}

	// Actually change the map. Starts RunChangeMap_Async in a coroutine.
	awaitable@ RunChangeMap_InBg() {
		return startnew(CoroutineFunc(this.RunChangeMap_Async));
	}

	// nextModeFlavor -> string (for use with `PlayMap()`)
	string GetLocalModeScriptName() {
		switch (nextModeFlavor) {
			case GameModeFlavor::TimeAttack:
				return "TrackMania/TM_PlayMap_Local";
			case GameModeFlavor::Royal:
				return "TrackMania/TM_RoyalTimeAttack_Local";
				// return "TM_RoyalTimeAttack_Online";
		}
		throw("Unknown game mode flavor: " + tostring(nextModeFlavor));
		return "";
	}

	// nextModeFlavor -> BRM::GameMode
	BRM::GameMode GetServerModeType() {
		switch (nextModeFlavor) {
			case GameModeFlavor::TimeAttack:
				return BRM::GameMode::TimeAttack;
			case GameModeFlavor::Royal:
				return BRM::GameMode::RoyalTimeAttack;
		}
		throw("Unknown game mode flavor: " + tostring(nextModeFlavor));
		return BRM::GameMode::TimeAttack;
	}

	// Override if it's not okay to change the map from anywhere.
	bool IsMapChangeOkay() {
		return true;
	}
}


// class LocalMapChanger : MapChanger {
// 	LocalMapChanger() {
// 		super();
// 	}

// 	void RunChangeMap_Async() override {
// 		Maps::LoadMap::LoadMapNow(nextMap, GetLocalModeScriptName());
// 	}
// }

class RoomMapChanger : MapChanger {
	RoomMapChanger() {
		super();
	}

	ChangeRoomParams@ changeRoomParams;

	MapChanger@ WithNextMap(const string&in mapUidOrUrl, GameModeFlavor mode) override {
        if (isInProgress && changeRoomParams !is null) changeRoomParams.cancel.Cancel();
		MapChanger::WithNextMap(mapUidOrUrl, mode);
		@this.changeRoomParams = ChangeRoomParams(mapUidOrUrl, GetServerModeType());
		return this;
	}

	bool isInProgress = false;

	void RunChangeMap_Async() override {
		isInProgress = true;
        auto @params = changeRoomParams;
		RunRoomChange(params);
        if (!params.cancel.IsCancelled()) {
            isInProgress = true;
            while (
                !IsPlayingOrFinish(CurrentUISequence())
                && !params.cancel.IsCancelled()
            ) yield();
        }
		isInProgress = false;
	}

	bool IsMapChangeOkay() override {
		// BRM::ServerInfo@ bsi;
		return !isInProgress && Together::ServerInTimeAttackAndAdmin();
			// && (
			// 	(@bsi = BRM::GetCurrentServerInfo(GetApp(), false)) !is null &&
			// 	bsi.isAdmin
			// );
	}
}

class ChangeRoomParams {
	Canceller@ cancel;
	BRM::GameMode toMode;
	string toMapUid;

	ChangeRoomParams(const string &in mapUid, BRM::GameMode mode) {
		@cancel = Canceller();
		toMode = mode;
		toMapUid = mapUid;
	}
}

class Canceller {
	private bool _isCancelled = false;
	Canceller() {}
	void Cancel() {
		_isCancelled = true;
	}
	bool IsCancelled() const {
		return _isCancelled;
	}
}




const string TEST_MAP_CHANGER_TA_MAP = "2fSBFs3oC3PhSbiP5TGlz_AHdxj"; // FATAL ERROR
const string TEST_MAP_CHANGER_ROYAL_MAP = "DOqdkqJQmZXzbB1ZfnZ3P1664i6";

const uint extraTimeoutSecs = 9 - 6;
const uint chatTime = 3 * 0;

void RunRoomChange(ref@ changeRoomParamsRef) {
	auto @params = cast<ChangeRoomParams>(changeRoomParamsRef);
	if (params is null) {
		throw("ChangeRoomParams is null");
		return;
	}
	auto @cancel = params.cancel;

	auto app = GetApp();
	auto bsi = BRM::GetCurrentServerInfo(app, false);
	if (bsi is null) throw("No server info");
	if (!bsi.isAdmin) throw("Not admin");
	if (bsi.clubId < 0) throw("No club id");
	if (bsi.roomId < 0) throw("No room id");

	// // todo: remove when ready
	// // todo: remove when ready
	// if (bsi.clubId != 46587) throw("Not in xertrov's club");


	print("Server info: " + (bsi.clubId) + " / " + bsi.roomId);
	auto builder = BRM::CreateRoomBuilder(bsi.clubId, bsi.roomId);
	builder.LoadCurrentSettingsAsync();
	print("Loaded Settings: " + Json::Write(builder.GetCurrentSettingsJson()));
	auto currGameMode = builder.GetMode();
	bool isRoyalAtm = currGameMode == BRM::GameMode::RoyalTimeAttack;
	bool isTimeAttackAtm = currGameMode == BRM::GameMode::TimeAttack;
	// set timeout to extraTimeoutSecs seconds from now
	int mapCurrS = GetServerCurrentRulesElapsedSeconds();
	int setTimeLimit = mapCurrS + extraTimeoutSecs;
	int currTimeLimit = builder.GetTimeLimit();
	int origGRET = GetRulesEndTime();

	print("Mode: " + tostring(currGameMode) + ", TimeLimit: " + currTimeLimit + " -> " + setTimeLimit);

	builder.SetTimeLimit(setTimeLimit);
	builder.SetChatTime(chatTime);
	if (cancel.IsCancelled()) return;
	builder.SaveRoom();
	// wait for settings to update
	if (currTimeLimit < 0 || currTimeLimit > setTimeLimit) {
		while (origGRET == GetRulesEndTime() && IsPlayingOrFinish(CurrentUISequence())) {
			yield();
		}
	}
	print("Time limit updated (or not playing/finished): GRET | " + origGRET + " -> " + GetRulesEndTime());
	// now prepare new mode

	bool isChangingMode = currGameMode != params.toMode;

	builder.SetMode(params.toMode);
	builder.SetMaps({params.toMapUid});
	SetRoomDecoUrls(builder);

	print("Ready to change mode");
	// wait for UI sequence to change before saving
	while (IsPlayingOrFinish(CurrentUISequence())) {
		yield();
	}
	print("UI Sequence changed: " + tostring(CurrentUISequence()));

	if (cancel.IsCancelled()) return;
	auto resp = builder.SaveRoom();
	if (resp is null) throw("Failed to save room");
	print("Room saved: " + Json::Write(resp));

	if (isChangingMode) {
		// doesn't happen when NOT changing modes (e.g. just changing map)
		while (!IsUISeqNone(CurrentUISequence())) yield();
	}
	while (!IsIntroOrPlayingOrFinish(CurrentUISequence())) yield();

	builder.SetTimeLimit(-1);
	// uint chatTime = 10;
	// if (builder.HasModeSetting("S_ChatTime")) {
	//     auto prevChatTime = Text::ParseInt64(builder.GetModeSetting("S_ChatTime"));
	//     if (prevChatTime == chatTime) {
	//         chatTime += 1;
	//     }
	// }
	builder.SetChatTime(chatTime);
	if (cancel.IsCancelled()) return;
	@resp = SetRoomDecoUrls(builder).SaveRoom();
	print("Time limit reset to -1");

	// while (!IsIntroOrPlayingOrFinish(CurrentUISequence())) yield();
	// check we're on the right map
	string mapUid = app.RootMap.IdName;
	bool wrongMap1 = builder.GetMapUids()[0] != mapUid;
	bool wrongMap = params.toMapUid != mapUid;
	if (wrongMap || wrongMap1) {
		warn("Wrong map after changing mode: curr=" + mapUid + " -> shouldBe=" + params.toMapUid);
		warn("Builder maps: " + Json::Write(builder.GetMapUids().ToJson()));
		// startnew(OnFailedToLoadCorrectMapCoro, params);
		NotifyError("Failed to change map: " + builder.GetMapUids()[0] + " -> " + app.RootMap.IdName);
		RoomErrorCorrection::OnFailedToLoadCorrectMap(params);
	}
}


#endif
