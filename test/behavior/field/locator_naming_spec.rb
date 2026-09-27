# target_name classifies events by shape: a battle trainer's two same-sprite pages gated by a self switch look like a
# lever but are not read as one.
Suite.define("locator: target_name classifies events by shape") do
  World.clear_events
  lever = World.event(:kind => :lever, :id => 1)
  trainer = World.event(:kind => :trainer, :id => 2, :name => "Trainer(5)")
  $game_map.map_id = 900

  match "a two-pose switch-gated event reads as a lever", PokeAccess::Locator.target_name(lever), /Palanca/i

  name = PokeAccess::Locator.target_name(trainer)
  eq "a battle trainer is NOT read as a lever", (name.to_s =~ /Palanca/i ? true : false), false

  door = World.event(:kind => :door, :id => 3)
  truthy "a touch-transfer tile is a transfer event", (PokeAccess::Locator.transfer_event?(door) rescue false)
end

# item_name reads the item out of an item ball's pbItemBall(...) script command.
Suite.define("locator: item_name parses the pbItemBall script") do
  cmd = Struct.new(:code, :parameters)
  ev = Struct.new(:l) do
    def instance_variable_get(s); s == :@list ? l : nil; end
  end.new([cmd.new(355, ["pbItemBall(PBItems::REPEL)"])])
  eq "reads the item out of the ball script", PokeAccess::Locator.item_name(ev), "Repel"
end

# Field-move obstacles: gen-6 and modern names resolve to a label; a name merely containing an obstacle word does not.
Suite.define("locator: field-move obstacle labelling") do
  fme = Struct.new(:name)
  eq "gen-6 Rock", PokeAccess::Locator.fieldmove_label(fme.new("Rock")), :loc_rock_smash
  eq "gen-6 Tree", PokeAccess::Locator.fieldmove_label(fme.new("Tree")), :loc_cut_tree
  eq "gen-6 Boulder", PokeAccess::Locator.fieldmove_label(fme.new("Boulder")), :loc_strength_boulder
  eq "modern cuttree", PokeAccess::Locator.fieldmove_label(fme.new("cuttree")), :loc_cut_tree
  eq "written with an underscore", PokeAccess::Locator.fieldmove_label(fme.new("Rock_Smash")), :loc_rock_smash
  truthy "no false positive", PokeAccess::Locator.fieldmove_label(fme.new("Rockstar")).nil?
end

# Keyboard stubs, rows in @@Characters: the modern one has four mode tabs at -6..-3, the gen-6 one three at -5..-3.
class FakeNamingScene
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [("áéíóúàèìòù ,.").scan(/./), "accents"], [(",.:;!?   ♂♀  ").scan(/./), "other"]]
end
class FakeNamingSceneGen6
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [(",.:;!?   ♂♀  ").scan(/./), "other"]]
end

# focus_text maps a keyboard grid position to its character (by mode) or to the space or control label.
Suite.define("locator: cursor-mode naming grid") do
  fn = FakeNamingScene.new
  eq "grid character", PokeAccess::CursorNaming.focus_text(fn, 0, 0), "A"
  eq "lowercase by mode", PokeAccess::CursorNaming.focus_text(fn, 1, 2), "c"
  eq "gap reads as space", PokeAccess::CursorNaming.focus_text(fn, 0, 10), PokeAccess::I18n.t(:key_space)
  eq "OK control", PokeAccess::CursorNaming.focus_text(fn, 0, -1), PokeAccess::I18n.t(:nm_ok)
  eq "back control", PokeAccess::CursorNaming.focus_text(fn, 0, -2), PokeAccess::I18n.t(:nm_back)
  eq "uppercase control", PokeAccess::CursorNaming.focus_text(fn, 0, -6), PokeAccess::I18n.t(:nm_upper)
  eq "symbols control", PokeAccess::CursorNaming.focus_text(fn, 0, -3), PokeAccess::I18n.t(:nm_symbols)
end

# The tab positions shift with the number of tabs: a three-tab keyboard names its own.
Suite.define("locator: three-tab keyboards name their own tabs, not the four-tab ones") do
  g6 = FakeNamingSceneGen6.new
  eq "uppercase sits at -5 here", PokeAccess::CursorNaming.focus_text(g6, 0, -5), PokeAccess::I18n.t(:nm_upper)
  eq "lowercase at -4", PokeAccess::CursorNaming.focus_text(g6, 0, -4), PokeAccess::I18n.t(:nm_lower)
  eq "symbols at -3", PokeAccess::CursorNaming.focus_text(g6, 0, -3), PokeAccess::I18n.t(:nm_symbols)
  eq "OK and back do not move", PokeAccess::CursorNaming.focus_text(g6, 0, -1), PokeAccess::I18n.t(:nm_ok)
end

