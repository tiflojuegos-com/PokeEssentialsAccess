# Royal's own minigame and menus, gamedata pass: the jump rope's tick, counter and end; the Internet date check's
# notice; the tip-card menu's focused group, said again on the way back from it.

module JumpMinigame
  # The game's rope, jump and points steps without the drawing, on a 384-pixel screen: each frame moves @storeMove by
  # the speed through the four phases, and the pass (the end of phase 2) counts a jump while the Pokemon is in the
  # air, else ends the game; a jump raises the sprite 5 pixels a frame until its head (the row hPkmn finds, here the
  # "bitmap" itself) passes the rope's top, then drops it back to the ground (@storeH), gap pixels below that.
  class Play
    YRopeT = 208
    HEAD = 20

    attr_accessor :jump

    def initialize(vel = 4, gap = 48)
      @comba_vel = vel
      @storeMove = 1
      @rot = 0
      @top = 60
      @bot = 63
      @timesJ = 0
      @over = false
      @jump = @jumped = @fall = false
      @storeBm = HEAD
      @storeH = YRopeT - HEAD + gap
      @y = @storeH
    end

    def hPkmn(bitmap, _bottom = false); bitmap; end

    def drawRope
      return :drawn if @over && @rot == 3
      (@rot == 0 || @rot == 2) ? @storeMove += @comba_vel : @storeMove -= @comba_vel
      if ((@rot == 1 || @rot == 3) && @storeMove < 0) || (@rot == 0 && @storeMove > @top) ||
         (@rot == 2 && @storeMove > @bot)
        @storeMove = (@rot == 0) ? @top : ((@rot == 2) ? @bot : 0)
        (@jump ? @timesJ += 1 : @over = true) if @rot == 2
        @rot = (@rot + 1) % 4
      end
      :drawn
    end

    def pkmnJump(pressed)
      @jump = @jumped = true if pressed && !@jumped
      return unless @jump
      if @y < YRopeT - hPkmn(@storeBm)
        @y = YRopeT - hPkmn(@storeBm)
        @fall = true
      end
      @fall ? @y += 5 : @y -= 5
      @y, @jump, @fall, @jumped = @storeH, false, false, false if @y > @storeH
    end

    def drawPoints(_terminar = false); :points; end
    def checkOver; :checked; end
  end
end

# The game's date check over the Internet: answers the date it got and, to show when the notice came, what had been
# said by the time it ran.
def obtenerFechaInternetConMensaje; [[1, 26, 2026], SpeakCapture.log.dup]; end

# The tip-card menu: the groups seen (@elementos) under the cursor (@index); its selection loop runs the group it
# opens, which the block stands for.
class TipMenu_Scene
  def initialize(elementos); @elementos = elementos; @index = 0; end
  def pbRedrawList; :redrawn; end
  def pbSelectElement; yield if block_given?; :selected; end
end

# The game's view of one group's tip cards.
def pbShowTipCardsGrouped(*_groups); :shown; end

