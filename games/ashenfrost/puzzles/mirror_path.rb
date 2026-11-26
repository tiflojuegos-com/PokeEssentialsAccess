# Ashen Frost's mirror path in the Well Temple (map 686, Case Seventeen): the canyon's door (EV76) brings the player in
# at (56,31) with switch 288 on and Cordelia (EV78) copying each step mirrored (variable 270). Tiles of terrain tag 20
# (FalseFloor) drop the player back (EV79) where Cordelia's side has a wall. The switch (EV85) sets variable 262 to 6.
module PokeAccess
  module AshenMirrorPath
    MAP = 686
    ROOM = [54, 59, 31, 51]
    FALL_FROM = [54, 59, 31, 48]
    FALL_TO = [55, 12]
    SWITCH = 85
    FALSE_FLOOR = 20

    # Whether the switch has been pressed.
    def self.done?
      $game_variables[262].to_i >= 6
    end

    # Whether the player walks the mirrored room.
    def self.inside?
      return false unless $game_switches[288] && !done?
      $game_player.x.between?(ROOM[0], ROOM[1]) && $game_player.y.between?(ROOM[2], ROOM[3])
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  mirror = PokeAccess::AshenMirrorPath
  terrain_rule(:maps => [mirror::MAP], :tags => [mirror::FALSE_FLOOR], :assist => true) { |_x, _y, _d| false }

  mechanic(:state, mirror::MAP, :part => :afd_mirrors) do
    auto
    name mirror::SWITCH, :afd_mirror_switch, :when => lambda { |_ev| !mirror.done? }
    sent_back :afd_mirror_fell, :from => mirror::FALL_FROM, :to => mirror::FALL_TO
    phase lambda { mirror.inside? }, :title => :afd_mirror_rule, :hint => :afd_mirror_hint
    solved(nil, :quiet => true) { mirror.done? }
  end
end
