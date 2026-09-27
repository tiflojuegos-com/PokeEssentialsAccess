# Focus primitives: UIV21.speak_changed keyed by slot as well as text, NumberEntry's dedup per window, the info key
# letting a closed screen's text go, and a sprite-button menu's nested fades.
Suite.define("menus: dos entradas que suenan igual se leen las dos") do
  ui = PokeAccess::UIV21
  ui.reset(:pea_focus)
  SpeakCapture.clear

  ui.speak_changed(:pea_focus, "Huevo", 1)
  ui.speak_changed(:pea_focus, "Huevo", 2)
  eq("los dos huevos se dicen", SpeakCapture.lines.length, 2)

  SpeakCapture.clear
  ui.speak_changed(:pea_focus, "Huevo", 2)
  ui.speak_changed(:pea_focus, "Huevo", 2)
  eq("el mismo hueco no se repite", SpeakCapture.lines.length, 0)

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

  win_b = Object.new
  ne.on_text(win_b, "x5")
  eq("tras reabrir con ventana nueva, se vuelve a decir", SpeakCapture.lines.length, 2)

  ne.forget
  ne.on_text(win_b, "x5")
  eq("forget tambien suelta el dedup de la misma ventana", SpeakCapture.lines.length, 3)
end

Suite.define("menus: el primer numero de un selector va en cola tras su pregunta, los cambios la cortan") do
  ne = PokeAccess::NumberEntry
  win = Object.new
  win.instance_variable_set(:@index, 0)
  win.instance_variable_set(:@digits_max, 3)
  def win.number; 10; end
  def win.sign; false; end
  SpeakCapture.clear
  ne.on_digit_window(win)
  eq("al abrir, el numero en cola", SpeakCapture.log, [["10", false]])
  win.instance_variable_set(:@index, 1)
  ne.on_digit_window(win)
  eq("mover de columna interrumpe", SpeakCapture.log.last[1], true)
end

Suite.define("field: la tecla de info suelta el texto de una pantalla que se cierra") do
  info = PokeAccess::Info

  info.set_info(:text, "lore de la carta")
  truthy("el texto esta disponible", info.info_text.to_s.include?("lore"))
  info.clear_text
  falsy("tras cerrar la pantalla, ya no", info.info_text.to_s.include?("lore"))

  pk =PokeAccess::Build.pokemon(:PIKACHU, 5) rescue nil
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

  r.enter!
  r.enter!
  r.leave!
  eq("el fade interno no anuncia", SpeakCapture.lines.length, 0)
  r.leave!
  truthy("el externo si", SpeakCapture.lines.length <= 1)

  m.close!
end

# Armonia and Africanus end the menu's scene before using a key item or a field move, from inside the held
# loop: the messages the use shows end as returns to a menu that is gone, and must not bring its option back.
Suite.define("menus: a sprite-button menu taken off the screen brings back no option") do
  m = PokeAccess::SpriteButtonMenu
  r = PokeAccess::MenuReturn
  r.reset_nesting
  m.open!
  begin
    m.instance_variable_set(:@last, "Mochila")
    SpeakCapture.clear
    r.enter!
    r.leave!
    eq "a message over the menu brings its option back", SpeakCapture.lines, ["Mochila"]
    m.gone!
    SpeakCapture.clear
    r.enter!
    r.leave!
    silent "once the menu has ended its scene, a message's end says nothing of it"
  ensure
    m.close!
  end
end
