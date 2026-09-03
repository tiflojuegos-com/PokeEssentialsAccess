# Config menu structure: a top list of categories, each opening a submenu of its settings. Verifies the
# groups, the per-mode rows, the nested "advanced navigation" and the unified audio menu layout (sound_nav
# above the positional submenus). The menu mode is an internal ivar driven here to inspect each submenu.
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

# Cyclers and clamps via adjust_setting: a multi-value cycler (sound_nav off/basic/full and the language
# toggle) wraps around, and a numeric setting clamps to its bounds. adjust_setting is the single edit path
# the menu uses; the numeric bounds come from the shared Config::KIND_BOUNDS table.
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

  # The language toggle is data-driven off lang/*.txt, so this walks whatever ships instead of pinning
  # two names: every language is visited exactly once and the cycle wraps. The floor pins the six that
  # ship today (es, en, fr, pt, de, pl) so a lost file fails loudly.
  langs = PokeAccess::I18n.available_languages
  truthy "at least the six shipped languages are discovered", langs.length >= 6
  PokeAccess::Config.language = :es
  seen = []
  langs.length.times do
    PokeAccess::ConfigMenu.adjust_setting(PokeAccess::Config.schema_row(:language), 1)
    seen.push(PokeAccess::Config.language)
  end
  eq "the toggle visits every shipped language once and wraps to the start",
     seen.map { |c| c.to_s }.sort, langs.map { |c| c.to_s }.sort
  eq "and a full lap lands back on the starting language", PokeAccess::Config.language, :es
  PokeAccess::Config.language = :es
end

# The numeric dispatch table (Config::KIND_BOUNDS) feeds BOTH Settings (clamp on load) and ConfigMenu (step
# + clamp on adjust); both paths must honour the same bounds and the default step grid.
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
