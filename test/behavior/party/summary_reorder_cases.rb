# Shared cases of summary_reorder_spec and summary_reorder_gd_spec: reordering moves through the two cursor sprites
# (movesel, movepresel over the move picked up) and pbUpdate every frame; the carry ends with movepresel hiding,
# placed or put back, and the back button's frame tells the two apart.
module SummaryReorderCases
  Cursor = Struct.new(:index, :visible)
  Move = Struct.new(:id, :name)

  # A scene of the given class on the moves page, both cursors on the first move, the carry cursor hidden.
  def self.scene(klass, pk)
    s = klass.new(pk)
    s.instance_variable_set(:@sprites, { "movesel" => Cursor.new(0, true), "movepresel" => Cursor.new(0, false) })
    s
  end

  def self.poke
    moves = [Move.new(33, "Placaje"), Move.new(45, "Grunido"), Move.new(52, "Ascuas")]
    Poke.build(:name => "Char", :moves => moves)
  end

  # One frame of the move selection, with the back button down in it when asked.
  def self.frame(scene, back = false)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| back && k == Input::B }
    scene.pbUpdate
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end

def define_summary_reorder_suites(klass)
  Suite.define("summary reorder: picking a move up, carrying it and placing it") do
    t = PokeAccess::I18n
    PokeAccess::Summary.reset_reorder
    scene = SummaryReorderCases.scene(klass, SummaryReorderCases.poke)
    sel = scene.instance_variable_get(:@sprites)["movesel"]
    pre = scene.instance_variable_get(:@sprites)["movepresel"]
    SummaryReorderCases.frame(scene)
    SpeakCapture.clear
    pre.visible = true
    SummaryReorderCases.frame(scene)
    sel.index = 2
    SummaryReorderCases.frame(scene)
    pre.visible = false
    SummaryReorderCases.frame(scene)
    eq "the move picked up with the keys that carry it, where the cursor carries it, and where it lands",
       SpeakCapture.lines,
       [PokeAccess::Verbosity.with_hint(t.t(:sm_reorder, :name => "Placaje"), t.t(:sm_reorder_hint)),
        "#{t.t(:sm_position, :n => 3)}, Ascuas", t.t(:sm_placed, :n => 3)]
  end

  Suite.define("summary reorder: the keys that carry the move are left out with the hints") do
    t = PokeAccess::I18n
    PokeAccess::Summary.reset_reorder
    PokeAccess::Config.verbosity = :brief
    begin
      scene = SummaryReorderCases.scene(klass, SummaryReorderCases.poke)
      pre = scene.instance_variable_get(:@sprites)["movepresel"]
      SummaryReorderCases.frame(scene)
      SpeakCapture.clear
      pre.visible = true
      SummaryReorderCases.frame(scene)
      eq "brief: the move picked up, alone", SpeakCapture.lines, [t.t(:sm_reorder, :name => "Placaje")]
    ensure
      PokeAccess::Config.verbosity = :full
    end
  end

  Suite.define("summary reorder: putting the move back with the back button is not placing it") do
    t = PokeAccess::I18n
    PokeAccess::Summary.reset_reorder
    scene = SummaryReorderCases.scene(klass, SummaryReorderCases.poke)
    sel = scene.instance_variable_get(:@sprites)["movesel"]
    pre = scene.instance_variable_get(:@sprites)["movepresel"]
    SummaryReorderCases.frame(scene)
    pre.visible = true
    SummaryReorderCases.frame(scene)
    sel.index = 1
    SummaryReorderCases.frame(scene)
    SpeakCapture.clear
    SummaryReorderCases.frame(scene, true)
    pre.visible = false
    SummaryReorderCases.frame(scene)
    eq "the carry was cancelled, and the next one starts clean", SpeakCapture.lines, [t.t(:sm_reorder_cancel)]

    SpeakCapture.clear
    pre.visible = true
    SummaryReorderCases.frame(scene)
    pre.visible = false
    SummaryReorderCases.frame(scene)
    eq "a carry ended by the button places the move", SpeakCapture.lines.last, t.t(:sm_placed, :n => 2)
  end
end
