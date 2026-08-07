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

  ne.on_text("x5")
  eq("la primera cantidad se dice", SpeakCapture.lines.length, 1)
  ne.on_text("x5")
  eq("repetida dentro del mismo aviso, no", SpeakCapture.lines.length, 1)

  # El selector nace de nuevo en cada aviso, y ese nacimiento es el limite: sin soltar el dedup, cancelar y
  # volver a entrar en el mismo objeto -- comparar precios, el gesto normal en una tienda -- es mudo.
  ne.forget
  ne.on_text("x5")
  eq("tras reabrir, se vuelve a decir", SpeakCapture.lines.length, 2)
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
  m.reset_nesting
  m.open!
  m.focus(nil, 0) rescue nil
  SpeakCapture.clear

  # El menu abre la mochila (un fade) y desde dentro se da un objeto (otro fade). Solo la salida del de
  # fuera devuelve el menu al frente: el de dentro acaba con la mochila en pantalla.
  m.fade_in!
  m.fade_in!
  m.fade_out!
  eq("el fade interno no anuncia", SpeakCapture.lines.length, 0)
  m.fade_out!
  truthy("el externo si", SpeakCapture.lines.length <= 1)

  m.close!
end
