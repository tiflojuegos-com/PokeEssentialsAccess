# Awakening's continue panel ("0271 Panel intro Jess.rb"): the badge slot is relabelled "Capítulo" and holds
# the story chapter, the pokedex line is commented out, and under it goes "Alineación" -- Orden, Caos or
# Neutro from whichever route file exists, "---" for none -- with the finished endings as four icons
# (Forden, Fcaos, Fneutral, Freal) and the saved team as icons. The stock panel reader said "4 medallas"
# and nothing of the rest.
module PokeAccess
  module AwakeningLoad
    ROUTES = [["Data/rutaorden.dat", "Orden"], ["Data/rutacaos.dat", "Caos"], ["Data/rutaneutra.dat", "Neutro"]]
    ENDINGS = [[2, "Orden"], [1, "Caos"], [3, "Neutro"]]

    # The alignment the panel paints: the first route file that exists, in the panel's own order.
    # param exist how a path is tested, so a spec can stand in for the disk
    def self.alignment(exist = nil)
      exist ||= lambda { |p| File.exist?(p) }
      hit = ROUTES.find { |path, _name| exist.call(path) }
      "Alineación: " + (hit ? hit[1] : "ninguna")
    end

    # The endings already completed, as the four icons say them: three through the game's own
    # checkNewGamePlus, the true ending through its own file. nil when none is done.
    def self.endings(check = nil, exist = nil)
      check ||= lambda { |n| (checkNewGamePlus(n) rescue false) }
      exist ||= lambda { |p| File.exist?(p) }
      done = ENDINGS.select { |n, _name| check.call(n) }.map { |_n, name| name }
      done.push("Real") if exist.call("Data/realfin.dat")
      done.empty? ? nil : "Finales completados: " + done.join(", ")
    end

    # How many Pokemon the saved team has, from the party the panel draws as icons.
    def self.team(trainer)
      n = (trainer.party.length rescue nil)
      n ? "Equipo de #{n}" : nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  override(PokeAccess::LoadPanel, :badges_text) { |_mod, _original, args| "Capítulo #{args[0]}" }
  override(PokeAccess::LoadPanel, :extras) do |_mod, _original, args|
    [PokeAccess::AwakeningLoad.alignment, PokeAccess::AwakeningLoad.endings, PokeAccess::AwakeningLoad.team(args[0])]
  end
end
