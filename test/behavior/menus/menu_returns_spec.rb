# Back in a menu that runs its options inline (the classic pause menu's command loop, Voltseon's carousel), the
# focused option is said again.

Suite.define("pause menu (classic): each return to the command loop says the option again") do
  scene = PokemonMenu_Scene.new
  scene.pbShowCommands([])
  eq "the opening says the focused option", SpeakCapture.lines, ["Pokédex"]
  SpeakCapture.clear
  scene.pbShowCommands([])
  eq "and so does the loop entered again after an option", SpeakCapture.lines, ["Pokédex"]
end

Suite.define("voltseon's pause menu: the entry is said again when an option returns to the carousel") do
  vm = PokeAccess::VoltseonMenu
  entry = Struct.new(:name).new("Bag")
  menu = World.stub_scene(:@entries => [entry], :@currentSelection => 0)
  scene = World.stub_scene(:@pauseMenu => menu)
  vm.read(menu)
  vm.read(menu)
  eq "the entry once while it stays", SpeakCapture.lines, ["Bag"]
  SpeakCapture.clear
  vm.returned
  vm.read(menu)
  eq "a return with the menu closed changes nothing", SpeakCapture.lines, []
  vm.watch(scene)
  begin
    vm.returned
    vm.read(menu)
    eq "with the menu up, the refresh after the option says it again", SpeakCapture.lines, ["Bag"]
  ensure
    vm.unwatch
  end
end
