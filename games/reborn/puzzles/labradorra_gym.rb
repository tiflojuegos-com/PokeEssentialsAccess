# Labradorra Gym (map 779): foes named "<order>-<species>" walk to the chest as variable 478 counts the waves, and
# meeting one starts its battle; switch 1098 marks the gym done. Foes are named by their sprite, the event names
# misspelling some; the info key says the nearest. Jump tiles use RebornJumpTiles; events 65 to 69 chain two hops.
module PokeAccess
  module RebornLabradorra
    MAP = 779
    CHEST = [[26, 43], [27, 43]]
    FOE = /\A\d+-([A-Za-z]+?)[A-Z]?\z/
    DONE = 1098

    # A foe's name: a knight, else the species its sprite shows, else the one its event name spells.
    def self.foe_label(ev)
      m = ev.name.to_s.match(FOE)
      return nil unless m
      return PokeAccess::I18n.t(:rbc2_labradorra_knight) if m[1] == "Knight"
      (PokeAccess::Locator.sprite_species_named(ev.character_name.to_s) rescue nil) || m[1]
    end

    # The foes standing now: drawn, of their own page.
    def self.foes
      ($game_map.events || {}).values.select do |e|
        e.name.to_s =~ FOE && !e.character_name.to_s.empty? && !PokeAccess.ivar(e, :@erased)
      end
    end

    # Tiles from a foe to the nearer tile of the chest.
    def self.to_chest(ev)
      CHEST.map { |x, y| (ev.x - x).abs + (ev.y - y).abs }.min
    end

    # With the assist, the foe nearest the chest and where it stands from the player; nil without a foe or the assist.
    def self.info_line
      return nil unless PokeAccess::Puzzles.assist? && !$game_switches[DONE]
      foe = foes.min_by { |e| to_chest(e) }
      return nil unless foe
      where = PokeAccess::Locator.dir_phrase(foe.x - $game_player.x, foe.y - $game_player.y)
      PokeAccess::I18n.t(:rbc2_labradorra_nearest, :name => foe_label(foe).to_s, :count => to_chest(foe), :where => where)
    end
  end
end

PokeAccess::Game.define("reborn") do
  gym = PokeAccess::RebornLabradorra
  mechanic(:state, gym::MAP, :part => :chest) do
    auto
    name gym::FOE, lambda { |ev| gym.foe_label(ev) }
    name [74, 75], :rbc2_labradorra_chest, :grouped => true
    arrival_hint :rbc2_labradorra_rule
    info { gym.info_line }
    active { PokeAccess::Puzzles.assist? && !gym.foes.empty? }
    solved { $game_switches[gym::DONE] }
  end
  jumps = PokeAccess::RebornJumpTiles
  terrain_exit(:maps => gym::MAP, :tiles => lambda { |x, y| jumps.from?(x, y) }) { |x, y, dir| jumps.hop(x, y, dir[2]) }
  mechanic(:state, gym::MAP, :part => :jumps) do
    auto
    arrival_hint :rb2b_labradorra_jump_rule
  end
end
