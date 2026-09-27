# Realidea's Hall of Fame PC viewer entered through its own selection loop, with the gen-6 BW plugin
# (plugins/hall_of_fame_bw_gen6.rb) and the profile's games/realidea/hall_of_fame.rb bound to it as in the game: the
# accept key stands for a click on the front entrant and back for one on the cancel button, only while the loop runs.
# Neither the scene nor the mouse exists when this engine's harness loads the plugin, so it is evaluated once more
# after the stand-ins below; the profile file loads here for the first time.

# The game's mouse (Raton), which never clicks here: on an object, or on an area.
class Game_Mouse
  def leftClick?(_object = nil, _width = nil, _height = nil); false; end
  def inAreaLeft?(_x, _y, _w, _h); false; end
end

# Realidea's BW Hall of Fame (0319), down to the PC viewer's selection loop: with no record picked, left or a click on
# the left arrow shows the previous record and right or the right arrow the next (with more than one saved), a click
# on the cancel button leaves, and a click on an entrant picks the record (selectPokePC writes the front entrant's
# card); with one picked, back puts it down and a click on an entrant moves to it.
class HallOfFameScene
  def writePokemonDataPC(_pokemon, _hallNumber = -1); end

  def selectPokePC; writePokemonDataPC(@hallEntry[0]); end

  def pbPCSelection
    loop do
      Graphics.update
      Input.update
      if @selectedrecord
        @selectedrecord = false if Input.trigger?(Input::B)
        (0...@hallEntry.size).each do |i|
          selectPokePC if $mouse.inAreaLeft?(@positions[i][0] - 48, @positions[i][1] - 48, 96, 96)
        end
      else
        records = $PokemonGlobal.hallOfFame
        if records.size > 1 && (Input.trigger?(Input::LEFT) || $mouse.leftClick?(@sprites["arrowleft"]))
          @hallIndex = (@hallIndex - 1) % records.size
          @hallEntry = records[@hallIndex]
        elsif records.size > 1 && (Input.trigger?(Input::RIGHT) || $mouse.leftClick?(@sprites["arrowright"]))
          @hallIndex = (@hallIndex + 1) % records.size
          @hallEntry = records[@hallIndex]
        elsif $mouse.leftClick?(@sprites["cancelbuttom"])
          break
        end
        (0...@hallEntry.size).each do |i|
          next unless $mouse.inAreaLeft?(@positions[i][0] - 48, @positions[i][1] - 48, 96, 96)
          selectPokePC
          @selectedrecord = true
        end
      end
    end
  end
end

eval(File.read(File.join(Harness::ROOT, "plugins", "hall_of_fame_bw_gen6.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "plugins", "hall_of_fame_bw_gen6.rb"))
require File.expand_path("../../../games/realidea/hall_of_fame", File.dirname(__FILE__))

# Frame by frame, the keys a script holds for Input.trigger?: each Graphics.update moves to the next frame, and a
# script that runs out stops the run, as a player who walks away would.
module ReaHofFrames
  @frames = []
  @keys = []
  def self.held?(k); @keys.include?(k); end

  def self.next_frame
    throw :rea_hof_out if @frames.empty?
    @keys = @frames.shift
  end

  # Runs the block over these frames; true when it returned by itself before they ran out.
  def self.play(frames)
    @frames = frames.dup
    @keys = []
    class << Graphics
      alias_method :pa_rhf_update, :update
      def update; ReaHofFrames.next_frame; pa_rhf_update; end
    end
    class << Input
      alias_method :pa_rhf_trigger?, :trigger?
      def trigger?(k, *rest); ReaHofFrames.held?(k) || pa_rhf_trigger?(k, *rest); end
    end
    catch(:rea_hof_out) do
      yield
      return true
    end
    false
  ensure
    class << Graphics; alias_method :update, :pa_rhf_update; end
    class << Input; alias_method :trigger?, :pa_rhf_trigger?; end
    @keys = []
    @frames = []
  end
end

# The viewer through pbPCSelection: accept picks the front entrant (the plugin's watch and inAreaLeft?), and only
# while no record is picked; back puts the record down, and back on the list leaves through the cancel button and no
# other (the profile's watch and leftClick?); once the loop is over the mouse is left alone.
Suite.define("realidea hall of fame PC: accept picks the front entrant, back puts the record down and then leaves") do
  saved = $mouse
  $mouse = Game_Mouse.new
  records = [[Poke.build(:name => "Chispa", :species => 25, :level => 30), Poke.build(:name => "Rocoso", :level => 51)],
             [Poke.build(:name => "Brasa", :level => 40)]]
  $PokemonGlobal.define_singleton_method(:hallOfFame) { records }
  begin
    cancel = Object.new
    scene = HallOfFameScene.allocate
    { :@hallIndex => 0, :@hallEntry => records[0], :@positions => [[256, 250, 100], [96, 190, 90]],
      :@selectedrecord => false,
      :@sprites => { "cancelbuttom" => cancel, "arrowleft" => Object.new, "arrowright" => Object.new } }.each do |k, v|
      scene.instance_variable_set(k, v)
    end
    ended = ReaHofFrames.play([[], [Input::C], [], [Input::C], [Input::B], [Input::B]]) { scene.pbPCSelection }
    truthy "back on the list clicks the cancel button, which ends the viewer's loop", ended
    eq "and no arrow: the record shown is still the first", scene.instance_variable_get(:@hallIndex), 0
    spoke_once "accept clicks the front entrant, whose card is read, and no other nor again once its record is picked",
               /\AChispa/
    not_spoke "the other entrant is never clicked", /Rocoso/
    falsy "and the first back put the record down", scene.instance_variable_get(:@selectedrecord)

    clicks = nil
    ReaHofFrames.play([[Input::C, Input::B]]) do
      Graphics.update
      clicks = [$mouse.inAreaLeft?(208, 202, 96, 96), $mouse.leftClick?(cancel)]
    end
    eq "outside the viewer's loop the mouse is left alone", clicks, [false, false]
  ensure
    $mouse = saved
    class << $PokemonGlobal; remove_method :hallOfFame; end
  end
end
