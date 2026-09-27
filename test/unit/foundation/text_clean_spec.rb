# PokeAccess.clean strips Essentials control codes (\c[n], \v[n], \PN...) and tags, and turns control bytes and
# line breaks into single spaces.
Suite.define("text: clean strips control codes and markup") do
  out = PokeAccess.clean("\\c[3]Hola\\v[1] <b>mundo</b>")
  truthy "no control codes or tags remain", out && out !~ /\\c|\\v|<b>/

  vout = PokeAccess.clean("HP \\v[5] restante")
  $game_variables[5] = 42
  eq "\\v[n] interpolates the game variable", PokeAccess.clean("HP \\v[5] restante"), "HP 42 restante"

  eq "html tags are removed but the inner text stays",
     PokeAccess.clean("Usa <ar>Surf</ar> aqui"), "Usa Surf aqui"
  eq "control bytes and newlines collapse to one space",
     PokeAccess.clean("uno\ndos\x01tres"), "uno dos tres"
  eq "blank input cleans to empty", PokeAccess.clean(nil), ""
end

# A bare code glued to the text ("\bHello!") is stripped by name, keeping the word after it.
Suite.define("text: a control code glued to the text loses the code and keeps the word") do
  bs = "\\"
  eq "the speaker colour before the first word", PokeAccess.clean(bs + "bHello! Sorry to keep you waiting!"),
     "Hello! Sorry to keep you waiting!"
  eq "the other colour too", PokeAccess.clean(bs + "rGreetings, " + bs + "PN!"), "Greetings, #{$Trainer.name}!"
  eq "the gendered colours", PokeAccess.clean(bs + "pogHola " + bs + "pgadios"), "Hola adios"
  eq "a line-break code glued to the next word becomes a space", PokeAccess.clean("a world" + bs + "nwhere"),
     "a world where"
  eq "the wait code and the window codes vanish", PokeAccess.clean("So?" + bs + "1 " + bs + "op" + bs + "cl end"),
     "So? end"
  eq "bracketed codes go whole, however long",
     PokeAccess.clean("<ac>" + bs + "c[0]" + bs + "l[3]You are" + bs + "wtnp[20] here"), "You are here"
  eq "an unknown standalone code and an actor-name code go", PokeAccess.clean(bs + "xyz " + bs + "n[1] ok"), "ok"
  eq "the money code reads the player's money", PokeAccess.clean("You have " + bs + "pm."), "You have #{$Trainer.money}."
  eq "a hex colour code goes", PokeAccess.clean(bs + "[ff00ff00]Red" + bs + "[00000000]!"), "Red!"
end

# The player's name codes: \upn upper case, \dpn lower case, \PN as is; \xn[name] becomes the speaker.
Suite.define("text: the player's name is spoken in the case the code asks for") do
  bs = "\\"
  who = $Trainer.name
  eq "the upper-case code", PokeAccess.clean(bs + "upnHOLA a todos"), "#{who.upcase}HOLA a todos"
  eq "the lower-case code", PokeAccess.clean(bs + "dpnhola a todos"), "#{who.downcase}hola a todos"
  eq "and the plain one is unchanged", PokeAccess.clean(bs + "PN dice hola"), "#{who} dice hola"
  eq "the speaker-name code becomes the speaker", PokeAccess.clean(bs + "xn[Cara]Vale."), "Cara: Vale."
end

# Every name-box code says the name before the line; of the \xn family's parameter list (name, colours, font, size,
# ...) only the name, the one field the box paints.
Suite.define("text: every code that opens a name box says the name, and only the name") do
  %w[tg ta tb js dxn xn xna xnb xnc].each do |code|
    line = '\\' + code + "[Brock]Hola."
    eq "#{line} names the speaker", PokeAccess.clean(line), "Brock: Hola."
  end
  eq "and the colour list the box does not paint is not read either",
     PokeAccess.clean('\xn[Brock,ef2110,ffadbd,0,0,nil,0,0,0]Hola.'), "Brock: Hola."
end

# The bare codes of the money and points windows (\pt, \hs, \qp, \apw, \pksz, \wshs) are stripped by name, the word
# after them kept.
Suite.define("text: the bare codes of the money and points windows leave the sentence whole") do
  { '\ptSi.' => "Si.", '\hsOh.' => "Oh.", '\ptAsi que si.' => "Asi que si.",
    '\qp5 puntos.' => "5 puntos.", '\apwHola.' => "Hola.", '\pkszHola.' => "Hola.",
    '\wshsHola.' => "Hola." }.each do |raw, want|
    eq "#{raw} keeps its sentence", PokeAccess.clean(raw), want
  end
