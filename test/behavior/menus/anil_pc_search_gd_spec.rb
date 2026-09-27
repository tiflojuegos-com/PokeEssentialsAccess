# Anil's PC search answers by jumping to the chosen box and fading every Pokemon in it that does not match: the
# box and the ones left bright are named. The gamedata pass runs the Anil profile, which loads the reader.

module AnilPCSearchSpec
  Icon = Struct.new(:opacity)

  # A box scene whose icons stand at the given opacities, over three Pokemon.
  def self.scene(opacities)
    icons = opacities.map { |o| Icon.new(o) }
    box = Object.new
    box.define_singleton_method(:getPokemon) { |i| icons[i] }
    mons = [Poke.build(:name => "Pikachu"), Poke.build(:name => "Bulbasaur"), Poke.build(:name => "Pichu")]
    store = Object.new
    def store.currentBox; 0; end
    def store.maxPokemon(_b); 3; end
    store.define_singleton_method(:[]) { |_b, i = nil| i.nil? ? Struct.new(:name).new("Caja 3") : mons[i] }
    World.stub_scene(:@storage => store, :@sprites => { "box" => box })
  end

  def self.pos(name, col)
    name + PokeAccess::I18n.t(:pc_pos, :row => 1, :col => col)
  end
end

Suite.define("anil: the PC search names the box it jumped to and the Pokemon the fade leaves bright") do
  t = PokeAccess::I18n
  s = AnilPCSearchSpec
  search = PokeAccess::AnilPCSearch
  search.start(s.scene([255, 240, 255]))
  SpeakCapture.clear
  search.poll
  silent "nothing while the box is still being chosen"
  search.jumped
  search.poll
  search.poll
  search.stop
  eq "once the jump is done, the box, then the bright ones with where they sit", SpeakCapture.lines,
     ["Caja 3. " + t.t(:anil_search_hits, :list => [s.pos("Pikachu", 1), s.pos("Pichu", 3)].join("; "))]

  search.start(s.scene([255, 255, 255]))
  SpeakCapture.clear
  search.jumped
  search.poll
  search.stop
  eq "a box where everything matches dims nothing, and says them all", SpeakCapture.lines,
     ["Caja 3. " + t.t(:anil_search_hits, :list => [s.pos("Pikachu", 1), s.pos("Bulbasaur", 2), s.pos("Pichu", 3)].join("; "))]
end

# The same, through the screen's own calls: the search holds the reader, the jump arms it, and the fade's
# first frame says the matches.
Suite.define("anil: the PC search is followed through pbSearch and pbJumpToBox") do
  t = PokeAccess::I18n
  s = AnilPCSearchSpec
  stub = s.scene([255, 240, 255])
  scene = PokemonStorageScene.new(stub.instance_variable_get(:@storage))
  scene.instance_variable_set(:@sprites, stub.instance_variable_get(:@sprites))
  scene.on_search_frame = lambda { PokeAccess::AnilPCSearch.poll }
  SpeakCapture.clear
  eq "the search keeps its own return", scene.pbSearch(0), :searched
  eq "the box, then the bright ones", SpeakCapture.lines,
     ["Caja 3. " + t.t(:anil_search_hits, :list => [s.pos("Pikachu", 1), s.pos("Pichu", 3)].join("; "))]
  SpeakCapture.clear
  PokeAccess::AnilPCSearch.poll
  silent "and the search over, the frames after it say nothing"
end
