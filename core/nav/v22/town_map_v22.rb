module PokeAccess
  # v22 town map (Essentials v22: UI::TownMapVisuals). The cursor is a 2D map point (not a linear index),
  # and the screen redraws the location name on refresh_on_cursor_move, so that is hooked directly (not
  # via the index-based on_nav). The reading lives HERE, in a module function, rather than inside the
  # hook body: a body is unreachable from a spec (hooks bind once at load, so a class defined later can
  # never be wired), which left this the one v22 screen with no coverage at all.
  module TownMapV22
    # The focused location's spoken name, resolved the way the screen's own refresh_map_name does:
    # get_point_data gives the message-hash key, which the region-location table turns into the display
    # name, and \PN expands to the player's name. nil when the cursor sits on a blank point.
    def self.name_at(vis)
      pd = (vis.send(:get_point_data) rescue nil)
      return nil unless pd && pd[:real_name]
      name = (pbGetMessageFromHash(MessageTypes::REGION_LOCATION_NAMES, pd[:real_name]) rescue pd[:real_name].to_s)
      name = (name.gsub(/\\PN/, (PokeAccess::Engine.player.name rescue "")) rescue name)
      name.to_s.empty? ? nil : name
    rescue StandardError
      nil
    end

    # Announces the focused location when it changes, so holding a direction across a run of blank points
    # does not repeat it.
    #
    # A blank point still CONSUMES the dedup key, with a marker no place name can equal. Guarding the whole
    # call on `if name` left the last town recorded while the cursor was off it, so sweeping off a town and
    # back onto it matched the old key and said nothing -- on a map whose entire purpose is finding places by
    # sweeping. The gen-6 screen never had this because it keys on the cursor's coordinates; here the name is
    # the only thing available, so the absence of one has to be a value rather than a skipped call.
    BLANK = :tm_blank

    def self.announce(vis)
      name = name_at(vis)
      spoken = PokeAccess::Cursor.on_change(vis, :tm_name, name || BLANK) { name }
      PokeAccess.speak(spoken, true) if spoken && !spoken.to_s.empty?
    end
  end
end

PokeAccess::Hooks.after_hook("UI::TownMapVisuals", :refresh_on_cursor_move, :optional => true) do |vis, _r, _a|
  PokeAccess::TownMapV22.announce(vis)
end
