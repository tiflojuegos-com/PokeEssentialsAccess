# The config menu's categories and submenus, each inspected by setting its @mode.
Suite.define("config menu: category structure and submenus") do
  top = PokeAccess::ConfigMenu.items
  truthy "top list has pathfinder and audio categories",
         top.any? { |i| i[:group] == :pathfinder } && top.any? { |i| i[:group] == :audio }

  PokeAccess::ConfigMenu.instance_variable_set(:@mode, :pathfinder)
  pf = PokeAccess::ConfigMenu.items.map { |i| i[:row] && i[:row][0] }.compact
  truthy "pathfinder has name_items", pf.include?(:name_items)
  truthy "pathfinder has hide_unreachable", pf.include?(:hide_unreachable)
  truthy "pathfinder has surface_cues", pf.include?(:surface_cues)
  truthy "pathfinder has an advanced submenu entry",
         PokeAccess::ConfigMenu.items.any? { |i| i[:kind] == :enter && i[:group] == :pathfinder_adv }

  PokeAccess::ConfigMenu.instance_variable_set(:@mode, :pathfinder_adv)
  nav_adv = PokeAccess::ConfigMenu.items.map { |i| i[:row] && i[:row][0] }.compact
  truthy "advanced navigation has guide_refresh", nav_adv.include?(:guide_refresh)

  PokeAccess::ConfigMenu.instance_variable_set(:@mode, :audio)
  audio = PokeAccess::ConfigMenu.items
  arows = audio.map { |i| i[:row] && i[:row][0] }.compact
  truthy "audio has sound_nav", arows.include?(:sound_nav)
  truthy "audio radar sits below sound_nav",
         arows.index(:proximity_radar) && arows.index(:proximity_radar) > arows.index(:sound_nav)
  truthy "audio has a volumes submenu",
         audio.any? { |i| i[:kind] == :enter && i[:group] == :audio3d_vol }
  truthy "audio has a frequencies submenu",
         audio.any? { |i| i[:kind] == :enter && i[:group] == :audio3d_freq }
  PokeAccess::ConfigMenu.instance_variable_set(:@mode, :top)
end

# adjust_setting, the menu's one edit path: a cycler (sound_nav, the language) wraps around, a number clamps.
Suite.define("config menu: cyclers and clamps") do
  PokeAccess::Config.sound_nav = :full
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:sound_nav), 1)
  eq "sound_nav cycles to off", PokeAccess::Config.sound_nav, :off
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:sound_nav), 1)
  eq "sound_nav cycles to basic", PokeAccess::Config.sound_nav, :basic
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:sound_nav), 1)
  eq "sound_nav wraps back to full", PokeAccess::Config.sound_nav, :full

  PokeAccess::Config.guide_refresh = 9
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:guide_refresh), 1)
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:guide_refresh), 1)
  eq "guide_refresh clamps at 10", PokeAccess::Config.guide_refresh, 10
  PokeAccess::Config.guide_refresh = 4

  langs =PokeAccess::I18n.available_languages
  truthy "at least the six shipped languages are discovered", langs.length >= 6
  PokeAccess::Config.language = :es
  seen = []
  (langs.length + 1).times do
    PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:language), 1)
    seen.push(PokeAccess::Config.language)
  end
  eq "the toggle visits the automatic entry and every shipped language once, then wraps",
     seen.map { |c| c.to_s }.sort, (["auto"] + langs.map { |c| c.to_s }).sort
  eq "and a full lap lands back on the starting language", PokeAccess::Config.language, :es
  PokeAccess::Config.language = :es
end

# Config::KIND_BOUNDS bounds both Settings on load and the menu's steps on adjust.
Suite.define("config menu: shared numeric bounds for Settings and adjust") do
  PokeAccess::Settings.set_numeric(:audio3d_volume, "150", :vol)
  eq "Settings clamps volume to 100", PokeAccess::Config.audio3d_volume, 100
  PokeAccess::Settings.set_numeric(:route_reach, "10", :reach)
  eq "Settings clamps reach to 32", PokeAccess::Config.route_reach, 32
  PokeAccess::Settings.set_numeric(:astar_max, "99999", :astar)
  eq "Settings clamps astar to 10000", PokeAccess::Config.astar_max, 10000

  PokeAccess::Config.audio3d_volume = 95
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_volume), 1)
  eq "menu volume +10 caps at 100", PokeAccess::Config.audio3d_volume, 100
  PokeAccess::Config.route_reach = 128
  PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:route_reach), -1)
  eq "menu reach steps 32 down to the grid (128 -> 96)", PokeAccess::Config.route_reach, 96
  PokeAccess::Config.route_reach = 128
end

# The menu's list is memoised per state, keyed on the dictionaries' write counters and the recorder's state.
Suite.define("config menu: the list is built once per state, and rebuilt the moment a dictionary moves") do
  cm = PokeAccess::ConfigMenu
  saved_mode = cm.instance_variable_get(:@mode)
  begin
    cm.instance_variable_set(:@mode, :top)
    cm.instance_variable_set(:@items, nil)
    first = cm.items
    truthy "the same state hands back the very same list, not an equal copy", cm.items.equal?(first)

    cm.instance_variable_set(:@mode, :personal)
    truthy "a different screen builds its own", !cm.items.equal?(first)

    cm.instance_variable_set(:@mode, :list_marks)
    before = cm.items
    PokeAccess::Marks.set(1, 4, 4, "Probe")
    truthy "and a mark written while the menu is open rebuilds it", !cm.items.equal?(before)
    truthy "with the new entry in it",
           cm.items.any? { |r| r[:kind] == :entry && r[:key] == [1, 4, 4] }
    PokeAccess::Marks.delete(1, 4, 4)
    falsy "and deleting it takes it out again",
          cm.items.any? { |r| r[:kind] == :entry && r[:key] == [1, 4, 4] }

    rec =PokeAccess::Recorder
    was_on = rec.instance_variable_get(:@on)
    cm.instance_variable_set(:@mode, :debug)
    rec.instance_variable_set(:@on, false)
    label = lambda { cm.items.detect { |r| r[:action] == :rec_toggle }[:label] }
    eq "with no recording running the row offers to start one", label.call, :dbg_rec_start
    rec.instance_variable_set(:@on, true)
    eq "and once one runs the same row offers to stop it", label.call, :dbg_rec_stop
    rec.instance_variable_set(:@on, was_on)
  ensure
    cm.instance_variable_set(:@mode, saved_mode)
    cm.instance_variable_set(:@items, nil)
  end
end
