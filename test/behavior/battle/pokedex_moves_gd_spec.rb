# The MUI Pokedex data page's move sub-list (Anil, Emerald, Soulstones 2's older copy): the focused move as the page
# shows it, the list's title only when it changes, and the window claimed so its bare name is not read.
Suite.define("pokedex data page: the move list reads the focused move as the page shows it") do
  t = PokeAccess::I18n
  scene = PokemonPokedexInfo_Scene.new
  win = Window_CommandPokemon.new(["MoveTACKLE", "MoveEMBER", "MoveGROWL"])
  scene.instance_variable_set(:@sprites, { "movecmds" => win })
  scene.instance_variable_set(:@moveCommands, ["MoveTACKLE", "MoveEMBER", "MoveGROWL"])
  scene.instance_variable_set(:@moveList, [[1, :TACKLE], [0, :EMBER], [12, :GROWL]])
  scene.instance_variable_set(:@moveListIndex, 0)
  base = lambda do |id|
    PokeAccess::MoveInfo.line("Move#{id}", "TypeTYPE1", 40, 100, :cat => PokeAccess::MoveInfo.category_word(0))
  end

  scene.pbChooseMove
  SpeakCapture.clear
  scene.pbDrawMoveList
  eq "entering: the list's title, then the move, its place, and the description last, queued; " \
     "a level-1 row marks no level",
     SpeakCapture.log,
     [["LEVEL-UP. #{base.call(:TACKLE)}. #{t.t(:list_pos, :i => 1, :n => 3)}. descTACKLE", false]]

  SpeakCapture.clear
  win.index = 1
  scene.pbDrawMoveList
  eq "the next move, interrupting, the title not repeated, learned on evolving before the description",
     SpeakCapture.log,
     [["#{base.call(:EMBER)}. #{t.t(:pdx_mv_evo)}. #{t.t(:list_pos, :i => 2, :n => 3)}. descEMBER", true]]

  SpeakCapture.clear
  win.index = 2
  scene.pbDrawMoveList
  match "a level row says its level", SpeakCapture.lines.join(" "), /#{Regexp.escape(t.t(:dbk_level, :n => 12))}/

  SpeakCapture.clear
  win.update
  silent "the window is claimed, so the generic reader does not say the bare name"

  SpeakCapture.clear
  scene.pbChooseSpeciesDataList(:move)
  scene.pbDrawMoveList
  match "coming back from the species that learn it says the move again", SpeakCapture.lines.join(" "),
        /\A#{Regexp.escape(base.call(:GROWL))}/

  SpeakCapture.clear
  scene.instance_variable_set(:@moveList, [:TACKLE, :EMBER, :GROWL])
  scene.instance_variable_set(:@moveListIndex, 1)
  win.index = 0
  scene.pbDrawMoveList
  match "another list says its new title first", SpeakCapture.lines.join(" "), /\ATM\/TUTOR\. MoveTACKLE/

  SpeakCapture.clear
  scene.instance_variable_set(:@moveList, [])
  scene.instance_variable_set(:@moveCommands, [])
  scene.instance_variable_set(:@moveListIndex, 2)
  scene.pbDrawMoveList
  eq "a list with nothing in it says its title and that it is empty", SpeakCapture.lines,
     ["INHERIT. #{t.t(:row_empty)}"]
end

# Eternal Emerald ships Z-Power, so its data page has a Z-Move list: a power move's row paints "??" for its PP
# and, when its power varies, "???" where the category icon goes; the row carries the crystal's icon.
Suite.define("pokedex data page: a Z-Move row names its crystal and says no PP or category the page does not show") do
  GameData::Move.class_eval do
    def powerMove?; @id.to_s.start_with?("Z"); end
    alias_method :pdx_z_power, :power
    def power; @id == :ZVARIES ? 1 : pdx_z_power; end
    def total_pp; 10; end
  end
  begin
    t = PokeAccess::I18n
    scene = PokemonPokedexInfo_Scene.new
    win = Window_CommandPokemon.new(["MoveZVARIES", "MoveZFIXED", "MoveTACKLE"])
    scene.instance_variable_set(:@sprites, { "movecmds" => win })
    scene.instance_variable_set(:@moveCommands, ["MoveZVARIES", "MoveZFIXED", "MoveTACKLE"])
    scene.instance_variable_set(:@moveList, [:ZVARIES, :ZFIXED, :TACKLE])
    scene.instance_variable_set(:@moveListIndex, 3)
    scene.instance_variable_set(:@zcrystals, [Struct.new(:zmove, :name).new(:ZVARIES, "Normastal Z")])
    scene.pbChooseMove
    SpeakCapture.clear
    scene.pbDrawMoveList
    eq "a Z-Move of varying power: no category and no PP, and the crystal beside it", SpeakCapture.lines,
       ["Z-MOVES. #{PokeAccess::MoveInfo.line("MoveZVARIES", "TypeTYPE1", 1, 100)}. Normastal Z. "         "#{t.t(:list_pos, :i => 1, :n => 3)}. descZVARIES"]

    SpeakCapture.clear
    win.index = 1
    scene.pbDrawMoveList
    match "one of fixed power keeps its category icon, still with no PP", SpeakCapture.lines.join(" "),
          /\AMoveZFIXED\. #{Regexp.escape(t.t(:mv_type, :t => "TypeTYPE1"))}\. #{t.t(:cat_physical)}\. #{Regexp.escape(t.t(:mv_power, :p => "40"))}\. #{Regexp.escape(t.t(:mv_acc, :a => 100))}\. #{Regexp.escape(t.t(:list_pos, :i => 2, :n => 3))}/

    SpeakCapture.clear
    win.index = 2
    scene.pbDrawMoveList
    match "and an ordinary move says its PP", SpeakCapture.lines.join(" "), /#{Regexp.escape(t.t(:mv_pp, :pp => 10, :tot => 10))}/
  ensure
    GameData::Move.class_eval do
      remove_method :powerMove?
      remove_method :total_pp
      alias_method :power, :pdx_z_power
      remove_method :pdx_z_power
    end
  end
end
