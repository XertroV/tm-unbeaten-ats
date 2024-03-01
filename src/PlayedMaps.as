const string PlayedTracksDbPath = IO::FromStorageFolder("played_tracks.txt");

dictionary@ PlayedTracks;

void MarkTrackPlayed(int TrackID) {
    if (HasPlayedTrack(TrackID)) return;
    IO::File f(PlayedTracksDbPath, IO::FileMode::Append);
    string tid = tostring(TrackID);
    f.WriteLine(tid);
    PlayedTracks[tid] = true;
    trace('Mark track as played: ' + tid);
}

void LoadPlayedTracks() {
    if (PlayedTracks is null) {
        @PlayedTracks = dictionary();
    }
    if (!IO::FileExists(PlayedTracksDbPath)) {
        return;
    }

    IO::File f(PlayedTracksDbPath, IO::FileMode::Read);
    string l = "";
    while ((l = f.ReadLine()).Length > 0) {
        l = l.Trim();
        if (l.Length > 0)
            PlayedTracks[l] = true;
        else {
            trace("Invalid track ID in played tracks db: " + l);
        }
    }
    trace('Loaded played tracks: ' + PlayedTracks.GetSize());
}

bool HasPlayedTrack(int TrackID) {
    return PlayedTracks.Exists(tostring(TrackID));
}
