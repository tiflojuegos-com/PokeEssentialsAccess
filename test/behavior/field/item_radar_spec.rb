# Reborn SWM's Item Radar Mod (plugins/item_radar.rb), in both Soulstones: once the Itemfinder turns it on, each
# aUpdateRadar marks the hidden items near the player, and the reader says how many and the nearest one whenever that
# set changes.
Suite.define("item radar: says the hidden items it marks as their set changes, and nothing while it is off") do
  ir = PokeAccess::ItemRadar
  t = PokeAccess::I18n
  switches_was = $game_self_switches
  $game_self_switches = {}
  World.clear_events
  begin
    near = World.event(:id => 1, :name => "HiddenItem", :x => 7, :y => 5)
    far = World.event(:id => 2, :name => "HiddenItem", :x => 5, :y => 1)
    World.event(:id => 3, :name => "HiddenItem", :x => 13, :y => 5)
    World.event(:id => 4, :name => "HiddenItem", :x => 5, :y => 11)
    World.event(:id => 5, :name => "Tree", :x => 6, :y => 5)
    World.event(:id => 6, :name => "HiddenItem", :x => 4, :y => 5)
    $game_self_switches[[1, 6, "A"]] = true
    screen = World.stub_scene(:@aItemsFoundVisible => true)

    eq "it marks as the radar does: hidden items within 7 columns and 5 rows, none picked up",
       ir.marked.map { |e| e.id }, [1, 2]
    SpeakCapture.clear
    ir.update(screen)
    eq "how many, then the nearest one, queued behind the game's message", SpeakCapture.log,
       [["#{t.t(:irad_marks, :n => 2)}. #{PokeAccess.hidden_item_text(near)}", false]]

    SpeakCapture.clear
    ir.update(screen)
    silent "a step that leaves the same marks says nothing"

    $game_self_switches[[1, 1, "B"]] = true
    ir.update(screen)
    eq "an item picked up changes the set", SpeakCapture.last,
       "#{t.t(:irad_marks, :n => 1)}. #{PokeAccess.hidden_item_text(far)}"

    SpeakCapture.clear
    screen.instance_variable_set(:@aItemsFoundVisible, false)
    ir.update(screen)
    silent "while the radar is off it says nothing"
    screen.instance_variable_set(:@aItemsFoundVisible, true)
    ir.update(screen)
    eq "and turned on again, it says its marks again", SpeakCapture.last,
       "#{t.t(:irad_marks, :n => 1)}. #{PokeAccess.hidden_item_text(far)}"

    $game_self_switches[[1, 2, "D"]] = true
    ir.update(screen)
    eq "with every item picked up it says it marks none", SpeakCapture.last, t.t(:irad_none)
  ensure
    $game_self_switches = switches_was
    World.clear_events
  end
end
