# The Snow Field (map 129): a blizzard hides the way, and with the Radiant Talisman (switch 146) a picture of it points
# ahead, to the left or to the right of where the player faces, by the game's laberintodehielodeloscojones; mkxp builds
# draw it as frames under talisman/normal, izquierda and derecha, others as amuleto1, amuletoizda and amuletodcha.
# Fifteen watchers (named Trainer(4), walking through) add to variable 69 when they see the player, and the exit at (5 and
# 6, 4) sends a player seen by any back to the start (35, 48); walks go round their sight, and the free camera says it.
# Crossing it sets no switch: beating Azelf (316), beyond it, ends it.
module PokeAccess
  module RealideaSnow
    MAP = 129
    START = [35, 48]
    AZELF_BEATEN = 316
    EXITS = [22, 23]
    WATCHERS = (8..20).to_a + [2, 3]
    WAYS = { :ahead => /talisman\/normal|amuleto1/, :left => /talisman\/izquierda|amuletoizda/,
             :right => /talisman\/derecha|amuletodcha/ }
    LINES = { :ahead => :rea_snow_ahead, :left => :rea_snow_left, :right => :rea_snow_right }
    FACES = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # Frames without the picture after which its way is told again, as after a menu or a return to the map.
    GAP = 20

    # Says where the talisman points as its picture changes way on the Snow Field.
    def self.on_picture(name)
      return unless $game_map.map_id == MAP
      way = WAYS.keys.find { |k| name.to_s =~ WAYS[k] }
      return unless way
      now = (Graphics.frame_count rescue 0)
      fresh = @at.nil? || now - @at > GAP
      @at = now
      return if way == @last && !fresh
      @last = way
      PokeAccess.speak(PokeAccess::I18n.t(LINES[way]), true)
    end

    # Forgets the last way told, so the next showing tells it again.
    def self.forget
      @last = nil
      @at = nil
    end

    # The name of a watcher, with the way it faces as it is asked.
    def self.watcher(ev)
      [:rea_snow_watcher, { :dir => PokeAccess::I18n.t(FACES[ev.direction] || :dir_down) }]
    end
  end
end

PokeAccess::Caches.register(:realidea_snow) { PokeAccess::RealideaSnow.forget }

PokeAccess::Game.define("realidea") do
  snow = PokeAccess::RealideaSnow
  on_picture { |name, _args| snow.on_picture(name) }
  watchers(snow::MAP)
  mechanic(:state, snow::MAP) do
    auto
    name snow::WATCHERS, lambda { |ev| snow.watcher(ev) }
    sent_back :rea_snow_back, :to => snow::START, :events => snow::EXITS
    active { PokeAccess::Puzzles.assist? && !$game_switches[snow::AZELF_BEATEN] }
    solved(nil, :quiet => true) { $game_switches[snow::AZELF_BEATEN] }
    hint :rea_snow_hint
  end
end
