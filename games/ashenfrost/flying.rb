# Ashen Frost's flying game (maps 551, 654 and 703): a box of four columns by seven rows the player moves in, closed by its tiles'
# passage bits, and the obstacles the control event sends through it from the right by move routes, a wave every two seconds. A
# touch costs health, which only its picture shows. The box's edge would hide them from the sonar until they are beside the player,
# and a wave takes 0.25 seconds a tile, 0.125 the fast ones, so on these maps they are heard through it and much oftener. They keep
# their graphics once they have passed and once their routes end, and the sonar keeps the nearest: only those on their way sound.
module PokeAccess
  module AshenFlying
    MAPS = [551, 654, 703]
    HEALTH_PICTURE = 2
    # The seconds between pings of the obstacles, one family: each of its nearest three sounds about once a second.
    PING_SECONDS = 0.3
    # A tile of the box no wave crosses on any of the three maps, as their routes walk them.
    SAFE_TILE = [12, 8]
    # The move-route steps that take an obstacle back to the right, flying left: right, lower right, upper right, backward.
    RIGHTWARD = [3, 6, 8, 13]

    # Whether the player is in the flying game.
    def self.here?
      $game_map && MAPS.include?($game_map.map_id) ? true : false
    end

    # Whether an obstacle is on its way to the player: its route runs, and it has not reached their column or has yet to turn
    # back, as one wave does inside the box.
    def self.coming?(ev)
      return false unless ev.move_route_forcing
      ev.x > $game_player.x || turning_back?(ev)
    end

    # Whether what is left of an obstacle's route steps back to the right.
    def self.turning_back?(ev)
      route = PokeAccess.ivar(ev, :@move_route)
      return false unless route
      (route.list[PokeAccess.ivar_i(ev, :@move_route_index)..-1] || []).any? { |c| RIGHTWARD.include?(c.code) }
    end

    # The assist's hint: where the safe tile is from the player.
    def self.safe_hint
      off = PokeAccess::Puzzles.offset_phrase(SAFE_TILE[0] - $game_player.x, SAFE_TILE[1] - $game_player.y)
      off.empty? ? :ashen_fly_safe_here : [:ashen_fly_safe, { :dist => off }]
    end

    # The health as its picture paints it; nil while there is none.
    def self.health
      PokeAccess::AshenPictures.counter($game_screen.pictures[HEALTH_PICTURE].name.to_s)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, PokeAccess::AshenFlying::MAPS) do
    obstacle(/\AFlying_Game_/, :moving => true, :label => :ashen_fly_obstacle)
    arrival_hint :ashen_fly_rule
    hint lambda { PokeAccess::AshenFlying.safe_hint }
    info { PokeAccess::AshenFlying.health }
  end

  override("PokeAccess::Sound::Scene", :family_of) do |_mod, original, args|
    family = original.call
    family == :trap && !PokeAccess::AshenFlying.coming?(args[0]) ? nil : family
  end
  # Beside an obstacle it is too late for a line, which would only hold up the next warning: the sonar tells them.
  override("PokeAccess::Puzzles", :near_phrase) do |_mod, original, _args|
    PokeAccess::AshenFlying.here? ? nil : original.call
  end
  override("PokeAccess::Sound::Scene", :occlusion_mode) do |_mod, original, _args|
    PokeAccess::AshenFlying.here? ? :hear : original.call
  end
  override("PokeAccess::Sound::Mixer", :ping_seconds) do |_mod, original, args|
    args[0] == :trap && PokeAccess::AshenFlying.here? ? PokeAccess::AshenFlying::PING_SECONDS : original.call
  end
end
