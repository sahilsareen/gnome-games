// This file is part of GNOME Games. License: GPLv3

private class Games.GameBoyAdvancePlugin : Object, Plugin {
	private const string FINGERPRINT_PREFIX = "game-boy-advance";
	private const string MIME_TYPE = "application/x-gba-rom";
	private const string MODULE_BASENAME = "libretro-game-boy-advance.so";
	private const bool SUPPORTS_SNAPSHOTTING = true;

	public GameSource get_game_source () throws Error {
		var query = new MimeTypeTrackerQuery (MIME_TYPE, game_for_uri);
		var connection = Tracker.Sparql.Connection.@get ();
		var source = new TrackerGameSource (connection);
		source.add_query (query);

		return source;
	}

	private static Game game_for_uri (string uri) throws Error {
		var uid = new FingerprintUid (uri, FINGERPRINT_PREFIX);
		var title = new FilenameTitle (uri);
		var cover = new DummyCover ();
		var runner =  new RetroRunner (MODULE_BASENAME, uri, uid, SUPPORTS_SNAPSHOTTING);

		return new GenericGame (title, cover, runner);
	}
}

[ModuleInit]
public Type register_games_plugin (TypeModule module) {
	return typeof(Games.GameBoyAdvancePlugin);
}
