# How an event is filed and named by its sprite, trigger and commands: doorway and warp-pad sprites make exits, a
# person's a person unless walked into, a sign or a self-running event is no exit, an idle unnamed one its sprite.
class DoorwaySpritesTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Sonar = PokeAccess::Sound::Scene
  CATEGORIES = [:exits, :people, :objects, :signs, :extras]
  # Each event as [sprite, trigger, commands (:warp asks and transfers, :ask only asks, :none), name or nil], and the
  # categories the locator files it under.
  FILED = {
    "an action-button door drawn as a doorway" => [["doors3", 0, :warp, nil], [:exits]],
    "a warp pad that asks first" => [["Umbral", 0, :warp, nil], [:exits]],
    "an invisible action-button warp" => [["", 0, :warp, nil], [:exits]],
    "Hoopa's ring" => [["Npc-Hoopa Rings", 0, :warp, nil], [:exits]],
    "a sailor who takes the player somewhere" => [["trchar036", 0, :warp, nil], [:people]],
    "the Hoopa character, who talks and then warps" => [["HOOPA", 0, :warp, nil], [:people]],
    "the trainer who teleports the player by common event" =>
      [["trainer_TELEPORTER_Honchkrow", 0, :ask, nil], [:people]],
    "a soldier the editor named Exit, who only talks" => [["trainer_INFANTRY_M", 0, :ask, "Exit"], [:people]],
    "a painted floor arrow with no commands" => [["flecha", 0, :none, nil], [:objects]],
    "a person the player walks into who talks and takes the player somewhere" => [["trchar036", 1, :warp, nil], [:people]],
    "a person an event's touch starts, who talks and takes the player somewhere" =>
      [["trchar036", 2, :warp, nil], [:people]],
    "the Safari Zone attendant the engine starts by sight, who charges and takes the player in" =>
      [["NPC 07", 2, :warp, "Counter(4)"], [:people]],
    "a Pokemon by its number that catches the player and sends them back" => [["011", 2, :warp, "Trainer(1)"], [:people]],
    "a person an event's touch starts, who takes the player somewhere without a word" =>
      [["trchar036", 2, :silent_warp, nil], [:exits]],
    "a portal drawn as an object, which asks before the player steps in" => [["Object_Timegate", 1, :warp, nil], [:exits]],
    "a hole drawn by a sheet of its own, which asks before the player dives" => [["throne_hole", 1, :warp, nil], [:exits]],
    "a door drawn by a sheet no doorway word names, which talks as the player walks in" =>
      [["Puertita", 1, :warp, nil], [:exits]],
    "an invisible autorun event that transfers" => [["", 3, :warp, nil], []],
    "an invisible parallel event that transfers" => [["", 4, :warp, nil], []],
    "a sign the editor named Salida" => [["", 0, :ask, "Salida"], [:signs]]
  }

  test "files each event under the categories its sprite, trigger and commands make it" do
    FILED.each_with_index do |(what, (shape, cats)), i|
      ev = doorway_case(i + 1, *shape)
      assert_equal cats, CATEGORIES.select { |c| Loc.in_category?(ev, c) }, what
    end
  end

  test "answers whether an event is an exit with a plain yes or no" do
    FILED.each_with_index do |(what, (shape, cats)), i|
      assert_equal cats.include?(:exits), Loc.transfer_event?(doorway_case(i + 1, *shape)), what
    end
  end

  test "takes an event that fails to be read for no exit" do
    ev = doorway_case(1, "", 0, :warp)
    def ev.name; raise "gone"; end
    Loc.clear_verdicts
    assert_equal false, Loc.transfer_event?(ev)
  end

  test "gives each event the sonar cue of what it is" do
    { "an action-button door drawn as a doorway" => :door, "a warp pad that asks first" => :teleporter,
      "an invisible action-button warp" => :door, "Hoopa's ring" => :teleporter,
      "a sailor who takes the player somewhere" => :npc, "the Hoopa character, who talks and then warps" => :npc,
      "the trainer who teleports the player by common event" => :npc,
      "a soldier the editor named Exit, who only talks" => :npc,
      "the Safari Zone attendant the engine starts by sight, who charges and takes the player in" => :npc,
      "a Pokemon by its number that catches the player and sends them back" => :npc,
      "a portal drawn as an object, which asks before the player steps in" => :door }.each_with_index do |(what, cue), i|
      assert_equal cue, Sonar.family_of(doorway_case(i + 1, *FILED[what][0])), what
    end
  end

  test "gives a painted floor arrow with no commands no sonar cue" do
    assert_nil Sonar.family_of(doorway_case(1, "flecha", 0, :none))
  end

  test "names an unnamed event with no commands after its sprite, or an object when the sprite tells nothing" do
    object = PokeAccess::I18n.t(:loc_object)
    { "flecha" => "flecha", "025" => PokeAccess::Data.species_name(25), "" => object, "1234" => object,
      "objeto_roca" => object }.each do |sprite, name|
      assert_equal name, Loc.target_name(doorway_case(1, sprite, 0, :none)), "drawn as #{sprite.inspect}"
    end
  end

  test "names a doorway the editor left as EV###, to a map with no name, an exit" do
    far = doorway_case(5, "doors1", 1, [TestCmd.new(201, [0, 77, 1, 1])])
    assert_equal PokeAccess::I18n.t(:loc_exit), Loc.target_name(far)
  end

  test "names someone who takes the player elsewhere as anyone else, then where to, unless it is this map" do
    there = doorway_case(1, "NPC 07", 2, [TestCmd.new(101, ["In?"]), TestCmd.new(201, [0, 35, 1, 1])], "Counter(4)")
    here = doorway_case(2, "NPC 07", 2, [TestCmd.new(101, ["Out!"]), TestCmd.new(201, [0, $game_map.map_id, 1, 1])])
    nowhere = doorway_case(3, "NPC 07", 2, [TestCmd.new(101, ["In?"]), TestCmd.new(201, [0, 77, 1, 1])])
    takes = PokeAccess::I18n.t(:loc_takes_to, :map => "Mapa 35")
    assert_equal ["NPC 07, #{takes}", "NPC 07", "NPC 07"], [there, here, nowhere].map { |ev| Loc.target_name(ev) }
  end

  test "a touch event whose sheet draws nothing in the frame it shows, or that is drawn see-through, stays an exit" do
    with_sheets("Graphics/Characters/trainer084" => 0, "Graphics/Characters/NPC 07" => 255) do
      hidden = doorway_case(1, "trainer084", 2, :warp, "Trainer(3)")
      faded = doorway_case(2, "NPC 07", 2, :warp, "Counter(4)")
      def faded.opacity; 0; end
      seen = doorway_case(3, "NPC 07", 2, :warp, "Counter(4)")
      assert_equal [[:exits], [:exits], [:people]], [hidden, faded, seen].map { |ev| CATEGORIES.select { |c| Loc.in_category?(ev, c) } }
    end
  end

  test "a touch event whose sheet the engine fails to load or to read with its own errors is someone, each reported" do
    with_engine_errors do
      with_sheets("Graphics/Characters/NPC 07" => :undecodable, "Graphics/Characters/trchar036" => :too_large) do
        before = swallowed_here
        broken = doorway_case(1, "NPC 07", 2, :warp, "Counter(4)")
        huge = doorway_case(2, "trchar036", 2, :warp)
        assert_equal [[:people], [:people]], [broken, huge].map { |ev| CATEGORIES.select { |c| Loc.in_category?(ev, c) } }
        assert_equal before + 2, swallowed_here
      end
    end
  end

  test "reads a frame from its bottom row up, where a character stands, to find it drawn" do
    with_sheets("Graphics/Characters/NPC 07" => lambda { |_x, y| y == 31 ? 255 : 0 }) do
      assert_equal true, Loc.frame_drawn?("NPC 07", 2, 0)
      assert_operator Sheet.reads, :<=, 32, "one row of the 32-pixel frame at most"
    end
  end

  private

  # A character sheet as the engine's Bitmap reads it, 128 by 128, every pixel at the alpha its path is given or the
  # one a lambda given returns for (x, y); :undecodable fails to load it and :too_large to read it, as mkxp-z fails.
  class Sheet
    Pixel = Struct.new(:alpha)
    @alphas = {}
    @reads = 0
    class << self; attr_accessor :alphas, :reads; end
    def initialize(path)
      @alpha = Sheet.alphas.fetch(path, 255)
      raise ::SDLError, "Error loading image '#{path}'" if @alpha == :undecodable
    end
    def width; 128; end
    def height; 128; end
    def get_pixel(x, y)
      raise ::MKXPError, "Bitmap too large" if @alpha == :too_large
      Sheet.reads += 1
      Pixel.new(@alpha.respond_to?(:call) ? @alpha.call(x, y) : @alpha)
    end
    def dispose; end
  end

  # Runs the block with mkxp-z's own SDLError and MKXPError defined as the engine defines them, under Exception.
  def with_engine_errors
    added = [:SDLError, :MKXPError].reject { |n| Object.const_defined?(n) }
    added.each { |n| Object.const_set(n, Class.new(Exception)) }
    yield
  ensure
    added.each { |n| Object.send(:remove_const, n) }
  end

  # The failures swallowed so far in the locator's naming file.
  def swallowed_here
    PokeAccess.swallowed_sites.select { |site, _n, _f| site =~ /locator_naming\.rb/ }.inject(0) { |sum, s| sum + s[1] }
  end

  # Runs the block with Sheet as the engine's Bitmap, each path at its alpha, no pixel read yet, and the locator's
  # frames read anew; the real Bitmap, if any, is put back after.
  def with_sheets(alphas)
    real = Object.const_defined?(:Bitmap) ? Object.send(:remove_const, :Bitmap) : nil
    Object.const_set(:Bitmap, Sheet)
    Sheet.alphas = alphas
    Sheet.reads = 0
    Loc.instance_variable_set(:@frames_drawn, {})
    yield
  ensure
    Object.send(:remove_const, :Bitmap)
    Object.const_set(:Bitmap, real) if real
    Loc.instance_variable_set(:@frames_drawn, {})
  end

  # A one-page event, id, on the map's row 6 with that sprite, trigger and commands (a command list, or :warp, :ask
  # or :none), named name or as the editor names it (EV00<id>), its verdicts cleared.
  def doorway_case(id, sprite, trigger, commands, name = nil)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => commands_for(commands))
    ev = TestGameEvent.new(:id => id, :x => 3 + id, :y => 6, :name => name || "EV00#{id}", :pages => [page],
                           :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    Loc.clear_verdicts
    ev
  end

  # The command list a case's commands stand for (:silent_warp transfers with no word).
  def commands_for(commands)
    return commands if commands.is_a?(Array)
    ask = TestCmd.new(101, ["Go in?"])
    warp = TestCmd.new(201, [0, 5, 1, 1])
    { :warp => [ask, warp], :silent_warp => [warp], :ask => [ask], :none => [] }[commands]
  end
end
