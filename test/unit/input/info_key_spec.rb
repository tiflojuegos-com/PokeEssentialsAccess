# The info key says the focused thing's sheet; with Ctrl, the focused row whole where the screen published one, else
# the same sheet.
Suite.define("info key: T says the sheet, Ctrl+T the row whole, and a screen with no row answers Ctrl+T with T") do
  keys = PokeAccess::Keys
  ctrl = keys.method(:ctrl_down?)
  shift = keys.method(:shift_down?)
  held = []
  keys.define_singleton_method(:ctrl_down?) { held.include?(:ctrl) }
  keys.define_singleton_method(:shift_down?) { held.include?(:shift) }
  begin
    PokeAccess::Info.set_info(:text, "Poción. Restaura 20 PS.", "Poción: 3, registrado")
    SpeakCapture.clear
    keys.info_key
    eq "T: the sheet", SpeakCapture.last, "Poción. Restaura 20 PS."
    held.push(:ctrl)
    SpeakCapture.clear
    keys.info_key
    eq "Ctrl+T: the row whole", SpeakCapture.last, "Poción: 3, registrado"
    PokeAccess::Info.add_to_row("En la mochila: 3", :qty)
    SpeakCapture.clear
    keys.info_key
    eq "with the windows that belong to it", SpeakCapture.last, "Poción: 3, registrado. En la mochila: 3"
    PokeAccess::Info.set_info(:text, "Una línea sin fila")
    SpeakCapture.clear
    keys.info_key
    eq "a screen with no row answers Ctrl+T with the info key's own text", SpeakCapture.last, "Una línea sin fila"
  ensure
    keys.define_singleton_method(:ctrl_down?, ctrl)
    keys.define_singleton_method(:shift_down?, shift)
  end
end
