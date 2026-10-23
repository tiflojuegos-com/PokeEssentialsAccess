# Shared cases of summary_reorder_test and summary_reorder_gd_test: reordering moves on the summary's moves page,
# read each frame (pbUpdate) from the move cursor (movesel) and the carry cursor (movepresel) over the move picked up.
module SummaryReorderCases
  # A cursor sprite of the moves page: the slot it is on and whether it shows.
  Cursor = Struct.new(:index, :visible)
  # A move as the Pokemon holds it.
  Move = Struct.new(:id, :name)

  # The moves of the Pokemon shown: three, the fourth slot empty.
  MOVES = [Move.new(33, "Placaje"), Move.new(45, "Grunido"), Move.new(52, "Ascuas")]

  # Defines the shared cases and their helpers on base, the test class of one engine's pass, whose summary scene class
  # is scene_class and whose game data names a move id as move_named answers for it.
  def self.define(base, scene_class, move_named)
    base.class_eval do
      test "says nothing on the frame it first sees the cursors, even over a carried move" do
        scene = open_summary
        carry_cursor(scene).visible = true
        frame(scene)
        frame(scene)
        assert_nothing_spoken
      end

      test "picking a move up says the move and the keys that carry it, interrupting" do
        scene = moves_page
        pick_up(scene)
        assert_equal [["#{t(:sm_reorder, :name => 'Placaje')}. #{t(:sm_reorder_hint)}", true]], SpeakCapture.log
      end

      test "with the hints left out, picking a move up says the move alone" do
        PokeAccess::Config.verbosity = :brief
        scene = moves_page
        pick_up(scene)
        assert_equal [[t(:sm_reorder, :name => "Placaje"), true]], SpeakCapture.log
      end

      test "carrying the move says each slot the cursor reaches: its move, an empty slot, the exit row" do
        scene = moves_page
        pick_up(scene)
        SpeakCapture.clear
        [1, 2, 3, 4, 0].each { |slot| move_to(scene, slot) }
        assert_equal [["#{t(:sm_position, :n => 2)}, Grunido", true], ["#{t(:sm_position, :n => 3)}, Ascuas", true],
                      ["#{t(:sm_position, :n => 4)}, #{t(:sm_empty_slot)}", true], [t(:sm_exit), true],
                      ["#{t(:sm_position, :n => 1)}, Placaje", true]],
                     SpeakCapture.log
      end

      test "a frame with the cursor where it was says nothing" do
        scene = moves_page
        pick_up(scene)
        move_to(scene, 2)
        SpeakCapture.clear
        frame(scene)
        assert_nothing_spoken
      end

      test "the cursor moving with no move carried says nothing" do
        scene = moves_page
        move_to(scene, 2)
        assert_nothing_spoken
      end

      test "placing the move says the position it lands in" do
        scene = moves_page
        pick_up(scene)
        move_to(scene, 2)
        SpeakCapture.clear
        drop(scene)
        assert_equal [[t(:sm_placed, :n => 3), true]], SpeakCapture.log
      end

      test "the back button cancels the carry once it ends, saying nothing as it is pressed" do
        scene = moves_page
        pick_up(scene)
        move_to(scene, 1)
        SpeakCapture.clear
        frame(scene, true)
        drop(scene)
        assert_equal [[t(:sm_reorder_cancel), true]], SpeakCapture.log
      end

      test "dropping the move on the exit row cancels the carry" do
        scene = moves_page
        pick_up(scene)
        move_to(scene, 4)
        SpeakCapture.clear
        drop(scene)
        assert_equal [[t(:sm_reorder_cancel), true]], SpeakCapture.log
      end

      test "a back button that cannot be read does not cancel the carry" do
        scene = moves_page
        pick_up(scene)
        SpeakCapture.clear
        frame(scene, :unreadable)
        drop(scene)
        assert_equal [[t(:sm_placed, :n => 1), true]], SpeakCapture.log
      end

      test "a carry after a cancelled one places its move" do
        scene = moves_page
        pick_up(scene)
        frame(scene, true)
        drop(scene)
        pick_up(scene)
        move_to(scene, 1)
        SpeakCapture.clear
        drop(scene)
        assert_equal [[t(:sm_placed, :n => 2), true]], SpeakCapture.log
      end

      test "a summary opened anew forgets a carry the last one left" do
        pick_up(moves_page)
        scene = open_summary
        frame(scene)
        assert_nothing_spoken
      end

      test "names a slot's move by its own name, else by the game's data, else as a move" do
        unnamed = Object.new
        def unnamed.move_name(_id); ""; end
        { "a move with no name of its own" => [Move.new(45, ""), nil, game_move_name(45)],
          "a move with a nil name" => [Move.new(45, nil), nil, game_move_name(45)],
          "a move the game's data does not name either" => [Move.new(45, ""), unnamed, t(:info_move)],
          "the gen-6 empty move, id 0" => [Move.new(0, ""), nil, t(:sm_empty_slot)] }.each do |what, (move, data, name)|
          scene = moves_page([MOVES[0], move])
          pick_up(scene)
          SpeakCapture.clear
          data ? Harness.with_provider(data, 99) { move_to(scene, 1) } : move_to(scene, 1)
          assert_equal [["#{t(:sm_position, :n => 2)}, #{name}", true]], SpeakCapture.log, what
        end
      end

      test "with no Pokemon on the scene, a slot is said by its position alone" do
        scene = moves_page(nil)
        pick_up(scene)
        SpeakCapture.clear
        move_to(scene, 1)
        assert_equal [[t(:sm_position, :n => 2), true]], SpeakCapture.log
      end

      test "a move cursor on a slot it cannot read says nothing as it moves" do
        scene = moves_page
        pick_up(scene)
        SpeakCapture.clear
        move_to(scene, nil)
        assert_nothing_spoken
      end

      test "placing the move from a slot it cannot read says the position as unknown" do
        scene = moves_page
        pick_up(scene)
        move_to(scene, nil)
        SpeakCapture.clear
        drop(scene)
        assert_equal [[t(:sm_placed, :n => "?"), true]], SpeakCapture.log
      end

      test "a page without both cursors says nothing of a carry" do
        { "neither cursor" => [], "only the move cursor" => ["movesel"],
          "only the carry cursor" => ["movepresel"] }.each do |what, kept|
          scene = moves_page
          sprites = scene.instance_variable_get(:@sprites)
          sprites.keep_if { |key, _sprite| kept.include?(key) }
          SpeakCapture.clear
          [true, false].each do |shown|
            sprites.each_value { |cursor| cursor.visible = shown }
            frame(scene)
          end
          assert_nothing_spoken what
        end
      end

      private

      define_method(:scene_class) { scene_class }

      define_method(:game_move_name) { |id| move_named.call(id) }

      def t(key, args = {}); PokeAccess::I18n.t(key, args); end

      # A summary opened on a Pokemon with moves (none for nil), as the game opens it, with its moves page's cursors
      # on the first slot, the carry cursor hidden; no frame has gone by and nothing said is kept.
      def open_summary(moves = SummaryReorderCases::MOVES)
        pk = moves ? Poke.build(:name => "Char", :moves => moves) : nil
        scene = scene_class.new(pk)
        scene.pbStartScene(pk ? [pk] : nil, 0)
        scene.instance_variable_set(:@sprites, { "movesel" => SummaryReorderCases::Cursor.new(0, true),
                                                 "movepresel" => SummaryReorderCases::Cursor.new(0, false) })
        SpeakCapture.clear
        scene
      end

      # open_summary with its first frame gone by.
      def moves_page(moves = SummaryReorderCases::MOVES)
        scene = open_summary(moves)
        frame(scene)
        SpeakCapture.clear
        scene
      end

      def move_cursor(scene); scene.instance_variable_get(:@sprites)["movesel"]; end

      def carry_cursor(scene); scene.instance_variable_get(:@sprites)["movepresel"]; end

      # The move under the cursor picked up, as the game shows it: the carry cursor over it.
      def pick_up(scene)
        carry_cursor(scene).index = move_cursor(scene).index
        carry_cursor(scene).visible = true
        frame(scene)
      end

      def move_to(scene, slot)
        move_cursor(scene).index = slot
        frame(scene)
      end

      # The carried move let go, placed or put back: the carry cursor hidden.
      def drop(scene)
        carry_cursor(scene).visible = false
        frame(scene)
      end

      # One frame of the move selection: the back button down in it when back is true, and the buttons unreadable
      # (Input.trigger? raising) when it is :unreadable.
      def frame(scene, back = false)
        trigger = Input.method(:trigger?)
        Input.define_singleton_method(:trigger?) do |key|
          raise IOError, "the buttons cannot be read" if back == :unreadable
          back == true && key == Input::B
        end
        scene.pbUpdate
      ensure
        Input.define_singleton_method(:trigger?, trigger)
      end
    end
  end
end
