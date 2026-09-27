# Anil's punch bag (games/anil/punch_bag.rb): the arrow's closeness to the bar's centre as a tick, and each hit's stars
# with the score window. Gamedata pass; the profile file is loaded once over a stubbed game that moves its arrow.
module AnilPunchBagSpec
  ScoreBox = Struct.new(:text)
  Arrow = Struct.new(:visible)

  # The game's scene as the profile reads it: the score window, the arrow and where it swings, driven by pbMain.
  class Scene
    attr_accessor :moves

    def initialize
      @sprites = { "scorebox" => ScoreBox.new("Puntos: 0 \nGolpe: 0/10"), "arrow" => Arrow.new(true) }
      @arrowXMiddle = 300
      @arrowX = 172
      @moves = []
    end

    def pbMain(_can_cancel)
      @moves.each do |x|
        @arrowX = x
        PokeAccess::Keys.run_frame_pollers
      end
      @sprites["arrow"].visible = false
      @arrowX = 236
      PokeAccess::Keys.run_frame_pollers
      @sprites["scorebox"].text = "Puntos: 4 \nGolpe: 1/10"
      pbDrawStars(4)
      12
    end

    def pbDrawStars(_stars); :stars_drawn; end
  end
end

Suite.define("anil punch bag: a tick sounds higher nearer the centre, and each hit says its stars and the score") do
  t = PokeAccess::I18n
  log = []
  orig = Audio.method(:se_play)
  made = !Object.const_defined?(:PunchBag)
  begin
    Object.const_set(:PunchBag, Module.new) if made
    PunchBag.const_set(:Scene, AnilPunchBagSpec::Scene) unless PunchBag.const_defined?(:Scene)
    unless $pa_anil_punch_bag_loaded
      load File.expand_path("../../../games/anil/punch_bag.rb", File.dirname(__FILE__))
      $pa_anil_punch_bag_loaded = true
    end
    Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
    scene = PunchBag::Scene.new
    scene.moves = [172, 236, 300, 300, 364]
    SpeakCapture.clear
    eq "the game keeps its own score", scene.pbMain(true), 12
    pitches = log.select { |a| a[0].to_s.include?("pa_mg_tick") }.map { |a| a[2] }
    eq "one tick per move of the shown arrow: the far end low, the centre highest, down again past it; none while " \
       "it stands still or is hidden", pitches, [80, 115, 150, 115]
    eq "the score window on entering, queued, then the hit's stars and the score, interrupting", SpeakCapture.log,
       [["Puntos: 0 Golpe: 0/10", false], ["#{t.t(:stars_count, :n => 4)}. Puntos: 4 Golpe: 1/10", true]]
  ensure
    Audio.define_singleton_method(:se_play, orig)
    PokeAccess::AnilPunchBag.release
    Object.send(:remove_const, :PunchBag) if made && Object.const_defined?(:PunchBag)
  end
end
