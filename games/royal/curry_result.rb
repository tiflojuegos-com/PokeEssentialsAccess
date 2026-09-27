# Royal's curry results, painted as overlays and read on open, each as the build paints it: the dish's name alone
# (ResultadosCurry_Scene, @tipo_de_curry[1]) and the rank line (ResultadosCurryPuntos_Scene, @pokemon_puntos).
module PokeAccess
  module RoyalCurryResult
    # The rank line as the scene composes it: its _INTL("¡Digno de un"), which the English build translates, and the
    # rank's Pokemon (Charizard best, Koffing worst); nil without a rank.
    def self.rank_line(rank)
      return nil if rank.nil? || rank.to_s.empty?
      "#{_INTL("¡Digno de un")} #{rank}!"
    end
  end
end

PokeAccess::Game.define("royal") do
  read_on_open("ResultadosCurry_Scene") do |scr|
    curry = PokeAccess.ivar(scr, :@tipo_de_curry)
    (curry.is_a?(Array) && curry[1] && !curry[1].to_s.empty?) ? curry[1].to_s : nil
  end

  read_on_open("ResultadosCurryPuntos_Scene") do |scr|
    PokeAccess::RoyalCurryResult.rank_line(PokeAccess.ivar(scr, :@pokemon_puntos))
  end
end
