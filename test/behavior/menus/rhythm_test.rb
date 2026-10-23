# Royal's curry rhythm minigame (games/royal/rhythm.rb): the note to press next is the first one not hit, not yet
# past where the game judges notes and not a rest; its direction is said once per note while the song's loop runs.

# The song scene as Royal's curry plugin shapes it: pbUpdate is the whole song, a blocking loop with an Input.update
# per frame; the stand-in plays a single frame over the notes it is given.
class JuegoRitmo_Scene
  def initialize(notes); @notes = notes; end

  def pbUpdate
    Input.update
    :song_over
  end
end
rhythm_path = File.join(Harness::ROOT, "games", "royal", "rhythm.rb")
eval(Harness.source(rhythm_path), TOPLEVEL_BINDING, rhythm_path)

class RhythmTest < PokeAccessTest
  # A note as the game keeps one (SongNote): its direction string ("" for a rest), where it is, hit or not, its id.
  Note = Struct.new(:note, :x, :hit, :id)
  # A selector sprite and its bitmap, of which the judging place reads only the width.
  Sprite = Struct.new(:bitmap)
  Bitmap = Struct.new(:width)

  Rhythm = PokeAccess::RoyalRhythm
  Reader = PokeAccess::RoyalRhythmReader

  test "the next note is the first one not hit and not yet past the selector, rests skipped" do
    sel = Rhythm.selector_x(Object.new)
    scene = song([Note.new("up", sel - 40, false, 0), Note.new("right", sel - 10, true, 1),
                  Note.new("", sel + 20, false, 2), Note.new("left", sel + 60, false, 3),
                  Note.new("down", sel + 95, false, 4)])
    assert_equal 3, Rhythm.pending(scene).id, "a missed note behind the selector does not hold up the song"
  end

  test "a hit note hands the turn to the next one" do
    sel = Rhythm.selector_x(Object.new)
    notes = [Note.new("left", sel + 60, false, 3), Note.new("down", sel + 95, false, 4)]
    scene = song(notes)
    notes[0].hit = true
    assert_equal 4, Rhythm.pending(scene).id
  end

  test "a note on the selector is still to press, one a pixel past it is not" do
    sel = Rhythm.selector_x(Object.new)
    assert_equal 7, Rhythm.pending(song([Note.new("up", sel, false, 7)])).id, "on the selector"
    assert_nil Rhythm.pending(song([Note.new("up", sel - 1, false, 8)])), "a pixel past it"
  end

  test "nothing is pending with every note ahead hit, before the song has notes, or for a note half set up" do
    sel = Rhythm.selector_x(Object.new)
    unknown_hit = Object.new
    def unknown_hit.hit; raise "not drawn yet"; end
    def unknown_hit.x; 600; end
    def unknown_hit.note; "up"; end
    {
      "every note hit" => [Note.new("up", sel + 10, true, 0), Note.new("down", sel + 30, true, 1)],
      "no notes yet" => nil,
      "notes not a list" => { 0 => Note.new("up", sel + 10, false, 0) },
      "a note with no place" => [Note.new("up", nil, false, 0)],
      "a note whose hit state raises" => [unknown_hit]
    }.each { |what, notes| assert_nil Rhythm.pending(song(notes)), what }
  end

  test "judges notes where the game does: the screen's middle less half the selector, plus 7" do
    {
      "a selector 50 wide" => [{ "selector" => Sprite.new(Bitmap.new(50)) }, 238],
      "a selector without its bitmap" => [{ "selector" => Sprite.new(nil) }, 263],
      "no selector" => [{}, 263],
      "no sprites" => [nil, 263]
    }.each do |what, (sprites, x)|
      assert_equal x, Rhythm.selector_x(World.stub_scene(:@sprites => sprites)), what
    end
  end

  test "names each direction by its arrow button's word" do
    t = PokeAccess::I18n
    { "up" => :btn_up, "down" => :btn_down, "left" => :btn_left, "right" => :btn_right }.each do |dir, key|
      scene = song([Note.new(dir, 400, false, 0)])
      with_reader(scene) do
        SpeakCapture.clear
        Reader.poll
        assert_equal [t.t(key)], SpeakCapture.lines, "a note #{dir}"
      end
    end
  end

  test "says each note once, the first queued and the next ones cutting in" do
    t = PokeAccess::I18n
    notes = [Note.new("left", 400, false, 3), Note.new("down", 450, false, 4)]
    scene = song(notes)
    with_reader(scene) do
      Reader.poll
      Reader.poll
      notes[0].hit = true
      Reader.poll
      Reader.poll
      assert_equal [[t.t(:btn_left), false], [t.t(:btn_down), true]], SpeakCapture.log
    end
  end

  test "says nothing while no note is left to press" do
    scene = song([Note.new("left", 400, true, 3), Note.new("", 450, false, 4)])
    with_reader(scene) { Reader.poll }
    assert_nothing_spoken
  end

  test "says the note ahead on a frame of the song's loop, and nothing on a frame once the loop is over" do
    notes = [Note.new("left", 400, false, 3), Note.new("down", 450, false, 4)]
    assert_equal :song_over, JuegoRitmo_Scene.new(notes).pbUpdate, "the song's own loop runs"
    assert_equal [[PokeAccess::I18n.t(:btn_left), false]], SpeakCapture.log, "the first note, queued"
    SpeakCapture.clear
    notes[0].hit = true
    Input.update
    assert_nothing_spoken "the next note, after the loop"
  end

  private

  # A song scene holding notes as the game's @notes.
  def song(notes)
    World.stub_scene(:@notes => notes)
  end

  # Runs the block with the reader watching scene, as the song's loop does, and lets it go after.
  def with_reader(scene)
    Reader.watch(scene)
    yield
  ensure
    Reader.unwatch
  end
end
