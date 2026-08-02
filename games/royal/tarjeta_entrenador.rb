module PokeAccess
  # royal's trainer League Card ([ROYAL] Tarjetas Liga -> TarjetaEntrenador_Scene): a static card drawn in
  # pbStartScene with the player's name, ID, Pokedex tally, money, gameplay points, badges, next-leader level
  # and play time. All read from $player and a couple of game variables when the scene opens (pressing C
  # opens the actual card list, which tarjetas_liga.rb covers).
  module RoyalTrainerCard
    # The game variable royal stores the next gym leader's level in.
    NEXT_LEADER_LEVEL_VAR = 24

    # The spoken card summary, or nil.
    def self.text
      return nil unless $player
      player = $player
      parts = ["Tarjeta de liga", "Nombre: #{player.name}"]
      id = (player.public_ID rescue nil); parts.push("Identificador: #{id}") if id
      dex = (player.pokedex rescue nil)
      parts.push("Pokédex: #{dex.owned_count} capturados de #{dex.seen_count} vistos") if dex
      mn = (player.money rescue nil); parts.push("Dinero: #{mn}") if mn
      pts = (player.puntos_gameplay_total rescue nil); parts.push("Puntos: #{pts}") if pts
      bc = PokeAccess::Util.badge_count(player); parts.push("Medallas: #{bc}") if bc
      nl = ($game_variables[NEXT_LEADER_LEVEL_VAR] rescue nil); parts.push("Nivel del próximo líder: #{nl}") if nl && nl.to_i > 0
      secs = ($stats.play_time.to_i rescue nil) || (Graphics.frame_count / Graphics.frame_rate rescue nil)
      hm = PokeAccess::Util.playtime_parts(secs)
      if hm
        h = hm[0]; m = hm[1]
        dur = (h > 0) ? "#{h} horas #{m} minutos" : "#{m} minutos"
        parts.push("Tiempo de juego: #{dur}")
      end
      parts.join(", ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  read_on_open("TarjetaEntrenador_Scene") { |_s| PokeAccess::RoyalTrainerCard.text }
end
