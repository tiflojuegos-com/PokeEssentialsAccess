# TextEntry.with_keyboard_input: a modern mkxp-z starts with text input off, so a naming screen runs with
# Input.text_input on and the switch is turned back off after, raise or not; a switch already on, or none, is left alone.
# And the keyboard field's echo: a character the field takes, and the one a deletion takes away; and what the free-text
# field over a message already holds as it opens.

# The game's free-text field over a message, down to what it answers: the text it opened with. The rest is the stock
# (passwordbox, maxlength, width) or Rejuvenation's (maxlength, width, past_texts, passwordbox).
def pbFreeText(_msgwindow, currenttext, *_rest); currenttext; end

# The reader's wrap of the field, which core's own load made before the function existed.
eval(Harness.source(File.join(Harness::ROOT, "core", "menus", "text_entry.rb"))
            .match(/^PokeAccess::Hooks\.wrap_kernel\("pbFreeText".*?^end\n/m)[0], TOPLEVEL_BINDING, "text_entry.rb free text")

class TextEntryKeyboardTest < PokeAccessTest
  # The reader's file, whose keyboard field hooks a test binds to a stand-in field.
  ENTRY = File.join(Harness::ROOT, "core", "menus", "text_entry.rb")

  test "echoes a character the field takes, not one a full field turns away" do
    with_field("1234", 5) do |field|
      field.insert("5")
      field.insert("7")
      assert_equal ["12345", [["5", true]]], [field.helper.text, SpeakCapture.log]
    end
  end

  test "names the character a deletion takes, the one before the cursor, a space as a space" do
    with_field("12 4", 5) do |field|
      field.helper.left
      field.delete
      field.delete
      assert_equal ["14", [[t(:te_deleted_char, :c => t(:key_space)), true], [t(:te_deleted_char, :c => "2"), true]]],
                   [field.helper.text, SpeakCapture.log]
    end
  end

  test "a free-text field says what it already holds as it opens, queued behind the question" do
    assert_equal "Ruta del Lago", pbFreeText(nil, "Ruta del Lago", false, 20)
    assert_equal [[t(:nm_current, :t => "Ruta del Lago"), false]], SpeakCapture.log
  end

  test "an empty free-text field, or a password box, says nothing as it opens" do
    pbFreeText(nil, "", false, 20)
    pbFreeText(nil, "secreto", true, 20)
    assert_nothing_spoken
  end

  test "Rejuvenation's field, its password flag last, says what it holds unless it is a password box" do
    pbFreeText(nil, "Ruta del Lago", 20, 240, [], false)
    pbFreeText(nil, "secreto", 20, 240, [], true)
    assert_equal [[t(:nm_current, :t => "Ruta del Lago"), false]], SpeakCapture.log
  end

  test "says nothing for a deletion that takes nothing" do
    with_field("", 5) { |field| field.delete }
    assert_nothing_spoken
  end

  test "runs the screen untouched where the runtime has no text input switch" do
    assert_equal :named, PokeAccess::TextEntry.with_keyboard_input { :named }
  end

  test "turns text input on for the screen, where the runtime starts with it off" do
    with_text_input_switch(false) do |switch|
      assert_equal true, PokeAccess::TextEntry.with_keyboard_input { switch[:on] }
    end
  end

  test "turns text input back off after the screen, with one write each way" do
    with_text_input_switch(false) do |switch|
      PokeAccess::TextEntry.with_keyboard_input { :named }
      assert_equal [true, false], switch[:writes]
    end
  end

  test "hands back the screen's own value" do
    with_text_input_switch(false) do
      assert_equal :named, PokeAccess::TextEntry.with_keyboard_input { :named }
    end
  end

  test "leaves a switch the game already turned on as it is" do
    with_text_input_switch(true) do |switch|
      PokeAccess::TextEntry.with_keyboard_input { :named }
      assert_equal [[], true], [switch[:writes], switch[:on]], "no write, and the switch stays on"
    end
  end

  test "turns the switch back off when the screen raises" do
    with_text_input_switch(false) do |switch|
      assert_raises(RuntimeError) { PokeAccess::TextEntry.with_keyboard_input { raise "screen blew up" } }
      assert_equal [true, false], switch[:writes]
    end
  end

  test "takes a switch it cannot read, or one with no getter, as off" do
    [:raising, :none].each do |getter|
      with_text_input_switch(true, getter) do |switch|
        PokeAccess::TextEntry.with_keyboard_input { :named }
        assert_equal [true, false], switch[:writes], "a getter that is #{getter}"
      end
    end
  end

  private

  # Runs the block with a stand-in keyboard field (field_class) holding text, at most max characters, bound by the
  # field's insert and delete hooks as boot binds them; yields it. The game's own class and hooks, if any, are put
  # back afterwards.
  def with_field(text, max)
    src = Harness.source(ENTRY)
    from = src.index(/^PokeAccess::Hooks\.after_hook\("Window_TextEntry", :insert\)/)
    hooks = src[from..-1][/\A.*?(?=^# Suppresses)/m]
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    kept = %w[insert delete].map { |m| "Window_TextEntry##{m}" }.map { |key| [key, chains.delete(key)] }
    had = Object.const_defined?(:Window_TextEntry, false) ? Object.send(:remove_const, :Window_TextEntry) : nil
    Object.const_set(:Window_TextEntry, field_class)
    eval(hooks, TOPLEVEL_BINDING, "text_entry.rb field hooks", src[0, from].count("\n") + 1)
    yield Window_TextEntry.new(text, max)
  ensure
    if kept
      Object.send(:remove_const, :Window_TextEntry) if Object.const_defined?(:Window_TextEntry, false)
      Object.const_set(:Window_TextEntry, had) if had
      kept.each { |key, chain| chain ? chains[key] = chain : chains.delete(key) }
    end
  end

  # The keyboard field as the game writes it: Window_TextEntry over a CharacterEntryHelper, whose insert turns a
  # character away (false) once the text holds max, and whose delete takes the character before the cursor.
  def field_class
    helper = Class.new do
      attr_reader :text
      def initialize(text, max); @text = text; @cursor = text.scan(/./m).length; @max = max; end
      def left; @cursor -= 1; end

      def insert(ch)
        chars = @text.scan(/./m)
        return false if chars.length >= @max
        @text = chars.insert(@cursor, ch).join
        @cursor += 1
        true
      end

      def delete
        chars = @text.scan(/./m)
        return false if chars.empty? || @cursor <= 0
        chars.delete_at(@cursor - 1)
        @text = chars.join
        @cursor -= 1
        true
      end
    end
    Class.new do
      attr_reader :helper
      define_method(:initialize) { |text, max| @helper = helper.new(text, max) }
      def insert(ch); @helper.insert(ch) ? true : false; end
      def delete; @helper.delete ? true : false; end
    end
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the stub Input given a text input switch that starts at initial and records each write;
  # yields its state ({:on, :writes}). The getter answers the switch, raises (:raising) or is absent (:none).
  def with_text_input_switch(initial, getter = :plain)
    switch = { :on => initial, :writes => [] }
    added = [:text_input=]
    Input.define_singleton_method(:text_input=) { |v| switch[:writes].push(v); switch[:on] = v }
    unless getter == :none
      added.push(:text_input)
      Input.define_singleton_method(:text_input) { getter == :raising ? raise("no switch to read") : switch[:on] }
    end
    yield switch
  ensure
    (added || []).each { |m| Input.singleton_class.send(:remove_method, m) }
  end
end
