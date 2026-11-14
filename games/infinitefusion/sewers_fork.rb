module PokeAccess
  # The original two-tile choice strips on Celadon Sewers map449; each has one representative.
  # Active commands, rather than future pages or a written story flag, determine whether the choice remains.
  module InfiniteFusionSewersFork
    def self.pending?(id)
      return false unless $game_map && $game_map.map_id == 449 && [9, 11].include?(id)
      ev = $game_map.events[id]
      return false unless ev && PokeAccess.ivar(ev, :@trigger) == 1
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array)
      list.any? { |c| c.code == 102 } && list.any? do |c|
        c.code == 121 && c.parameters[0].to_i <= 147 && c.parameters[1].to_i >= 147
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Keep existing tags, hiding and recognized sound families before adding the graphicless passage cue.
    def self.cue?(ev)
      return false unless ev && pending?(ev.id)
      !PokeAccess::Locator.hidden?(ev) && PokeAccess::Locator.tag_override(ev).nil?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  override("PokeAccess::Sound::Scene", :family_of) do |_scene, original, args|
    family = original.call
    family || (PokeAccess::InfiniteFusionSewersFork.cue?(args[0]) ? :object : nil)
  end
end
