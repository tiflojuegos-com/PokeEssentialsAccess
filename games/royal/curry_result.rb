# royal's curry result screens ([ROYAL] Curry): ResultadosCurry_Scene shows the dish made and
# ResultadosCurryPuntos_Scene the quality rank. Both are non-navigable displays whose key text is drawn as
# an overlay (not a message), so read it on open: the curry name (@tipo_de_curry[1]) and the rank
# (@pokemon_puntos, a Pokemon name standing for quality -- Charizard best, Koffing worst). The
# congratulation/happiness lines use pbMessageBlack and are already voiced by the dialogue hook.
PokeAccess::Game.define("royal") do
  read_on_open("ResultadosCurry_Scene") do |scr|
    curry = PokeAccess.ivar(scr, :@tipo_de_curry)
    (curry.is_a?(Array) && curry[1] && !curry[1].to_s.empty?) ? "Has cocinado #{curry[1]}" : nil
  end

  read_on_open("ResultadosCurryPuntos_Scene") do |scr|
    rank = PokeAccess.ivar(scr, :@pokemon_puntos)
    (rank && !rank.to_s.empty?) ? "Digno de un #{rank}" : nil
  end
end
