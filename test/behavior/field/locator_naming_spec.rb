# Regression + coverage: target_name classifies map events by data shape, not by name. A battle trainer's
# two same-sprite pages gated by a self-switch look like a lever, so trainers must NOT read as levers
# (the lever check runs after Trainer/PC/exit, and a battle script disqualifies a lever).
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

# The locator reads the item an item-ball event gives, by parsing its pbItemBall(...) script command, so a
# pickup announces what it contains rather than a generic "item ball".
Suite.define("locator: item_name parses the pbItemBall script") do
  cmd = Struct.new(:code, :parameters)
  ev = Struct.new(:l) do
    def instance_variable_get(s); s == :@list ? l : nil; end
  end.new([cmd.new(355, ["pbItemBall(PBItems::REPEL)"])])
  eq "reads the item out of the ball script", PokeAccess::Locator.item_name(ev), "Repel"
end

# Field-move obstacles: both gen-6 bare sprite names AND modern names resolve to a label, with no false
# positive on a name that merely contains an obstacle word ("Rockstar").
Suite.define("locator: field-move obstacle labelling") do
  fme = Struct.new(:name)
  eq "gen-6 Rock", PokeAccess::Locator.fieldmove_label(fme.new("Rock")), :loc_rock_smash
  eq "gen-6 Tree", PokeAccess::Locator.fieldmove_label(fme.new("Tree")), :loc_cut_tree
  eq "gen-6 Boulder", PokeAccess::Locator.fieldmove_label(fme.new("Boulder")), :loc_strength_boulder
  eq "modern cuttree", PokeAccess::Locator.fieldmove_label(fme.new("cuttree")), :loc_cut_tree
  truthy "no false positive", PokeAccess::Locator.fieldmove_label(fme.new("Rockstar")).nil?
end

# The two on-screen-keyboard layouts, both real: the modern PokemonEntryScene2 has FOUR mode tabs (upper,
# lower, accents, other) at -6..-3, and the gen-6 one has THREE (upper, lower, other) at -5..-3. Both expose
# their rows the same way, through the class variable @@Characters.
class FakeNamingScene
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [("áéíóúàèìòù ,.").scan(/./), "accents"], [(",.:;!?   ♂♀  ").scan(/./), "other"]]
end
class FakeNamingSceneGen6
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [(",.:;!?   ♂♀  ").scan(/./), "other"]]
end

# Cursor-mode naming: focus_text maps a grid position to its character (upper/lower by mode) or to the
# space/control label, so the on-screen-keyboard reader voices what the cursor is on.
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

# The tab positions shift with the number of tabs, and a table nailed to the four-tab layout named every
# gen-6 tab as the next one along -- "lowercase" while standing on UPPER, which is where a player picking a
# name goes wrong without ever being told why.
Suite.define("locator: three-tab keyboards name their own tabs, not the four-tab ones") do
  g6 = FakeNamingSceneGen6.new
  eq "uppercase sits at -5 here", PokeAccess::CursorNaming.focus_text(g6, 0, -5), PokeAccess::I18n.t(:nm_upper)
  eq "lowercase at -4", PokeAccess::CursorNaming.focus_text(g6, 0, -4), PokeAccess::I18n.t(:nm_lower)
  eq "symbols at -3", PokeAccess::CursorNaming.focus_text(g6, 0, -3), PokeAccess::I18n.t(:nm_symbols)
  eq "OK and back do not move", PokeAccess::CursorNaming.focus_text(g6, 0, -1), PokeAccess::I18n.t(:nm_ok)
end
