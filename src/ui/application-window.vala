// This file is part of GNOME Games. License: GPLv3

[GtkTemplate (ui = "/org/gnome/Games/ui/application-window.ui")]
private class Games.ApplicationWindow : Gtk.ApplicationWindow {
	private UiState _ui_state;
	public UiState ui_state {
		set {
			if (value == ui_state)
				return;

			_ui_state = value;

			if (ui_state != UiState.COLLECTION)
				search_mode = false;
		}
		get { return _ui_state; }
	}

	private bool _search_mode;
	public bool search_mode {
		set { _search_mode = value && (ui_state == UiState.COLLECTION); }
		get { return _search_mode; }
	}

	[GtkChild]
	private ContentBox content_box;
	private Binding cb_ui_binding;
	private Binding cb_search_binding;

	[GtkChild]
	private HeaderBar header_bar;
	private Binding hb_ui_binding;
	private Binding hb_search_binding;

	private HashTable<Game, Runner> runners;

	private Cancellable run_game_cancellable;
	private Cancellable quit_game_cancellable;

	public ApplicationWindow (ListModel collection) {
		content_box.collection = collection;
	}

	construct {
		runners = new HashTable<Game, Runner> (GLib.direct_hash, GLib.direct_equal);

		cb_ui_binding = content_box.bind_property ("ui-state",
		                                           this, "ui-state", BindingFlags.BIDIRECTIONAL);
		hb_ui_binding = header_bar.bind_property ("ui-state",
		                                          this, "ui-state", BindingFlags.BIDIRECTIONAL);

		cb_search_binding = content_box.bind_property ("search-mode",
		                                               this, "search-mode", BindingFlags.BIDIRECTIONAL);
		hb_search_binding = header_bar.bind_property ("search-mode",
		                                              this, "search-mode", BindingFlags.BIDIRECTIONAL);

		header_bar.display_back.connect (() => {
			if (quit_game ())
				ui_state = UiState.COLLECTION;
		});
	}

	public void run_game (Game game) {
		if (run_game_cancellable != null)
			run_game_cancellable.cancel ();

		run_game_cancellable = new Cancellable ();

		run_game_with_cancellable (game, run_game_cancellable);
	}

	public bool quit_game () {
		// If the window have been deleted/hidden we probably don't want to
		// prompt the user.
		if (!visible)
			return true;

		if (run_game_cancellable != null)
			run_game_cancellable.cancel ();

		if (quit_game_cancellable != null)
			quit_game_cancellable.cancel ();

		quit_game_cancellable = new Cancellable ();

		return quit_game_with_cancellable (quit_game_cancellable);
	}

	[GtkCallback]
	public bool on_delete_event () {
		return !quit_game ();
	}

	[GtkCallback]
	public bool on_key_pressed (Gdk.EventKey event) {
		var default_modifiers = Gtk.accelerator_get_default_mod_mask ();

		if ((event.keyval == Gdk.Key.q || event.keyval == Gdk.Key.Q) &&
		    (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
			if (!quit_game ())
				return false;

			destroy ();

			return true;
		}

		if ((event.keyval == Gdk.Key.f || event.keyval == Gdk.Key.F) &&
		    (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
			if (!search_mode)
				search_mode = true;

			return true;
		}

		if (ui_state == UiState.COLLECTION && content_box.search_bar_handle_event (event))
			return true;

		return false;
	}

	[GtkCallback]
	private void on_game_activated (Game game) {
		run_game (game);
	}

	private void run_game_with_cancellable (Game game, Cancellable cancellable) {
		Runner runner = null;
		try {
			runner = get_runner_for_game (game);
		}
		catch (Error e) {
			warning ("%s\n", e.message);
			content_box.display_error (e.message);

			return;
		}

		header_bar.game_title = game.name;
		content_box.runner = runner;
		ui_state = UiState.DISPLAY;

		var resume = false;

		if (runner.can_resume) {
			var dialog = new ResumeDialog ();
			dialog.set_transient_for (this);

			cancellable.cancelled.connect (() => {
				dialog.destroy ();
			});

			var response = dialog.run ();
			dialog.destroy ();

			if (cancellable.is_cancelled ())
				response = Gtk.ResponseType.CANCEL;

			switch (response) {
			case Gtk.ResponseType.CANCEL:
				content_box.runner = null;
				ui_state = UiState.COLLECTION;

				return;
			case Gtk.ResponseType.REJECT:
				resume = false;

				break;
			case Gtk.ResponseType.ACCEPT:
			default:
				resume = true;

				break;
			}
		}

		try {
			if (resume)
				runner.resume ();
			else
				runner.start ();
		}
		catch (Error e) {
			warning (@"$(e.message)\n");

			return;
		}
	}

	public bool quit_game_with_cancellable (Cancellable cancellable) {
		if (content_box.runner == null)
			return true;

		content_box.runner.pause ();

		if (content_box.runner.can_quit_safely)
			return true;

		var dialog = new QuitDialog ();
		dialog.set_transient_for (this);

		cancellable.cancelled.connect (() => {
			dialog.destroy ();
		});

		var response = dialog.run ();
		dialog.destroy ();

		if (cancellable.is_cancelled ())
			return cancel_quitting_game ();

		if (response == Gtk.ResponseType.ACCEPT)
			return true;

		return cancel_quitting_game ();
	}

	private bool cancel_quitting_game () {
		content_box.ui_state = ui_state;
		header_bar.ui_state = ui_state;

		if (content_box.runner != null)
			content_box.runner.resume ();

		return false;
	}

	private Runner get_runner_for_game (Game game) throws Error {
		if (runners.contains (game))
			return runners[game];

		var runner = game.get_runner ();
		runner.check_is_valid ();
		runners[game] = runner;

		runner.stopped.connect (remove_runner);

		return runner;
	}

	private void remove_runner (Runner runner) {
		foreach (var game in runners.get_keys ()) {
			if (runners[game] == runner)
				runners.remove (game);
		}
	}
}
