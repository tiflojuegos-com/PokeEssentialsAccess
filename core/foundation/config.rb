module PokeAccess
  # The gen-6 frame rate that frame-counted tunables are written in; dividing by it gives the wall-clock seconds
  # the cues pace by (freq_to_seconds, the bump cooldown). A fixed constant, not the running game's rate.
  FPS = 40.0

  # The mod's settings: a schema of rows (what each setting is, where the menu lists it and when it applies) and their
  # values, read as Config.<key> and written through Config.set, which emits :config_changed. Settings persists the
  # rows; ConfigMenu lists them by group.
  module Config
    # One setting: its key, default and kind (how it steps, is said and is stored), the menu group it sits in, its
    # label and help keys, and when the menu shows it: show_if is [key, value or values] another setting must hold,
    # needs the capabilities it takes.
    Setting = Struct.new(:key, :default, :kind, :group, :label, :help, :show_if, :needs)

    # A menu group: its id, its label key and the group it hangs from (:top for the top list, nil for a group only a
    # screen of its own lists).
    Group = Struct.new(:id, :label, :parent)

    # Numeric kinds: [min, max, step, spoken-unit key or nil].
    KIND_BOUNDS = {
      :vol   => [0, 100, 10, nil],
      # A tone: 50 plays the recording and each step of 5 is a tenth of an octave either way (tone_to_pitch).
      :tone  => [0, 100, 5, nil],
      :tiles => [1, 20, 1, :tiles_unit],
      # The sonar's range; its own kind so widening it leaves the wall probe and alternation distance alone.
      :sonar => [1, 30, 1, :tiles_unit],
      :astar => [1000, 10000, 500, nil],
      :ms    => [2, 40, 2, :ms_unit],
      :gdist => [1, 6, 1, :tiles_unit],
      :reach => [32, 1024, 32, :tiles_unit],
      :desk  => [0, 3, 1, :tiles_unit],
      :msgs  => [100, 2000, 100, :msgs_unit],
      :hpacl => [6, 20, 2, :tiles_unit]
    }

    # List kinds: their values in the order the menu steps through them (a Proc for values listed elsewhere) and how
    # each is said (the prefix of its key, or a Proc).
    LISTS = {
      :lang      => [lambda { PokeAccess::I18n.language_choices }, lambda { |v| PokeAccess::I18n.language_name(v) }],
      :verbosity => [lambda { PokeAccess::Verbosity.rotation },
                     lambda { |v| PokeAccess::Verbosity.name_of(PokeAccess::Verbosity.rotation.include?(v) ? v : :full) }],
      :hide      => [[:off, :unreachable, :room], "hide_"],
      :navmode   => [[:off, :basic, :full], "nav_"],
      :occ       => [[:hear, :occlude, :hide], "occ_"],
      :algo      => [lambda { PokeAccess::Pathfinder::ALGORITHMS }, "algo_"],
      :aweight   => [lambda { PokeAccess::Pathfinder::WEIGHT_CHOICES }, "aweight_"],
      :rlimit    => [[:effort, :time, :none], "rlim_"],
      :rstyle    => [lambda { PokeAccess::Routes::CostModel::STYLES }, "rstyle_"],
      :tord      => [[:near, :walk, :fixed], "tord_"],
      :tnum      => [[:off, :dynamic, :static], "tnum_"],
      :grhythm   => [[:distance, :constant], "grhythm_"]
    }

    # Internal/structural config (not user settings, not in the menu).
    OTHER = [:keys, :bump_cooldown, :rebinds, :rebind_labels, :key_hint_letters, :categories,
             :status_names, :weather_names, :field_weather_names, :gender_numbers, :money_label, :trainer_parts]

    class << self
      attr_accessor(*OTHER)
    end

    @settings = []
    @groups = []
    @capabilities = {}

    # Declares a setting and its accessor, set to its default the first time; declaring a key again replaces its row
    # where it stands. opts: :show_if, :needs (a capability or a list of them).
    def self.define(key, default, kind, group, label, help, opts = {})
      needs = opts[:needs]
      needs = [needs] if needs && !needs.is_a?(Array)
      row = Setting.new(key, default, kind, group, label, help, opts[:show_if], needs || [])
      i = @settings.index { |s| s.key == key }
      if i
        @settings[i] = row
      else
        @settings.push(row)
        (class << self; self; end).send(:attr_accessor, key)
        send("#{key}=", default)
      end
      row
    end

    # Declares a menu group; parent :top lists it in the top list, another id hangs it from that group.
    def self.group(id, label, parent = nil)
      g = Group.new(id, label, parent)
      i = @groups.index { |x| x.id == id }
      i ? @groups[i] = g : @groups.push(g)
      g
    end

    # Every declared setting, in declaration order.
    def self.settings; @settings; end

    # The setting with a key, or nil.
    def self.setting(key); @settings.find { |s| s.key == key }; end

    # The settings in a group, in declaration order.
    def self.settings_in(group); @settings.select { |s| s.group == group }; end

    # Every declared group, in declaration order.
    def self.groups; @groups; end

    # The groups that hang from a parent (:top for the top list), in declaration order.
    def self.groups_in(parent); @groups.select { |g| g.parent == parent }; end

    # The only way a setting changes from here on: assigns it and emits :config_changed with its key.
    def self.set(key, value)
      send("#{key}=", value)
      PokeAccess::Events.emit(:config_changed, key)
      value
    end

    # Registers a capability a setting can need, as a probe answered when asked (the positional engine, say).
    def self.capability(name, &probe); @capabilities[name] = probe; end

    # Whether a capability holds now; an unregistered or failing probe does not.
    def self.capable?(name)
      probe = @capabilities[name]
      probe ? (probe.call ? true : false) : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # What decides which rows show, as one comparable value: the capabilities that hold now and the values of the
    # settings some row's show_if names.
    def self.visibility_key
      caps = @capabilities.keys.map { |c| c.to_s }.sort.select { |c| capable?(c.to_sym) }
      deps = @settings.map { |s| s.show_if && s.show_if[0] }.compact.uniq
      [caps, deps.map { |k| send(k) }]
    end

    # Whether the menu shows a setting: its capabilities hold and the setting its show_if names is shown and holds
    # one of the listed values.
    def self.visible?(s, seen = nil)
      return false unless s.needs.all? { |c| capable?(c) }
      return true unless s.show_if
      key, vals = s.show_if
      dep = setting(key)
      seen ||= {}
      return false if dep.nil? || seen[key]
      seen[key] = true
      vals = [vals] unless vals.is_a?(Array)
      visible?(dep, seen) && vals.include?(send(key))
    end

    # The values a list kind steps through.
    def self.values_of(kind)
      list = LISTS[kind][0]
      list.is_a?(Proc) ? list.call : list
    end

    # The value a setting takes one step away (dir 1 or -1): a flag flips, a number steps within its bounds, a list
    # value moves to its neighbour and wraps, counting from the default when the current one is not in the list.
    def self.next_value(s, dir)
      cur = send(s.key)
      b = KIND_BOUNDS[s.kind]
      if b
        v = cur.to_i + dir * b[2]
        return v < b[0] ? b[0] : (v > b[1] ? b[1] : v)
      end
      return !cur if s.kind == :flag
      list = values_of(s.kind)
      list[((list.index(cur) || list.index(s.default) || 0) + dir) % list.length]
    end

    # A value of a setting in words: a number with its unit, on or off, or a list value's name.
    def self.value_name(s, v)
      b = KIND_BOUNDS[s.kind]
      return (b[3] ? "#{v} #{PokeAccess::I18n.t(b[3], :n => v)}" : v.to_s) if b
      return PokeAccess::I18n.t(v ? :val_on : :val_off) if s.kind == :flag
      namer = LISTS[s.kind][1]
      namer.is_a?(Proc) ? namer.call(v) : PokeAccess::I18n.t("#{namer}#{v}".to_sym)
    end

    # A stored string as a value of a setting, or nil when it is not one: a number is clamped to its bounds, a flag
    # is true or false, a list value must be one of the kind's.
    def self.parse(s, str)
      str = str.to_s.strip
      b = KIND_BOUNDS[s.kind]
      if b
        return nil unless str =~ /\A-?\d+\z/
        n = str.to_i
        return n < b[0] ? b[0] : (n > b[1] ? b[1] : n)
      end
      if s.kind == :flag
        return true if str == "true"
        return str == "false" ? false : nil
      end
      return nil if str.empty?
      v = str.to_sym
      values_of(s.kind).include?(v) ? v : nil
    end

    # Puts every setting back to its default but the mod's language, which stays as the player chose it.
    def self.restore_defaults
      @settings.each { |s| set(s.key, s.default) unless s.key == :language }
    end

    group(:general,        :cat_general,        :top)
    group(:pathfinder,     :cat_pathfinder,     :top)
    group(:pathfinder_adv, :cat_nav_adv,        :pathfinder)
    group(:audio,          :cat_audio,          :top)
    group(:audio3d_on,     :cat_sounds_on,      :audio)
    group(:audio3d_vol,    :cat_pos_vol,        :audio)
    group(:audio3d_freq,   :cat_pos_freq,       :audio)
    group(:audio3d_tone,   :cat_pos_tone,       :audio)
    group(:audio3d_walls,  :cat_pos_walls,      :audio)
    group(:audio3d_adv,    :cat_positional_adv, :audio)
    group(:verbosity,      :cat_verbosity)
    group(:debug,          :cat_debug)

    SONAR = { :show_if => [:sound_nav, :full], :needs => :positional }
    NAV_ON = { :show_if => [:sound_nav, [:basic, :full]] }
    NAV_ENGINE = { :show_if => [:sound_nav, [:basic, :full]], :needs => :positional }
    NAV_FULL = { :show_if => [:sound_nav, :full] }
    # When a catalog family's rows show (its shown).
    SHOWN = { :sonar => SONAR, :nav_on => NAV_ON, :nav_full => NAV_FULL }

    define(:language,             :auto,  :lang,      :general,        :lbl_language,         :help_language)
    define(:auto_detect,          true,   :flag,      :general,        :lbl_auto_detect,      :help_auto_detect)
    define(:read_help,            true,   :flag,      :general,        :lbl_read_help,        :help_read_help)
    define(:dialogue_pages,       false,  :flag,      :general,        :lbl_dialogue_pages,   :help_dialogue_pages)
    define(:history_size,         300,    :msgs,      :general,        :lbl_history_size,     :help_history_size)
    define(:verbosity,            :full,  :verbosity, :verbosity,      :lbl_scheme_in_use,    :help_verbosity)
    define(:auto_guide,           false,  :flag,      :pathfinder,     :lbl_auto_guide,       :help_auto_guide)
    define(:auto_steps,           false,  :flag,      :pathfinder,     :lbl_auto_steps,       :help_auto_steps)
    define(:hide_unreachable,     :off,   :hide,      :pathfinder,     :lbl_hide_unreachable, :help_hide_unreachable)
    define(:hide_noninteractive,  false,  :flag,      :pathfinder,     :lbl_hide_noninter,    :help_hide_noninter)
    define(:target_order,         :walk,  :tord,      :pathfinder,     :lbl_target_order,     :help_target_order)
    define(:target_numbering,     :dynamic, :tnum,    :pathfinder,     :lbl_target_numbering, :help_target_numbering)
    define(:name_items,           true,   :flag,      :pathfinder,     :lbl_name_items,       :help_name_items)
    define(:name_trainers,        true,   :flag,      :pathfinder,     :lbl_name_trainers,    :help_name_trainers)
    define(:name_species,         true,   :flag,      :pathfinder,     :lbl_name_species,     :help_name_species)
    define(:name_signs,           true,   :flag,      :pathfinder,     :lbl_name_signs,       :help_name_signs)
    define(:surface_cues,         true,   :flag,      :pathfinder,     :lbl_surface_cues,     :help_surface_cues)
    define(:puzzle_assist,        false,  :flag,      :pathfinder,     :lbl_puzzle_assist,    :help_puzzle_assist)
    define(:route_style,          :shortest, :rstyle, :pathfinder_adv, :lbl_route_style,      :help_route_style)
    define(:route_reach,          128,    :reach,     :pathfinder_adv, :lbl_reach,            :help_reach)
    define(:route_limit,          :effort, :rlimit,   :pathfinder_adv, :lbl_route_limit,      :help_route_limit)
    define(:astar_max,            2500,   :astar,     :pathfinder_adv, :lbl_astar,            :help_astar,
           :show_if => [:route_limit, :effort])
    define(:route_budget_ms,      12,     :ms,        :pathfinder_adv, :lbl_route_budget,     :help_route_budget,
           :show_if => [:route_limit, :time])
    define(:path_algorithm,       :regions, :algo,    :pathfinder_adv, :lbl_path_algorithm,   nil)
    define(:astar_weight,         :w150,  :aweight,   :pathfinder_adv, :lbl_astar_weight,     :help_astar_weight,
           :show_if => [:path_algorithm, :weighted])
    define(:hpa_cluster,          10,     :hpacl,     :pathfinder_adv, :lbl_hpa_cluster,      :help_hpa_cluster,
           :show_if => [:path_algorithm, :hpa])
    define(:edge_relax,           false,  :flag,      :pathfinder_adv, :lbl_edge_relax,       :help_edge_relax)
    define(:regions_background,   true,   :flag,      :pathfinder_adv, :lbl_regions_background, :help_regions_background)
    define(:sound_nav,            :full,  :navmode,   :audio,          :lbl_sound_nav,        :help_sound_nav)
    define(:sonar_only_locatable, false,  :flag,      :audio,          :lbl_sonar_locatable,  :help_sonar_locatable, SONAR)
    define(:game_bump,            false,  :flag,      :audio,          :lbl_game_bump,        :help_game_bump, NAV_ON)
    define(:audio3d_volume,       80,     :vol,       :audio,          :lbl_pos_master,       :help_pos_master, NAV_ENGINE)
    [:on, :vol, :freq, :tone].each do |kind|
      Sound::Catalog.rows(kind).each do |key, default, k, group, label, help, shown|
        define(key, default, k, group, label, help, SHOWN[shown] || {})
      end
    end
    define(:audio3d_occlusion,    :hide,  :occ,       :audio3d_walls,  :lbl_occlusion,        :help_occlusion, SONAR)
    define(:audio3d_air,          false,  :flag,      :audio3d_walls,  :lbl_pos_air,          :help_pos_air, SONAR)
    define(:audio3d_wall_range,   3,      :tiles,     :audio3d_walls,  :lbl_wall_range,       :help_wall_range, SONAR)
    define(:audio3d_wall_falloff, 50,     :vol,       :audio3d_walls,  :lbl_wall_falloff,     :help_wall_falloff, SONAR)
    define(:audio3d_desk_range,   2,      :desk,      :audio3d_walls,  :lbl_desk_range,       :help_desk_range,
           :show_if => [:audio3d_occlusion, :hide])
    define(:audio3d_range,        12,     :sonar,     :audio3d_adv,    :lbl_sonar_range,      :help_sonar_range, SONAR)
    define(:audio3d_alt_dist,     5,      :tiles,     :audio3d_adv,    :lbl_alt_dist,         :help_alt_dist, SONAR)
    define(:guide_distance,       3,      :gdist,     :audio3d_adv,    :lbl_guide_distance,   :help_guide_distance,
           NAV_ENGINE)
    define(:transfer_active_page_only, true, :flag,   :debug,          :lbl_transfer_active_only, :help_transfer_active_only)
    define(:route_stats,          false,  :flag,      :debug,          :lbl_route_stats,      :help_route_stats)
    define(:revert_surf_sound,    false,  :flag,      :debug,          :lbl_revert_surf_sound, :help_revert_surf_sound)

    #--- non-schema defaults ---

    # Mod hotkeys: action => Windows virtual-key code. The frozen defaults let the remap menu restore one key and
    # settings.rb save only the changed ones; :verbosity ships unbound (every letter is some game's).
    KEY_DEFAULTS = {
      :next => 0x4C, :prev => 0x4A, :where => 0x4B, :route => 0x49,
      :info => 0x54, :hp => 0x48, :coords => 0x4D, :field => 0x47,
      :config => 0x4F, :shift => 0x10, :ctrl => 0x11,
      :hist_prev => 0x24, :hist_next => 0x23, :verbosity => nil
    }.freeze
    self.keys = KEY_DEFAULTS.dup
    # Wall-cue cooldown in frames.
    self.bump_cooldown = 16

    # Key remap (action => VK code, from settings.ini) and per-game button relabels; empty = native input.
    self.rebinds       = {}
    self.rebind_labels = {}
    # The letters a game paints in its key hints and the buttons they stand for (KeyHints); empty = hints untouched.
    self.key_hint_letters = {}
    # Per-game override for picture-based gender selection (option number => label); empty = the default.
    self.gender_numbers = {}
    # i18n key for the spoken money amount; a game with a different currency overrides it.
    self.money_label = :tr_money
    # The trainer line the info key speaks, as the ordered names of its parts (readers in Info::TRAINER_PARTS).
    # A profile reorders, drops or adds names here; Info.set_trainer_part appends a new one by itself.
    self.trainer_parts = [:name, :money, :badges, :pokedex, :playtime]

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
    # Per-game overworld weather names (PBFieldWeather, not the battle enum), consulted before the vanilla
    # Battle::FIELD_WEATHER, since fangames give the same number different weathers. Empty = vanilla only.
    self.field_weather_names = {}
  end
end
