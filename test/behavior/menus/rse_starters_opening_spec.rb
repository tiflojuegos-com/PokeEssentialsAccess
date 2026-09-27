# The Emerald UI Pack's starter choice paints the call's message in its window as it opens ("Choose your Starter
# Pokemon."); it is said then, and the first starter waits behind it.

StarterSpecSpecies = Struct.new(:name, :category)

Suite.define("starter choice: the opening message comes before the first starter") do
  rs = PokeAccess::RSEStarters
  pokemon = Struct.new(:visible).new(true)
  scene = World.stub_scene(:@index => 0, :@species_cache => [StarterSpecSpecies.new("Treecko", "Wood Gecko")],
                           :@sprites => { "messageWindow" => FakeTextWin.new("Choose your Starter Pokemon."),
                                          "pokemon" => pokemon })
  SpeakCapture.clear
  rs.opening(scene)
  rs.read(scene)
  eq "the message, then the starter, both queued", SpeakCapture.log,
     [["Choose your Starter Pokemon.", false], [PokeAccess::I18n.t(:list_entry, :name => "Treecko", :n => 1, :tot => 1), false]]
  quiet = World.stub_scene(:@message => "", :@sprites => { "messageWindow" => FakeTextWin.new("") })
  SpeakCapture.clear
  rs.opening(quiet)
  silent "a call with no message says nothing"
end
