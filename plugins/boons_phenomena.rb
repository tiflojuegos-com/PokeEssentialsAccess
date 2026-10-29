module PokeAccess
  # Boon's Phenomena (Phenomenon): the rustling grass, water drops, cave dust or flying birds a step brings up near the
  # player, whose animation and sound tell where only by sight and loudness. Said once as the game first shows one,
  # with where it lies from the player, and once more if it goes away before the player walks onto it.
  module Phenomena
    # The phenomenon's kind, by the encounter type it was made for.
    KINDS = { :PhenomenonGrass => :phen_grass, :PhenomenonWater => :phen_water, :PhenomenonCave => :phen_cave,
              :PhenomenonBird => :phen_bird }
    # The farthest drawAnim draws and sounds one, in tiles across plus along: its (|dx| + |dy|) / 4 <= 6.
    SHOWN = 27

    @said = nil
    @map = nil

    # Speaks a phenomenon drawAnim is about to show, the first time it lies within the game's range (as it comes out,
    # or once the player walks near it): its kind and its place from the player, queued.
    def self.shown(phn)
      return if phn.equal?(@said) || $game_player.nil?
      key = KINDS[phn.type]
      dx = phn.x - $game_player.x
      dy = phn.y - $game_player.y
      return unless key && dx.abs + dy.abs <= SHOWN
      @said = phn
      @map = ($game_map.map_id rescue nil)
      where = PokeAccess::Locator.dir_phrase(dx, dy)
      PokeAccess.speak(PokeAccess::I18n.t(:phen_appeared, :kind => PokeAccess::I18n.t(key), :where => where), false)
    end

    # Says, queued, that the phenomenon said went away, once the game holds it no more and the player is free; not on
    # another map, nor with the player standing on it (they walked onto it, and its battle or item followed).
    def self.tick
      phn = @said
      return if phn.nil? || phn.equal?(($PokemonTemp.phenomenon rescue nil))
      return unless PokeAccess::Control.free?
      forget
      return unless $game_map && $game_player && $game_map.map_id == @map
      return if $game_player.x == phn.x && $game_player.y == phn.y
      PokeAccess.speak(PokeAccess::I18n.t(:phen_gone, :kind => PokeAccess::I18n.t(KINDS[phn.type])), false)
    end

    # Drops the phenomenon said: once it is gone, and on a map change or a load.
    def self.forget; @said = nil; end
  end
end

PokeAccess::Hooks.before_hook("Phenomenon", :drawAnim, :optional => true) do |phn, _a|
  PokeAccess::Phenomena.shown(phn)
end
PokeAccess::Frame.each_pulse { PokeAccess::Phenomena.tick }
PokeAccess::Caches.register(:phenomena) { PokeAccess::Phenomena.forget }
