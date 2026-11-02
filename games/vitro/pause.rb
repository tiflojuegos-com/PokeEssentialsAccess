# Vitro's pause menu (0281_Menu_Base, Menu2) paints each icon's word under it, said as painted, and on its panel the map's
# name, the time and, in the Safari or the Bug Contest, the balls and the catch; a rescue chain's count in its corner. The
# info key says them with the trainer, whose money it already has.
module PokeAccess
  module VitroPause
    @open = false

    # Runs the menu saying it is up, and hands that back as it closes.
    def self.painting
      was = @open
      @open = true
      yield
    ensure
      @open = was
    end

    # The map's name and the time, as the panel paints them.
    def self.place
      return nil unless @open
      "#{pbGetMapNameFromId($game_map.map_id)}, #{pbGetTimeNow.strftime('%H:%M')}"
    end

    # The balls left in the Safari or the Bug Contest, and the contest's catch, as the panel paints them.
    def self.contest
      return nil unless @open
      return _INTL("Balls: {1}", pbSafariState.ballcount) if pbInSafari?
      return nil unless pbInBugContest?
      balls = _INTL("Balls: {1}", pbBugContestState.ballcount)
      last = pbBugContestState.lastPokemon
      last ? "#{balls}, #{_INTL('{1} Lv. {2}', PBSpecies.getName(last.species), last.level)}" : balls
    end

    # The rescue chain's count and the species of its icon, as its corner paints them from two rescues on, and not with a
    # contest's catch there.
    def self.chain
      return nil if !@open || pbBugContestState.lastPokemon
      count, species = ($PokemonTemp.rescuechain rescue nil)
      return nil unless count && count > 1
      "#{_INTL('Cadena de {1}', count)}, #{PokeAccess::Data.species_name(species)}"
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::Menu2Pause", :label) { |_mod, _original, args| PokeAccess.clean(args[0][1].to_s) }
  trainer_part(:place) { |_trainer| PokeAccess::VitroPause.place }
  trainer_part(:contest) { |_trainer| PokeAccess::VitroPause.contest }
  trainer_part(:chain) { |_trainer| PokeAccess::VitroPause.chain }
  around("Menu2", :pbUpdate, :optional => true) { |_menu, nxt, _a| PokeAccess::VitroPause.painting { nxt.call } }
end
