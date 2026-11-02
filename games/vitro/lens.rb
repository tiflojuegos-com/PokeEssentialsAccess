# Vitro's Eye of Truth (0304_Eye of Truth) is worked by the Dowsing Machine, each use turning it on or off, and any event that
# runs turns it off (check_event_running); nothing but its picture says so, and core's lens poll asks for a Scene_Map state this
# copy does not keep. So the state is followed each frame, wherever it changes. What it reveals is the locator's.
module PokeAccess
  module VitroLens
    @on = false

    # Says the lens's state when it changes, with the item it goes by: turning off is queued, as an event that starts does it,
    # with its message just said.
    def self.poll
      on = LensOfTruth.active? ? true : false
      return if on == @on
      @on = on
      key = on ? :vitro_lens_on : :vitro_lens_off
      PokeAccess.speak(PokeAccess::I18n.t(key, :item => PokeAccess::FieldMoves.item_name(:DOWSINGMACHINE)), on)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  poll_each_frame { PokeAccess::VitroLens.poll }
end
