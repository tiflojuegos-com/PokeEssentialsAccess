# Radon's security feed of the Lonardo warehouse (map 800, EV2): a menu at each of three cameras, where one choice moves
# the quest on (variable 380): camera 1's coins (self switch A of EV3), camera 2's litter (EV7's A) and camera 3's phone
# (EV2's D). The other choices only talk; the assist names the choice that does it, or the camera to switch to.
module PokeAccess
  module AshenLonardoCameras
    MAP = 800
    FEED = 2
    DONE = { 1 => [3, "A"], 2 => [7, "A"], 3 => [2, "D"] }
    # The feed's self switch of each camera: switching to it sets it, leaving it clears it.
    SWITCH_TO = { 2 => "B", 3 => "C" }

    # The camera on screen, by the feed's self switches.
    def self.camera
      return 3 if $game_self_switches[[MAP, FEED, "C"]]
      $game_self_switches[[MAP, FEED, "B"]] ? 2 : 1
    end

    # Whether a camera's task is done.
    def self.done?(cam)
      ev, letter = DONE[cam]
      $game_self_switches[[MAP, ev, letter]] ? true : false
    end

    # The camera with a task left to switch to, camera 3 first and camera 1 last; nil with none.
    def self.next_camera
      cam = camera
      [3, 2, 1].find { |c| c != cam && !done?(c) }
    end

    # The assist's branch at the feed's menus: this camera's quest choice while its task is left, else the switch to the
    # next camera with one left (camera 1: clear this camera's own self switch); nil with none.
    def self.choice
      cam = camera
      return { :var => 380 } unless done?(cam)
      to = next_camera
      return nil unless to
      { :self => SWITCH_TO[to == 1 ? cam : to] }
    end

    # The line after the cameras' menu asks which: camera 1 when it is the one left, else none.
    def self.camera_line
      done?(camera) && next_camera == 1 ? :afi_lonardo_first : ""
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  feed = PokeAccess::AshenLonardoCameras
  mechanic(:state, feed::MAP, :part => :cameras) do
    auto
    right_choice feed::FEED, :takes => lambda { feed.choice }
    on_reach feed::FEED, { :text => /Which camera\?/ }, lambda { feed.camera_line }, :assist => true
  end
end
