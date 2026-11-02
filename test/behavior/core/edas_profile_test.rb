# The Pokemon Edas profile loaded whole, over doubles with the shape of its scripts: its rules for the field moves and
# the Blood Medallion's vampire, the Eye of Truth, the pictures with no text, the load screen's Continue row, the pause
# menu and the debt, the quest log, the PC's IV stars, the boss's box and the rhythm game. In a process of its own, since
# its overrides would reach every other test here.
class EdasProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The boss's switch, as 0211_2 vs 1 names it.
    NO_CAPTURES_SWITCH = 99
    require File.join(Harness::ROOT, "test", "support", "tile_world")

    # The maps whose water the action key does nothing on (0228_Finales).
    NO_SURF_MAPS = [7]

    # The moves the party knows, as the game's finder asks for them: a function defined at the top level, public in the
    # game, which calls it on Kernel.
    $party_moves = []
    def pbCheckMove(move); $party_moves.include?(move) ? :a_pokemon : nil; end
    Object.send(:public, :pbCheckMove)

    def drawFormattedTextEx2(_bitmap, _x, _y, _width, _height, _text, _base = nil, _shadow = nil, _outline = true); end

    # The debt the pause menu paints, kept by the game's global.
    def $PokemonGlobal.deuda; @deuda.to_i; end
    def $PokemonGlobal.deuda=(v); @deuda = v; end

    # The pause menu: entries [icon, label, function], drawn as icons.
    class Menu2
      def initialize(items, selected)
        @items = items
        @selected_item = selected
      end

      def redrawSelector; end
    end

    # The command window of the load screen.
    class LoadWindow
      attr_accessor :index, :active

      def initialize(index)
        @index = index
        @active = true
      end

      def update; end
    end

    Shade = Struct.new(:red, :green, :blue)
    Quest = Struct.new(:name, :color, :completed)
    Pager = Struct.new(:opacity) do
      def disposed?; false; end
    end
    Boss = Struct.new(:index, :level)
    Named = Struct.new(:name)
    SelectorBitmap = Struct.new(:width)
    Selector = Struct.new(:bitmap)

    # A note of the rhythm game, moving left by its step each frame, in reach of the selector within its range of 30.
    class SongNote
      attr_accessor :note, :step_distance, :x, :range, :hit

      def initialize(note, x, hit = false)
        @note = note
        @step_distance = 3.5
        @x = x
        @range = 30
        @hit = hit
      end

      def doStep; self.x -= step_distance; end
    end

    # The rhythm game: pbUpdate is its modal loop, here over the frames a probe gives it.
    class Idol
      attr_accessor :frames

      def initialize(notes)
        @notes = notes
        @frames = 0
      end

      def pbStartScene; @sprites = { "selector" => Selector.new(SelectorBitmap.new(64)) }; end

      def pbUpdate
        @frames.times do
          @notes.each { |n| n.doStep }
          PokeAccess::Frame.run_pollers
        end
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    # A shore two steps from the player, two tiles of water, and (7, 1) beyond them, reached by water alone.
    STRAIT = ["#########",
              "#@..~~..#",
              "#########"]

    # Runs the block with a bag holding just these items.
    def with_bag(items)
      was = $PokemonBag
      $PokemonBag = Object.new
      $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
      yield
    ensure
      $PokemonBag = was
    end

    # Runs the block with the party knowing these moves.
    def with_moves(moves)
      was = $party_moves
      $party_moves = moves
      yield
    ensure
      $party_moves = was
    end

    # Whether the party can use a move, for each list of what it knows.
    def can_cut(moves)
      moves.map { |m| with_moves([m]) { PokeAccess::FieldMoves.can?(:CUT) } }
    end

    # Runs the block on STRAIT, on the player's last floor tile facing the water, with this bag and this much company.
    def on_strait(bag, map_id = 900, company = false)
      was = [$game_map, $game_player]
      $game_map = TileWorld.new(STRAIT, map_id)
      $game_player = TileWorldPlayer.new(3, 1)
      $game_player.direction = 6
      $game_player.define_singleton_method(:pbHasDependentEvents?) { company }
      PokeAccess::Pathfinder.invalidate_cache(true)
      PokeAccess::World::Epoch.touch(:tiles)
      with_bag(bag) { yield }
    ensure
      $game_map, $game_player = was
      PokeAccess::Pathfinder.invalidate_cache(true)
      PokeAccess::World::Epoch.touch(:tiles)
    end

    # What the surface notices say facing the water.
    def water_cue
      PokeAccess::Config.surface_cues = true
      PokeAccess::Surfaces.reset_map_state
      said { PokeAccess::Surfaces.surfaces }
    end

    def field_moves_play
      probe(:cut_moves) { can_cut([:CUT, :SLASH, :LEAFBLADE, :NIGHTSLASH, :CUCHILLADAASTRAL, :TACKLE]) }
      probe(:other_move) do
        [with_moves([:ROCKSMASH]) { PokeAccess::FieldMoves.can?(:ROCKSMASH) }, with_moves([:SLASH]) { PokeAccess::FieldMoves.can?(:ROCKSMASH) }]
      end
      probe(:cut_unreadable) do
        finder = Object.instance_method(:pbCheckMove)
        Object.send(:remove_method, :pbCheckMove)
        begin
          PokeAccess::FieldMoves.can?(:CUT)
        ensure
          Object.send(:define_method, :pbCheckMove, finder)
          Object.send(:public, :pbCheckMove)
        end
      end
      probe(:surf_rules) do
        fm = PokeAccess::FieldMoves
        [with_bag([:BICYCLE]) { fm.can?(:SURF) }, with_bag([]) { fm.can?(:SURF) },
         with_bag([]) { with_moves([:SURF]) { fm.can?(:SURF) } }]
      end
      probe(:surf_no_surf_map) do
        fm = PokeAccess::FieldMoves
        on_strait([:BICYCLE], 7) do
          [fm.can?(:SURF), with_moves([:SURF]) { fm.can?(:SURF) }, fm.item_ready?(:CUT)]
        end
      end
      probe(:surf_no_list) do
        was = Object.send(:remove_const, :NO_SURF_MAPS)
        begin
          on_strait([:BICYCLE], 7) { PokeAccess::FieldMoves.can?(:SURF) }
        ensure
          Object.const_set(:NO_SURF_MAPS, was)
        end
      end
      probe(:water_cues) do
        [on_strait([:BICYCLE]) { water_cue }, on_strait([]) { water_cue }, on_strait([:BICYCLE], 7) { water_cue },
         on_strait([:BICYCLE], 900, true) { water_cue }]
      end
      probe(:water_floating) do
        $PokemonGlobal.bicycle = true
        begin
          on_strait([:BICYCLE]) { water_cue }
        ensure
          $PokemonGlobal.bicycle = false
        end
      end
      probe(:water_plans) do
        [[[:BICYCLE], 900, false], [[], 900, false], [[:BICYCLE], 7, false], [[:BICYCLE], 900, true]].map do |bag, map, company|
          on_strait(bag, map, company) { PokeAccess::Routes::Planner.plan(7, 1).kind }
        end
      end
      probe(:vampire) do
        [said { $PokemonGlobal.bicycle = true; PokeAccess::Frame.run_pollers }, said { PokeAccess::Frame.run_pollers },
         said { $PokemonGlobal.bicycle = false; PokeAccess::Frame.run_pollers }, said { PokeAccess::Frame.run_pollers }]
      end
      probe(:orb_night) do
        $game_switches[100] = true
        night = PokeAccess::Battle.time_of_day
        $game_switches[100] = false
        [night, PokeAccess::Battle.time_of_day]
      end
      probe(:float_no_surf_map) do
        on_strait([:BICYCLE]) do
          was = $game_map.map_id
          $game_map.map_id = NO_SURF_MAPS[0]
          line = PokeAccess::I18n.t(:surf_ahead)
          $game_map.map_id = was
          line
        end
      end
      probe(:float_words) do
        i18n = PokeAccess::I18n
        lines = lambda { [i18n.t(:surf_ahead), i18n.t(:loc_surf_here), i18n.t(:loc_surf_toward, :dir => "x"), i18n.t(:loc_surf_company)] }
        [on_strait([:BICYCLE]) { lines.call }, on_strait([]) { lines.call }]
      end
      probe(:other_words) do
        i18n = PokeAccess::I18n
        [i18n.t(:loc_dismount_here, :dir => "x"), i18n.t(:loc_dismount_route), i18n.t(:loc_dismount_spot), i18n.t(:fs_lens_on),
         i18n.t(:fs_lens_off), i18n.t(:qu_detail, :name => "Misión", :status => "En progreso", :desc => "Lleva el paquete", :npc => "Jefe Paco"),
         i18n.t(:water_ahead)]
      end
    end

    def world_play
      probe(:profile_name) { PokeAccess::Game.profile_name }
      probe(:key_letters) { PokeAccess::KeyHints.table }
      probe(:plain_passability) { PokeAccess::World::Probe.plain? }
      probe(:remap) { [PokeAccess::Config.rebind_labels[:l], PokeAccess::Remap.extras.select { |row| row[1] == 0x45 || row[1] == 0x46 }] }
      probe(:lens) { ["EOT", "#EOT", "Puerta EOT", "Puerta", nil].map { |n| PokeAccess::Locator.lens_tile?(Named.new(n)) } }
      probe(:picture_names) { PokeAccess::PictureCues::TEXTS.keys.map { |n| [n, PokeAccess::PictureCues.text_for(n)] } }
      probe(:picture_shown) { said { PokeAccess::PictureCues.on_picture("aende", []) } }
    end

    # A load screen with these rows, its cursor on one.
    def load_scene(rows, index)
      scene = PokemonLoadScene.new
      scene.instance_variable_set(:@commands, rows)
      scene.instance_variable_set(:@sprites, { "cmdwindow" => LoadWindow.new(index) })
      scene
    end

    def load_play
      rows = ["", "Nueva partida", "Opciones"]
      probe(:load_opening) do
        scene = load_scene(rows, 0)
        [said { scene.pbUpdate }, said { scene.pbUpdate }]
      end
      probe(:load_away_and_back) do
        scene = load_scene(rows, 0)
        scene.pbUpdate
        win = PokeAccess.sprite(scene, "cmdwindow")
        win.index = 1
        away = said { scene.pbUpdate }
        win.index = 0
        [away, said { scene.pbUpdate }]
      end
      probe(:load_elsewhere) { said { load_scene(rows, 2).pbUpdate } }
      probe(:load_titled) { said { load_scene(["Continuar", "Opciones"], 0).pbUpdate } }
      probe(:load_past_the_end) { said { load_scene(rows, 5).pbUpdate } }
      probe(:load_inactive) do
        scene = load_scene(rows, 0)
        PokeAccess.sprite(scene, "cmdwindow").active = false
        said { scene.pbUpdate }
      end
      probe(:load_no_rows) { said { load_scene(nil, 0).pbUpdate } }
      probe(:load_nested_hooks) do
        PokeAccess::Hooks.after_hook("LoadWindow", :update) { |_w, _r, _a| PokeAccess.speak("una fila", false) }
        said { load_scene(rows, 2).pbUpdate }
      end
    end

    # The trainer line with this debt, this money and these switches.
    def debt_line(debt, money, on68, on137)
      $PokemonGlobal.deuda = debt
      was = PokeAccess::Info.player_object.money
      PokeAccess::Info.player_object.money = money
      $game_switches[68] = on68
      $game_switches[137] = on137
      PokeAccess::Info.trainer_info
    ensure
      PokeAccess::Info.player_object.money = was
      $game_switches[68] = false
      $game_switches[137] = false
    end

    def pause_play
      probe(:pause_words) do
        %w[bag pokeball save options misiones reloj].map { |icon| PokeAccess::Menu2Pause.label([icon, "copia", "f"]) }
      end
      probe(:pause_others) { [PokeAccess::Menu2Pause.label(["otro", "Algo", "f"]), PokeAccess::Menu2Pause.label(["exit", "copia", "f"])] }
      probe(:pause_focus) { said { Menu2.new([["bag", "x", "f"], ["misiones", "x", "g"]], 1).redrawSelector } }
      probe(:debt_due) { [debt_line(1500, 500, true, false), debt_line(501, 500, true, false)] }
      probe(:debt_paid) { [debt_line(500, 500, true, false), debt_line(400, 500, true, false)] }
      probe(:debt_cleared) { debt_line(1500, 500, true, true) }
      probe(:debt_not_yet) { debt_line(1500, 500, false, false) }
    end

    def quests_play
      probe(:quest_marks) do
        [[18, 235, 170], [255, 115, 115], [197, 252, 70], [255, 255, 255], [18, 235, 171]].map do |r, g, b|
          PokeAccess::EdasQuests.mark(Quest.new("Misión", Shade.new(r, g, b)))
        end
      end
      probe(:quest_row) { PokeAccess::Quests.quest_row(Quest.new("Misión", Shade.new(255, 115, 115), false)) }
      probe(:quest_plain) { PokeAccess::Quests.color_mark(Quest.new("Misión", nil)) }
      probe(:quest_page) do
        log = Object.new
        log.instance_variable_set(:@sprites, { "pager" => Pager.new(255) })
        log.instance_variable_set(:@page, 0)
        [PokeAccess::Quests.page_mark(log), PokeAccess::Quests.with_page(log, "Detalle")]
      end
    end

    def battle_and_pc_play
      probe(:stars) { TestPoke.build(:iv => [31, 30, 29, 3, 1, 0]).then { |pk| PokeAccess::Party.pc_details(pk).last } }
      probe(:boss_level) do
        $game_switches[99] = true
        [PokeAccess::Battle.shown_level(Boss.new(1, 70)), PokeAccess::Battle.shown_level(Boss.new(0, 40)),
         PokeAccess::Battle.shown_level(Boss.new(3, 50))]
      end
      probe(:boss_off) do
        $game_switches[99] = false
        PokeAccess::Battle.shown_level(Boss.new(1, 70))
      end
    end

    # The rhythm game with these notes, opened, and what the next frames of its loop sound, batch by batch.
    def song(notes, batches)
      scene = Idol.new(notes)
      scene.pbStartScene
      batches.map do |frames|
        scene.frames = frames
        cues { scene.pbUpdate }
      end
    end

    def idol_play
      probe(:idol_open) { said { Idol.new([]).pbStartScene } }
      probe(:idol_chimes) { song([SongNote.new("up", 300), SongNote.new("left", 400)], [5, 1, 27, 1, 10]) }
      probe(:idol_together) { song([SongNote.new("right", 240), SongNote.new("down", 245)], [1, 1]) }
      probe(:idol_hit) { song([SongNote.new("up", 240, true), SongNote.new("left", 245)], [1]) }
      probe(:idol_past_reach) { song([SongNote.new("up", 197), SongNote.new("left", 240)], [1]) }
      probe(:idol_behind) do
        behind = SongNote.new("up", 400)
        song([behind, SongNote.new("left", 245)], [1, 42])
      end
      probe(:idol_unknown) { song([SongNote.new(nil, 240), SongNote.new("left", 245)], [1]) }
      probe(:idol_word) do
        PokeAccess::Config.sound_minigame = false
        scene = Idol.new([SongNote.new("up", 240)])
        scene.pbStartScene
        scene.frames = 1
        sounds = nil
        lines = said { sounds = cues { scene.pbUpdate } }
        PokeAccess::Config.sound_minigame = true
        [lines, sounds]
      end
      probe(:idol_after_loop) do
        note = SongNote.new("up", 300)
        scene = Idol.new([note])
        scene.pbStartScene
        scene.frames = 1
        scene.pbUpdate
        note.x = 240
        cues { PokeAccess::Frame.run_pollers }
      end
    end

    field_moves_play
    world_play
    load_play
    pause_play
    quests_play
    battle_and_pc_play
    idol_play
  RUBY

  profile "edas", WORLD, PLAY

  # The guide's flat chime toward d at the minigames' volume.
  def chime(d)
    file, pitch = PokeAccess::Sound::Catalog::GUIDE_FLAT[d]
    [file, PokeAccess::Sound::Mixer.volume(:minigame), (pitch * PokeAccess::Sound::Mixer.flat_factor(:guide)).round]
  end

  test "loads whole, what it imports and every plugin, and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    assert_equal [], played(:absent_functions) & %w[drawFormattedTextEx2]
  end

  test "goes by its own name, not its common's" do
    assert_equal "edas", played(:profile_name)
  end

  test "its key hints are RPG Maker XP's letters, and its passability reads nothing an event sets" do
    assert_equal PokeAccess::KeyHints::RGSS_LETTERS, played(:key_letters)
    assert_equal true, played(:plain_passability)
  end

  test "the remap screen tells what L does on the map, and takes the game's E and F keys" do
    assert_equal [:edas_btn_l, [[:gem_flight, 0x45, :edas_key_e], [:text_log, 0x46, :rem_ext_key_f]]], played(:remap)
  end

  test "any of its five moves cuts, and a move that does not cut does not" do
    assert_equal [true, true, true, true, true, false], played(:cut_moves)
  end

  test "the other field moves are asked as ever, and Cut with no finder is not a no" do
    assert_equal [true, false], played(:other_move)
    assert_nil played(:cut_unreadable)
  end

  test "water can be taken with the Blood Medallion or a Pokemon that knows Surf" do
    assert_equal [true, false, true], played(:surf_rules)
  end

  test "on a map where the medallion does nothing only a Pokemon that knows Surf can, and the other moves' items are untouched" do
    assert_equal [false, true, false], played(:surf_no_surf_map)
  end

  test "with no list of such maps the medallion works everywhere" do
    assert_equal true, played(:surf_no_list)
  end

  test "water ahead is said floatable with the medallion, and plain without it, on a map it does nothing on and with company" do
    surf = [[t(:edas_float_ahead), false]]
    water = [[t(:water_ahead), false]]
    assert_equal [surf, water, water, water], played(:water_cues)
  end

  test "floating already, the water ahead is no longer anything to start on" do
    assert_equal [], played(:water_floating)
  end

  test "a way by water is planned only where the medallion works, and said to be barred by company along" do
    assert_equal [:surf, :none, :none, :company], played(:water_plans)
  end

  test "the form is said queued only when it changes, also when the game drops the bike's mode with no function of its own" do
    assert_equal [[[t(:edas_vampire_on), false]], [], [[t(:edas_vampire_off), false]], []], played(:vampire)
  end

  test "the time of day is night under the Time Orb, whatever the clock says" do
    assert_equal [:tod_night, nil], played(:orb_night)
  end

  test "on a map the action key does nothing on, the water goes by Surf even with the medallion" do
    assert_equal t(:surf_ahead), played(:float_no_surf_map)
  end

  test "taking to the water is said as floating with the medallion, and as Surf with only a Pokemon that knows it" do
    float = [t(:edas_float_ahead), t(:edas_float_here), t(:edas_float_toward, :dir => "x"), t(:edas_float_company)]
    surf = [t(:surf_ahead), t(:loc_surf_here), t(:loc_surf_toward, :dir => "x"), t(:loc_surf_company)]
    assert_equal [float, surf], played(:float_words)
  end

  test "the bike is the vampire, the lens the Dark Gem's, the quest detail names no giver, and any other line stands" do
    assert_equal [t(:edas_unfloat_here, :dir => "x"), t(:edas_unfloat_route), t(:edas_unfloat_spot), t(:edas_lens_on), t(:edas_lens_off),
                  "Misión, En progreso. Lleva el paquete", t(:water_ahead)], played(:other_words)
  end

  test "the Eye of Truth reveals any event with EOT in its name, with or without the hash" do
    assert_equal [true, true, true, false, false], played(:lens)
  end

  test "every picture has its text, literal or in the mod's words" do
    names = played(:picture_names).to_h
    %w[intro1 BadEndingCiencia GoodEndingCiencia NormalEnding FinalCorrida haremending aend aende Edas].each do |name|
      refute_nil names[name], name
    end
    assert_equal "Pokémon Edas: Código Ámbar", names["Código Ámbar"]
    assert_equal "¿Fin?", names["aende"]
    { "campos" => :edas_pic_fields, "Camión Base" => :edas_pic_truck, "Centefico1" => :edas_pic_scientists,
      "Draculaura1" => :edas_pic_night, "Dibujo Ecchi" => :edas_pic_drawing, "Escena1_Capa2" => :edas_pic_satellite }.each do |name, key|
      assert_equal t(key), names[name], name
    end
  end

  test "a picture is said as it is shown, cutting in" do
    assert_equal [["¿Fin?", true]], played(:picture_shown)
  end

  test "the load screen names its Continue row as it opens, queued, and only once" do
    assert_equal [[[t(:msv_continue), false]], []], played(:load_opening)
  end

  test "back on the Continue row it is named again, cutting in, and the other rows are the generic reader's" do
    assert_equal [[], [[t(:msv_continue), true]]], played(:load_away_and_back)
    assert_equal [], played(:load_elsewhere)
  end

  test "a row with a title, no row, an idle window and no rows at all say nothing" do
    assert_equal [[], [], [], []], [played(:load_titled), played(:load_past_the_end), played(:load_inactive), played(:load_no_rows)]
  end

  test "what a frame of the load screen updates can still say its own" do
    assert_equal [["una fila", false]], played(:load_nested_hooks)
  end

  test "the pause menu's icons are said by the word each carries" do
    assert_equal ["Bolsa", "Equipo", "Guardar", "Opciones", "Misiones", "Reloj Arcano"], played(:pause_words)
    assert_equal [["Misiones", true]], played(:pause_focus)
  end

  test "an icon it does not paint falls to the shared reader" do
    assert_equal ["Algo", t(:m2_exit)], played(:pause_others)
  end

  test "the trainer line says what is still owed, as the menu paints it" do
    assert_includes played(:debt_due)[0], "Deuda: 1000$"
    assert_includes played(:debt_due)[1], "Deuda: 1$"
  end

  test "no debt is said once paid, once cleared or before it starts" do
    (played(:debt_paid) + [played(:debt_cleared), played(:debt_not_yet)]).each { |line| refute_includes line, "Deuda" }
  end

  test "a quest's mark goes by the exact colour its name is painted in" do
    assert_equal [t(:edas_quest_blue), t(:edas_quest_red), t(:edas_quest_green), nil, nil], played(:quest_marks)
    assert_nil played(:quest_plain)
  end

  test "a quest's row says its mark" do
    assert_includes played(:quest_row), t(:edas_quest_red)
  end

  test "a quest's detail says no page: the sprite named pager is a separator" do
    assert_equal [nil, "Detalle"], played(:quest_page)
  end

  test "the PC says each stat's star among the full details, in the panel's order" do
    list = ["#{t(:st_hp)} #{t(:iv_star_perfect)}", "#{t(:st_atk)} #{t(:iv_star_high)}", "#{t(:st_def)} #{t(:iv_star_low)}",
            "#{t(:st_spatk)} #{t(:iv_star_low)}", "#{t(:st_spdef)} #{t(:iv_star_empty)}", "#{t(:st_speed)} #{t(:iv_star_low)}"]
    assert_equal [t(:iv_stars, :list => list.join(", ")), :full], played(:stars)
  end

  test "a boss's box draws no level, the player's and a partner's do, and off a boss battle all do" do
    assert_equal [nil, 40, 50], played(:boss_level)
    assert_equal 70, played(:boss_off)
  end

  test "the rhythm game opens with what it is and how it goes, queued" do
    assert_equal [["#{t(:edas_idol_title)}. #{t(:edas_idol_hint)}", false]], played(:idol_open)
  end

  test "each arrow sounds toward its direction a fifth of a second before coming within reach, once" do
    assert_equal [[], [chime(8)], [], [chime(4)], []], played(:idol_chimes)
  end

  test "arrows due together sound in the song's order, each once" do
    assert_equal [[chime(6), chime(2)], []], played(:idol_together)
  end

  test "a note already struck, one past its reach and one the song names no arrow for are skipped" do
    assert_equal [[chime(4)]], played(:idol_hit)
    assert_equal [[chime(4)]], played(:idol_past_reach)
    assert_equal [[chime(4)]], played(:idol_unknown)
  end

  test "a note behind the last one sounded stays quiet" do
    assert_equal [[chime(4)], []], played(:idol_behind)
  end

  test "with the minigames' sounds off the arrow is the word, cutting in" do
    assert_equal [[[t(:dir_up), true]], []], played(:idol_word)
  end

  test "no arrow sounds outside the game's loop" do
    assert_equal [], played(:idol_after_loop)
  end
end
