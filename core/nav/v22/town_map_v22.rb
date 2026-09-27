module PokeAccess
  # v22 town map (UI::TownMapVisuals): the location under the cursor, read on refresh_on_cursor_move, where the
  # screen redraws its name.
  module TownMapV22
    # The focused location's name as the screen's refresh_map_name resolves it (get_point_data, the region-location
    # messages, \PN as the player's name); nil on a blank point.
    def self.name_at(vis)
      pd = (vis.send(:get_point_data) rescue nil)
      return nil unless pd && pd[:real_name]
      name = (pbGetMessageFromHash(MessageTypes::REGION_LOCATION_NAMES, pd[:real_name]) rescue pd[:real_name].to_s)
      name = (name.gsub(/\\PN/, (PokeAccess::Engine.player.name rescue "")) rescue name)
      name.to_s.empty? ? nil : name
    rescue StandardError
      nil
    end

    # The dedup key of a blank point, so sweeping off a place and back onto it says it again.
    BLANK = :tm_blank

    # Announces the focused location when it changes.
    def self.announce(vis)
      name = name_at(vis)
      spoken = PokeAccess::Cursor.on_change(vis, :tm_name, name || BLANK) { name }
      PokeAccess.speak(spoken, true)
    end
  end
end

PokeAccess::Hooks.after_hook("UI::TownMapVisuals", :refresh_on_cursor_move, :optional => true) do |vis, _r, _a|
  PokeAccess::TownMapV22.announce(vis)
end
