# Currydex (royal's [ROYAL] Curry plugin): Window_Currydex is a Window_DrawableCommand, but its entries
# are [number, name] pairs, which the generic reader skips (pairs read as nil for safety), so the list was
# silent. This extractor reads the focused recipe -- its number and name, or "no descubierto" for one not
# yet found -- and what the screen repaints beside it: the best score with its star rank (the
# puntuacion_1..5 icon), and the recipe's description on the info key. The recipe count the screen keeps
# in its corner is said once, as it opens.
PokeAccess::Game.define("royal") do
  screen_reader("Window_Currydex") do |win, i|
    cmds = win.instance_variable_get(:@commands)
    next nil unless cmds.is_a?(Array) && cmds[i]
    id = cmds[i][0]
    num = id.to_i; name = cmds[i][1]
    next "#{num + 1}, no descubierto" unless (pbCurryRegistered?(id) rescue false)
    parts = ["#{num + 1}, #{name}"]
    best = ($PokemonGlobal.curry_mejor_puntuacion[id] rescue nil)
    if best.is_a?(Integer) && best > -1
      rank = (rangoPuntuacionCurry(best) rescue -1).to_i
      stars = rank == 1 ? "1 estrella" : "#{rank} estrellas"
      parts.push(rank > 0 ? "mejor puntuación #{best}, #{stars}" : "mejor puntuación #{best}")
    end
    desc = (ResultadosCurry::LISTADO_CURRYS[id][2] rescue nil)
    PokeAccess::Info.set_info(:text, PokeAccess.clean(desc.to_s)) if desc && !desc.to_s.empty?
    parts.join(", ")
  end

  after("PokemonCurrydex_Scene", :pbStartScene, :optional => true) do |_s, _r, _a|
    total = (ResultadosCurry::LISTADO_CURRYS.length rescue nil)
    found = (pbCurryDexCount rescue nil)
    PokeAccess.speak("Recetas: #{found} de #{total}", false) if found && total
  end
end
