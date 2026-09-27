# The keys a page offers are written on it ("[C]: Descripcion", a sentence asking for a key, Awakening's hint
# painted over two lines), and a page composed from the data says them after it.
Suite.define("summary: the key hints a page paints are said after it") do
  s = PokeAccess::Summary
  eq "a bracketed key, a sentence asking for one, and one painted over two lines",
     s.page_hints(["PS", "[C]: Descripcion", "Habilidad", "Pulsa F para leer la descripcion completa.",
                   "Pulsa S en cualquier pantalla", "para ver la descripcion."]),
     ["[C]: Descripcion.", "Pulsa F para leer la descripcion completa.", "Pulsa S en cualquier pantalla para ver la descripcion."]
  eq "a page without any says the page alone", s.with_hints("Estadisticas.", ["PS", "Ataque"]), "Estadisticas."
  eq "and with one, it follows", s.with_hints("Estadisticas.", ["[D]: Descripcion"]), "Estadisticas. [D]: Descripcion."
end
