# Labradorra Gym (map 779), the foes as they come: variable 478 counts the waves and the movement controller (event 83)
# sends each foe named "<wave>-<species>" to the chest. The mod says each once as it comes into view and once as it gets
# within reach of the chest while the chest is in view too.
module PokeAccess
  module RebornLabradorraFoes
    SCREEN = [8, 6]
    NEAR = 3
    ORDER = /\A(\d+)-/

    # The foes sent off up to a wave, looked up once a wave.
    def self.walkers(wave)
      foe = PokeAccess::RebornLabradorra::FOE
      ($game_map.events || {}).values.select do |e|
        m = e.name.to_s.match(ORDER)
        m && m[1].to_i <= wave && e.name.to_s =~ foe
      end
    end

    # True while a tile is on the player's screen, 16 tiles by 12 around them.
    def self.in_view?(x, y)
      (x - $game_player.x).abs <= SCREEN[0] && (y - $game_player.y).abs <= SCREEN[1]
    end

    # Each pulse in the gym: says each foe sent off as it comes into view and as it nears the chest.
    def self.tick
      gym = PokeAccess::RebornLabradorra
      return unless $game_map && $game_player && $game_map.map_id == gym::MAP && PokeAccess::Control.scene_map?
      return if $game_switches[gym::DONE]
      wave = $game_variables[478].to_i
      if wave != @wave
        @seen = {} if @wave.nil? || wave < @wave
        @near = {} if @wave.nil? || wave < @wave
        @wave = wave
        @foes = wave < 1 ? [] : walkers(wave)
      end
      @foes.each { |foe| say(foe, gym) }
    end

    # Says one foe if it has just come into view or near the chest.
    def self.say(foe, gym)
      return if PokeAccess.ivar(foe, :@erased) || foe.character_name.to_s.empty? || !in_view?(foe.x, foe.y)
      i18n = PokeAccess::I18n
      name = gym.foe_label(foe).to_s
      unless @seen[foe.id]
        @seen[foe.id] = true
        where = PokeAccess::Locator.dir_phrase(foe.x - $game_player.x, foe.y - $game_player.y)
        PokeAccess.speak(i18n.t(:rbg_foe_comes, :name => name, :where => where), false)
        return
      end
      return if @near[foe.id] || gym.to_chest(foe) > NEAR || !gym::CHEST.any? { |x, y| in_view?(x, y) }
      @near[foe.id] = true
      PokeAccess.speak(i18n.t(:rbg_foe_near_chest, :name => name), true)
    end

    # Forgets the waves, on a new map.
    def self.forget
      @wave = nil
      @foes = []
    end

    PokeAccess::Frame.each_pulse { PokeAccess::RebornLabradorraFoes.tick } unless @pulsing
    @pulsing = true
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornLabradorraFoes.forget }
