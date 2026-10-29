# The mod's config menu over Config's schema: the rows each screen lists as the settings and the engine allow, how a
# row is said and stepped, the frame's keys over its stack of screens, the resets' confirmations, and how Config
# reads, names and announces a setting's value.
class ConfigMenuTest < PokeAccessTest
  Menu = PokeAccess::ConfigMenu
  Cfg = PokeAccess::Config
  T = PokeAccess::I18n
  # The menu's own state, put back after each test.
  STATE = [:@active, :@mode, :@index, :@stack, :@armed, :@items, :@items_key, :@entry, :@capturing, :@preview, :@ri]
  # The sonar's volumes, which only positional sound plays, in the order the volumes screen lists them.
  SONAR_VOLUMES = [:audio3d_npc, :audio3d_object, :audio3d_hazard, :audio3d_trap, :audio3d_control, :audio3d_push,
                   :audio3d_belt, :audio3d_door, :audio3d_exit, :audio3d_teleporter, :audio3d_mark, :audio3d_water,
                   :audio3d_shore, :audio3d_wind]
  # The pathfinder's advanced settings before and after the row the search limit shows of its own.
  ADV_HEAD = [:route_style, :route_reach, :route_limit]
  ADV_TAIL = [:path_algorithm, :edge_relax, :regions_background, :back]

  test "lists the setting groups on the top screen, then its own screens and the reset, each by its label" do
    on_screen(:top) do
      assert_equal [[[:enter, :general], :cat_general], [[:enter, :pathfinder], :cat_pathfinder],
                    [[:enter, :audio], :cat_audio], [[:enter, :sounds], :cat_sounds],
                    [[:enter, :personal], :cat_personal], [:remap, :cat_remap], [[:enter, :debug], :cat_debug],
                    [[:action, :reset], :cat_reset]], rows(:top).zip(Menu.items.map { |i| i[:label] })
    end
  end

  test "lists the pathfinder's settings, then its advanced screen, then back" do
    on_screen(:pathfinder) do
      assert_equal [:auto_guide, :auto_steps, :hide_unreachable, :hide_noninteractive, :target_order,
                    :target_numbering, :name_items, :name_trainers, :name_species, :name_signs, :surface_cues,
                    :puzzle_assist, [:enter, :pathfinder_adv], :back],
                   rows(:pathfinder)
    end
  end

  test "keeps the search limit in the advanced navigation screen, by effort as it ships" do
    on_screen(:pathfinder_adv) do
      assert_equal ADV_HEAD + [:astar_max] + ADV_TAIL, rows(:pathfinder_adv)
    end
  end

  test "lists debug's diagnostics, recorder and self-check, then its settings, the route statistics among them" do
    on_screen(:debug) do
      assert_equal [[:action, :diag_audio], [:action, :diag_events], [:action, :diag_perf], [:action, :diag_map],
                    [:action, :diag_scene], [:action, :diag_full], [:action, :rec_toggle], [:action, :selfcheck],
                    :transfer_active_page_only, :route_stats, :revert_surf_sound, :back], rows(:debug)
    end
  end

  test "lists the audio settings and every sound screen with the positional engine up" do
    on_screen(:audio) do
      Reset.with_capability(:positional, true) do
        assert_equal [:sound_nav, :sonar_only_locatable, :game_bump, :audio3d_volume, [:enter, :audio3d_on],
                      [:enter, :audio3d_vol], [:enter, :audio3d_freq], [:enter, :audio3d_tone],
                      [:enter, :audio3d_walls], [:enter, :audio3d_adv], :back], rows(:audio)
      end
    end
  end

  test "offers only the flat sound screens without the positional engine" do
    on_screen(:audio) do
      Reset.with_capability(:positional, false) do
        assert_equal [:sound_nav, :game_bump, [:enter, :audio3d_on], [:enter, :audio3d_vol], [:enter, :audio3d_freq],
                      [:enter, :audio3d_tone], :back], rows(:audio)
      end
    end
  end

  test "drops the walls screen while none of its rows may sound" do
    on_screen(:audio) do
      Reset.with_capability(:positional, true) do
        Cfg.sound_nav = :basic
        assert_equal false, rows(:audio).include?([:enter, :audio3d_walls])
      end
    end
  end

  test "hides the master volume and the guide's distance while sound navigation is off, though the engine is up" do
    { :off => false, :basic => true, :full => true }.each do |nav, shown|
      Reset.with_capability(:positional, true) do
        on_screen(:audio) do
          Cfg.sound_nav = nav
          assert_equal shown, rows(:audio).include?(:audio3d_volume), nav.to_s
        end
        on_screen(:audio3d_adv) do
          Cfg.sound_nav = nav
          assert_equal shown, rows(:audio3d_adv).include?(:guide_distance), nav.to_s
        end
      end
    end
  end

  test "auditions the master volume's flat sample at the master just set, and not at all at 0" do
    level = PokeAccess::Sound::Mixer.level(PokeAccess::Sound::Glossary.preview_of(:audio3d_volume))
    Reset.with_capability(:positional, false) do
      with_cue_log do |log|
        Menu.preview(:audio3d_volume, :vol, 50)
        Menu.preview(:audio3d_volume, :vol, 0)
        assert_equal [level * 50 / 100], log.map { |e| e[1] }
      end
    end
  end

  test "adds the sonar's volumes only with the positional engine and the full nav mode" do
    flat = [:footstep_volume, :wall_volume, :event_volume, :jump_volume]
    {
      [true, :full]  => SONAR_VOLUMES + flat + [:radar_volume, :puzzle_volume, :minigame_volume],
      [false, :full] => flat + [:radar_volume, :puzzle_volume, :minigame_volume],
      [true, :basic] => flat + [:puzzle_volume, :minigame_volume],
      [true, :off]   => [:event_volume, :jump_volume, :puzzle_volume, :minigame_volume]
    }.each do |(positional, nav), volumes|
      on_screen(:audio3d_vol) do
        Reset.with_capability(:positional, positional) do
          Cfg.sound_nav = nav
          assert_equal volumes + [:back], rows(:audio3d_vol), "positional #{positional}, nav #{nav}"
        end
      end
    end
  end

  test "shows the counters' range only while walls hide what is behind them" do
    walls = [:audio3d_occlusion, :audio3d_air, :audio3d_wall_range, :audio3d_wall_falloff]
    shown = { :hide => walls + [:audio3d_desk_range, :back], :hear => walls + [:back], :occlude => walls + [:back] }
    shown.each do |occ, want|
      on_screen(:audio3d_walls) do
        Reset.with_capability(:positional, true) do
          Cfg.audio3d_occlusion = occ
          assert_equal want, rows(:audio3d_walls), occ.to_s
        end
      end
    end
  end

  test "shows the search limit's own row: effort's by effort, time's by time, neither by none" do
    { :effort => [:astar_max], :time => [:route_budget_ms], :none => [] }.each do |limit, own|
      on_screen(:pathfinder_adv) do
        Cfg.route_limit = limit
        assert_equal ADV_HEAD + own + ADV_TAIL, rows(:pathfinder_adv), limit.to_s
      end
    end
  end

  test "lists the guide's row among the sound switches, just before the jumps' switch" do
    on_screen(:audio3d_on) do
      Reset.with_capability(:positional, false) do
        assert_equal [:sound_steps, :sound_wall, :guide, :sound_jumps, :sound_ledges, :proximity_radar, :sound_grid,
                      :sound_minigame, :back], rows(:audio3d_on)
      end
    end
  end

  test "says a setting's value in words: a number with its unit, a flag as on or off, a list value by its name" do
    {
      [:audio3d_wall_range, 3]          => "3 #{T.t(:tiles_unit, :n => 3)}",
      [:audio3d_wall_range, 1]          => "1 #{T.t(:tiles_unit, :n => 1)}",
      [:audio3d_wall_falloff, 50]       => "50",
      [:auto_guide, true]               => T.t(:val_on),
      [:auto_guide, false]              => T.t(:val_off),
      [:hide_unreachable, :off]         => T.t(:hide_off),
      [:hide_unreachable, :unreachable] => T.t(:hide_unreachable),
      [:hide_unreachable, :room]        => T.t(:hide_room)
    }.each do |(key, value), said|
      Cfg.send("#{key}=", value)
      assert_equal said, Menu.value_text(Cfg.setting(key)), "#{key} = #{value.inspect}"
    end
  end

  test "says a setting's row as its name and value, and any other row as its name" do
    on_screen(:pathfinder) do
      items = Menu.items
      assert_equal "#{T.t(:lbl_auto_guide)}, #{T.t(:val_off)}", Menu.describe(items[0]), "a setting"
      assert_equal T.t(:back), Menu.describe(items.last), "back"
    end
  end

  test "says a verbosity scheme that no longer exists as the full level" do
    Cfg.verbosity = :NoSuchScheme
    assert_equal T.t(:vb_level_full), Menu.value_text(Cfg.setting(:verbosity))
  end

  test "steps a list setting on and back, wrapping round its ends" do
    on_screen(:audio) do
      row = Cfg.setting(:sound_nav)
      went = [1, 1, 1, -1].map { |dir| Menu.adjust_setting(row, dir); Cfg.sound_nav }
      assert_equal [:off, :basic, :full, :basic], went
    end
  end

  test "steps a number by its kind's step, stopping at its bounds" do
    {
      [:audio3d_wall_range, 19, 1]    => 20,
      [:audio3d_wall_range, 20, 1]    => 20,
      [:audio3d_wall_range, 1, -1]    => 1,
      [:audio3d_wall_falloff, 5, -1]  => 0,
      [:audio3d_volume, 95, 1]        => 100,
      [:route_reach, 128, -1]         => 96,
      [:route_reach, 32, -1]          => 32,
      [:history_size, 300, 1]         => 400
    }.each do |(key, from, dir), to|
      on_screen(:audio) do
        Cfg.send("#{key}=", from)
        Menu.adjust_setting(Cfg.setting(key), dir)
        assert_equal to, Cfg.send(key), "#{key} from #{from}, #{dir > 0 ? 'right' : 'left'}"
      end
    end
  end

  test "steps a flag by flipping it" do
    on_screen(:pathfinder) do
      row = Cfg.setting(:auto_guide)
      went = [1, -1].map { |dir| Menu.adjust_setting(row, dir); Cfg.auto_guide }
      assert_equal [true, false], went
    end
  end

  test "says the setting and its new value as it steps" do
    on_screen(:audio) do
      Menu.adjust_setting(Cfg.setting(:sound_nav), 1)
      assert_equal [["#{T.t(:lbl_sound_nav)}, #{T.t(:nav_off)}", true]], SpeakCapture.log
    end
  end

  test "steps the language through automatic and every shipped language once, then wraps" do
    on_screen(:general) do
      shipped = T.available_languages
      assert_equal [], [:de, :en, :es, :fr, :pl, :pt] - shipped, "the shipped languages are found"
      lap = [:auto] + shipped
      went = lap.map { Menu.adjust_setting(Cfg.setting(:language), 1); Cfg.language }
      assert_equal lap.rotate(lap.index(:es) + 1), went
    end
  end

  test "steps the language back with left" do
    on_screen(:general) do
      Menu.adjust_setting(Cfg.setting(:language), -1)
      assert_equal :en, Cfg.language
    end
  end

  test "steps a verbosity scheme that no longer exists on from the full level" do
    Cfg.verbosity = :NoSuchScheme
    assert_equal :brief, Cfg.next_value(Cfg.setting(:verbosity), 1)
  end

  test "steps the hide setting off, unreachable, room and off again" do
    on_screen(:pathfinder) do
      row = Cfg.setting(:hide_unreachable)
      went = 3.times.map { Menu.adjust_setting(row, 1); Cfg.hide_unreachable }
      assert_equal [:unreachable, :room, :off], went
    end
  end

  test "Ctrl+M steps the hide setting on as its row does and says the new value" do
    on_screen(:top) do
      Cfg.hide_unreachable = :room
      PokeAccess::Locator.toggle_hide_unreachable
      assert_equal [:off, [["#{T.t(:lbl_hide_unreachable)}, #{T.t(:hide_off)}", true]]],
                   [Cfg.hide_unreachable, SpeakCapture.log]
    end
  end

  test "steps the search limit with the focus kept on it as its own row changes" do
    on_screen(:pathfinder_adv) do
      point_at { |row| row[:row] && row[:row].key == :route_limit }
      went = 2.times.map { Menu.adjust_setting(Cfg.setting(:route_limit), 1); Menu.describe }
      limit = T.t(:lbl_route_limit)
      assert_equal ["#{limit}, #{T.t(:rlim_time)}", "#{limit}, #{T.t(:rlim_none)}"], went
    end
  end

  test "opens on the top screen's first row whatever it was left on, and back there closes it, saved" do
    on_screen(:pathfinder, 3, [[:top, 1]]) do
      Menu.instance_variable_set(:@capturing, true)
      put_back(nil)
      open_holding(Input::B)
      assert_equal [["#{T.t(:cfg)}. #{T.t(:cat_general)}", true], [T.t(:cfg_saved), true]], SpeakCapture.log
      assert_equal [false, true], [Menu.active?, File.exist?(PokeAccess::Settings::FILE)], "closed and saved"
    end
  end

  test "closing says the settings were not saved when the settings file cannot be written" do
    on_screen(:top) do
      put_back(nil)
      Dir.mkdir(PokeAccess::Settings::FILE)
      begin
        Menu.close
      ensure
        Dir.rmdir(PokeAccess::Settings::FILE)
      end
      assert_equal [[T.t(:cfg_not_saved), true]], SpeakCapture.log
    end
  end

  test "a key capture takes no Alt that begins Alt+Tab, Alt+F4 or Alt+Enter, nor the key pressed with it" do
    [0x09, 0x73, 0x0D].each do |chord|
      assert_equal [[], nil], capture(:c, [[[0x12], true], [[0x12, chord], true], [[], true]]), "Alt with #{chord}"
    end
  end

  test "a key capture takes Alt once it is released with nothing pressed beside it" do
    said = T.t(:rmp_assigned, :action => PokeAccess::Remap.label(:c), :key => T.t(:key_alt))
    assert_equal [[said], 0x12], capture(:c, [[[0x12], true], [[], true]])
  end

  test "a key capture reads no key while the game window is not in front, nor one still held as it comes back" do
    assert_equal [[], nil], capture(:c, [[[0x51], false], [[0x51], true], [[], true]])
  end

  test "a reserved key pressed in a capture is said as reserved for what holds it, with nothing to free" do
    said = T.t(:rmp_reserved, :key => T.t(:key_f, :n => 8), :action => T.t(:rmp_key_f8))
    assert_equal [[said], nil], capture(:c, [[[0x77], true]])
  end

  test "names the function keys a capture takes, F13 to F24 among them, by their number" do
    assert_equal [T.t(:key_f, :n => 2), T.t(:key_f, :n => 13), T.t(:key_f, :n => 24)],
                 [Menu.keyname(0x71), Menu.keyname(0x7C), Menu.keyname(0x87)]
  end

  test "names a key by the sign the keyboard layout types on it, a numpad one as the numpad's, a letter as itself" do
    with_layout(0xBC => 0x2C, 0xBD => 0x2D, 0xC0 => 0xF1, 0xDE => 0xB4 - 0x80000000, 0x6B => 0x2B) do
      assert_equal [T.t(:key_comma), T.t(:key_minus), "ñ", T.t(:key_acute), T.t(:key_numpad, :n => T.t(:key_plus))],
                   [0xBC, 0xBD, 0xC0, 0xDE, 0x6B].map { |c| Menu.keyname(c) }
    end
  end

  test "names the signs the Swiss, Belgian, Canadian and Portuguese layouts type on their own keys, dead ones too" do
    with_layout(0xBF => 0xA7, 0xC0 => 0xA8 - 0x80000000, 0xDC => 0xB5, 0xDB => 0xB8 - 0x80000000, 0xDD => 0xAB) do
      assert_equal ["signo de párrafo", "diéresis", "micro", "cedilla", "abrir comillas angulares"],
                   [0xBF, 0xC0, 0xDC, 0xDB, 0xDD].map { |c| Menu.keyname(c) }
    end
  end

  test "names a key by its code where the layout types nothing on it or a sign it has no name for" do
    with_layout(0xBA => 0x2603) do
      assert_equal [T.t(:key_code, :n => 0xBA), T.t(:key_code, :n => 0xBF)], [Menu.keyname(0xBA), Menu.keyname(0xBF)]
    end
  end

  test "names Caps Lock, which only the engine's own bindings put a button on, by its name" do
    assert_equal T.t(:key_caps_lock), Menu.keyname(0x14)
  end

  test "a key capture takes the keys that type < and ! on European layouts, named by the sign the layout types" do
    with_layout(0xE2 => 0x3C, 0xDF => 0x21) do
      said = [0xE2, 0xDF].map { |vk| capture(:c, [[[vk], true]]) }
      label = PokeAccess::Remap.label(:c)
      assert_equal [[[T.t(:rmp_assigned, :action => label, :key => T.t(:key_less))], 0xE2],
                    [[T.t(:rmp_assigned, :action => label, :key => T.t(:key_exclamation))], 0xDF]], said
    end
  end

  test "a key capture takes the Brazilian ABNT2 key beside the right Shift, named by the slash the layout types" do
    with_layout(0xC1 => 0x2F) do
      said = T.t(:rmp_assigned, :action => PokeAccess::Remap.label(:c), :key => T.t(:key_slash))
      assert_equal [[said], 0xC1], capture(:c, [[[0xC1], true]])
    end
  end

  test "says a taken key with the word for a key once, in every language, even a key named by its code" do
    doubled = (T.language_choices - [:auto]).map do |lang|
      Cfg.language = lang
      line = Menu.taken_line(0xBC, :next)
      words = line.downcase.split(/[^[:alpha:]]+/)
      words.each_cons(2).any? { |a, b| a == b } ? "#{lang}: #{line}" : nil
    end
    assert_equal [], doubled.compact
  end

  test "opens only over the map, saying so anywhere else" do
    was = $scene
    $scene = Object.new
    on_screen(:top) do
      Menu.open
      assert_equal [[[T.t(:cfg_map_only), true]], false], [SpeakCapture.log, Menu.active?]
    end
  ensure
    $scene = was
  end

  test "closes instead of hanging when a frame of it fails" do
    on_screen(:top) do
      replacing(Input, :update, lambda { raise "broken input" }) { Menu.open }
      assert_equal [false, ["#{T.t(:cfg)}. #{T.t(:cat_general)}"]], [Menu.active?, SpeakCapture.lines]
    end
  end

  test "does nothing when opened again while it runs" do
    on_screen(:pathfinder) do
      Menu.instance_variable_set(:@active, true)
      cutting_frames { Menu.open }
      assert_nothing_spoken
    end
  end

  test "moves down and up a row, wrapping round the ends, saying the row" do
    on_screen(:top) do
      press(Input::DOWN)
      press(Input::UP)
      press(Input::UP)
      assert_equal [T.t(:cat_pathfinder), T.t(:cat_general), T.t(:cat_reset)], SpeakCapture.lines
    end
  end

  test "puts a cursor left past the end of its screen back on the first row" do
    on_screen(:top, 99) do
      press(Input::DOWN)
      assert_equal [T.t(:cat_pathfinder)], SpeakCapture.lines
    end
  end

  test "steps the focused setting with right and left" do
    on_screen(:pathfinder) do
      point_at { |row| row[:row] && row[:row].key == :hide_unreachable }
      went = [Input::LEFT, Input::RIGHT, Input::RIGHT].map { |button| press(button); Cfg.hide_unreachable }
      assert_equal [:room, :off, :unreachable], went
    end
  end

  test "steps the focused setting on confirm as right does" do
    on_screen(:pathfinder) do
      point_at { |row| row[:row] && row[:row].key == :hide_unreachable }
      press(Input::C)
      said = "#{T.t(:lbl_hide_unreachable)}, #{T.t(:hide_unreachable)}"
      assert_equal [:unreachable, [[said, true]]], [Cfg.hide_unreachable, SpeakCapture.log]
    end
  end

  test "says the focused row's help when the info key is pressed on a frame" do
    on_screen(:pathfinder) do
      point_at { |row| row[:row] && row[:row].key == :hide_unreachable }
      replacing(PokeAccess::Keys, :key, lambda { |name| name == :info }) { Menu.step }
      assert_equal [T.t(:help_hide_unreachable)], SpeakCapture.lines
    end
  end

  test "the info key pressed while another program is in front says nothing, though Windows reports it" do
    on_screen(:pathfinder) do
      point_at { |row| row[:row] && row[:row].key == :hide_unreachable }
      replacing(PokeAccess::Keyboard, :pressed?, lambda { |code| code == Cfg.keys[:info] }) do
        replacing(PokeAccess::Focus, :focused?, lambda { false }) { Menu.step }
        assert_nothing_spoken
        replacing(PokeAccess::Focus, :focused?, lambda { true }) { Menu.step }
      end
      assert_equal [T.t(:help_hide_unreachable)], SpeakCapture.lines
    end
  end

  test "says the focused row whole with ctrl and the info key: its name and value, then its help, or the row alone" do
    said = [[:pathfinder, :hide_unreachable], [:pathfinder, :back]].map do |mode, id|
      on_screen(mode) do
        point_at { |row| row[:kind] == id || (row[:row] && row[:row].key == id) }
        replacing(PokeAccess::Keys, :ctrl_down?, lambda { true }) do
          replacing(PokeAccess::Keys, :key, lambda { |name| name == :info }) { Menu.step }
        end
        [Menu.describe, SpeakCapture.last]
      end
    end
    assert_equal [[said[0][0], "#{said[0][0]}. #{T.t(:help_hide_unreachable)}"], [T.t(:back), T.t(:back)]], said
  end

  test "goes back on confirm over a back row, as cancel does" do
    on_screen(:pathfinder, 0, [[:top, 1]]) do
      point_at { |row| row[:kind] == :back }
      Menu.activate(1)
      assert_equal [T.t(:cat_pathfinder)], SpeakCapture.lines
    end
  end

  test "opens the key screen on its first entry whatever it was left on, and back returns to the row it opened from" do
    on_screen(:top) do
      Menu.instance_variable_set(:@ri, 3)
      point_at { |row| row[:kind] == :remap }
      Menu.activate(1)
      opened = SpeakCapture.lines.dup
      SpeakCapture.clear
      press(Input::B)
      assert_equal [["#{T.t(:cat_remap)}. #{native_entry(:btn_down)}"], [T.t(:cat_remap)]],
                   [opened, SpeakCapture.lines]
    end
  end

  test "hands a frame on the key screen to the key screen's own keys, down moving to the next entry" do
    on_screen(:remap, 0, [[:top, 5]]) do
      Menu.instance_variable_set(:@ri, 0)
      press(Input::DOWN)
      assert_equal [native_entry(:btn_left)], SpeakCapture.lines
    end
  end

  test "says a game button without a key of its own as on the game's keys, and a bound one by its key" do
    on_entry(:c) do
      unbound = Menu.rebind_desc
      Cfg.rebinds = { :c => 0x4B }
      bound = "#{T.t(:rmp_entry, :action => T.t(:btn_accept), :key => "K")}. #{T.t(:rmp_entry_hint)}"
      assert_equal [native_entry(:btn_accept), bound], [unbound, Menu.rebind_desc]
    end
  end

  test "says a game extra without a key of its own by the key the game reads it on" do
    PokeAccess::Remap.register_extra(:test_extra, 0x54, :btn_x)
    on_entry(:test_extra) do
      assert_equal "#{T.t(:rmp_entry, :action => T.t(:btn_x), :key => "T")}. #{T.t(:rmp_entry_hint)}", Menu.rebind_desc
    end
  ensure
    PokeAccess::Remap.extras.reject! { |row| row[0] == :test_extra }
  end

  test "left on a bound game button gives it the game's keys back and says so, then finds nothing to undo" do
    on_entry(:c) do
      Cfg.rebinds = { :c => 0x4B }
      said = [1, 2].map { Menu.clear_binding; [Cfg.rebinds[:c], SpeakCapture.last] }
      assert_equal [[nil, T.t(:rmp_native_back, :action => T.t(:btn_accept))], [nil, T.t(:rmp_none)]], said
    end
  end

  test "left on a mod key already on its shipped key says it is there, changing nothing" do
    on_entry(:next) do
      Menu.clear_binding
      assert_equal [Cfg::KEY_DEFAULTS[:next], T.t(:rmp_at_default, :action => T.t(:rmk_next))],
                   [Cfg.keys[:next], SpeakCapture.last]
    end
  end

  test "the info key on the key screen says the focused entry with its hint, at brief verbosity too" do
    on_entry(:c) do
      Cfg.verbosity = :brief
      info = lambda { |name| name == :info }
      replacing(PokeAccess::Keys, :key, info) { Menu.step }
      Menu.instance_variable_set(:@ri, PokeAccess::Remap.buttons.length - 1)
      replacing(PokeAccess::Keys, :key, info) { Menu.step }
      assert_equal [native_entry(:btn_accept), "#{T.t(:rmp_reset)}. #{T.t(:rmp_reset_hint)}"], SpeakCapture.lines
    end
  end

  test "opens a screen on confirm saying its title and first row, and back returns to the row it was opened from" do
    on_screen(:top, 1) do
      press(Input::C)
      press(Input::B)
      assert_equal ["#{T.t(:cat_pathfinder)}. #{T.t(:lbl_auto_guide)}, #{T.t(:val_off)}", T.t(:cat_pathfinder)],
                   SpeakCapture.lines
    end
  end

  test "lands back within a screen that lost rows while one of its screens was open" do
    on_screen(:audio3d_adv, 0, [[:audio, 9]]) do
      Reset.with_capability(:positional, false) do
        Menu.back_one
        assert_equal [[T.t(:back), true]], SpeakCapture.log
      end
    end
  end

  test "says the chosen search algorithm's own help on the algorithm's row" do
    on_screen(:pathfinder_adv) do
      point_at { |row| row[:row] && row[:row].key == :path_algorithm }
      said = PokeAccess::Pathfinder::ALGORITHMS.map do |algo|
        Cfg.path_algorithm = algo
        Menu.speak_help
        SpeakCapture.last
      end
      assert_equal PokeAccess::Pathfinder::ALGORITHMS.map { |algo| T.t("help_algo_#{algo}".to_sym) }, said
    end
  end

  test "says a setting's help, the guide row's own with its keys named, and the row itself where a row has none" do
    {
      [:pathfinder, :hide_unreachable] => T.t(:help_hide_unreachable),
      [:audio3d_on, :guide]            => T.t(:help_on_guide, :key_shift => T.t(:key_shift), :key_route => "I"),
      [:pathfinder, :back]             => T.t(:back)
    }.each do |(mode, id), want|
      on_screen(mode) do
        point_at { |row| row[:kind] == id || row[:group] == id || (row[:row] && row[:row].key == id) }
        Menu.speak_help
        assert_equal want, SpeakCapture.last, "#{mode}, #{id}"
      end
    end
  end

  test "says what a sound marks on the info key over its switch" do
    on_screen(:audio3d_on) do
      said = [:sound_ledges, :sound_steps, :proximity_radar].map do |key|
        point_at { |row| row[:row] && row[:row].key == key }
        Menu.speak_help
        SpeakCapture.last
      end
      assert_equal [T.t(:snd_ledge_help), T.t(:snd_step_help), T.t(:snd_radar_help)], said
    end
  end

  test "says what a screen holds on the info key over the row that opens it" do
    {
      [:top, :audio]                 => :cat_audio_help,
      [:top, :sounds]                => :cat_sounds_help,
      [:top, :remap]                 => :cat_remap_help,
      [:audio, :audio3d_on]          => :cat_sounds_on_help,
      [:pathfinder, :pathfinder_adv] => :cat_nav_adv_help
    }.each do |(mode, id), key|
      on_screen(mode) do
        point_at { |row| row[:group] == id || row[:kind] == id }
        Menu.speak_help
        assert_equal T.t(key), SpeakCapture.last, "#{mode}, #{id}"
      end
    end
  end

  test "has what each screen holds in words for every group the menu lists and each of its own screens" do
    listed = Cfg.groups.select { |g| g.parent }.map { |g| g.id } + [:debug, :sounds, :personal, :remap]
    unnamed = Menu::SCREEN_HELP.values.select { |key| T.t(key) == key.to_s }
    assert_equal [[], []], [listed - Menu::SCREEN_HELP.keys, unnamed]
  end

  test "says the guide's row as the cane's state" do
    on_screen(:audio3d_on) do
      guide = Menu.items.find { |row| row[:kind] == :guide }
      said = [false, true].map { |on| PokeAccess::Guide.switch(:cane, on); Menu.describe(guide) }
      assert_equal ["#{T.t(:lbl_on_guide)}, #{T.t(:val_off)}", "#{T.t(:lbl_on_guide)}, #{T.t(:val_on)}"], said
    end
  ensure
    PokeAccess::Guide.switch(:cane, false)
  end

  test "switches the cane off on the guide's row with right, left or confirm, as Shift+I does" do
    on_screen(:audio3d_on) do
      point_at { |row| row[:kind] == :guide }
      guide = Menu.items[Menu.instance_variable_get(:@index)]
      { "right" => lambda { Menu.adjust(guide, 1) }, "left" => lambda { Menu.adjust(guide, -1) },
        "confirm" => lambda { Menu.activate(1) } }.each do |what, act|
        PokeAccess::Guide.switch(:cane, true)
        SpeakCapture.clear
        act.call
        assert_equal [false, [[T.t(:loc_guide_off), true]]], [PokeAccess::Guide.on?(:cane), SpeakCapture.log], what
      end
    end
  ensure
    PokeAccess::Guide.switch(:cane, false)
  end

  test "keeps no setting behind the guide's row, so nothing of it is saved" do
    assert_nil Cfg.settings.find { |s| s.label == :lbl_on_guide }
  end

  test "hands back the very same rows while nothing they depend on changes" do
    on_screen(:top) do
      assert_same Menu.items, Menu.items
    end
  end

  test "builds other rows for another screen" do
    on_screen(:top) do
      top = Menu.items
      Menu.instance_variable_set(:@mode, :personal)
      refute_same top, Menu.items
    end
  end

  test "rebuilds the open list the moment a mark is written or deleted" do
    on_screen(:list_marks) do
      entry = lambda { Menu.items.any? { |r| r[:kind] == :entry && r[:key] == [1, 4, 4] } }
      PokeAccess::Marks.set(1, 4, 4, "Sonda")
      written = entry.call
      PokeAccess::Marks.delete(1, 4, 4)
      assert_equal [true, false], [written, entry.call]
    end
  ensure
    PokeAccess::Marks.delete(1, 4, 4)
  end

  test "offers to start a recording on the debug screen, and to stop it once one runs" do
    on_screen(:debug) do
      with_recorder("rec-1.txt", 4) do
        label = lambda { Menu.items.find { |r| r[:action] == :rec_toggle }[:label] }
        before = label.call
        point_at { |row| row[:action] == :rec_toggle }
        Menu.activate(1)
        assert_equal [:dbg_rec_start, :dbg_rec_stop], [before, label.call]
      end
    end
  end

  test "says the file a recording started from the debug screen writes, then how many events it held" do
    on_screen(:debug) do
      with_recorder("rec-1.txt", 4) do
        point_at { |row| row[:action] == :rec_toggle }
        2.times { Menu.activate(1) }
        assert_equal [T.t(:rec_started, :file => "rec-1.txt"), T.t(:rec_stopped, :n => 4)], SpeakCapture.lines
      end
    end
  end

  test "says a recording that cannot start" do
    on_screen(:debug) do
      with_recorder(nil, 0) do
        point_at { |row| row[:action] == :rec_toggle }
        Menu.activate(1)
        assert_equal [T.t(:rec_failed)], SpeakCapture.lines
      end
    end
  end

  test "copies each diagnostic row's own section, or the whole dump, and runs the self-check from its row" do
    ran = []
    keys = PokeAccess::Keys
    replacing(keys, :diag_section_to_clip, lambda { |section| ran.push(section) }) do
      replacing(keys, :diag_dump, lambda { ran.push(:dump) }) do
        replacing(PokeAccess::SelfCheck, :run, lambda { ran.push(:selfcheck) }) do
          on_screen(:debug) do
            [:diag_audio, :diag_events, :diag_perf, :diag_map, :diag_scene, :diag_full, :selfcheck].each do |action|
              point_at { |row| row[:action] == action }
              Menu.activate(1)
            end
          end
        end
      end
    end
    assert_equal [:audio, :events, :perf, :map, :scene, :dump, :selfcheck], ran
  end

  test "asks before restoring the defaults, changing nothing on the first press" do
    on_reset_row do
      Cfg.auto_guide = true
      Menu.activate(1)
      assert_equal [true, [[T.t(:cfg_reset_confirm), true]]], [Cfg.auto_guide, SpeakCapture.log]
    end
  end

  test "asks before restoring the defaults naming what stays as it is, the language and the keys" do
    on_reset_row do
      Cfg.language = :es
      Menu.activate(1)
      want = "¿Restaurar todos los ajustes salvo el idioma y las teclas? Pulsa Aceptar otra vez para confirmar."
      assert_equal want, SpeakCapture.last
    end
  end

  test "restores every setting on a second press in a row, saying so" do
    on_reset_row do
      Cfg.auto_guide = true
      Cfg.route_reach = 512
      2.times { Menu.activate(1) }
      assert_equal [false, 128, T.t(:cfg_reset_done)], [Cfg.auto_guide, Cfg.route_reach, SpeakCapture.last]
    end
  end

  test "asks again when the cursor moved away between the presses" do
    on_reset_row do
      Cfg.auto_guide = true
      Menu.activate(1)
      Menu.move(-1)
      Menu.move(1)
      Menu.activate(1)
      assert_equal [true, T.t(:cfg_reset_confirm)], [Cfg.auto_guide, SpeakCapture.last]
    end
  end

  test "asks again on the press after a restore" do
    on_reset_row do
      2.times { Menu.activate(1) }
      point_at { |row| row[:action] == :reset }
      Cfg.auto_guide = true
      Menu.activate(1)
      assert_equal [true, T.t(:cfg_reset_confirm)], [Cfg.auto_guide, SpeakCapture.last]
    end
  end

  test "saves the settings it restores" do
    on_reset_row do
      Cfg.auto_guide = true
      PokeAccess::Settings.write
      2.times { Menu.activate(1) }
      assert_equal "false", PokeAccess::Settings.read["auto_guide"]
    end
  end

  test "keeps the focus on the reset's row once it restores" do
    on_reset_row do
      2.times { Menu.activate(1) }
      assert_equal T.t(:cat_reset), Menu.describe
    end
  end

  test "leaves the key rebinds as they are when it restores the settings" do
    on_reset_row do
      Cfg.rebinds = { :l => 36 }
      2.times { Menu.activate(1) }
      assert_equal({ :l => 36 }, Cfg.rebinds)
    end
  end

  test "keeps the mod's language as it is when it restores the settings, saying so in it" do
    on_reset_row do
      Cfg.language = :fr
      2.times { Menu.activate(1) }
      assert_equal [:fr, T.t(:cfg_reset_done)], [Cfg.language, SpeakCapture.last]
    end
  end

  test "asks before resetting every key, touching none on the first press" do
    on_screen(:remap) do
      Cfg.rebinds = { :l => 36 }
      Cfg.keys[:next] = 0x58
      Menu.reset_all
      assert_equal [{ :l => 36 }, 0x58, [[T.t(:rmp_reset_confirm), true]]],
                   [Cfg.rebinds, Cfg.keys[:next], SpeakCapture.log]
    end
  end

  test "resets the rebinds and the mod's keys on a second press, saving them and saying so" do
    on_screen(:remap) do
      Cfg.rebinds = { :l => 36 }
      Cfg.keys[:next] = 0x58
      PokeAccess::Settings.write
      2.times { Menu.reset_all }
      saved = PokeAccess::Settings.read.keys.grep(/\A(bind|key)_/)
      assert_equal [{}, Cfg::KEY_DEFAULTS[:next], [], T.t(:rmp_all_reset)],
                   [Cfg.rebinds, Cfg.keys[:next], saved, SpeakCapture.last]
    end
  end

  test "asks again on the press after a key reset" do
    on_screen(:remap) do
      2.times { Menu.reset_all }
      Cfg.rebinds = { :l => 36 }
      Menu.reset_all
      assert_equal [{ :l => 36 }, T.t(:rmp_reset_confirm)], [Cfg.rebinds, SpeakCapture.last]
    end
  end

  test "sets a value, tells the subscribers which setting moved and answers the value" do
    heard = []
    listener = lambda { |key| heard.push(key) }
    PokeAccess::Events.on(:config_changed, &listener)
    answer = Cfg.set(:auto_guide, true)
    assert_equal [true, true, [:auto_guide]], [answer, Cfg.auto_guide, heard]
  ensure
    PokeAccess::Events.instance_variable_get(:@handlers)[:config_changed].delete_if { |h| h.equal?(listener) }
  end

  test "reads a stored value as its kind takes it, a number clamped to its bounds" do
    {
      [:audio3d_wall_falloff, "150"]  => 100,
      [:audio3d_wall_falloff, "-5"]   => 0,
      [:audio3d_wall_falloff, " 40 "] => 40,
      [:route_reach, "10"]            => 32,
      [:astar_max, "99999"]           => 10000,
      [:astar_max, "2500"]            => 2500,
      [:astar_max, "lots"]            => nil,
      [:auto_guide, "true"]           => true,
      [:auto_guide, "false"]          => false,
      [:auto_guide, "yes"]            => nil,
      [:sound_nav, "basic"]           => :basic,
      [:sound_nav, "loud"]            => nil,
      [:sound_nav, ""]                => nil
    }.each do |(key, text), want|
      got = Cfg.parse(Cfg.setting(key), text)
      want.nil? ? assert_nil(got, "#{key} #{text.inspect}") : assert_equal(want, got, "#{key} #{text.inspect}")
    end
  end

  test "names every value of every list setting, keys the menu builds at run time" do
    missing = []
    Cfg::LISTS.each do |kind, (_values, namer)|
      next unless namer.is_a?(String)
      Cfg.values_of(kind).each do |v|
        key = "#{namer}#{v}"
        missing.push(key) if T.t(key.to_sym) == key
      end
    end
    assert_equal [], missing
  end

  test "does not show a setting whose capability nobody registered" do
    row = Cfg::Setting.new(:pa_probe, false, :flag, :debug, :lbl_route_stats, nil, nil, [:pa_unregistered])
    assert_equal false, Cfg.visible?(row)
  end

  test "does not show a setting that depends on one never declared" do
    row = Cfg::Setting.new(:pa_probe, false, :flag, :debug, :lbl_route_stats, nil, [:pa_undeclared, true], [])
    assert_equal false, Cfg.visible?(row)
  end

  private

  # The rows of screen mode as short ids: a setting's key, [:enter, group] for a screen it opens, [:action, action]
  # for one it runs, else the row's kind.
  def rows(mode)
    Menu.instance_variable_set(:@mode, mode)
    Menu.items.map do |i|
      case i[:kind]
      when :setting then i[:row].key
      when :enter   then [:enter, i[:group]]
      when :action  then [:action, i[:action]]
      else i[:kind]
      end
    end
  end

  # Runs the block on screen mode with the cursor on row index and the screens under it in stack; the menu's state
  # and the settings file are put back afterwards.
  def on_screen(mode, index = 0, stack = [])
    saved = STATE.map { |iv| Menu.instance_variable_get(iv) }
    settings = (File.read(PokeAccess::Settings::FILE) rescue nil)
    Menu.instance_variable_set(:@mode, mode)
    Menu.instance_variable_set(:@index, index)
    Menu.instance_variable_set(:@stack, stack)
    Menu.instance_variable_set(:@armed, nil)
    yield
  ensure
    STATE.each_with_index { |iv, i| Menu.instance_variable_set(iv, saved[i]) }
    put_back(settings)
  end

  # Runs the block on the top screen with the cursor on the reset's row.
  def on_reset_row
    on_screen(:top) do
      point_at { |row| row[:action] == :reset }
      yield
    end
  end

  # Puts the cursor on the first row of the screen the block accepts.
  def point_at
    i = Menu.items.index { |row| yield row }
    flunk "no such row on #{Menu.instance_variable_get(:@mode)}" unless i
    Menu.instance_variable_set(:@index, i)
  end

  # Runs the block with obj's singleton method name answering by body, the method it had put back afterwards.
  def replacing(obj, name, body)
    was = obj.method(name)
    obj.define_singleton_method(name, &body)
    yield
  ensure
    obj.define_singleton_method(name, was)
  end

  # One frame of the menu with the game's Input reporting button pressed.
  def press(button)
    holding(button) { Menu.step }
  end

  # Runs the block with the game's Input reporting button as triggered and repeated.
  def holding(button)
    pressed = lambda { |b| b == button }
    replacing(Input, :trigger?, pressed) { replacing(Input, :repeat?, pressed) { yield } }
  end

  # Opens the menu with the game's Input holding button, its modal loop cut should the menu not close itself.
  def open_holding(button)
    cutting_frames { holding(button) { Menu.open } }
  end

  # Runs the block with Graphics cutting a modal loop after a few frames, so a menu that does not close fails its
  # test instead of hanging the run.
  def cutting_frames
    frames = 0
    cut = lambda { frames += 1; raise "the menu did not close" if frames > 5 }
    replacing(Graphics, :update, cut) { yield }
  end

  # Runs the block with the recorder answering as a stand-in: the file a start opens (nil when it cannot) and the
  # count a stop reports.
  def with_recorder(file, count)
    on = false
    rec = PokeAccess::Recorder
    replacing(rec, :recording?, lambda { on }) do
      replacing(rec, :start, lambda { on = !file.nil?; file }) do
        replacing(rec, :stop, lambda { on = false; count }) { yield }
      end
    end
  end

  # The key screen's entry for a game button left on the game's keys, labelled label, said with its hint as at full
  # verbosity.
  def native_entry(label)
    "#{T.t(:rmp_entry, :action => T.t(label), :key => T.t(:rmp_native))}. #{T.t(:rmp_entry_hint)}"
  end

  # Runs the block on the key screen with the cursor on action's entry.
  def on_entry(action)
    on_screen(:remap, 0, [[:top, 5]]) do
      Menu.instance_variable_set(:@ri, PokeAccess::Remap.buttons.index { |b| b[0] == action })
      yield
    end
  end

  # Runs a key capture on the key screen's entry for action, one look at the keys per frame given as [the
  # virtual-keys held, whether the game has the focus]; answers [what was said, the entry's binding after]. The
  # bindings are put back afterwards.
  def capture(action, frames)
    held = []
    focus = true
    rebinds = (Cfg.rebinds || {}).dup
    keys = Cfg.keys.dup
    on_screen(:top) do
      Menu.instance_variable_set(:@ri, PokeAccess::Remap.buttons.index { |b| b[0] == action })
      replacing(Menu, :down?, lambda { |c| held.include?(c) }) do
        replacing(PokeAccess::Focus, :focused?, lambda { focus }) do
          Menu.start_capture
          SpeakCapture.clear
          frames.each do |down, front|
            held = down
            focus = front
            3.times { Menu.capture_step if Menu.instance_variable_get(:@capturing) }
          end
          bound = PokeAccess::Remap.mod_action?(action) ? Cfg.keys[action] : Cfg.rebinds[action]
          return [SpeakCapture.lines, bound]
        end
      end
    end
  ensure
    Cfg.rebinds = rebinds
    Cfg.keys = keys
  end

  # Runs the block with MapVirtualKey answering, for a virtual key to its character (MAPVK_VK_TO_CHAR), what chars
  # gives it (0 for the rest), as the active keyboard layout would; put back after.
  def with_layout(chars)
    fake = Object.new
    fake.define_singleton_method(:call) { |vk, type| type == 2 ? (chars[vk] || 0) : 0 }
    real = PokeAccess::Keyboard::MVK_CHAR
    PokeAccess::Keyboard.send(:remove_const, :MVK_CHAR)
    PokeAccess::Keyboard.const_set(:MVK_CHAR, fake)
    yield
  ensure
    PokeAccess::Keyboard.send(:remove_const, :MVK_CHAR)
    PokeAccess::Keyboard.const_set(:MVK_CHAR, real)
  end

  # Puts the settings file back as text, or removes it for nil.
  def put_back(text)
    file = PokeAccess::Settings::FILE
    if text
      File.open(file, "w") { |f| f.write(text) }
    elsif File.exist?(file)
      File.delete(file)
    end
  end
end