# A v19+ item ball, whose pickup is a Conditional Branch on pbItemBall(:ITEM): named from the branch's script, and
# interactable even when drawn with nothing.
Suite.define("locator: a modern item ball, whose pickup is a conditional branch, is named and counts") do
  World.clear_events
  $game_map.map_id = 901
  page = TestPage.new(:trigger => 0, :sprite => "Object ball",
                      :list => [TestCmd.new(111, [12, "pbItemBall(:REPEL)"]), TestCmd.new(123, ["A", 0]),
                                TestCmd.new(0, []), TestCmd.new(412, [])])
  ball = TestGameEvent.new(:id => 21, :name => "Item", :pages => [page])
  $game_map.events[21] = ball
  eq "the item comes out of the branch's script", PokeAccess::Locator.item_name(ball), "Repel"
  truthy "it is an item ball", PokeAccess::Locator.item_ball?(ball)
  truthy "and something the player can do, so the sonar has it", PokeAccess::Locator.interactable?(ball)
  eq "which it pings as an object", PokeAccess::Audio3D.type_of(ball), :object
  hidden_page = TestPage.new(:trigger => 0, :sprite => "",
                             :list => [TestCmd.new(111, [12, "pbItemBall(:ETHER)"]), TestCmd.new(123, ["A", 0]),
                                       TestCmd.new(0, []), TestCmd.new(412, [])])
  hidden = TestGameEvent.new(:id => 22, :name => "HiddenItem", :pages => [hidden_page])
  $game_map.events[22] = hidden
  truthy "a hidden one, drawn with nothing, counts too", PokeAccess::Locator.interactable?(hidden)
  World.clear_events
end

# A drawn event that only flips a switch when pressed is something to press (Pokemon Z's Fort Leviatan, map 126,
# switch 265); the same commands on an unseen event are a helper, out of the lists.
Suite.define("locator: a drawn control that only flips a switch is something to press; an unseen one is not") do
  World.clear_events
  $game_map.map_id = 902
  press = [TestCmd.new(250, [nil]), TestCmd.new(224, [nil, 10]), TestCmd.new(225, [5, 5, 5]),
           TestCmd.new(106, [12]), TestCmd.new(121, [265, 265, 0]), TestCmd.new(0, [])]
  lever = TestGameEvent.new(:id => 2, :name => "EV002/noShadow/", :tile_id => 718,
                            :pages => [TestPage.new(:trigger => 0, :sprite => "", :list => press)])
  helper = TestGameEvent.new(:id => 3, :name => "EV003",
                             :pages => [TestPage.new(:trigger => 0, :sprite => "", :list => press)])
  $game_map.events[2] = lever
  $game_map.events[3] = helper
  truthy "the drawn tile that opens the way is examinable", PokeAccess::Locator.examinable?(lever)
  truthy "so it is listed with the extras", PokeAccess::Locator.in_category?(lever, :extras)
  truthy "and with everything", PokeAccess::Locator.in_category?(lever, :all)
  eq "the sonar pings it as an object", PokeAccess::Audio3D.type_of(lever), :object
  falsy "the same commands on an invisible helper stay out of the lists", PokeAccess::Locator.examinable?(helper)
  falsy "and off the sonar", PokeAccess::Audio3D.type_of(helper)
  World.clear_events
end

# An EV### event whose sprite is a national number ("025", "025s" when shiny) is named as that species; any other
# numbered sprite stays an object.
Suite.define("locator: a Pokemon on the map is named by the species its numbered sprite shows") do
  World.clear_events
  $game_map.map_id = 903
  mon = TestGameEvent.new(:id => 18, :name => "EV018",
                          :pages => [TestPage.new(:trigger => 0, :sprite => "789",
                                                  :list => [TestCmd.new(355, ["pbWildBattle(PBSpecies::COSMOG,95)"])])])
  shiny = TestGameEvent.new(:id => 19, :name => "EV019", :pages => [TestPage.new(:trigger => 0, :sprite => "025s")])
  odd = TestGameEvent.new(:id => 20, :name => "EV020", :pages => [TestPage.new(:trigger => 0, :sprite => "0001")])
  $game_map.events[18] = mon; $game_map.events[19] = shiny; $game_map.events[20] = odd
  eq "the number is the species", PokeAccess::Locator.target_name(mon), PBSpecies.getName(789)
  eq "and its shiny sprite too", PokeAccess::Locator.target_name(shiny), PBSpecies.getName(25)
  eq "a sprite that is not a three-digit number stays an object", PokeAccess::Locator.target_name(odd),
     PokeAccess::I18n.t(:loc_object)
  World.clear_events
end

# An unnamed event in a trainer charset is named by the class in the file name (number or constant, variant suffix
# aside); an unknown class keeps the file name, and a name of punctuation alone is no name.
Suite.define("locator: a trainer charset names its class, and punctuation is no name") do
  World.clear_events
  loc = PokeAccess::Locator
  eq "by number", loc.target_name(World.event(:id => 1, :sprite => "trchar065")), "Posadera"
  eq "by constant, a variant set aside", loc.target_name(World.event(:id => 2, :sprite => "trcharHIKER_2")), "Montanero"
  eq "a class the game lacks keeps the file name", loc.target_name(World.event(:id => 3, :sprite => "trchar099")), "trchar099"
  eq "any other sprite too", loc.target_name(World.event(:id => 4, :sprite => "npc_girl")), "npc_girl"
  eq "a name of punctuation alone is no name", loc.target_name(World.event(:id => 5, :name => "'", :sprite => "trchar065")),
     "Posadera"
  eq "a real name still wins", loc.target_name(World.event(:id => 6, :name => "Rosa", :sprite => "trchar065")), "Rosa"
end
