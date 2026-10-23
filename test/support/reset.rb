# Resets the mod's mutable module state before each test, so a test cannot leak into the next: config, globals,
# puzzles (their last tracked line among them), the field-move rules, caches and the maps the world keeps, info,
# battle, locator, cursor dedup, the test map, the input claims, the frame's stall count and control's state, history,
# the last dialogue line (a repeat within half a second is not spoken), the last line spoken and the speak log.
module Reset
  # Runs before each test, each reset guarded; the language is pinned to Spanish, which the literal assertions
  # are written against, rather than the shipped :auto that follows this machine.
  def self.before_test
    (reset_config rescue nil)
    (PokeAccess::Config.language = :es rescue nil)
    (reset_globals rescue nil)
    (PokeAccess::World::Mechanics.instance_variable_set(:@defs, {}) rescue nil)
    (PokeAccess::Puzzles.instance_variable_set(:@track_seq, nil) rescue nil)
    (PokeAccess::World::Probe.instance_variable_set(:@loose_pushes, false) rescue nil)
    (PokeAccess::Routes::Pushes.instance_variable_set(:@sliding, false) rescue nil)
    (reset_field_rules rescue nil)
    (PokeAccess::Caches.reset_all rescue nil)
    (PokeAccess::World::Visits.forget rescue nil)
    (PokeAccess::Info.set_info(nil, nil) rescue nil)
    (PokeAccess::Info.note_item_desc(nil, nil) rescue nil)
    (PokeAccess::Battle.clear_battle rescue nil)
    (PokeAccess::Battle.battle_ended rescue nil)
    (PokeAccess::Locator.forget_map rescue nil)
    (PokeAccess::Cursor.reset_global rescue nil)
    (reset_map rescue nil)
    (reset_keys rescue nil)
    (reset_control rescue nil)
    (PokeAccess::History.clear rescue nil)
    (PokeAccess.instance_variable_set(:@last_say, nil) rescue nil)
    (PokeAccess.instance_variable_set(:@last_spoken, nil) rescue nil)
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

  # Clears the frame's stall count, which specs driving Input.update alone build up, and settles control on the
  # state it reads now, with no transition left pending.
  def self.reset_control
    PokeAccess::Frame.instance_variable_set(:@idle, 0)
    c = PokeAccess::Control
    c.instance_variable_set(:@holds, [])
    c.instance_variable_set(:@memo, {})
    c.instance_variable_set(:@watched, [c.scene_map?, false])
    c.instance_variable_set(:@held, c.find(:hold))
  end

  # Re-applies every declared setting's default, guarded per setting, and empties the rebinds (not settings) and
  # restores the mod's own keys.
  def self.reset_config
    PokeAccess::Config.settings.each do |s|
      (PokeAccess::Config.send("#{s.key}=", s.default) rescue nil)
    end
    (PokeAccess::Config.rebinds = {} rescue nil)
    (PokeAccess::Config.rebind_labels = {} rescue nil)
    (PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup rescue nil)
  end

  # Runs the block with a capability answering value, whatever the engine state earlier suites left; the registered
  # probe is put back after.
  def self.with_capability(name, value)
    caps = PokeAccess::Config.instance_variable_get(:@capabilities)
    saved = caps[name]
    PokeAccess::Config.capability(name) { value }
    yield
  ensure
    caps[name] = saved
  end

  # Empties $game_variables and $game_switches (hashes in the stubs, whose defaults survive clear).
  def self.reset_globals
    ($game_variables.clear if $game_variables.respond_to?(:clear))
    ($game_switches.clear if $game_switches.respond_to?(:clear))
  end

  # Puts the field-move rules back as they stood when the suite began (FieldMoves' items, tools and naming, the
  # obstacles games clear their own way), so a test that loads a profile file takes its declarations away with it.
  def self.reset_field_rules
    fm = PokeAccess::FieldMoves
    fx = PokeAccess::Routes::Effects
    @field_rules ||= Marshal.dump([fm.instance_variable_get(:@items), fm.instance_variable_get(:@tools), fm.named?,
                                   fx.instance_variable_get(:@field_gates)])
    items, tools, named, gates = Marshal.load(@field_rules)
    fm.instance_variable_set(:@items, items)
    fm.instance_variable_set(:@tools, tools)
    fm.named = named
    fx.instance_variable_set(:@field_gates, gates)
  end

  # A fresh test map (id 1, no events, ledges or grid), the player on foot at (5, 5) facing down, the route cache
  # dropped, and the locator's toggles and push tiles, kept by map id, read afresh.
  def self.reset_map
    return unless $game_map
    $game_map.map_id = 1
    ($game_map.events.clear if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash))
    [:@lever_map, :@push_map].each { |iv| PokeAccess::Locator.instance_variable_set(iv, nil) }
    ($game_map.clear_ledges if $game_map.respond_to?(:clear_ledges))
    ($game_map.clear_grid if $game_map.respond_to?(:clear_grid))
    ($game_player.x = 5; $game_player.y = 5; $game_player.direction = 2) if $game_player
    [:surfing=, :diving=, :bicycle=, :bridge=].each { |w| ($PokemonGlobal.send(w, w == :bridge= ? 0 : false) if $PokemonGlobal.respond_to?(w)) }
    (PokeAccess::Pathfinder.invalidate_cache(true) rescue nil)
  end
end
