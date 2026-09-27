# Royal's own minigame and menus, gamedata pass: the jump rope's tick, counter and end; the Internet date check's
# notice; the tip-card menu's focus on the way back from a group. The stand-ins come before the profile files load.
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

# Plays a rope game frame by frame in the game's order (the rope, then the jump read from that frame's input) for a
# player who presses `late` frames after the input read that follows each tick. The game starts at speed 4 and here
# takes `vel` at the first pass, where it speeds up itself. Answers the ticks' leads over their passes, the jumps
# counted and whether the game ended.
def jump_rope_run(vel, gap, late, frames = 700)
  play = JumpMinigame::Play.new(4, gap)
  log = []
  leads = []
  press = nil
  tick = nil
  orig = Audio.method(:se_play)
  begin
    Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
    frames.times do |frame|
      log.clear
      before = play.instance_variable_get(:@timesJ)
      play.drawRope
      passed = play.instance_variable_get(:@timesJ) > before
      over = play.instance_variable_get(:@over)
      play.instance_variable_set(:@comba_vel, vel) if passed
      leads.push(frame - tick) if tick && (passed || over)
      tick = nil if passed || over
      unless log.empty?
        tick = frame
        press = frame + 1 + late
      end
      play.pkmnJump(frame == press)
      break if over
    end
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end
  [leads, play.instance_variable_get(:@timesJ), play.instance_variable_get(:@over)]
end

def obtenerFechaInternetConMensaje; [1, 26, 2026]; end

class TipMenu_Scene
  def initialize(elementos); @elementos = elementos; @index = 0; end
  def pbRedrawList; :redrawn; end
  def pbSelectElement; yield if block_given?; :selected; end
end

def pbShowTipCardsGrouped(*_groups); :shown; end

%w[comba internet_date tip_menu].each do |f|
  load File.expand_path("../../../games/royal/#{f}.rb", File.dirname(__FILE__))
end

Suite.define("royal jump rope: a tick as the jump that clears the rope can start, for each Pokemon and speed") do
  eq "the hook keeps the rope's own value", JumpMinigame::Play.new.drawRope, :drawn
  eq "a Pokemon 48 pixels below the rope's top is up 20 frames",
     PokeAccess::RoyalJumpRope.airtime(JumpMinigame::Play.new(4, 48)), 20
  eq "one 90 below, 38", PokeAccess::RoyalJumpRope.airtime(JumpMinigame::Play.new(4, 90)), 38
  eq "and one taller than the gap never leaves the ground", PokeAccess::RoyalJumpRope.airtime(JumpMinigame::Play.new(4, -6)), 1
  [[48, [4, 8, 12]], [90, [4, 6]]].each do |gap, speeds|
    n = PokeAccess::RoyalJumpRope.airtime(JumpMinigame::Play.new(4, gap))
    speeds.each do |vel|
      [0, n / 2, n - 2].each do |late|
        leads, jumps, over = jump_rope_run(vel, gap, late)
        truthy "gap #{gap}, speed #{vel}: a jump #{late} frames after each tick clears every pass (#{jumps})",
               !over && jumps >= 8
        eq "gap #{gap}, speed #{vel}: each tick #{n} frames ahead of its pass", leads.uniq, [n]
      end
      _leads, jumps, over = jump_rope_run(vel, gap, n - 1)
      truthy "gap #{gap}, speed #{vel}: one #{n - 1} frames after lands before the rope passes", over && jumps == 0
    end
  end
  play = JumpMinigame::Play.new
  200.times { play.drawRope }
  truthy "a pass with the Pokemon on the ground ends the game", play.instance_variable_get(:@over)
  log = []
  orig = Audio.method(:se_play)
  begin
    Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
    50.times { play.drawRope }
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end
  eq "and no tick follows", log, []
end

Suite.define("royal jump rope: the counter, 'faster' and the end as the game paints them") do
  play = JumpMinigame::Play.new
  SpeakCapture.clear
  eq "the hook keeps the points' own value", play.drawPoints, :points
  silent "no jump yet, nothing to say"
  play.instance_variable_set(:@timesJ, 1)
  play.drawPoints
  play.drawPoints
  eq "the counter once when it moves", SpeakCapture.lines, ["1 salto"]
  play.instance_variable_set(:@timesJ, 5)
  SpeakCapture.clear
  play.drawPoints
  eq "with the 'faster' the game paints every 5 jumps up to 10", SpeakCapture.lines, ["5 saltos. ¡Más rápido!"]
  play.instance_variable_set(:@timesJ, 7)
  SpeakCapture.clear
  play.drawPoints
  eq "and without it in between", SpeakCapture.lines, ["7 saltos"]
  SpeakCapture.clear
  play.checkOver
  silent "the end check says nothing while the game goes on"
  play.instance_variable_set(:@over, true)
  with_intl("saltos" => "jumps", "¡Se acabó!" => "Finish!") do
    SpeakCapture.clear
    eq "the end check keeps its own value", play.checkOver, :checked
    eq "the end over the final count, in the build's words", SpeakCapture.lines, ["Finish! 7 jumps"]
  end
  play.instance_variable_set(:@timesJ, 8)
  SpeakCapture.clear
  play.drawPoints
  silent "and nothing after it"
end

Suite.define("royal Internet date check: its notice is said as the check starts") do
  with_intl("Conectándose a Internet para verificar la fecha..." => "Connecting to the Internet to verify the date...") do
    SpeakCapture.clear
    eq "the check keeps its own result", obtenerFechaInternetConMensaje, [1, 26, 2026]
    eq "the notice, as the build paints it", SpeakCapture.lines, ["Connecting to the Internet to verify the date..."]
  end
end

Suite.define("royal tip menu: the focused group, and again on the way back from it") do
  had = Settings.const_defined?(:TIP_CARDS_GROUPS)
  Settings.const_set(:TIP_CARDS_GROUPS, { :BASICS => { :Title => "Lo básico" }, :SHINY => { :Title => "Variocolor" } }) unless had
  begin
    menu = TipMenu_Scene.new([:BASICS, :SHINY])
    SpeakCapture.clear
    eq "the hook keeps the list's own value", menu.pbRedrawList, :redrawn
    menu.pbRedrawList
    eq "a group by its title, once while the cursor stays", SpeakCapture.lines, ["Lo básico"]
    menu.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    menu.pbRedrawList
    eq "the next one on moving", SpeakCapture.lines, ["Variocolor"]
    SpeakCapture.clear
    ret = menu.pbSelectElement { pbShowTipCardsGrouped(:SHINY, :no_top => true) }
    eq "the menu's loop keeps its own value", ret, :selected
    eq "a group closing says the focused title again, which the menu does not repaint", SpeakCapture.lines,
       ["Variocolor"]
    SpeakCapture.clear
    eq "the group keeps its own value", pbShowTipCardsGrouped(:SHINY), :shown
    silent "and one shown with no menu open brings nothing back"
  ensure
    Settings.send(:remove_const, :TIP_CARDS_GROUPS) unless had
  end
end