[%w[royal comba], %w[royal internet_date], %w[royal_common tip_menu]].each do |dir, name|
  path = File.join(Harness::ROOT, "games", dir, "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RoyalMinigamesGdTest < PokeAccessTest
  Rope = PokeAccess::RoyalJumpRope
  GROUPS = { :BASICS => { :Title => "Lo básico" }, :SHINY => { :Title => "Variocolor" }, :BLANK => {} }

  test "works out a Pokemon's time in the air as long as the game keeps it jumping" do
    wrong = (-12..120).map { |gap| [gap, Rope.airtime(JumpMinigame::Play.new(4, gap)), frames_in_air(gap)] }
    assert_equal [], wrong.reject { |_gap, said, played| said == played }.first(5), "[gap, airtime, frames played]"
  end

  test "works out the time in the air once per game, measuring the sprite once" do
    play = JumpMinigame::Play.new(4, 48)
    measured = 0
    play.define_singleton_method(:hPkmn) do |bitmap, _bottom = false|
      measured += 1
      bitmap
    end
    assert_equal [20, 20, 1], [Rope.airtime(play), Rope.airtime(play), measured]
  end

  test "counts the frames to the rope's next pass as the game draws them, from every phase at speeds 1 to 13" do
    wrong = []
    phases = []
    (1..13).each do |vel|
      play = JumpMinigame::Play.new(vel)
      play.jump = true
      150.times do
        state = [vel, play.instance_variable_get(:@rot), play.instance_variable_get(:@storeMove)]
        phases.push(state[1])
        counted = Rope.frames_to_pass(play)
        drawn = frames_drawn_to_pass(play)
        wrong.push(state + [counted, drawn]) if counted != drawn
        play.drawRope
      end
    end
    assert_equal [0, 1, 2, 3], phases.uniq.sort, "rope phases checked"
    assert_equal [], wrong.first(5), "[speed, phase, rope position, frames counted, frames drawn]"
  end

  test "counts no frames to a pass for a rope with no speed" do
    assert_nil Rope.frames_to_pass(JumpMinigame::Play.new(0))
  end

  test "ticks once per pass, as many frames ahead of it as the Pokemon stays in the air" do
    each_game do |gap, vel, n|
      leads, jumps, _over = rope_game(vel, gap, 0)
      assert_operator jumps, :>=, 8, "gap #{gap}, speed #{vel}: passes cleared"
      assert_equal [n] * jumps, leads, "gap #{gap}, speed #{vel}: each pass's tick, #{n} frames ahead"
    end
  end

  test "lets a jump up to the time in the air less two frames after the tick clear every pass" do
    each_game do |gap, vel, n|
      [0, n / 2, n - 2].each do |late|
        _leads, jumps, over = rope_game(vel, gap, late)
        refute over, "gap #{gap}, speed #{vel}, #{late} frames late: the game goes on"
        assert_operator jumps, :>=, 8, "gap #{gap}, speed #{vel}, #{late} frames late: passes cleared"
      end
    end
  end

  test "ends the game for a jump the time in the air less one frame after the tick, too late for the rope's pass" do
    each_game do |gap, vel, n|
      leads, jumps, over = rope_game(vel, gap, n - 1)
      assert_equal [[n], 0, true], [leads, jumps, over],
                   "gap #{gap}, speed #{vel}: the tick's lead, passes cleared, game over"
    end
  end

  test "ticks no more once the game is over" do
    play = JumpMinigame::Play.new
    play.instance_variable_set(:@over, true)
    played = with_ticks { |log| 100.times { play.drawRope }; log.dup }
    assert_equal [], played
  end

  test "ticks never for a rope with no speed" do
    play = JumpMinigame::Play.new(0)
    played = with_ticks { |log| 100.times { play.drawRope }; log.dup }
    assert_equal [], played
  end

  test "ticks never, and leaves the rope drawn, for a Pokemon whose sprite cannot be measured" do
    play = JumpMinigame::Play.new
    play.define_singleton_method(:hPkmn) { |_bitmap, _bottom = false| raise "disposed bitmap" }
    drawn = []
    played = with_ticks { |log| 100.times { drawn.push(play.drawRope) }; log.dup }
    assert_equal [[], [:drawn]], [played, drawn.uniq]
  end

  test "leaves each hooked call's own value to the game" do
    play = JumpMinigame::Play.new
    menu = TipMenu_Scene.new([:BASICS])
    assert_equal [:drawn, :points, :checked, :redrawn, :selected, :shown],
                 [play.drawRope, play.drawPoints, play.checkOver, menu.pbRedrawList, menu.pbSelectElement,
                  pbShowTipCardsGrouped(:BASICS)]
  end

  test "says the jump counter when it moves, once, and nothing before the first jump" do
    play = JumpMinigame::Play.new
    play.drawPoints
    play.instance_variable_set(:@timesJ, 1)
    play.drawPoints
    play.drawPoints
    assert_equal [["1 salto", true]], SpeakCapture.log
  end

  test "adds the game's 'faster' every 5 jumps up to 10, then every 10" do
    play = JumpMinigame::Play.new
    { 4 => "4 saltos", 5 => "5 saltos. ¡Más rápido!", 6 => "6 saltos", 10 => "10 saltos. ¡Más rápido!",
      11 => "11 saltos", 15 => "15 saltos", 20 => "20 saltos. ¡Más rápido!", 25 => "25 saltos",
      30 => "30 saltos. ¡Más rápido!" }.each do |jumps, said|
      SpeakCapture.clear
      play.instance_variable_set(:@timesJ, jumps)
      play.drawPoints
      assert_equal [said], SpeakCapture.lines, "#{jumps} jumps"
    end
  end

  test "says the end over the final count as the build paints it" do
    english = { "salto" => "jump", "saltos" => "jumps", "¡Se acabó!" => "Finish!" }
    [[7, {}, "¡Se acabó! 7 saltos"], [1, {}, "¡Se acabó! 1 salto"], [7, english, "Finish! 7 jumps"],
     [1, english, "Finish! 1 jump"]].each do |jumps, words, said|
      play = JumpMinigame::Play.new
      play.instance_variable_set(:@timesJ, jumps)
      play.instance_variable_set(:@over, true)
      SpeakCapture.clear
      with_intl(words) { play.checkOver }
      assert_equal [[said, true]], SpeakCapture.log, "#{jumps} jumps, #{words.empty? ? 'Spanish' : 'English'} build"
    end
  end

  test "says nothing at the end check while the game goes on" do
    play = JumpMinigame::Play.new
    play.instance_variable_set(:@timesJ, 3)
    play.checkOver
    assert_nothing_spoken
  end

  test "says no count once the game is over" do
    play = JumpMinigame::Play.new
    play.instance_variable_set(:@over, true)
    play.instance_variable_set(:@timesJ, 8)
    play.drawPoints
    assert_nothing_spoken
  end

  test "says the Internet date notice as the build paints it, before the check runs" do
    english = { "Conectándose a Internet para verificar la fecha..." => "Connecting to the Internet to verify the date..." }
    { {} => "Conectándose a Internet para verificar la fecha...",
      english => "Connecting to the Internet to verify the date..." }.each do |words, notice|
      SpeakCapture.clear
      answer = with_intl(words) { obtenerFechaInternetConMensaje }
      assert_equal [[1, 26, 2026], [[notice, true]]], answer, "the date the check got, and what was said as it ran"
    end
  end

  test "says the focused group's title, once while the cursor stays" do
    with_tip_groups(GROUPS) do
      menu = TipMenu_Scene.new([:BASICS, :SHINY])
      menu.pbRedrawList
      menu.pbRedrawList
      assert_equal [["Lo básico", true]], SpeakCapture.log
    end
  end

  test "says the next group's title as the cursor moves" do
    with_tip_groups(GROUPS) do
      menu = TipMenu_Scene.new([:BASICS, :SHINY])
      menu.pbRedrawList
      menu.instance_variable_set(:@index, 1)
      SpeakCapture.clear
      menu.pbRedrawList
      assert_equal [["Variocolor", true]], SpeakCapture.log
    end
  end

  test "says a group's title through the game's _INTL, as the build translates it" do
    with_tip_groups(GROUPS) do
      with_intl("Lo básico" => "The basics") { TipMenu_Scene.new([:BASICS]).pbRedrawList }
      assert_equal ["The basics"], SpeakCapture.lines
    end
  end

  test "says nothing for a group it cannot name" do
    { "a group with no title" => [GROUPS, [:BLANK], 0], "a group the game does not list" => [GROUPS, [:GONE], 0],
      "no groups in the game" => [nil, [:BASICS], 0], "no cursor" => [GROUPS, [:BASICS], nil],
      "no list of groups" => [GROUPS, nil, 0] }.each do |what, (groups, elementos, index)|
      SpeakCapture.clear
      menu = TipMenu_Scene.new(elementos)
      menu.instance_variable_set(:@index, index)
      with_tip_groups(groups) { menu.pbRedrawList }
      assert_nothing_spoken what
    end
  end

  test "says the focused title again on the way back from a group the menu opened" do
    with_tip_groups(GROUPS) do
      menu = TipMenu_Scene.new([:BASICS, :SHINY])
      menu.instance_variable_set(:@index, 1)
      menu.pbRedrawList
      SpeakCapture.clear
      menu.pbSelectElement { pbShowTipCardsGrouped(:SHINY) }
      assert_equal [["Variocolor", true]], SpeakCapture.log
    end
  end

  test "brings nothing back for a group shown with no menu open" do
    with_tip_groups(GROUPS) do
      pbShowTipCardsGrouped(:BASICS)
      assert_nothing_spoken
    end
  end

  test "brings nothing back for a group shown after the menu's loop has ended" do
    with_tip_groups(GROUPS) do
      menu = TipMenu_Scene.new([:BASICS])
      menu.pbRedrawList
      menu.pbSelectElement
      SpeakCapture.clear
      pbShowTipCardsGrouped(:BASICS)
      assert_nothing_spoken
    end
  end

  test "lets the menu go when its loop ends in an error" do
    with_tip_groups(GROUPS) do
      menu = TipMenu_Scene.new([:BASICS])
      menu.pbRedrawList
      assert_raises(RuntimeError) { menu.pbSelectElement { raise "the group failed" } }
      SpeakCapture.clear
      pbShowTipCardsGrouped(:BASICS)
      assert_nothing_spoken
    end
  end

  private

  # Yields each rope game the timing tests play: a gap under the rope, a speed, and the Pokemon's time in the air; the
  # 20-pixel gap at speed 4 keeps the Pokemon up for less than the rope's last phase, where its tick then falls.
  def each_game
    [[20, [4]], [48, [4, 8, 12]], [90, [4, 6]]].each do |gap, speeds|
      n = Rope.airtime(JumpMinigame::Play.new(4, gap))
      speeds.each { |vel| yield gap, vel, n }
    end
  end

  # Frames the game draws from this rope state to the next pass under the Pokemon, played on a copy that jumps
  # throughout (so the pass counts a jump instead of ending the game).
  def frames_drawn_to_pass(play)
    copy = play.dup
    copy.jump = true
    jumps = copy.instance_variable_get(:@timesJ)
    frames = 0
    until copy.instance_variable_get(:@timesJ) > jumps || frames > 1000
      copy.drawRope
      frames += 1
    end
    frames
  end

  # Frames a jump keeps the game's @jump on, played: from the frame it is pressed to the one it lands.
  def frames_in_air(gap)
    play = JumpMinigame::Play.new(4, gap)
    play.pkmnJump(true)
    frames = 1
    while play.jump && frames < 1000
      play.pkmnJump(false)
      frames += 1
    end
    frames
  end

  # Plays a rope game frame by frame in the game's order (the rope, then the jump read from that frame's input), the
  # player pressing `late` frames after the input read that follows each tick. The game starts at speed 4 and takes
  # vel at its first pass, where it speeds up itself. Answers each tick's lead over its pass, the passes cleared and
  # whether the game ended.
  def rope_game(vel, gap, late, frames = 700)
    play = JumpMinigame::Play.new(4, gap)
    leads = []
    press = tick = nil
    with_ticks do |played|
      frames.times do |frame|
        played.clear
        before = play.instance_variable_get(:@timesJ)
        play.drawRope
        passed = play.instance_variable_get(:@timesJ) > before
        over = play.instance_variable_get(:@over)
        play.instance_variable_set(:@comba_vel, vel) if passed
        leads.push(frame - tick) if tick && (passed || over)
        tick = nil if passed || over
        unless played.empty?
          tick = frame
          press = frame + 1 + late
        end
        play.pkmnJump(frame == press)
        break if over
      end
    end
    [leads, play.instance_variable_get(:@timesJ), play.instance_variable_get(:@over)]
  end

  # Runs the block with the sound effects the mod starts (each a minigame tick) collected in the array it yields;
  # answers the block's value.
  def with_ticks
    played = []
    orig = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*a| played.push(a); nil }
    yield played
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end

  # Runs the block with the game's tip groups (Settings::TIP_CARDS_GROUPS) set to groups, or absent for nil; what
  # was there is put back after.
  def with_tip_groups(groups)
    had = Settings.const_defined?(:TIP_CARDS_GROUPS, false)
    was = had ? Settings.const_get(:TIP_CARDS_GROUPS) : nil
    Settings.send(:remove_const, :TIP_CARDS_GROUPS) if had
    Settings.const_set(:TIP_CARDS_GROUPS, groups) if groups
    yield
  ensure
    Settings.send(:remove_const, :TIP_CARDS_GROUPS) if Settings.const_defined?(:TIP_CARDS_GROUPS, false)
    Settings.const_set(:TIP_CARDS_GROUPS, was) if had
  end
end
