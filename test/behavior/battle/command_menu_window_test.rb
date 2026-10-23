# Battle.read_command: the focused command from the command window's list (@window up to v17, @cmdWindow from v19),
# else from the labels stash_command_texts kept; a missing list or label says nothing.
class CommandMenuWindowTest < PokeAccessTest
  LABELS = ["Luchar", "Mochila", "Pokemon", "Huir"]

  test "reads the focused label whichever name the engine gives its window" do
    [:@window, :@cmdWindow].each do |name|
      disp = display(name => window(LABELS))
      { 0 => "Luchar", 1 => "Mochila", 3 => "Huir" }.each do |index, label|
        assert_equal [[label, true]], command_line(disp, index), "#{name}, button #{index}"
      end
    end
  end

  test "an opening read is queued as it is asked" do
    assert_equal [["Luchar", false]], command_line(display(:@cmdWindow => window(LABELS)), 0, false)
  end

  test "says a label cleaned of its codes" do
    assert_equal [["Huir", true]], command_line(display(:@window => window(["\\c[2]Huir"])), 0)
  end

  test "says nothing for a display with no window and no kept labels" do
    assert_equal [], command_line(Object.new, 0)
  end

  test "says nothing for a window without a list" do
    assert_equal [], command_line(display(:@cmdWindow => Object.new), 0)
  end

  test "says nothing for a position with no label in the list" do
    disp = display(:@cmdWindow => window(["Luchar", nil, :bag]))
    [1, 2, 99].each { |index| assert_equal [], command_line(disp, index), "button #{index}" }
  end

  test "reads the labels kept from setTexts, without the message they come after" do
    disp = Object.new
    PokeAccess::Battle.stash_command_texts(disp, ["Que hara Pikachu?"] + LABELS)
    { 0 => "Luchar", 2 => "Pokemon", 3 => "Huir" }.each do |index, label|
      assert_equal [[label, true]], command_line(disp, index), "button #{index}"
    end
  end

  test "keeps four labels, the first four after the message" do
    disp = Object.new
    PokeAccess::Battle.stash_command_texts(disp, ["msg"] + LABELS + ["Extra"])
    assert_equal [], command_line(disp, 4)
  end

  test "prefers the window's list to the kept labels" do
    disp = display(:@window => window(["DesdeVentana"]))
    PokeAccess::Battle.stash_command_texts(disp, ["msg", "DesdeStash"])
    assert_equal [["DesdeVentana", true]], command_line(disp, 0)
  end

  test "falls back to the kept labels when the window has no list" do
    disp = display(:@cmdWindow => Object.new)
    PokeAccess::Battle.stash_command_texts(disp, ["msg", "DesdeStash"])
    assert_equal [["DesdeStash", true]], command_line(disp, 0)
  end

  test "keeps nothing from setTexts handed something other than a list" do
    disp = Object.new
    PokeAccess::Battle.stash_command_texts(disp, "no soy un array")
    assert_equal [], command_line(disp, 0)
  end

  test "keeping the labels on a display that refuses them raises nothing" do
    assert_nil PokeAccess::Battle.stash_command_texts(Object.new.freeze, ["msg"] + LABELS)
  end

  private

  # A command window holding these commands.
  def window(commands)
    w = Object.new
    w.instance_variable_set(:@commands, commands)
    w
  end

  # A battle command display with the given instance variables.
  def display(ivars)
    d = Object.new
    ivars.each { |name, value| d.instance_variable_set(name, value) }
    d
  end

  # What reading button index of disp says, as [text, interrupt] pairs.
  def command_line(disp, index, interrupt = true)
    SpeakCapture.clear
    PokeAccess::Battle.read_command(disp, index, interrupt)
    SpeakCapture.log.dup
  end
end
