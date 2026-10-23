# Hooks.read_on_open, the summary a screen gives as it opens: spoken queued and cleaned, once the opener has run or,
# with :timing => :before, ahead of an opener that blocks in its own loop; a block that answers nothing stays silent.

# A screen with one opener per way of reading it; the read ones note in order when they ran and when they were read.
class ReadOnOpenScene
  attr_reader :order
  def initialize; @order = []; end
  def pbStartScene; @order.push(:opener); :started; end
  def pbBlockingPage; @order.push(:opener); :page; end
  def pbCodedTitle; :coded; end
  def pbNilAfter; :nil_after; end
  def pbFalseAfter; :false_after; end
  def pbEmptyAfter; :empty_after; end
  def pbNilBefore; :nil_before; end
  def pbFalseBefore; :false_before; end
end

PokeAccess::Hooks.read_on_open("ReadOnOpenScene") { |s| s.order.push(:read); "Resumen al abrir" }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbBlockingPage, :timing => :before) do |s|
  s.order.push(:read)
  "Resumen de la página"
end
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbCodedTitle) { |_s| "\\c[1]Mochila\\c[0] abierta" }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbNilAfter) { |_s| nil }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbFalseAfter) { |_s| false }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbEmptyAfter) { |_s| "" }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbNilBefore, :timing => :before) { |_s| nil }
PokeAccess::Hooks.read_on_open("ReadOnOpenScene", :pbFalseBefore, :timing => :before) { |_s| false }

class ReadOnOpenTest < PokeAccessTest
  test "speaks the opening text queued, once the opener has run" do
    scene = ReadOnOpenScene.new
    scene.pbStartScene
    assert_equal [["Resumen al abrir", false]], SpeakCapture.log, "queued, never cutting in"
    assert_equal [:opener, :read], scene.order, "the text is asked for after the opener"
  end

  test "with its timing before, speaks ahead of the opener, queued" do
    scene = ReadOnOpenScene.new
    scene.pbBlockingPage
    assert_equal [["Resumen de la página", false]], SpeakCapture.log, "queued, never cutting in"
    assert_equal [:read, :opener], scene.order, "the text is asked for before the blocking opener runs"
  end

  test "keeps the opener's own result" do
    { :pbStartScene => :started, :pbBlockingPage => :page }.each do |opener, result|
      assert_equal result, ReadOnOpenScene.new.send(opener), "for #{opener}"
    end
  end

  test "speaks the text cleaned of the game's control codes" do
    ReadOnOpenScene.new.pbCodedTitle
    assert_equal [["Mochila abierta", false]], SpeakCapture.log
  end

  test "a block that answers nil, false or an empty text leaves the opening silent" do
    [:pbNilAfter, :pbFalseAfter, :pbEmptyAfter, :pbNilBefore, :pbFalseBefore].each do |opener|
      ReadOnOpenScene.new.send(opener)
      assert_nothing_spoken "for #{opener}"
    end
  end
end
