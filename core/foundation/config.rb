module PokeAccess
  # gen-6 game tick rate (fps). The unit the frame-shaped tunables are written in: a cooldown of "16" means
  # 16 gen-6 frames, and dividing by this turns it into the seconds PokeAccess.clock speaks (freq_to_seconds,
  # the bump cooldown). It is a fixed design constant, not a reading of the running game -- the clock itself
  # is wall time, so a game at another frame rate keeps the same real-world cadence.
  FPS = 40.0

  # Engine defaults, overridden per game in games/<game>/constants.rb. User-facing settings live in
  # SCHEMA (key, default, kind, group, label, help) so adding one is a single row; Settings and
  # ConfigMenu both derive from it. Numeric kinds take their range from KIND_BOUNDS.
  module Config
    SCHEMA = [
      [:language,            :es,   :lang, :general,    :lbl_language,         :help_language],
      [:auto_guide,          false, :flag, :pathfinder, :lbl_auto_guide,       :help_auto_guide],
      [:hide_unreachable,    false, :flag, :pathfinder, :lbl_hide_unreachable, :help_hide_unreachable],
      [:hide_noninteractive, false, :flag, :pathfinder, :lbl_hide_noninter,    :help_hide_noninter],
      [:fixed_target_number, true,  :flag, :pathfinder, :lbl_fixed_number,     :help_fixed_number],
      [:name_items,          true,  :flag, :pathfinder, :lbl_name_items,       :help_name_items],
      [:puzzle_assist,        false, :flag, :general,    :lbl_puzzle_assist,    :help_puzzle_assist],
      [:auto_detect,          true,  :flag, :general,    :lbl_auto_detect,      :help_auto_detect],
      [:read_help,            true,  :flag, :general,    :lbl_read_help,        :help_read_help],
      [:straight_routes,     false, :flag,  :pathfinder_adv, :lbl_straight,     :help_straight],
      [:guide_refresh,       4,     :sec,   :pathfinder_adv, :lbl_guide_refresh, :help_guide_refresh],
      [:route_reach,         128,   :reach, :pathfinder_adv, :lbl_reach,        :help_reach],
      [:astar_max,           2500,  :astar, :pathfinder_adv, :lbl_astar,        :help_astar],
      [:route_auto,          false, :flag,  :debug, :lbl_route_auto,   :help_route_auto],
      [:route_budget_ms,     8,     :ms,    :debug, :lbl_route_budget, :help_route_budget],
      [:path_algorithm,      :astar, :algo, :pathfinder_adv, :lbl_path_algorithm, :help_path_algorithm],
      [:edge_relax,          false, :flag,  :pathfinder_adv, :lbl_edge_relax,   :help_edge_relax],
      [:ledge_directions,    true,  :flag,  :pathfinder_adv, :lbl_ledge_dir,    :help_ledge_dir],
      [:route_cache,         true,  :flag,  :pathfinder_adv, :lbl_route_cache,  :help_route_cache],
      [:surface_cues,        false, :flag, :pathfinder, :lbl_surface_cues,     :help_surface_cues],
      [:guide_distance,      3,     :gdist, :pathfinder, :lbl_guide_distance,  :help_guide_distance],
      [:sound_nav,           :full, :navmode, :audio,   :lbl_sound_nav,        :help_sound_nav],
      [:proximity_radar,     false, :flag, :audio,      :lbl_proximity_radar,  :help_proximity_radar],
      [:audio3d_volume,      80,    :vol,  :audio,      :lbl_pos_master,       :help_pos_master],
      [:audio3d_npc,         85,    :vol,  :audio3d_vol, :lbl_pos_people,      :help_pos_people],
      [:audio3d_object,      85,    :vol,  :audio3d_vol, :lbl_pos_objects,     :help_pos_objects],
      [:audio3d_door,        85,    :vol,  :audio3d_vol, :lbl_pos_doors,       :help_pos_doors],
      [:audio3d_teleporter,  90,    :vol,  :audio3d_vol, :lbl_pos_teleporter,  :help_pos_teleporter],
      [:audio3d_water,       70,    :vol,  :audio3d_vol, :lbl_pos_water,       :help_pos_water],
      [:audio3d_wind,        55,    :vol,  :audio3d_vol, :lbl_pos_wind,        :help_pos_wind],
      [:footstep_volume,     80,    :vol,  :audio3d_vol, :lbl_footstep_vol,    :help_footstep_vol],
      [:wall_volume,         80,    :vol,  :audio3d_vol, :lbl_wall_vol,        :help_wall_vol],
      [:event_volume,        70,    :vol,  :audio3d_vol, :lbl_guide_vol,       :help_guide_vol],
      [:audio3d_freq_npc,    70,    :vol,  :audio3d_freq, :lbl_freq_people,    :help_freq_people],
      [:audio3d_freq_object, 70,    :vol,  :audio3d_freq, :lbl_freq_objects,   :help_freq_objects],
      [:audio3d_freq_door,   70,    :vol,  :audio3d_freq, :lbl_freq_doors,     :help_freq_doors],
      [:guide_freq,          55,    :vol,  :audio3d_freq, :lbl_guide_freq,     :help_guide_freq],
      [:audio3d_occlusion,   :occlude, :occ, :audio3d_walls, :lbl_occlusion,   :help_occlusion],
      [:audio3d_air,         false, :flag,  :audio3d_walls, :lbl_pos_air,      :help_pos_air],
      [:audio3d_wall_range,  3,     :tiles, :audio3d_walls, :lbl_wall_range,   :help_wall_range],
      [:audio3d_wall_falloff,50,    :vol,   :audio3d_walls, :lbl_wall_falloff, :help_wall_falloff],
      [:audio3d_desk_range,  2,     :desk,  :audio3d_walls, :lbl_desk_range,   :help_desk_range],
      [:audio3d_range,       12,    :sonar, :audio3d_adv, :lbl_sonar_range,   :help_sonar_range],
      [:audio3d_alt_dist,    5,     :tiles, :audio3d_adv, :lbl_alt_dist,      :help_alt_dist],
      [:transfer_active_page_only, true, :flag, :debug, :lbl_transfer_active_only, :help_transfer_active_only]
    ]

    # Numeric setting bounds by kind: [min, max, step, spoken-unit key or nil]. The single source for
    # clamping (Settings) and stepping (ConfigMenu); non-numeric kinds are handled separately.
    KIND_BOUNDS = {
      :vol   => [0, 100, 10, nil],
      :sec   => [1, 10, 1, :secs],
      :tiles => [1, 20, 1, :tiles_unit],
      # The sonar's own range, apart from :tiles because it is the only one the player has a reason to
      # push out: the wall probe and the alternation distance are short by design and widening them with
      # it would be a silent side effect of a slider that says "sonar".
      :sonar => [1, 30, 1, :tiles_unit],
      :astar => [1000, 10000, 500, nil],
      :ms    => [2, 40, 2, :ms_unit],
      :gdist => [1, 6, 1, :tiles_unit],
      :reach => [32, 1024, 32, :tiles_unit],
      :desk  => [0, 3, 1, :tiles_unit]
    }

    CATEGORIES = [
      [:general,    :cat_general],
      [:pathfinder, :cat_pathfinder],
      [:audio,      :cat_audio]
    ]

    # Internal/structural config (not user settings, not in the menu).
    OTHER = [:keys, :bump_cooldown, :rebinds, :rebind_labels, :categories,
             :status_names, :weather_names, :field_weather_names, :gender_numbers, :money_label]

    class << self
      attr_accessor(*(SCHEMA.map { |row| row[0] } + OTHER))
    end

    # Apply the schema defaults.
    SCHEMA.each { |row| send("#{row[0]}=", row[1]) }

    # The schema rows in a group, in order. Used by Settings and ConfigMenu.
    def self.schema_group(group); SCHEMA.select { |row| row[3] == group }; end

    # The schema row for a key, or nil.
    def self.schema_row(key); SCHEMA.find { |row| row[0] == key }; end

    # The keys of every setting of a given kind. Used by Settings to persist them.
    def self.keys_of_kind(kind); SCHEMA.select { |row| row[2] == kind }.map { |row| row[0] }; end

    #--- non-schema defaults ---

    # Mod hotkeys: action => Windows virtual-key code. Kept as a frozen table of shipped defaults AND a
    # working copy, because the two are needed for different things: the remap menu restores ONE key from
    # the defaults (a mod key has no native fallback the way a game button does -- cleared, it would simply
    # stop working), and settings.rb only writes to the ini the ones the player actually changed.
    KEY_DEFAULTS = {
      :next => 0x4C, :prev => 0x4A, :where => 0x4B, :route => 0x49,
      :info => 0x54, :hp => 0x48, :coords => 0x4D, :field => 0x47,
      :config => 0x4F, :shift => 0x10, :ctrl => 0x11
    }.freeze
    self.keys = KEY_DEFAULTS.dup
    # Wall-cue cooldown in frames.
    self.bump_cooldown = 16

    # Key remap (action => VK code, from settings.ini) and per-game button relabels; empty = native input.
    self.rebinds       = {}
    self.rebind_labels = {}
    # Per-game override for picture-based gender selection (option number => label); empty = the default.
    self.gender_numbers = {}
    # i18n key for the spoken money amount; a game with a different currency overrides it.
    self.money_label = :tr_money

    # Locator target categories as language-neutral symbols (spoken names come from tcat_* keys).
    self.categories = [:all, :people, :objects, :exits, :signs, :extras, :surfaces]

    # Battle status/weather name tables (i18n keys; a game may override with literal strings).
    self.status_names = {
      1 => :st_sleep, 2 => :st_poison, 3 => :st_burn, 4 => :st_paralysis, 5 => :st_freeze
    }
    self.weather_names = {
      1 => :w_sun, 2 => :w_rain, 3 => :w_sandstorm, 4 => :w_hail,
      5 => :w_harsh_sun, 6 => :w_heavy_rain, 7 => :w_strong_winds, 8 => :w_shadow_sky
    }
    # Overworld weather is a SEPARATE enum from battle weather (PBFieldWeather in gen-6), and its vanilla
    # range lives in Battle::FIELD_WEATHER. This table holds only what a game adds on top, consulted first,
    # because fangames extend the enum with entries that clash: 8 is ShadowSky in one game and Charco in
    # another, so a single shared table could not be right for both. Empty means "vanilla only".
    self.field_weather_names = {}
  end
end
