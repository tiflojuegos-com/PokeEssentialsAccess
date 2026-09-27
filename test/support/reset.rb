# Resets the mod's mutable module state between suites, so a suite cannot leak into the next: config, globals,
# puzzles, caches, info, battle, locator, cursor dedup, the test map, the input claims, history and the speak log.
module Reset
  # Runs before each suite, each reset guarded; the language is pinned to Spanish, which the literal assertions
  # are written against, rather than the shipped :auto that follows this machine.
  def self.between_suites
    (reset_config rescue nil)
    (PokeAccess::Config.language = :es rescue nil)
    (reset_globals rescue nil)
    (PokeAccess::Puzzles.instance_variable_set(:@defs, {}) rescue nil)
    (PokeAccess::Caches.reset_all rescue nil)
    (PokeAccess::Info.set_info(nil, nil) rescue nil)
    (PokeAccess::Battle.clear_battle rescue nil)
    (PokeAccess::Battle.battle_ended rescue nil)
    (PokeAccess::Locator.forget_map rescue nil)
    (PokeAccess::Cursor.reset_global rescue nil)
    (reset_map rescue nil)
    (reset_keys rescue nil)
    (PokeAccess::History.clear rescue nil)
    (SpeakCapture.clear rescue nil)
  rescue StandardError
    nil
  end

  # Drops the input layer's short-lived claims (typing hold, menu lock, yielded keys), which lapse only with play.
  def self.reset_keys
    k = PokeAccess::Keys
    k.instance_variable_set(:@typing_ttl, 0)
    k.instance_variable_set(:@menu_lock_ttl, 0)
    k.instance_variable_set(:@yielded, {})
  end

  # Re-applies every Config::SCHEMA default (row[0] key, row[1] default), guarded per row, and empties the rebinds
  # (outside SCHEMA) and restores the mod's own keys.
  def self.reset_config
    PokeAccess::Config::SCHEMA.each do |row|
      (PokeAccess::Config.send("#{row[0]}=", row[1]) rescue nil)
    end
    (PokeAccess::Config.rebinds = {} rescue nil)
    (PokeAccess::Config.rebind_labels = {} rescue nil)
    (PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup rescue nil)
  end

  # Empties $game_variables and $game_switches (hashes in the stubs, whose defaults survive clear).
  def self.reset_globals
    ($game_variables.clear if $game_variables.respond_to?(:clear))
    ($game_switches.clear if $game_switches.respond_to?(:clear))
  end

  # A fresh test map (id 1, no events, ledges or grid), the player on foot at (5, 5), the route cache dropped.
  def self.reset_map
    return unless $game_map
    $game_map.map_id = 1
    ($game_map.events.clear if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash))
    ($game_map.clear_ledges if $game_map.respond_to?(:clear_ledges))
    ($game_map.clear_grid if $game_map.respond_to?(:clear_grid))
    ($game_player.x = 5; $game_player.y = 5) if $game_player
    [:surfing=, :diving=, :bicycle=, :bridge=].each { |w| ($PokemonGlobal.send(w, w == :bridge= ? 0 : false) if $PokemonGlobal.respond_to?(w)) }
    (PokeAccess::Pathfinder.invalidate_cache(true) rescue nil)
  end
end
