module PokeAccess
  # Multi Save (shipped as "Auto Multi Save" and as plain "Multi Save"): replaces the single save file with
  # numbered slots. The slot LABELS are an ordinary command window the generic reader already voices; what it
  # cannot see is the detail box beside them, which the plugin rebuilds every frame from the focused slot --
  # "(empty)", or the date, map and play time of the save sitting there.
  #
  # That box is the whole point of the screen: without it a blind player cannot tell an empty slot from one
  # holding a run, and saving is the one action here that cannot be undone. The load side is already covered,
  # because its outer loop re-calls pbStartScene on every slot change and core/menus/load reads that.
  #
  # Queued rather than interrupting, so the detail follows the slot label instead of cutting it.
  module MultiSave
    # The box is laid out with markup, not with punctuation: the fields are separated by <r> (align right)
    # and <br> (line break), which clean deletes outright, running the three values into one word --
    # "08/05/2606:31PMPetalburg CityTime2h 15m". The layout tags become the pause the layout implied.
    LAYOUT = /<\s*(r|br)\s*\/?\s*>/i

    def self.slot_info(scene, text)
      t = PokeAccess.clean(text.to_s.gsub(LAYOUT, ", ")).to_s.strip
      t = t.gsub(/(,\s*)+/, ", ").sub(/\A,\s*/, "").sub(/,\s*\z/, "")
      return if t.empty?
      PokeAccess::Cursor.reset(scene, :ams_slot) if moving?
      PokeAccess::Cursor.announce(scene, :ams_slot, t, false) { t }
    rescue StandardError
      nil
    end

    # Whether the cursor just moved. Needed because every empty slot renders one byte-identical string, so on
    # a fresh install the first slot would be described and the other seven would be silent -- the player
    # hears the label move and cannot tell whether the box still describes the slot they left.
    #
    # The plugin's loop calls this hook, then reads input, then moves the cursor. So on the frame the box
    # first shows the NEW slot, the directional press that caused the move is still the live one, and that is
    # what separates "same text, different slot" from "same slot, redrawn".
    def self.moving?
      [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT].any? do |k|
        Input.trigger?(k) || Input.repeat?(k)
      end
    rescue StandardError
      false
    end
  end
end

# The scene holds the dedup rather than the module: it is built fresh per opening, so reopening the save
# screen describes the focused slot again instead of inheriting the last one from the previous visit.
PokeAccess::Hooks.before_hook("PokemonSave_Scene", :pbUpdateSlotInfo, :optional => true) do |scene, args|
  PokeAccess::MultiSave.slot_info(scene, args[0])
end
