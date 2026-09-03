# Las tres primitivas que la ronda 2 tuvo que arreglar, cada una detras de un fallo distinto que ninguna
# prueba de "¿habla?" ve, porque el sintoma es que NO habla en el segundo caso.
#
#   - la clave de dedup por TEXTO, que enmudece al moverse entre dos entradas que suenan igual
#   - un dedup de MODULO que nadie reinicia, que enmudece al reabrir el mismo aviso
#   - un slot global para la tecla de info, que contesta por una pantalla que ya se cerro
Suite.define("menus: dos entradas que suenan igual se leen las dos") do
  ui = PokeAccess::UIV21
  ui.reset(:pea_focus)
  SpeakCapture.clear

  # Dos huevos seguidos: party_member devuelve la misma cadena para los dos, asi que sobre el texto solo el
  # segundo entra mudo y el jugador no sabe que el cursor se ha movido.
  ui.speak_changed(:pea_focus, "Huevo", 1)
  ui.speak_changed(:pea_focus, "Huevo", 2)
  eq("los dos huevos se dicen", SpeakCapture.lines.length, 2)

  # Y el mismo foco repitiendose sigue deduplicando, que es para lo que existe la primitiva.
  SpeakCapture.clear
  ui.speak_changed(:pea_focus, "Huevo", 2)
  ui.speak_changed(:pea_focus, "Huevo", 2)
  eq("el mismo hueco no se repite", SpeakCapture.lines.length, 0)

  # Sin discriminador se comporta como siempre: el texto ES la clave.
  ui.reset(:pea_focus2)
  SpeakCapture.clear
  ui.speak_changed(:pea_focus2, "Pocion")
  ui.speak_changed(:pea_focus2, "Pocion")
  eq("sin clave, el texto sigue deduplicando", SpeakCapture.lines.length, 1)
end

Suite.define("menus: reabrir el selector de cantidad con el mismo importe vuelve a hablar") do
  ne = PokeAccess::NumberEntry
  ne.forget
  SpeakCapture.clear

  win_a = Object.new
  ne.on_text(win_a, "x5")
  eq("la primera cantidad se dice", SpeakCapture.lines.length, 1)
  ne.on_text(win_a, "x5")
  eq("repetida por la misma ventana, no", SpeakCapture.lines.length, 1)

  # Every prompt builds its OWN text window (UIHelper.pbChooseNumber, the marts), and that identity is the
  # boundary between one prompt and the next: cancelling and re-entering on the same object -- comparing
  # prices, the normal gesture in a shop -- speaks even when the amount did not change. Hanging it off a
  # forget hooked to a window that flow never builds left the second prompt mute in all 13 games.
  win_b = Object.new
  ne.on_text(win_b, "x5")
  eq("tras reabrir con ventana nueva, se vuelve a decir", SpeakCapture.lines.length, 2)

  ne.forget
  ne.on_text(win_b, "x5")
  eq("forget tambien suelta el dedup de la misma ventana", SpeakCapture.lines.length, 3)
end

Suite.define("field: la tecla de info suelta el texto de una pantalla que se cierra") do
  info = PokeAccess::Info

  info.set_info(:text, "lore de la carta")
  truthy("el texto esta disponible", info.info_text.to_s.include?("lore"))
  info.clear_text
  falsy("tras cerrar la pantalla, ya no", info.info_text.to_s.include?("lore"))

  # Un Pokemon o un objeto siguen teniendo sentido fuera de su pantalla, asi que clear_text no los toca.
  pk = PokeAccess::Build.pokemon(:PIKACHU, 5) rescue nil
  if pk
    info.set_info(:pokemon, pk)
    info.clear_text
    truthy("un pokemon sobrevive a clear_text", !info.info_text.to_s.empty?)
  end
end

Suite.define("menus: un desvanecido dentro de otro no habla por encima de la pantalla hija") do
  m = PokeAccess::SpriteButtonMenu
  r = PokeAccess::MenuReturn
  r.reset_nesting
  m.open!
  m.focus(nil, 0) rescue nil
  SpeakCapture.clear

  # The menu opens the bag (one fade) and an item is given from inside it (another fade). Only the outer
  # exit brings the menu back: the inner one ends with the bag on screen. The signal is the shared one
  # (MenuReturn), so what is tested is the nesting the menu sees.
  r.enter!
  r.enter!
  r.leave!
  eq("el fade interno no anuncia", SpeakCapture.lines.length, 0)
  r.leave!
  truthy("el externo si", SpeakCapture.lines.length <= 1)

  m.close!
end
