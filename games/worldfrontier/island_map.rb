# World Frontier's island map (IslaDesafioMapScene, "Mapa" in the pause menu): a list of the island's places beside a
# picture of the island with a dot for each and one for the player. Each place is said with its place in the list, how
# far it lies from the player's dot in tiles as the locator says it, and, in full, the description painted under it.
module PokeAccess
  module WfIslandMap
    # The focused place's line: its name and place in the list, its offset from the player's dot and, where
    # descriptions are said, the description; full is everything, for the info key.
    def self.line(scene, full = false)
      locs = PokeAccess.ivar(scene, :@locations)
      idx = PokeAccess.ivar(scene, :@index)
      return nil unless locs.is_a?(Array) && idx.is_a?(Integer) && locs[idx].is_a?(Hash)
      loc = locs[idx]
      head = full ? loc[:name].to_s : PokeAccess::Verbosity.list_entry(loc[:name].to_s, idx + 1, locs.length)
      marker = (scene.player_marker rescue nil)
      where = marker ? PokeAccess::Locator.dir_phrase(loc[:x].to_i - marker[0].to_i, loc[:y].to_i - marker[1].to_i) : nil
      desc = (full || PokeAccess::Verbosity.descriptions?) ? loc[:desc] : nil
      PokeAccess.sentences([[head, where].compact.join(", "), desc])
    end

    # After each repaint: the title and the keys as the map opens, the focused place when it moves.
    def self.refresh(scene)
      opening = PokeAccess::Cursor.pending?(scene, :wf_island)
      text = line(scene)
      return unless text
      PokeAccess::Info.set_info(:text, PokeAccess.clean(line(scene, true)))
      return unless PokeAccess::Cursor.changed?(scene, :wf_island, PokeAccess.ivar(scene, :@index))
      if opening
        text = PokeAccess::WfHint.after(PokeAccess.sentences([_INTL("Isla Desafío"), text]), (scene.help_text rescue nil))
      end
      PokeAccess.speak_clean(text, !opening)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("IslaDesafioMapScene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfIslandMap.refresh(scene) }
  # The notice painted while the island's picture is drawn the first time.
  after("IslaDesafioMapScene", :show_loading) do |_scene, _r, _a|
    PokeAccess.speak_clean(_INTL("Abriendo el mapa de la isla..."), true)
  end
end
