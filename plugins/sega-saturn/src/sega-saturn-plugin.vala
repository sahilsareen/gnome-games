// This file is part of GNOME Games. License: GPLv3

private class Games.SegaSaturnPlugin : Object, Plugin {
	private const string MIME_TYPE = "application/x-saturn-rom";

	public GameSource get_game_source () throws Error {
		var query = new MimeTypeTrackerQuery (MIME_TYPE, game_for_uri);
		var connection = Tracker.Sparql.Connection.@get ();
		var source = new TrackerGameSource (connection);
		source.add_query (query);

		return source;
	}

	private static Game game_for_uri (string uri) throws Error {
		return new SegaSaturnGame (uri);
	}
}

[ModuleInit]
public Type register_games_plugin (TypeModule module) {
	return typeof(Games.SegaSaturnPlugin);
}
