# Vitro's gym of Azalea (map 57): twelve webs carry the player across two gaps to another platform. The six over the lower gap always
# land in the same place; the six over the upper gap land by the levers, red (switch 78, event 13) and blue (switch 79, events 7, 8
# and 9). Whatever the levers say, each platform the player can come to leads on to Anton and back to the exit. Switch 5 is the badge.
# A web is a move route, so what it says at the end is the platform it left the player on.
module PokeAccess
  # The webs and levers of Azalea's gym, and the next step from each platform for each state of the levers.
  module VitroAzalea
    # Each web's event => the column it hangs in and the way it leads.
    WEBS = { 2 => [:left, :up], 1 => [:center, :up], 3 => [:right, :up], 17 => [:left, :up], 10 => [:center, :up],
             16 => [:right, :up], 4 => [:left, :down], 5 => [:center, :down], 6 => [:right, :down], 20 => [:left, :down],
             19 => [:center, :down], 18 => [:right, :down] }
    LEVERS = { 7 => :blue, 8 => :blue, 9 => :blue, 13 => :red }
    COLUMNS = { :left => :vitro_azalea_col_left, :center => :vitro_azalea_col_center, :right => :vitro_azalea_col_right }
    WAYS = { :up => :vitro_azalea_dir_up, :down => :vitro_azalea_dir_down }
    COLORS = { :blue => :vitro_azalea_lever_blue, :red => :vitro_azalea_lever_red }
    # The platforms the player can come to, as boxes of tiles [x0, x1, y0, y1].
    REGIONS = { :south => [1, 17, 31, 38], :center => [7, 11, 18, 23], :top_left => [2, 4, 7, 10], :mid_left => [2, 4, 18, 20],
                :top_right => [14, 16, 7, 10], :low_left => [2, 4, 22, 23], :low_right => [14, 16, 22, 23],
                :boss => [7, 11, 6, 10] }
    PLATFORMS = { :south => :vitro_azalea_at_south, :center => :vitro_azalea_at_center, :top_left => :vitro_azalea_at_top_left,
                  :mid_left => :vitro_azalea_at_mid_left, :top_right => :vitro_azalea_at_top_right,
                  :low_left => :vitro_azalea_at_low_left, :low_right => :vitro_azalea_at_low_right, :boss => :vitro_azalea_at_boss }
    # The event to use from a platform whatever the levers say.
    ANY = { :south => 2, :low_left => 4, :low_right => 6 }
    # The event to use from [platform, red lever, blue lever]; those the player can never come to are not listed.
    BY_LEVERS = { [:center, false, false] => 10, [:center, false, true] => 7, [:center, true, false] => 10,
                  [:center, true, true] => 7, [:top_left, false, false] => 9, [:top_left, false, true] => 20,
                  [:mid_left, false, true] => 13, [:mid_left, true, true] => 17, [:top_right, false, true] => 18,
                  [:top_right, true, true] => 18 }

    # What an event of the gym is called: a web by its column and way, a lever by its colour.
    def self.name_of(id)
      web = WEBS[id]
      if web
        return PokeAccess::I18n.t(:vitro_azalea_web, :col => PokeAccess::I18n.t(COLUMNS[web[0]]),
                                                     :dir => PokeAccess::I18n.t(WAYS[web[1]]))
      end
      PokeAccess::I18n.t(COLORS[LEVERS[id]])
    end

    # The platform a tile is on, or nil.
    def self.region_of(x, y)
      found = REGIONS.find { |_name, b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
      found && found[0]
    end

    # The platform a web has left the player on, or nil between platforms.
    def self.landed
      region = region_of($game_player.x, $game_player.y)
      region && [:vitro_azalea_landed, { :at => PokeAccess::I18n.t(PLATFORMS[region]) }]
    end

    # The next event to use from the platform the player stands on, as the levers are now, or nil.
    def self.next_event(region)
      return ANY[region] if ANY[region]
      BY_LEVERS[[region, $game_switches[78] ? true : false, $game_switches[79] ? true : false]]
    end

    # The hint: the next step, or that Anton is on this platform; nothing between platforms.
    def self.hint
      region = region_of($game_player.x, $game_player.y)
      return nil unless region
      return :vitro_azalea_goal if region == :boss
      id = next_event(region)
      id && [:vitro_azalea_next, { :what => name_of(id) }]
    end
  end
end

PokeAccess::Game.define("vitro") do
  mechanic(:state, 57) do
    name PokeAccess::VitroAzalea::WEBS.keys + PokeAccess::VitroAzalea::LEVERS.keys, lambda { |ev| PokeAccess::VitroAzalea.name_of(ev.id) }
    watch :switch => 78, :label => :vitro_azalea_lever_red, :on => :vitro_azalea_lever_on, :off => :vitro_azalea_lever_off
    watch :switch => 79, :label => :vitro_azalea_lever_blue, :on => :vitro_azalea_lever_on, :off => :vitro_azalea_lever_off
    sent_back lambda { PokeAccess::VitroAzalea.landed }, :events => PokeAccess::VitroAzalea::WEBS.keys, :forced => true
    solved { $game_switches[5] }
    arrival_hint :vitro_azalea_rule
    hint lambda { PokeAccess::VitroAzalea.hint }
  end
end
