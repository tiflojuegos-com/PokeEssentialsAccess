# Resets the mod's mutable module state between suites, so a suite cannot leak into the next and a failure
# points at its own cause (the tracing the runner is built for). Each call restores every Config schema
# default, clears the game globals, the registered puzzle defs, the per-run caches, the contextual info,
# the battle reference, the locator's map memory, the cursor dedup table, the test map (id + events, which
# key the per-map lever/push caches), and the speak log.
module Reset
  # Runs before each suite. Every reset is guarded so a not-yet-loaded module never aborts the run.
  def self.between_suites
    (reset_config rescue nil)
    (reset_globals rescue nil)
    (PokeAccess::Puzzles.instance_variable_set(:@defs, {}) rescue nil)
    (PokeAccess::Caches.reset_all rescue nil)
    (PokeAccess::Info.set_info(nil, nil) rescue nil)
    (PokeAccess::Battle.clear_battle rescue nil)
    (PokeAccess::Battle.battle_ended rescue nil)
    (PokeAccess::Locator.forget_map rescue nil)
    (PokeAccess::Cursor.reset_global rescue nil)
    (reset_map rescue nil)
    (SpeakCapture.clear rescue nil)
  rescue StandardError
    nil
  end

  # Re-applies every Config::SCHEMA default (row[0]=key, row[1]=default), guarded per row, so a suite that
  # tunes a setting (astar_max, volumes, language) cannot leak it into the next suite.
  def self.reset_config
    PokeAccess::Config::SCHEMA.each do |row|
      (PokeAccess::Config.send("#{row[0]}=", row[1]) rescue nil)
    end
    # The key rebinds are NOT in SCHEMA (they live in Config::OTHER), so the loop above never reached
    # them: a suite that bound a key left it bound for every suite after it, silently changing which
    # keys the mod answers to. They reset to empty, which is what a player with no rebinds has.
    (PokeAccess::Config.rebinds = {} rescue nil)
    (PokeAccess::Config.rebind_labels = {} rescue nil)
  end

  # Empties $game_variables / $game_switches (hashes in the stubs, so clear keeps their defaults), removing
  # values a suite wrote (e.g. a \v[n] interpolation fixture).
  def self.reset_globals
    ($game_variables.clear if $game_variables.respond_to?(:clear))
    ($game_switches.clear if $game_switches.respond_to?(:clear))
  end

  # Restores a fresh test map (id 1, no events, no ledges, no loaded grid) and player position, so the per-map
  # caches keyed on map_id (lever/push) never carry events from a previous suite and neither a placed ledge nor
  # a grid's walls leak forward into a suite that assumes open space.
  def self.reset_map
    return unless $game_map
    $game_map.map_id = 1
    ($game_map.events.clear if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash))
    ($game_map.clear_ledges if $game_map.respond_to?(:clear_ledges))
    ($game_map.clear_grid if $game_map.respond_to?(:clear_grid))
    ($game_player.x = 5; $game_player.y = 5) if $game_player
  end
end