end

# register_name_filter lets a profile rewrite the name a name-box code shows (a game's "???" for a hidden speaker);
# a box of question marks, which a screen reader drops, is said as the word for an unknown speaker.
Suite.define("text: a profile can say what name the box really shows") do
  before = PokeAccess.name_filters.dup
  unknown = PokeAccess::I18n.t(:msg_speaker_unknown)
  begin
    PokeAccess.register_name_filter { |nm| nm == "Anthony" ? "???" : nil }
    eq "the profile's rule wins, its question marks said as a word", PokeAccess.clean('\tg[Anthony]Hola.'),
       "#{unknown}: Hola."
    eq "and leaves every other name alone", PokeAccess.clean('\tg[Brock]Hola.'), "Brock: Hola."
  ensure
    PokeAccess.name_filters.replace(before)
  end
end

# Reminiscencia's intro names its speaker "???" outright (\tg[???]); the box paints the marks, and the line must not
# sound like narration.
Suite.define("text: a name box of question marks is an unknown speaker, not a silent one") do
  unknown = PokeAccess::I18n.t(:msg_speaker_unknown)
  eq "\\tg[???] leads with the word", PokeAccess.clean('\tg[???]¿Dónde...? ¿Dónde me encuentro...?'),
     "#{unknown}: ¿Dónde...? ¿Dónde me encuentro...?"
  eq "any run of them", PokeAccess.clean('\tg[??]Hola.'), "#{unknown}: Hola."
  eq "a name with a question mark in it stays", PokeAccess.clean('\tg[¿Quién?]Hola.'), "¿Quién?: Hola."
  eq "and marks in the message itself are the message's", PokeAccess.clean('\tg[Kyle]¿???'), "Kyle: ¿???"
end

# The games' text drawing turns five entities back into characters (toUnformattedText, getFormattedText); the
# spoken line does too, after the tags are gone, &amp; last as the games do.
Suite.define("text: the entities a game writes are said as the characters it paints") do
  eq "quotes", PokeAccess.clean('\tg[Raiu]&quot;Señor Raiu&quot;, ¿eh?'), "Raiu: \"Señor Raiu\", ¿eh?"
  eq "apostrophe, ampersand, angle brackets", PokeAccess.clean("Kyle&apos;s &amp; Co &lt;3 &gt;"), "Kyle's & Co <3 >"
  eq "a decoded bracket is not taken for a tag", PokeAccess.clean("&lt;b&gt;negrita&lt;/b&gt;"), "<b>negrita</b>"
  eq "an escaped entity stays one, as painted", PokeAccess.clean("&amp;quot;"), "&quot;"
  eq "real tags still go", PokeAccess.clean("<c2=06644bd2>Hola</c2> &quot;tú&quot;"), "Hola \"tú\""
end

# PokeAccess.sentences puts one period between parts: none after a part that closes its own, or after a colon.
Suite.define("sentences: one mark between parts, none after a closing one or a lead-in colon") do
  eq "plain parts take a period", PokeAccess.sentences(["Piso 3", "Nivel maximo 15"]), "Piso 3. Nivel maximo 15"
  eq "a part that closes its own takes no second one", PokeAccess.sentences(["Teletr.", "Uno"]), "Teletr. Uno"
  eq "a label ending in a colon leads into the next part", PokeAccess.sentences(["LISTA DE TARJETAS:", "Pulsa C"]),
     "LISTA DE TARJETAS: Pulsa C"
  eq "and empty parts are left out", PokeAccess.sentences(["", "Uno", " "]), "Uno"
end

# PokeAccess.clean_fields joins a panel's fields with ", ": a money window's right-align tag is a separator, the comma
# grouping the thousands of the sum it paints is not.
Suite.define("text: clean_fields separates a panel's fields and keeps a painted sum whole") do
  eq "a money window", PokeAccess.clean_fields("Money:\r\n<r>$3,000"), "Money:, $3,000"
  eq "every group of a long number", PokeAccess.clean_fields("1,234,567 pts<br>next"), "1,234,567 pts, next"
  eq "runs of separators become one", PokeAccess.clean_fields("<r>a,,b , c<br>"), "a, b, c"
end
