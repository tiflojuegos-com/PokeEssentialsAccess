module PokeAccess
  # BerryPots for Essentials v20 (ItemBerryPots_Scene, opened by the pots item): the pots, the watering can and the exit
  # under @index (0 and up the pots, -1 the can, -2 the exit). A pot's plant is drawn only as pictures, so it is said
  # from its BerryPlantData as the field's plants are (core's Berry): its stage, its berry and its soil.
  module BerryPots
    # The focused place: a pot by number with its plant, the can with the one in use, or the exit; the can and the
    # exit with the help window's line.
    def self.text(scene, idx)
      return pot_text(scene, idx) if idx >= 0
      help = PokeAccess.clean((PokeAccess.sprite(scene, "helpwindow").text rescue "").to_s)
      can = idx == -1 ? PokeAccess::Data.item_name(can_item(scene)) : nil
      PokeAccess.sentences([help, can].compact.reject { |t| t.to_s.strip.empty? })
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A pot by its number among the pots, then its plant or that it is empty.
    def self.pot_text(scene, idx)
      plants = PokeAccess.ivar(scene, :@berry_plant)
      total = (scene.potsCount rescue nil) || (plants.is_a?(Array) ? plants.length : idx + 1)
      parts = PokeAccess::Berry.state_parts(plants.is_a?(Array) ? plants[idx] : nil)
      parts = [PokeAccess::I18n.t(:bpots_empty)] if parts.empty?
      PokeAccess::I18n.t(:bpots_pot, :n => idx + 1, :total => total) + ", " + parts.join(", ")
    end

    # The can the screen shows: the one being picked while the can list is open, else the one in use.
    def self.can_item(scene)
      cans = PokeAccess.ivar(scene, :@can_temp)
      id = PokeAccess.ivar(scene, :@can_id)
      cans.is_a?(Array) && id.is_a?(Integer) && cans[id] ? cans[id] : PokeAccess.ivar(scene, :@item)
    end

    # Speaks the focused place when it changes (the can when the picked can changes too); the first, on opening,
    # queued behind the screen's own opening.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx.is_a?(Integer)
      opening = !PokeAccess.ivar(scene, :@access_bpots_open)
      scene.instance_variable_set(:@access_bpots_open, true)
      key = idx == -1 ? [idx, can_item(scene)] : idx
      PokeAccess::Cursor.announce(scene, :bpots_place, key, !opening) { text(scene, idx) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # After acting on a pot (planting, watering, picking), says the pot again as it now stands, queued behind the
    # messages the action showed.
    def self.acted(scene)
      PokeAccess::Cursor.reset(scene, :bpots_place)
      idx = PokeAccess.ivar(scene, :@index)
      PokeAccess::Cursor.announce(scene, :bpots_place, idx, false) { text(scene, idx) } if idx.is_a?(Integer)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# pbUpdate runs it every frame of the screen's loop; the dedup keeps it to the moves.
PokeAccess::Hooks.after_hook("ItemBerryPots_Scene", :pbUpdateCursor, :optional => true) do |scene, _r, _a|
  PokeAccess::BerryPots.focus(scene)
end

# A container: the action runs its messages and the bag inside.
PokeAccess::Hooks.after_hook("ItemBerryPots_Scene", :pbBerryPlantVar, :optional => true,
                             :hook_container => true) do |scene, _r, _a|
  PokeAccess::BerryPots.acted(scene)
end
