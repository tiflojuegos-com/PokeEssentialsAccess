module PokeAccess
  # Sevii's Berry Blender (BerryBlender, 0226_Contests #3 Berry Blender.rb), opened from the Pokeblock Kit: a berry
  # picked in the bag, a countdown and a spinning circle that scores a press of the confirm key at 40 degrees (Perfect)
  # or 30 and 50 (Good), the results in two painted pages, and the block made said in a message. Its pictures say
  # nothing, so the blender is named as its countdown starts, the circle's way to 40 degrees is played as the
  # minigame's tick rising to its highest there, and each results page is said as it paints.
  module SeviiBerryBlender
    # The minigame tick's height at each angle the circle plays one: rising to the Perfect angle, Good past it.
    TICKS = { 10 => 0.25, 20 => 0.5, 30 => 0.75, 40 => 1.0, 50 => 0.75 }
    # The game's speed past which the circle turns a STEP every frame, its Perfect angle lasting that one frame: the
    # ticks then sound a step early, so a press on the highest lands on it.
    FAST = 40
    STEP = 10
    # The counts the first results page paints under the Perfect, Good and Miss pictures, in that order, and the
    # player's own the game keeps, for a single player's page, which paints none.
    MARKS = [:sv_bb_perfect, :sv_bb_good, :sv_bb_miss]
    COUNTS = [:@perfect, :@good, :@miss]

    # Names the blender as its first countdown starts, then how to play it while key hints are said.
    def self.counting(scene)
      return if PokeAccess.ivar(scene, :@access_bb_named)
      scene.instance_variable_set(:@access_bb_named, true)
      hint = PokeAccess::I18n.t(:sv_bb_hint, :key => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:sv_bb_title), hint), false)
    end

    # One frame of the spin: plays the tick of the angle the circle has just turned to, a step early when fast.
    def self.spun(scene)
      circle = PokeAccess.sprite(scene, "circle")
      return unless circle
      angle = circle.angle.to_i
      return if angle == PokeAccess.ivar(scene, :@access_bb_angle)
      scene.instance_variable_set(:@access_bb_angle, angle)
      angle += STEP if PokeAccess.ivar_i(scene, :@speed) > FAST
      PokeAccess::Sound.gauge(TICKS[angle]) if TICKS[angle]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A results page as one line per player: on the counts page, the counts after the name labelled by their pictures,
    # the player's own from the game where the page paints none.
    def self.page(scene, pairs, counted)
      lines = PokeAccess::PaintCapture.cells(pairs).map do |cells|
        name = cells.shift
        if counted
          cells = COUNTS.map { |iv| PokeAccess.ivar_i(scene, iv) } if cells.empty?
          cells = (0...cells.length).map { |i| PokeAccess::I18n.t(MARKS[i] || MARKS.last, :n => cells[i]) }
        end
        ([name] + cells).join(", ")
      end
      PokeAccess.sentences(lines)
    end

    # Runs a results page's paint (the block) and says the page: the game paints it every frame until confirm turns it.
    def self.results(scene, counted)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      say_page(scene, pairs, counted)
      ret
    end

    # Says a painted results page when it differs from the page last said: the first of each blend queued, the next
    # cutting in.
    def self.say_page(scene, pairs, counted)
      text = page(scene, pairs, counted)
      PokeAccess::Cursor.announce(scene, :sv_bb_results, text, true, false) { text } unless text.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("sevii") do
  before("BerryBlender", :annoucement) { |s, _a| PokeAccess::SeviiBerryBlender.counting(s) }
  before("BerryBlender", :choice_berry) { |s, _a| PokeAccess::Cursor.reset(s, :sv_bb_results) }
  around("BerryBlender", :play) do |s, nxt, _a|
    ret = nxt.call
    PokeAccess::SeviiBerryBlender.spun(s)
    ret
  end
  around("BerryBlender", :draw_result_one) { |s, nxt, _a| PokeAccess::SeviiBerryBlender.results(s, true) { nxt.call } }
  around("BerryBlender", :draw_for_first_result) do |s, nxt, _a|
    PokeAccess::SeviiBerryBlender.results(s, true) { nxt.call }
  end
  around("BerryBlender", :redraw_result_one) { |s, nxt, _a| PokeAccess::SeviiBerryBlender.results(s, false) { nxt.call } }
  around("BerryBlender", :draw_for_second_result) do |s, nxt, _a|
    PokeAccess::SeviiBerryBlender.results(s, false) { nxt.call }
  end
end
