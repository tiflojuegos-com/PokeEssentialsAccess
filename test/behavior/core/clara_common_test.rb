# What Clara Dragon's games share (games/clara_common) over doubles with the shape of their scripts: the fishing
# minigame's chime and bars, the arcane clock's gems and what the summary adds to its stock pages. In a process of its
# own, since its overrides of the summary would reach every other test here.
class ClaraCommonTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The size of the ring at the middle of its best band, as 0217_Fishing3H sets it.
    RADIUS_MAX_PERFECT = 240

    # The extra buttons their PSystem_Controls adds.
    module Input
      E = 30
      F = 31
    end

    RingPicture = Struct.new(:bitmap, :zoom_x)
    RingBitmap = Struct.new(:width)

    # The life bar: all it paints is its name and a gauge.
    class LifeBar
      attr_accessor :life, :maxLife

      def initialize(life, name)
        @life = life
        @maxLife = life
        @name = name
      end
    end

    # The ring, shrinking by its speed each frame from twice its picture's width of 240.
    class FishingRing
      attr_accessor :speed

      def initialize(speed)
        @sprite = RingPicture.new(RingBitmap.new(240), 2.0)
        @speed = speed / (@sprite.bitmap.width * 2.0)
      end

      def update; @sprite.zoom_x -= @speed; end
    end

    # The game: update is its modal loop, here over the steps a probe gives it, a frame each.
    class FishingMinigame
      attr_accessor :steps
      attr_reader :ring, :info_seen

      def initialize(speed, life)
        @speed = speed
        @life = life
        @combo = 0
        @sprites = {}
        @steps = []
      end

      def createGraphics
        @sprites["playerBar"] = LifeBar.new(@life, "Jugador")
        @sprites["enemyBar"] = LifeBar.new(@life, "Enemigo")
      end

      def refresh(life, enemyLife)
        @ring = nil
        @sprites["playerBar"].life -= life
        @sprites["enemyBar"].life -= enemyLife
      end

      def update
        @steps.each do |step|
          case step
          when :ring then @ring = FishingRing.new(@speed)
          when :shrink then @ring.update
          when :perfect then (@combo += 1; refresh(1, 3 * @combo))
          when :good then (@combo = 0; refresh(2, 3))
          when :miss then refresh(5, 0)
          when :info_key then @info_seen = PokeAccess::Info.info_text
          end
          PokeAccess::Frame.run_pollers
        end
      end
    end

    # The clock: entries [picture, label, function], the picture blank while the gem is missing.
    class ItemsM
      attr_accessor :selected_item

      def initialize(items)
        @items = items
        @selected_item = 0
      end

      def redrawSelector; end
      def pbEndScene; end
    end

    def drawFormattedTextEx2(_bitmap, _x, _y, _width, _height, _text, _base = nil, _shadow = nil, _outline = true); end

    # The Hidden Power by the IVs, as the information page asks for it; a first IV of -1 stands for one it cannot work out.
    def pbHiddenPower(iv)
      raise ArgumentError, "no hidden power" if iv[0] == -1
      [iv[0] > 15 ? 10 : (iv[0] == -2 ? 99 : 11), 60]
    end

    # The stats page paints the hint to the information page beside its column of EVs, and the page's C opens it.
    class PokemonSummaryScene
      def drawPageThree(pk = nil)
        (@pokemon = pk) if pk
        drawFormattedTextEx2(nil, 238, 316, 276, 0, "Pulsa C o Espacio para ver mas información.")
      end

      def drawInfoPage(pokemon)
        drawFormattedTextEx2(nil, 238, 124, 276, 0, "La descripción de la habilidad de #{pokemon.name}")
        :info_closed
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    # A game with its graphics built, about to run these steps.
    def fishing(steps = [])
      game = FishingMinigame.new(25.0, 20)
      game.createGraphics
      game.steps = steps
      game
    end

    # The sounds of each batch of frames a game runs through, one after the other.
    def chimes(batches)
      game = fishing
      batches.map do |steps|
        game.steps = steps
        cues { game.update }
      end
    end

    # The frame of a new ring its chime sounds on, at this best size.
    def chime_frame(best)
      was = Object.send(:remove_const, :RADIUS_MAX_PERFECT)
      Object.const_set(:RADIUS_MAX_PERFECT, best) if best
      game = fishing([:ring])
      game.update
      (1..40).find do
        game.steps = [:shrink]
        !cues { game.update }.empty?
      end
    ensure
      Object.send(:remove_const, :RADIUS_MAX_PERFECT) if best
      Object.const_set(:RADIUS_MAX_PERFECT, was)
    end

    def fish_play
      probe(:fish_open) do
        game = FishingMinigame.new(25.0, 20)
        [said { game.createGraphics }, PokeAccess::Info.info_text]
      end
      probe(:fish_open_brief) do
        was = PokeAccess::Config.verbosity
        PokeAccess::Config.verbosity = :brief
        begin
          said { FishingMinigame.new(25.0, 20).createGraphics }
        ensure
          PokeAccess::Config.verbosity = was
        end
      end
      probe(:fish_chime) { chimes([[:ring] + [:shrink] * 11, [:shrink], [:shrink] * 20, [:miss, :ring] + [:shrink] * 12]) }
      probe(:fish_chime_frames) { [chime_frame(240), chime_frame(300), chime_frame(nil)] }
      probe(:fish_word) do
        PokeAccess::Config.sound_minigame = false
        game = fishing([:ring] + [:shrink] * 12)
        lines = nil
        sounds = cues { lines = said { game.update } }
        PokeAccess::Config.sound_minigame = true
        [lines, sounds]
      end
      probe(:fish_after_loop) do
        game = fishing([:ring])
        game.update
        game.ring.instance_variable_get(:@sprite).zoom_x = 1.0
        cues { PokeAccess::Frame.run_pollers }
      end
      probe(:fish_no_game) { cues { PokeAccess::Frame.run_pollers } }
      probe(:fish_perfect) do
        game = fishing([:ring, :perfect, :info_key])
        [said { game.update }, game.info_seen, PokeAccess::Info.info_text]
      end
      probe(:fish_good) do
        game = fishing([:ring, :perfect, :ring, :good])
        said { game.update }
      end
      probe(:fish_no_bars) { PokeAccess::ClaraFishing.bars(FishingMinigame.new(25.0, 20)) }
      probe(:fish_empty_bar) do
        game = fishing([:ring] + [:miss, :ring] * 4 + [:miss, :ring] + [:miss])
        said { game.update }.last
      end
    end

    def clock_play
      items = [["Joya Verde", "Joya Verde", "openWind"], ["", "Joya Oscura", "openNoJoya"], ["Joya Azul", "Joya Azul", "openWater"]]
      menu = ItemsM.new(items)
      probe(:clock_first) { said { menu.redrawSelector } }
      probe(:clock_again) { said { menu.redrawSelector } }
      probe(:clock_empty_gem) do
        menu.selected_item = 1
        said { menu.redrawSelector }
      end
      probe(:clock_past_the_end) do
        menu.selected_item = 3
        said { menu.redrawSelector }
      end
      probe(:clock_no_items) { said { ItemsM.new(nil).redrawSelector } }
      probe(:clock_info) do
        open = ItemsM.new(items)
        open.redrawSelector
        kept = PokeAccess::Info.info_text
        open.pbEndScene
        [kept, PokeAccess::Info.info_text]
      end
    end

    # A Pokemon with its EVs and IVs in the order the game keeps them: HP, Attack, Defense, Speed, Sp. Atk, Sp. Def.
    def mon(opts = {})
      TestPoke.build({ :name => "Bulby", :happiness => 88, :ev => [4, 252, 0, 6, 1, 247], :iv => [31, 2, 3, 4, 5, 6] }.merge(opts))
    end

    def summary_play
      probe(:ability_line) { PokeAccess::Summary.ability_line(mon) }
      probe(:hidden_power_type) { [PokeAccess::Data.type_name(10), PokeAccess::Data.type_name(11)] }
      probe(:sheet_hearts) do
        [0, 43, 44, 88, 131, 132, 220, 255].map { |n| PokeAccess::ClaraSummary.friendship(mon(:happiness => n)) }
      end
      probe(:sheet) { PokeAccess::Info.summary_text(mon) }
      probe(:sheet_egg) do
        egg = mon
        egg.define_singleton_method(:isEgg?) { true }
        PokeAccess::ClaraSummary.friendship(egg)
      end
      probe(:sheet_no_friendship) do
        pk = mon
        pk.define_singleton_method(:happiness) { raise ArgumentError, "no happiness" }
        [PokeAccess::ClaraSummary.friendship(pk), PokeAccess::Info.summary_text(pk).nil?]
      end
      probe(:sheet_nobody) { PokeAccess::Info.summary_text(nil) }
      probe(:stats) { PokeAccess::SummaryGen6.stats_text(mon) }
      probe(:stats_page) do
        scene = PokemonSummaryScene.new(mon)
        said { scene.drawPageThree(mon) }
      end
      probe(:info_page) do
        scene = PokemonSummaryScene.new(mon)
        pk = mon
        ret = nil
        lines = said { ret = scene.drawInfoPage(pk) }
        [lines, ret]
      end
      probe(:info_page_other_power) { said { PokemonSummaryScene.new(mon).drawInfoPage(mon(:iv => [1, 2, 3, 4, 5, 6])) } }
      probe(:info_page_no_power) { said { PokemonSummaryScene.new(mon).drawInfoPage(mon(:iv => [-1, 2, 3, 4, 5, 6])) } }
      probe(:info_page_unnamed_power) do
        names = PokeAccess::Data.method(:type_name)
        begin
          [nil, ""].map do |name|
            PokeAccess::Data.define_singleton_method(:type_name) { |_id| name }
            said { PokemonSummaryScene.new(mon).drawInfoPage(mon(:iv => [-2, 2, 3, 4, 5, 6])) }
          end
        ensure
          PokeAccess::Data.define_singleton_method(:type_name, names)
        end
      end
      probe(:info_page_nothing) { said { PokemonSummaryScene.new(mon).drawInfoPage(mon(:iv => [-1, 2, 3, 4, 5, 6], :ability => 0)) } }
      probe(:back_from_info) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        first = said { scene.drawPageThree(pk) }
        repeat = said { scene.drawPageThree(pk) }
        scene.drawInfoPage(pk)
        back = said { scene.drawPageThree(pk) }
        [first.map { |text, _interrupt| text } == back.map { |text, _interrupt| text }, first.length, back[0][1], repeat]
      end
    end

    fish_play
    clock_play
    summary_play
  RUBY

  profile "clara_common", WORLD, PLAY

  # The guide's flat chime toward d at the minigames' volume.
  def chime(d)
    file, pitch = PokeAccess::Sound::Catalog::GUIDE_FLAT[d]
    [file, PokeAccess::Sound::Mixer.volume(:minigame), (pitch * PokeAccess::Sound::Mixer.flat_factor(:guide)).round]
  end

  test "loads whole, its files and every plugin, and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    refute_includes played(:absent_functions), "drawFormattedTextEx2"
  end

  test "the fishing game opens with what it is and the key, queued, and the info key holds the bars" do
    title = "#{t(:clara_fish_title)}. #{t(:clara_fish_hint, :key => 'C')}"
    assert_equal [[[title, false]], "Enemigo: 20 de 20, Jugador: 20 de 20"], played(:fish_open)
  end

  test "with key hints off it opens with what it is alone" do
    assert_equal [[t(:clara_fish_title), false]], played(:fish_open_brief)
  end

  test "a ring chimes once, a fifth of a second ahead of the middle of its best band, and each new ring again" do
    assert_equal [[], [chime(8)], [], [chime(8)]], played(:fish_chime)
  end

  test "the chime goes by the game's best size, and by the stock one should the game lack it" do
    assert_equal [12, 7, 12], played(:fish_chime_frames)
  end

  test "with the minigames' sounds off the chime is the word, cutting in" do
    assert_equal [[[t(:clara_fish_now), true]], []], played(:fish_word)
  end

  test "no chime sounds outside the game's loop, a ring still up or none held" do
    assert_equal [[], []], [played(:fish_after_loop), played(:fish_no_game)]
  end

  test "a strike says the two bars and the combo, cutting in, and the info key holds them until the game ends" do
    line = "Enemigo: 17 de 20, Jugador: 19 de 20, #{t(:clara_fish_combo, :n => 1)}"
    assert_equal [[[line, true]], line, nil], played(:fish_perfect)
  end

  test "a combo broken is no longer said" do
    assert_equal ["Enemigo: 17 de 20, Jugador: 19 de 20, #{t(:clara_fish_combo, :n => 1)}", "Enemigo: 14 de 20, Jugador: 17 de 20"],
                 played(:fish_good).map { |text, _interrupt| text }
  end

  test "a bar past its end is said empty" do
    assert_equal ["Enemigo: 20 de 20, Jugador: 0 de 20", true], played(:fish_empty_bar)
  end

  test "a game with no bars yet has none to say" do
    assert_equal "", played(:fish_no_bars)
  end

  test "the info key keeps the gem under the selector until the clock closes" do
    kept, after = played(:clock_info)
    assert_equal PokeAccess::Verbosity.list_entry("Joya Verde", 1, 3), kept
    refute_equal kept, after
  end

  test "the clock says the first gem queued, by its label and place" do
    assert_equal [[PokeAccess::Verbosity.list_entry("Joya Verde", 1, 3), false]], played(:clock_first)
  end

  test "the clock keeps quiet on a redraw that moved nothing" do
    assert_equal [], played(:clock_again)
  end

  test "a missing gem is said as such, cutting in as the selector moves" do
    assert_equal [[PokeAccess::Verbosity.list_entry(t(:clara_gem_empty, :name => "Joya Oscura"), 2, 3), true]], played(:clock_empty_gem)
  end

  test "the clock keeps quiet with no entry under the selector or no entries at all" do
    assert_equal [[], []], [played(:clock_past_the_end), played(:clock_no_items)]
  end

  test "the friendship is the hearts the sheet paints, one per 44 of happiness" do
    want = [0, 0, 1, 2, 2, 3, 5, 5].map { |n| t(:mui_happiness_value, :n => n, :max => 5) }
    assert_equal want, played(:sheet_hearts)
  end

  test "the sheet ends with the hearts" do
    assert played(:sheet).end_with?(" #{t(:mui_happiness_value, :n => 2, :max => 5)}"), played(:sheet)
  end

  test "an egg has no hearts" do
    assert_nil played(:sheet_egg)
  end

  test "a friendship that cannot be read leaves the sheet as it was" do
    assert_equal [nil, false], played(:sheet_no_friendship)
    assert_nil played(:sheet_nobody)
  end

  test "the stats say the EV column in its rows' order, not the order the game keeps them in" do
    list = "#{t(:st_hp)} 4, #{t(:st_atk)} 252, #{t(:st_def)} 0, #{t(:st_spatk)} 1, #{t(:st_spdef)} 247, #{t(:st_speed)} 6"
    assert_includes played(:stats), t(:clara_evs, :list => list)
  end

  test "the stats page says the hint it paints with its own text function" do
    text = played(:stats_page).map { |line, _interrupt| line }.join(" ")
    assert_includes text, "Pulsa C o Espacio para ver mas información."
    assert_includes text, t(:clara_evs, :list => "#{t(:st_hp)} 4, #{t(:st_atk)} 252, #{t(:st_def)} 0, #{t(:st_spatk)} 1, #{t(:st_spdef)} 247, #{t(:st_speed)} 6")
  end

  test "the information page says the ability and the Hidden Power its icon shows, cutting in, and runs" do
    power = t(:sm_hidden_power, :t => played(:hidden_power_type)[0])
    refute_nil played(:ability_line)
    assert_equal [[[PokeAccess.sentences([played(:ability_line), power]), true]], :info_closed], played(:info_page)
  end

  test "the Hidden Power goes by the Pokemon's IVs" do
    power = t(:sm_hidden_power, :t => played(:hidden_power_type)[1])
    assert_equal [[PokeAccess.sentences([played(:ability_line), power]), true]], played(:info_page_other_power)
  end

  test "a Hidden Power that cannot be worked out leaves the ability, and with no ability nothing is said" do
    assert_equal [[PokeAccess.sentences([played(:ability_line)]), true]], played(:info_page_no_power)
    assert_equal [[[PokeAccess.sentences([played(:ability_line)]), true]]] * 2, played(:info_page_unnamed_power)
    assert_equal [], played(:info_page_nothing)
  end

  test "back from the information page the stats are said again, cutting in, as they are not on a mere redraw" do
    assert_equal [true, 1, true, []], played(:back_from_info)
  end
end
