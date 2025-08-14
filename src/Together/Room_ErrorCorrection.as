#if DEPENDENCY_BETTERROOMMANAGER
// original source: bosslike/src/Room_ErrorCorrection.as
// original author: XertroV

const int HOURS_48_IN_SECS = 172800;

namespace RoomErrorCorrection {
	// updated periodically through EC process
	string _lastMsg;
	// if the last message was an error
	bool _lastMsgIsError;
	// time of last message
	uint _lastMsgTime = 0;
	// if the EC process exits after this msg.
	bool _lastMsgTerminal;

	bool get_HasActiveMsg() {
		return _lastMsgTime > 0 && (
			!_lastMsgTerminal
			|| Time::Now - _lastMsgTime < 15000
		);
	}

	void Render() {
		if (!HasActiveMsg) return;
        UI::Text(_lastMsg);
		// Game::Render::NvgStatusBox_Exclusive(
		// 	// "Room/Map Error Correction",
		// 	// _lastMsg
		// );
	}

	void SetMapCorrectionMsg(const string &in msg, bool error = false, bool terminal = false) {
		_lastMsg = msg;
		_lastMsgIsError = error;
		_lastMsgTime = Time::Now;
		_lastMsgTerminal = terminal;
		if (!error) {
			print("\\$bfb[Room/Map Err Correction] \\$i\\$bfb" + msg);
		} else {
			print("\\$f70[Room/Map Err Correction] \\$i\\$ffa" + msg);
		}
	}

	void ThrowMapCorrectionMsg(const string &in msg) {
		SetMapCorrectionMsg(msg, true, true);
		throw(msg);
	}

