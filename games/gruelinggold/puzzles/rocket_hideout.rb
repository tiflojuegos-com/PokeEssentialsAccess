# Team Rocket's hideout (map 279): five statues (events 1 to 5) each watch an alarm tile (events 10, 24, 25, 26 and 27)
# that sends two grunts; beating them switches that statue off (switches 151 to 155), and the
# computer with no sprite (event 9) switches off all five at once (switch 143), the scientist beside it asking whether
# the player has figured it out. With the puzzle assist, walks keep off the alarm tiles while they can still sound.
module PokeAccess
  module GgRocketStatues
    MAP = 279
    ALARMS = [10, 24, 25, 26, 27]

    # Whether statue id still watches: neither its grunts beaten nor the computer used.
    def self.watching?(id)
      !($game_switches[143] || $game_switches[150 + id] || $game_self_switches[[MAP, id, "A"]])
    end
  end
end

PokeAccess::Game.define("gruelinggold") do
  statues = PokeAccess::GgRocketStatues
  mechanic(:state, statues::MAP) do
    auto
    name 1..5, lambda { |ev| statues.watching?(ev.id) ? :gg_rocket_statue : :gg_rocket_statue_off }
    name 9, :gg_rocket_computer, :when => lambda { |_ev| !$game_switches[143] }
    avoid statues::ALARMS, :assist => true
    solved(nil, :quiet => true) { $game_switches[143] }
    phase lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => :gg_rocket_hint
  end
end
