# Text cleaning for speech: clean strips Essentials control codes (\c[n], \v[n], \PN...) and HTML-like
# tags, collapses whitespace, and removes the non-speakable control bytes (\x00-\x1f) whose presence makes a
# paused line differ from its twin and slip past say_dialogue's dedup (the double-battle-message bug).
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

# A bare code is glued straight onto the text ("\bHello!"), so the stripper must know the codes by name:
# matched as "a backslash and some letters" it swallowed the first word of every such line, which is how
# all of FireAsh's dialogue (speaker colour \b on every message) lost its opening word.
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

# A bare code the list does not know is not stripped, it is SPOKEN: the generic remover leaves a code glued
# to its text alone on purpose, so that it cannot eat the first word. Which makes the list of codes the only
# thing standing between the player and hearing "upnHOLA jugador" out loud -- and that is a real line from a
# real game, whose message system adds the player's name in upper and lower case.
Suite.define("text: the player's name is spoken in the case the code asks for") do
  bs = "\\"
  who = $Trainer.name
  eq "the upper-case code", PokeAccess.clean(bs + "upnHOLA a todos"), "#{who.upcase}HOLA a todos"
  eq "the lower-case code", PokeAccess.clean(bs + "dpnhola a todos"), "#{who.downcase}hola a todos"
  eq "and the plain one is unchanged", PokeAccess.clean(bs + "PN dice hola"), "#{who} dice hola"
  eq "the speaker-name code becomes the speaker", PokeAccess.clean(bs + "xn[Cara]Vale."), "Cara: Vale."
end

# WHO IS SPEAKING. Seven spellings of the name-box code across the games and their plugins, and only two of
# them were resolved: the other five went through the generic bracket sweep, so the box appeared on screen
# and the line reached the player with no subject at all. And the \xn family carries a whole parameter list
# (name, base colour, shadow colour, font, size, alignment, x, y, skin) of which the window paints only the
# first field -- the rest was read out as hexadecimal.
Suite.define("text: every code that opens a name box says the name, and only the name") do
  %w[tg ta tb js dxn xn xna xnb xnc].each do |code|
    line = '\\' + code + "[Brock]Hola."
    eq "#{line} names the speaker", PokeAccess.clean(line), "Brock: Hola."
  end
  eq "and the colour list the box does not paint is not read either",
     PokeAccess.clean('\xn[Brock,ef2110,ffadbd,0,0,nil,0,0,0]Hola.'), "Brock: Hola."
end

# A bare code that is not on the list falls to the generic sweep, which cannot tell where it ends: it eats
# the word after it, and where the next letter is accented -- not [A-Za-z] -- it splits the word instead and
# the code itself is spoken letter by letter. \pt alone is in vanilla and eight of the games.
Suite.define("text: the bare codes of the money and points windows leave the sentence whole") do
  { '\ptSi.' => "Si.", '\hsOh.' => "Oh.", '\ptAsi que si.' => "Asi que si.",
    '\qp5 puntos.' => "5 puntos.", '\apwHola.' => "Hola.", '\pkszHola.' => "Hola.",
    '\wshsHola.' => "Hola." }.each do |raw, want|
    eq "#{raw} keeps its sentence", PokeAccess.clean(raw), want
  end
end

# The name in the CODE is not always the name on the SCREEN. One game hides a character behind "???" until a
# switch is flipped and rewrites the parameter on its way to the box, so reading the code raw handed the
# player exactly what that scene is withholding. The rule is the game's, so a profile registers it.
Suite.define("text: a profile can say what name the box really shows") do
  before = PokeAccess.name_filters.dup
  begin
    PokeAccess.register_name_filter { |nm| nm == "Anthony" ? "???" : nil }
    eq "the profile's rule wins", PokeAccess.clean('\tg[Anthony]Hola.'), "???: Hola."
    eq "and leaves every other name alone", PokeAccess.clean('\tg[Brock]Hola.'), "Brock: Hola."
  ensure
    PokeAccess.name_filters.replace(before)
  end
end