	void OnFailedToLoadCorrectMap(ChangeRoomParams@ toPrams) {
		// the server didn't load the map. We need to fix the server config.

		// wait for
		SetMapCorrectionMsg("Waiting for UI Sequence == Playing");
		while (!IsPlayingOrFinish(CurrentUISequence())) yield();
		yield(10);
		while (!IsPlayingOrFinish(CurrentUISequence())) yield();


		// prep
		SetMapCorrectionMsg("Updating room settings to match current mode and map");
		auto app = GetApp();
		if (app.RootMap is null) ThrowMapCorrectionMsg("RootMap is null");

		auto currentMapId = app.RootMap.Id.Value;
		auto currentMapUid = app.RootMap.IdName;
		auto bsi = BRM::GetCurrentServerInfo(app, true);
		auto builder = BRM::CreateRoomBuilder(bsi.clubId, bsi.roomId);
		auto @loadSettingsCoro = startnew(LoadBuilderSettingsCoro, builder);
		if (loadSettingsCoro.IsRunning()) {
			print("Started LoadBuilderSettingsCoro");
		} else {
			ThrowMapCorrectionMsg("Failed to start LoadBuilderSettingsCoro");
		}

		// wait a moment for anything to happen
		sleep(2000);
		if (app.RootMap.Id.Value != currentMapId) ThrowMapCorrectionMsg("Map was changed. Cancelling recovery.");

		// Recover server

		// get settings and change to match game mode and map with -1 timeout

		// auto pish = cast<CSmArenaInterfaceManialinkScripHandler>(app.Network.PlaygroundInterfaceScriptHandler);
		auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
		auto isInTA = si.CurGameModeStr == "TM_TimeAttack_Online";
		auto isInRoyalTA = si.CurGameModeStr == "TM_RoyalTimeAttack_Online";
		auto currMode = isInTA ? BRM::GameMode::TimeAttack : BRM::GameMode::RoyalTimeAttack;
		int rulesEnd = GetRulesEndTime();
		// auto newMode = isInTA ? BRM::GameMode::RoyalTimeAttack : BRM::GameMode::TimeAttack;
		// auto newMode = toPrams.toMode;


		if (!isInRoyalTA && !isInTA) ThrowMapCorrectionMsg("Server in unknown mode: " + si.CurGameModeStr);

		if (loadSettingsCoro.IsRunning()) {
			await(loadSettingsCoro);
		} else {
			print("LoadBuilderSettingsCoro is not running");
		}
		if (app.RootMap.Id.Value != currentMapId) ThrowMapCorrectionMsg("Map was changed. Cancelling recovery.");
		SetMapCorrectionMsg("Got Room settings.");

		// set to current stuff
		auto resp = builder.SetMode(currMode)
			.SetTimeLimit(rulesEnd < 0 ? HOURS_48_IN_SECS : -1)
			.SetChatTime(10)
			.SetMaps({currentMapUid})
			.SaveRoom();
		print("Server Recovery update settings 1 resp: " + Json::Write(resp));
		SetMapCorrectionMsg("Awaiting server settings update");

		bool rulesEndChanged = AwaitChangeInRulesEndTime_OrTimeout(rulesEnd, 10000);
		if (!rulesEndChanged) {
			SetMapCorrectionMsg("Did not detect server settings update. Proceeding anyway to set time limit.", true);
		} else {
			SetMapCorrectionMsg("Setting time limit to near future + 10s S_ChatTime.");
		}

		// change timeout and longer chat time
		int elapsed = GetServerCurrentRulesElapsedSeconds();
		bool isEarly = elapsed < 10;
		bool elapsedIsHuge = elapsed > 3600;
		if (elapsedIsHuge) {
			warn("Unexpected: elapsed time is huge: " + elapsed);
			warn("RulesStartTime: " + GetRulesStartTime());
			warn("GameTime: " + PlaygroundNow());
			warn("RulesEndTime: " + GetRulesEndTime());
		}
		elapsed = Math::Clamp(elapsed, 10, 120);

		rulesEnd = GetRulesEndTime();

		@resp = builder.SetTimeLimit(elapsed + 15)
			.SetChatTime(11)
			.SaveRoom();
		print("Server Recovery update settings 2 resp: " + Json::Write(resp));

		rulesEndChanged = AwaitChangeInRulesEndTime_OrTimeout(rulesEnd, 10000);
		if (rulesEndChanged) SetMapCorrectionMsg("Waiting for round to end.");
		else SetMapCorrectionMsg("Did not detect server settings update. Waiting for end of round anyway (skip map could manually fix if stuck, maybe).", true);

		while (IsPlayingOrFinish(CurrentUISequence())) yield();
		SetMapCorrectionMsg("Updating server mode. (Long delay expected)");

		// change mode
		@resp = SetRoomDecoUrls(builder)
			.SetMode(toPrams.toMode).SetMaps({toPrams.toMapUid})
			.SaveRoom();
		print("Server Recovery update settings 3 resp: " + Json::Write(resp));
		SetMapCorrectionMsg("Updated server mode. (Long delay expected)");

		while (CurrentUISequence() != SGamePlaygroundUIConfig::EUISequence::None) yield();
		while (CurrentUISequence() == SGamePlaygroundUIConfig::EUISequence::None || app.RootMap is null) yield();

		if (app.RootMap.IdName == toPrams.toMapUid) {
			SetMapCorrectionMsg("Server recovered successfully. Removing Time Limit.");
			while (!IsIntroOrPlayingOrFinish(CurrentUISequence())) yield();
			@resp = SetRoomDecoUrls(builder).SetTimeLimit(-1)
				.SetChatTime(9)
				.SaveRoom();

			while (!IsIntroOrPlayingOrFinish(CurrentUISequence())) yield();
			SetMapCorrectionMsg("Server recovered. Time limit reset to -1.", false, true);
			// todo: startnew(ReportMapCorrectionSuccess, fromData, toPrams.toMapUid, finalData);
			return;
		} else {
			SetMapCorrectionMsg("Server failed to recover. Map still incorrect :(.", true, true);
			// todo: startnew(ReportMapCorrectionFailure, fromData, toPrams.toMapUid, finalData);
		}
	}
}

BRM::IRoomSettingsBuilder@ SetRoomDecoUrls(BRM::IRoomSettingsBuilder@ builder) {
	// todo: set deco urls based on settings
	builder.SetModeSetting("S_DisableGoToMap", "true");
	return builder;
}

void OnFailedToLoadCorrectMapCoro(ref@ paramsRef) {
	auto params = cast<ChangeRoomParams>(paramsRef);
	if (params is null) {
		RoomErrorCorrection::ThrowMapCorrectionMsg("ChangeRoomParams is null");
		return;
	}
	RoomErrorCorrection::OnFailedToLoadCorrectMap(params);
}

