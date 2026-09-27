# active_categories adds :puzzles once and never mutates Config.categories; a base already holding it ends with one.
Suite.define("puzzles: active_categories never mutates the base") do
  PokeAccess::Config.categories = [:all, :people, :objects, :exits, :signs, :extras, :surfaces]
  saved_current = PokeAccess::Puzzles.method(:current)
  PokeAccess::Puzzles.define_singleton_method(:current) { { :obstacles => [{ :kind => :mover }] } }
  500.times { PokeAccess::Locator.active_categories }
  eq "base intact after 500 uses", PokeAccess::Config.categories.size, 7
  ac = PokeAccess::Locator.active_categories
  truthy "active = base + puzzles exactly once", ac.size == 8 && ac.count { |c| c == :puzzles } == 1
  PokeAccess::Config.categories =
    [:all, :puzzles, :people, :puzzles, :objects, :puzzles, :exits, :signs, :extras, :surfaces]
  ac2 = PokeAccess::Locator.active_categories
  eq "self-heals a polluted base", ac2.count { |c| c == :puzzles }, 1
  PokeAccess::Puzzles.define_singleton_method(:current, saved_current)
  PokeAccess::Config.categories = [:all, :people, :objects, :exits, :signs, :extras, :surfaces]
end

# Puzzle controls are the player-triggered events whose commands write a watched flag (122 variable, 121 switch),
# labelled by that watch entry; autorun and parallel controllers and unrelated events are not.
Suite.define("puzzles: state controls detected by their watched flag") do
  cmd = Struct.new(:code, :parameters)
  page = Struct.new(:trigger, :list)
  rev = Struct.new(:pages)
  ev_class = Class.new do
    attr_accessor :x, :y
    def initialize(x, y, rev); @x = x; @y = y; @event = rev; end
  end
  crank = ev_class.new(8, 3, rev.new([page.new(0, [cmd.new(122, [132, 132, 0, 0, 1])])]))
  valve = ev_class.new(2, 9, rev.new([page.new(0, [cmd.new(121, [312, 312, 0])])]))
  para  = ev_class.new(1, 1, rev.new([page.new(4, [cmd.new(122, [132, 132, 0, 0, 0])])]))
  deco  = ev_class.new(4, 4, rev.new([page.new(0, [cmd.new(201, [0, 5, 1, 1])])]))

  $game_map.events.clear
  [crank, valve, para, deco].each_with_index { |e, i| $game_map.events[i + 1] = e }
  PokeAccess::Puzzles.register($game_map.map_id,
    :kind => :state,
    :watch => [{ :var => 132, :label => :ship_crank_red }, { :switch => 312, :label => :ship_valve1 }])
  PokeAccess::Puzzles.reset_state
  ctrls = PokeAccess::Puzzles.controls
  truthy "detects crank and valve, ignores parallel and door",
         ctrls.length == 2 && ctrls.map { |c| c[0] }.include?(crank) && ctrls.map { |c| c[0] }.include?(valve)
  truthy "control? true for the crank, false for the door",
         PokeAccess::Puzzles.control?(crank) && !PokeAccess::Puzzles.control?(deco)
  eq "labelled by its watch entry",
     PokeAccess::Puzzles.control_label(crank), PokeAccess::I18n.t(:ship_crank_red)

  $game_map.events.clear
  PokeAccess::Puzzles.reset_state
end
