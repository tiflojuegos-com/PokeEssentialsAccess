module PokeAccess
  # Preventive: the overworld Safari of 053_PIF_Hoenn/Gameplay/SafariZone, which the 1.3.2 scripts carry but no map
  # reaches (MAP_SAFARI_1..6 are maps 149 to 154, absent from Data/; nothing calls initialize_safari; the template map 21
  # has no events 15 and 16, the thrown ball and the Pokeblock). Inert unless initialize_safari has set
  # $PokemonTemp.overworld_safari and the Safari state is in progress. Once the maps ship, check: whether something clears
  # that mark on leaving, where displayCaughtPokemonIcons is called (the pause menu, Scene_Map#call_menu, and
  # safariNewAreaCheck), that the panel's sprite keys are still "<SPECIES>_<n>", how the ball template ends a throw that
  # hits nothing (said by nothing here), and that try_catch_safari_pokemon still records a catch before it returns.
  # - The caught panel (SafariCaughtIcons_UI): an icon per catch, a row per species in the order first caught, and no
  #   cursor. Its rows are said queued as it opens: as the pause menu opens over it, before the menu's first option.
  # - The ball counter in the corner (updateBallDisplay) and the icons over the Pokemon that have noticed the player,
  #   which no ball can catch: the info key on the map says both. A message freezes every visible Pokemon
  #   (pause_movement, state :PAUSED), which takes the icons down unsaid; the info key leaves those out.
  # - A throw that fails shows only the Pokemon popping out of the ball: said queued. A catch is the game's message.
  module IF2Safari
    PANEL_ICON = /\A(.+)_\d+\z/

    # Whether the overworld Safari runs: its mark, which nothing clears on leaving, and the Safari state still in
    # progress, which pbEnd stops as the player leaves.
    def self.on?
      return false unless ($PokemonTemp.overworld_safari rescue false)
      (pbSafariState.inProgress? rescue false) ? true : false
    end

    # Says the caught panel's rows as it opens; an empty panel draws nothing and says nothing.
    def self.panel(ui)
      order = []
      counts = {}
      (PokeAccess.ivar(ui, :@sprites) || {}).keys.each do |k|
        m = PANEL_ICON.match(k.to_s)
        next unless m
        order.push(m[1]) unless counts[m[1]]
        counts[m[1]] = counts[m[1]].to_i + 1
      end
      return if order.empty?
      t = PokeAccess::I18n
      rows = order.map { |sp| t.t(:if2_safari_row, :n => counts[sp], :name => PokeAccess::IF2Overworld.species_name(sp)) }
      PokeAccess.speak(t.t(:if2_safari_caught, :list => rows.join(", ")), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The info key's line in the Safari: the balls left and the Pokemon whose notice icon is up, with where they are.
    def self.line
      return nil unless on?
      t = PokeAccess::I18n
      parts = [t.t(:safari_balls, :n => (pbSafariState.ballcount rescue 0).to_i)]
      seen = watchers.map { |ev| "#{PokeAccess::IF2Overworld.wild_name(ev)}, #{where(ev)}" }
      parts.push(t.t(:if2_safari_seen, :list => seen.join("; "))) unless seen.empty?
      PokeAccess.sentences(parts)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The visible wild Pokemon showing the notice icon now (OverworldPokemonEvent#update_notice_icon's test).
    def self.watchers
      return [] unless defined?(::OverworldPokemonEvent) && $game_map
      $game_map.events.values.select do |ev|
        ev.is_a?(::OverworldPokemonEvent) && PokeAccess.ivar(ev, :@current_state) == :NOTICED_PLAYER &&
          (ev.opacity rescue 0).to_i > 0 && !PokeAccess.ivar(ev, :@notice_icon_hidden)
      end
    end

    def self.where(ev)
      PokeAccess::Locator.dir_phrase(ev.x - $game_player.x, ev.y - $game_player.y)
    end

    # Runs a throw at ev, then says the Pokemon broke free when the catch list did not grow.
    def self.throw_at(ev)
      before = caught
      name = PokeAccess::IF2Overworld.wild_name(ev)
      ret = yield
      PokeAccess.speak(PokeAccess::I18n.t(:if2_safari_escaped, :name => name), false) if name && caught == before
      ret
    end

    def self.caught
      ((pbSafariState.caught_pokemon || []).length rescue 0)
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("SafariCaughtIcons_UI", :initialize, :optional => true) { |ui, _r, _a| PokeAccess::IF2Safari.panel(ui) }
  kernel("try_catch_safari_pokemon", :around) { |a, nxt| PokeAccess::IF2Safari.throw_at(a[0]) { nxt.call } }
  PokeAccess::Info.map_owner(:if2_safari) { PokeAccess::IF2Safari.line }
end
