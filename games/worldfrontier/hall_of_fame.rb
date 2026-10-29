# World Frontier's edit of the BW Hall of Fame: each card's lower bar paints the nickname alone, with no level, and its
# upper bar the type icons alone, with no species; the finale crowns the Battle Frontier's champion. Read as painted
# (royal_common leaves the sex out).
module PokeAccess
  module WfHallOfFame
    # A team member's card: the nickname, then the types its icons show.
    def self.card(pk)
      return nil unless pk
      types = PokeAccess::Data.pokemon_types(pk)
      parts = [(pk.name rescue nil).to_s]
      parts.push(PokeAccess::I18n.t(:mv_type, :t => types.join("/"))) unless types.empty?
      parts.reject { |p| p.empty? }.join(", ")
    end

    # The finale: the champion line as the game writes it, then the player and the play time its lower bar shows.
    def self.finale(scene)
      first = _INTL("¡{1}! ¡Felicidades!", _INTL("Campeón del Frente Batalla Mundial"))
      name = (PokeAccess::Engine.player.name rescue nil).to_s
      time = (scene.get_play_time_formatted rescue nil)
      second = time ? PokeAccess::I18n.t(:hofbw_finale, :name => name, :time => time) : name
      PokeAccess::Util.join_parts([first, name.empty? ? nil : second], " ")
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  override("PokeAccess::HallOfFameBW", :card) do |_mod, _original, args|
    (PokeAccess::WfHallOfFame.card(args[0]) rescue nil)
  end
  override("PokeAccess::HallOfFameBW", :finale) do |_mod, _original, args|
    (PokeAccess::WfHallOfFame.finale(args[0]) rescue nil)
  end
end
