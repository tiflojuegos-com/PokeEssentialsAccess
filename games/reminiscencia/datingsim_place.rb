module PokeAccess
  # Reminiscencia's Dating Sim task screen: the date LOCATION is chosen on a horizontal strip (LEFT/RIGHT)
  # shown only as bubbles/icons, with the choice in @index (0..11) -> DATING_PLACES.keys[@index]. The
  # existing datingsim reader covers the gender page and the name list, but not this place selector, so it
  # was silent. inputs runs every frame; read the focused place name (DATING_PLACES[key][2]) when @index
  # changes. The place strip shares the screen with the name list (@cmdwindow), read by the generic hook.
  module ReminDatingPlace
    # The display name of the place at the given strip index, via the DATING_PLACES hash, or nil.
    def self.place_name(idx)
      keys = (DATING_PLACES.keys rescue nil)
      return nil unless keys && idx && idx >= 0 && idx < keys.length
      entry = DATING_PLACES[keys[idx]]
      (entry.is_a?(Array) && entry[2]) ? entry[2].to_s : keys[idx].to_s
    rescue StandardError
      nil
    end

    # Reads the focused place when the horizontal index changes.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless PokeAccess::Cursor.changed?(scene, :place_idx, idx)
      t = place_name(idx)
      PokeAccess.speak_clean(t, true) if t && !t.to_s.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  # hook_container because inputs DRIVES the readers of the rest of the screen from inside itself: it calls
  # @cmdwindow.update, which is what voices the character list, and setGenderPage when the tab changes. As a
  # plain atomic hook its original ran guarded, so both were dropped as nested and the only thing that ever
  # spoke on this screen was the place strip below. The place reader still runs after, on its own dedup.
  after("DatingSimTaskScreen", :inputs, :hook_container => true) do |scene, _result, _args|
    PokeAccess::ReminDatingPlace.announce(scene)
  end
end
