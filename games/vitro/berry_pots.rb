# Vitro's berry pots (0302_Berrypots, Caruban's older script): four pots in a row under @index, with neither the can nor the
# exit of the later version, each plant kept as the field's array in @berryData and drawn only as pictures: said as the field's
# plants are (core's Berry), as the cursor moves and after acting on a pot.
module PokeAccess
  module VitroBerryPots
    # The pots the screen draws.
    POTS = 4

    # A pot by its number, then its plant or that it is empty.
    def self.text(scene, idx)
      plants = PokeAccess.ivar(scene, :@berryData)
      parts = PokeAccess::Berry.state_parts(plants.is_a?(Array) ? plants[idx] : nil)
      parts = [PokeAccess::I18n.t(:bpots_empty)] if parts.empty?
      "#{PokeAccess::I18n.t(:bpots_pot, :n => idx + 1, :total => POTS)}, #{parts.join(', ')}"
    end

    # After acting on a pot, says it again as it now stands, queued behind the messages the action showed; the info key
    # keeps it.
    def self.acted(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx.is_a?(Integer)
      line = text(scene, idx)
      PokeAccess::Info.set_info(:text, line, line)
      PokeAccess.speak(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  focus_reader("ItemBerryPots_Scene", :on => :pbUpdateCursor, :slot => :vitro_pot, :close => :pbEndScene, :optional => true) do |idx, scene|
    PokeAccess::VitroBerryPots.text(scene, idx)
  end
  # A container: the action runs its messages and the bag inside.
  after("ItemBerryPots_Scene", :pbBerryPlantVar, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::VitroBerryPots.acted(scene)
  end
end
