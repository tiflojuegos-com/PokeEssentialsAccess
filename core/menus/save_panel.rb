module PokeAccess
  # The save screen's summary panel, built once by pbStartScreen and read queued: the locwindow's text (map, player,
  # play time, badges, dex counts), or, where a plugin paints the panel instead of that window (the BW and HGSS save
  # screens), what it painted and the team its icons show.
  module SavePanel
    # Speaks the panel pbStartScreen has just built; a plugin overrides it where that panel can close unseen.
    # param pairs what pbStartScreen painted, as PaintCapture.take_pairs gives it
    def self.say(scene, pairs = nil)
      win = PokeAccess.sprite(scene, "locwindow")
      t = win ? PokeAccess.clean_fields((win.text rescue nil)) : painted(scene, pairs)
      PokeAccess.speak(t, false) unless t.to_s.empty?
    end

    # A painted panel as one line: its texts top to bottom and left to right, a label ending in a colon joined to the
    # value beside it, then the team its icons show; "" when nothing was painted.
    def self.painted(scene, pairs)
      cells = PokeAccess::PaintCapture.pair_labels(PokeAccess::PaintCapture.cells(pairs).flatten)
      return "" if cells.empty?
      [cells.join(", "), PokeAccess::LoadPanel.team_line(icon_party(scene), true)].compact.join(". ")
    end

    # The Pokemon the panel's party icons show (its pokemon0, pokemon1... sprites), in their order.
    def self.icon_party(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      return [] unless sprites.is_a?(Hash)
      keys = sprites.keys.select { |k| k.to_s =~ /\Apokemon\d+\z/ }.sort_by { |k| k.to_s[/\d+/].to_i }
      keys.map { |k| (sprites[k].pokemon rescue nil) }.compact
    end

    # Reads the panel cname's pbStartScreen builds: what it paints is sampled while the original runs under the
    # reentrancy guard, then said.
    def self.bind(cname)
      PokeAccess::Hooks.around_hook(cname, :pbStartScreen, :optional => true) do |scene, nxt, _a|
        r = nil
        pairs = PokeAccess::PaintCapture.sample { r = PokeAccess::Hooks.guarded(:pbStartScreen) { nxt.call } }
        begin
          PokeAccess::SavePanel.say(scene, pairs)
        rescue StandardError => e
          PokeAccess.swallowed(e)
        end
        r
      end
    end
  end
end

PokeAccess::Engine.scene_classes("PokemonSaveScene", "PokemonSave_Scene").each { |cn| PokeAccess::SavePanel.bind(cn) }