void LoadBuilderSettingsCoro(ref@ builderRef) {
	auto builder = cast<BRM::IRoomSettingsBuilder>(builderRef);
	if (builder is null) {
		RoomErrorCorrection::ThrowMapCorrectionMsg("Builder is null");
		return;
	}
	builder.LoadCurrentSettingsAsync();
	print("LoadBuilderSettingsCoro: Done!");
}

// Wait for a change in the rules end time, or timeout. return true if the rules end time changed.
bool AwaitChangeInRulesEndTime_OrTimeout(int origEndTime, int timeoutMs) {
	awaitany({Start_AwaitChangeInRulesEndTime(origEndTime), Start_SleepCoro(timeoutMs)});
	return int(GetRulesEndTime()) != origEndTime;
}


awaitable@ Start_AwaitChangeInRulesEndTime(int origEndTime) {
	return startnew(AwaitChangeInRulesEndTime, origEndTime);
}

void AwaitChangeInRulesEndTime(int64 origEndTime) {
	while (int(GetRulesEndTime()) == int(origEndTime)) {
		yield();
	}
}

awaitable@ Start_SleepCoro(int ms) {
	return startnew(SleepCoro, ms);
}

void SleepCoro(int64 ms) {
	sleep(ms);
}



// -------- SUPPORTING FUNCTIONS ----------

int GetServerCurrentRulesElapsedSeconds() {
	return GetServerCurrentRulesElapsedMillis() / 1000 + 1;
}

int GetServerCurrentRulesElapsedMillis() {
    int start_time = GetRulesStartTime();
	if (start_time < 0) return -1;
    int64 game_time = PlaygroundNow();
	if (start_time > game_time) return -1;
	return game_time - start_time;
}

// measured in ms
uint PlaygroundNow() {
	auto app = GetApp();
	// auto pg = app.Network.PlaygroundClientScriptAPI;
	auto pg = app.Network.PlaygroundInterfaceScriptHandler;
	if (pg is null) return uint(-1);
	return uint(pg.GameTime);
}

// measured in ms
uint GetRulesStartTime() {
	auto app = GetApp();
	auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
	if (cp is null || cp.Arena is null || cp.Arena.Rules is null) return uint(-1);
	return uint(cp.Arena.Rules.RulesStateStartTime);
}

// measured in ms
uint GetRulesEndTime() {
	auto app = GetApp();
	auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
	if (cp is null || cp.Arena is null || cp.Arena.Rules is null) return uint(-1);
	return uint(cp.Arena.Rules.RulesStateEndTime);
}

SGamePlaygroundUIConfig::EUISequence CurrentUISequence() {
	try {
		auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
		return cp.GameTerminals[0].UISequence_Current;
	} catch {}
	return SGamePlaygroundUIConfig::EUISequence::None;
}

bool IsUISeqNone(SGamePlaygroundUIConfig::EUISequence seq) {
	return seq == SGamePlaygroundUIConfig::EUISequence::None;
}

bool IsIntroOrPlayingOrFinish(SGamePlaygroundUIConfig::EUISequence seq) {
	return seq == SGamePlaygroundUIConfig::EUISequence::Intro || seq == SGamePlaygroundUIConfig::EUISequence::Playing || seq == SGamePlaygroundUIConfig::EUISequence::Finish;
}


// Used to avoid Playing sometimes triggering false positives before intro (happens for a second or two sometimes)
bool IsGameTimeAndStartTimePlaying() {
    auto rules_start = GetRulesStartTime();
	return PlaygroundNow() > rules_start && rules_start >= 0;
}

bool IsPlaying(SGamePlaygroundUIConfig::EUISequence seq) {
	return seq == SGamePlaygroundUIConfig::EUISequence::Playing
		&& IsGameTimeAndStartTimePlaying();
}


bool IsPlayingOrFinish(SGamePlaygroundUIConfig::EUISequence seq) {
	bool goodSeq = seq == SGamePlaygroundUIConfig::EUISequence::Playing || seq == SGamePlaygroundUIConfig::EUISequence::Finish;
	return goodSeq && IsGameTimeAndStartTimePlaying();
}



#endif
