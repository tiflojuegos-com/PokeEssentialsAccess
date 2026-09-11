# The EV allocator: a mode of the summary's stats page where the player spends a pool of effort points. The
# stat under the cursor and the number being changed are LOCAL variables of the plugin's own loop, and the
# only thing on screen that says which stat is selected is a sprite that moves.
#
# It is readable at all because the plugin keeps two things where they can be seen: it mirrors the cursor
# onto the selector sprite's index on every move, and it raises $evalloc for as long as the mode is up. So
# the reader hangs off pbUpdate -- which that loop calls every frame -- and says nothing the rest of the
# time, which is the half that matters: pbUpdate runs on every summary, allocator or not.
class PokemonSummary_Scene
  def ev_rig(pokemon, index)
    @pokemon = pokemon
    sel = Object.new
    sel.instance_variable_set(:@i, index)
    def sel.index; @i; end
    def sel.index=(v); @i = v; end
    @sprites = { "EVsel" => sel }
    sel
  end
end
Suite.define("ev allocator: the focused stat and its value are read, and only while the mode is up") do
  pk = Poke.build(:name => "Chispa")
  def pk.ev; { :HP => 84, :ATTACK => 12, :DEFENSE => 0, :SPECIAL_DEFENSE => 4, :SPEED => 252,
               :SPECIAL_ATTACK => 8 }; end
  scene = PokemonSummary_Scene.new
  sel = scene.ev_rig(pk, 0)
  had = defined?($evalloc)
  begin
    $evalloc = false
    SpeakCapture.clear
    scene.pbUpdate
    silent "outside the allocator the summary is not narrated on every frame"

    $evalloc = true
    SpeakCapture.clear
    scene.pbUpdate
    match "the focused stat is named with its effort points", SpeakCapture.lines.join(" "), /84/

    SpeakCapture.clear
    scene.pbUpdate
    silent "and a frame where nothing moved says nothing"

    sel.index = 1
    SpeakCapture.clear
    scene.pbUpdate
    match "moving to the next stat reads that one", SpeakCapture.lines.join(" "), /12/

    # The mixed mode keeps the page's six rows and paints Attack on the Sp. Atk row too; a five-entry table
    # named Sp. Def there, Speed on the Sp. Def row, and nothing at all on the last one.
    sel.index = 3
    SpeakCapture.clear
    scene.pbUpdate
    match "the fourth row of the mixed mode is Attack again", SpeakCapture.lines.join(" "), /12/
    sel.index = 5
    SpeakCapture.clear
    scene.pbUpdate
    match "and the sixth is Speed", SpeakCapture.lines.join(" "), /252/
  ensure
    $evalloc = false
  end
end

# The plugin's other unread piece: pbFullAbilityWindow, the modal panel holding the FULL description of an
# ability or a move, which three of its screens raise because the summary's own box only fits a line. It is
# declared to ModalPanel, so the panel is read on the way in; the file is replayed because the function has
# to exist before the declaration runs, exactly as it does in a game.
def pbFullAbilityWindow(text, scene = nil); [text, scene]; end
eval(File.read(File.join(Harness::ROOT, "plugins", "ev_allocator.rb")),
     TOPLEVEL_BINDING, File.join(Harness::ROOT, "plugins", "ev_allocator.rb"))

Suite.define("ev allocator: the full-description panel is read on the way in") do
  SpeakCapture.clear
  pbFullAbilityWindow("Levitate: Gives full immunity to all Ground-type moves.")
  spoke "the panel says what it holds", /full immunity to all Ground-type moves/

  SpeakCapture.clear
  pbFullAbilityWindow("")
  silent "and an empty one says nothing"
end
