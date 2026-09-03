module PokeAccess
  # Multi Save ("Auto Multi Save" and plain "Multi Save"): numbered save slots. The labels are an ordinary
  # command window the generic reader voices; this reads the detail box beside them, which the plugin
  # rebuilds every frame from the focused slot -- empty, or the date, map and play time of the save there.
  #
  # Queued rather than interrupting, so the detail follows the slot label instead of cutting it. The load
  # side needs nothing: its outer loop re-calls pbStartScene per slot and core/menus/load reads that.
  module MultiSave
    # The box separates its fields with markup, not punctuation (clean_fields turns that into the pause the
    # layout implied).
    def self.slot_info(scene, text)
      t = PokeAccess.clean_fields(text)
      return if t.empty?
      PokeAccess::Cursor.reset(scene, :ams_slot) if moving?
      PokeAccess::Cursor.announce(scene, :ams_slot, t, false) { t }
    rescue StandardError
      nil
    end

    # Whether the cursor just moved, which is what separates "same text, different slot" from "same slot,
    # redrawn" -- every empty slot renders one byte-identical string.
    #
    # The plugin's loop calls this hook, reads input, then moves the cursor, so on the frame the box first
    # shows the new slot the press that caused it is still live. The four keys the list answers to: it is a
    # Window_CommandPokemonEx, vertical, and its update also pages with JUMPUP and JUMPDOWN. The index is a
    # local of the plugin's loop and never reaches here, so holding a direction at either end still
    # re-describes the same slot.
    KEYS = [:UP, :DOWN, :JUMPUP, :JUMPDOWN]

    def self.moving?
      KEYS.any? do |name|
        k = (Input.const_get(name) rescue nil)
        k && (Input.trigger?(k) || Input.repeat?(k))
      end
    rescue StandardError
      false
    end
  end
end

# The dedup lives on the scene, which is built fresh per opening, so reopening describes the focused slot
# again instead of inheriting the previous visit's.
#
# The reset rides the slot SUBMENU (slotSelectCommands, the one method all five copies share -- only anil
# has pbClearSlotInfo), on both edges: its loop repaints the detail per frame through pbUpdateSlotInfo, so
# entering re-reads the focused entry's info under the question, and leaving re-arms the list detail --
# including the "exit without saving?, no" path, which re-enters this method with the text unchanged and
# used to come back mute.
PokeAccess::Hooks.around_hook("PokemonSaveScreen", :slotSelectCommands, :optional => true) do |screen, nxt, _a|
  scene = PokeAccess.ivar(screen, :@scene)
  PokeAccess::Cursor.reset(scene, :ams_slot) if scene
  begin
    nxt.call
  ensure
    PokeAccess::Cursor.reset(scene, :ams_slot) if scene
  end
end

PokeAccess::Hooks.before_hook("PokemonSave_Scene", :pbUpdateSlotInfo, :optional => true) do |scene, args|
  PokeAccess::MultiSave.slot_info(scene, args[0])
end
