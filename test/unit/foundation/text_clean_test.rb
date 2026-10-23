# Game text made speakable (core/speech/text.rb): clean says the name, money and variable codes and a name box's
# speaker, drops the other codes and tags and decodes entities; clean_fields and sentences join fields and parts.
class TextCleanTest < PokeAccessTest
  BS = "\\"
  # A trainer as either era keeps it ($player or $Trainer): the two fields the name and money codes read.
  Trainer = Struct.new(:name, :money)

  test "drops colour codes and tags, keeping the text inside them" do
    { "\\c[3]Hola <b>mundo</b>" => "Hola mundo", "Usa <ar>Surf</ar> aqui" => "Usa Surf aqui" }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw.inspect
    end
  end

  test "says a game variable's value for its code" do
    $game_variables[5] = 42
    assert_equal "HP 42 restante", PokeAccess.clean("HP \\v[5] restante")
  end

  test "says nothing for a variable code before the game has its variables" do
    without_variables do
      assert_equal "HP restante", PokeAccess.clean("HP \\v[5] restante")
    end
  end

  test "turns line breaks and control bytes into single spaces" do
    { "uno\ndos\x01tres" => "uno dos tres", "uno\r\ndos" => "uno dos", "uno\tdos" => "uno dos",
      " uno \n\n dos " => "uno dos" }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw.inspect
    end
  end

  test "turns a line-break tag into a space between the words" do
    { "uno<br>dos" => "uno dos", "uno<BR/>dos" => "uno dos", "uno< br />dos" => "uno dos" }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw.inspect
    end
  end

  test "turns a bare pipe into a space" do
    assert_equal "uno dos", PokeAccess.clean("uno|dos")
  end

  test "drops a stray backslash no code claims, keeping what follows it" do
    assert_equal "Vale adiós", PokeAccess.clean("Vale" + BS + " adiós")
  end

  test "drops a wait or display code whole, as the game shows nothing for it" do
    [".", "|", "!", "^", "<", ">", "~", "1"].each do |code|
      assert_equal "Holaadiós", PokeAccess.clean("Hola" + BS + code + "adiós"), (BS + code).inspect
    end
  end

  test "drops an escaped backslash whole, keeping the word after it" do
    { "adiós" => "Holaadiós", "big" => "Holabig" }.each do |word, want|
      assert_equal want, PokeAccess.clean("Hola" + BS + BS + word), word
    end
  end

  test "cleans no text into an empty one" do
    assert_equal "", PokeAccess.clean(nil)
  end

  test "drops a code glued to the text and keeps the word after it" do
    with_players(nil, Trainer.new("Ana", 1500)) do
      { BS + "bHello! Sorry to keep you waiting!" => "Hello! Sorry to keep you waiting!",
        BS + "rGreetings, " + BS + "PN!" => "Greetings, Ana!",
        BS + "pogHola " + BS + "pgadios" => "Hola adios",
        "a world" + BS + "nwhere" => "a world where",
        "So?" + BS + "1 " + BS + "op" + BS + "cl end" => "So? end",
        "<ac>" + BS + "c[0]" + BS + "l[3]You are" + BS + "wtnp[20] here" => "You are here",
        BS + "xyz " + BS + "n[1] ok" => "ok",
        "You have " + BS + "pm." => "You have 1500.",
        BS + "[ff00ff00]Red" + BS + "[00000000]!" => "Red!" }.each do |raw, want|
        assert_equal want, PokeAccess.clean(raw), raw.inspect
      end
    end
  end

  test "says the player's name in the case its code asks for" do
    with_players(nil, Trainer.new("Ana", 1500)) do
      { BS + "upnHOLA a todos" => "ANAHOLA a todos", BS + "dpnhola a todos" => "anahola a todos",
        BS + "PN dice hola" => "Ana dice hola" }.each do |raw, want|
        assert_equal want, PokeAccess.clean(raw), raw.inspect
      end
    end
  end

  test "reads the name and money codes from $player in the GameData era" do
    with_players(Trainer.new("Ana", 1500), Trainer.new("Ayoub", 3000)) do
      assert_equal "Ana: 1500", PokeAccess.clean(BS + "PN: " + BS + "PM")
    end
  end

  test "reads the name and money codes from $Trainer while $player is empty" do
    with_players(nil, Trainer.new("Ana", 1500)) do
      assert_equal "Ana: 1500", PokeAccess.clean(BS + "PN: " + BS + "PM")
    end
  end

  test "says nothing for the name and money codes without a trainer" do
    with_players(nil, nil) do
      assert_equal ["", "Dinero:"], [PokeAccess.clean(BS + "PN"), PokeAccess.clean("Dinero: " + BS + "PM")]
    end
  end

  test "says the speaker of every code that opens a name box before the line" do
    %w[tg ta tb js dxn xn xna xnb xnc].each do |code|
      line = BS + code + "[Brock]Hola."
      assert_equal "Brock: Hola.", PokeAccess.clean(line), line
    end
  end

  test "says only the name of a name box's parameter list" do
    assert_equal "Brock: Hola.", PokeAccess.clean('\xn[Brock,ef2110,ffadbd,0,0,nil,0,0,0]Hola.')
  end

  test "drops a colour code inside a name box's name" do
    assert_equal "Brock: Hola.", PokeAccess.clean(BS + "tg[" + BS + "c[2]Brock]Hola.")
  end

  test "drops the bare codes of the money and points windows, keeping the sentence whole" do
    { '\ptSi.' => "Si.", '\hsOh.' => "Oh.", '\ptAsi que si.' => "Asi que si.", '\qp5 puntos.' => "5 puntos.",
      '\apwHola.' => "Hola.", '\pkszHola.' => "Hola.", '\wshsHola.' => "Hola." }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw
    end
  end

  test "says the name a profile's rule makes of the box, its question marks as the unknown speaker" do
    with_name_filter(lambda { |name| name == "Anthony" ? "???" : nil }) do
      assert_equal ["#{PokeAccess::I18n.t(:msg_speaker_unknown)}: Hola.", "Brock: Hola."],
                   [PokeAccess.clean('\tg[Anthony]Hola.'), PokeAccess.clean('\tg[Brock]Hola.')]
    end
  end

  test "a profile's rule that fails leaves the name the code carries" do
    with_name_filter(lambda { |_name| raise "the rule failed" }) do
      assert_equal "Brock: Hola.", PokeAccess.clean('\xn[Brock,ef2110,ffadbd]Hola.')
    end
  end

  test "a profile's rule that fails leaves the rules after it to apply" do
    with_name_filter(lambda { |_name| raise "the rule failed" }, lambda { |name| name == "Anthony" ? "???" : nil }) do
      assert_equal "#{PokeAccess::I18n.t(:msg_speaker_unknown)}: Hola.", PokeAccess.clean('\tg[Anthony]Hola.')
    end
  end

  test "says a name box of question marks as the unknown speaker" do
    unknown = PokeAccess::I18n.t(:msg_speaker_unknown)
    { '\tg[???]¿Dónde...? ¿Dónde me encuentro...?' => "#{unknown}: ¿Dónde...? ¿Dónde me encuentro...?",
      '\tg[??]Hola.' => "#{unknown}: Hola." }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw
    end
  end

  test "keeps a name with a question mark in it, and the marks of the message itself" do
    { '\tg[¿Quién?]Hola.' => "¿Quién?: Hola.", '\tg[Kyle]¿???' => "Kyle: ¿???" }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw
    end
  end

  test "says the entities a game writes as the characters it paints" do
    { '\tg[Raiu]&quot;Señor Raiu&quot;, ¿eh?' => "Raiu: \"Señor Raiu\", ¿eh?",
      "Kyle&apos;s &amp; Co &lt;3 &gt;" => "Kyle's & Co <3 >",
      "&lt;b&gt;negrita&lt;/b&gt;" => "<b>negrita</b>",
      "&amp;quot;" => "&quot;",
      "<c2=06644bd2>Hola</c2> &quot;tú&quot;" => "Hola \"tú\"" }.each do |raw, want|
      assert_equal want, PokeAccess.clean(raw), raw
    end
  end

  test "sentences puts one period between parts, none after one that closes its own or leads in with a colon" do
    { ["Piso 3", "Nivel maximo 15"] => "Piso 3. Nivel maximo 15", ["Teletr.", "Uno"] => "Teletr. Uno",
      ["¡Hola!", "Uno"] => "¡Hola! Uno", ["¿Sí?", "Uno"] => "¿Sí? Uno",
      ["LISTA DE TARJETAS:", "Pulsa C"] => "LISTA DE TARJETAS: Pulsa C" }.each do |parts, want|
      assert_equal want, PokeAccess.sentences(parts), parts.inspect
    end
  end

  test "sentences leaves out the empty parts and trims the others" do
    { ["", "Uno", " "] => "Uno", [nil, " Piso 3 ", "Uno"] => "Piso 3. Uno", [] => "" }.each do |parts, want|
      assert_equal want, PokeAccess.sentences(parts), parts.inspect
    end
  end

  test "clean_fields separates a panel's fields with a comma and keeps a painted sum whole" do
    { "Money:\r\n<r>$3,000" => "Money:, $3,000", "1,234,567 pts<br>next" => "1,234,567 pts, next",
      "uno<ac>dos</r>tres<BR/>cuatro" => "uno, dos, tres, cuatro" }.each do |raw, want|
      assert_equal want, PokeAccess.clean_fields(raw), raw.inspect
    end
  end

  test "clean_fields turns runs of separators into one and drops them at the ends" do
    assert_equal "a, b, c", PokeAccess.clean_fields("<r>a,,b , c<br>")
  end

  private

  # Runs the block with $player (the GameData era's trainer) and $Trainer (the older eras') set as given, put back
  # after.
  def with_players(player, trainer)
    was = [$player, $Trainer]
    $player = player
    $Trainer = trainer
    yield
  ensure
    $player, $Trainer = was
  end

  # Runs the block before the game has its variables ($game_variables unset), put back after.
  def without_variables
    was = $game_variables
    $game_variables = nil
    yield
  ensure
    $game_variables = was
  end

  # Runs the block with these rules registered in order as a profile's, the profiles' rules put back after.
  def with_name_filter(*rules)
    before = PokeAccess.name_filters.dup
    rules.each { |rule| PokeAccess.register_name_filter(&rule) }
    yield
  ensure
    PokeAccess.name_filters.replace(before)
  end
end
