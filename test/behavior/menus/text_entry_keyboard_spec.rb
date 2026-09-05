# The keyboard switch around a naming screen. A modern mkxp-z starts with text input off and Input.gets
# yields nothing until Input.text_input = true; a gen-6 naming script on that runtime opens a box nobody can
# type into (Reminiscencia: Ctrl+G, Shift+K and Shift+M all "opened nothing"). What is pinned is the
# contract that makes the fix safe everywhere else: on for the screen, restored afterwards, and a runtime or
# a game that already manages the switch is left exactly as found.

# Gives the stub Input a text_input switch for the block, recording every write, and removes it after.
def with_text_input_switch(initial)
  $tik_state = initial
  $tik_writes = []
  Input.define_singleton_method(:text_input) { $tik_state }
  Input.define_singleton_method(:text_input=) { |v| $tik_writes.push(v); $tik_state = v }
  yield
ensure
  class << Input
    remove_method :text_input
    remove_method :text_input=
  end
end

Suite.define("text entry: the naming screen runs with keyboard input on, and leaves the switch as it found it") do
  te = PokeAccess::TextEntry
  falsy "the stub runtime has no switch to begin with", Input.respond_to?(:text_input=)
  ran = false
  te.with_keyboard_input { ran = true }
  truthy "without a switch the screen simply runs", ran

  with_text_input_switch(false) do
    during = nil
    te.with_keyboard_input { during = $tik_state }
    truthy "a runtime that starts with text input off has it on for the screen", during
    falsy "and off again afterwards", $tik_state
    eq "exactly one write each way", $tik_writes, [true, false]
  end

  with_text_input_switch(true) do
    te.with_keyboard_input { }
    truthy "a game that already switched it on keeps it on", $tik_state
    eq "and the mod never touched it", $tik_writes, []
  end

  with_text_input_switch(false) do
    begin
      te.with_keyboard_input { raise "screen blew up" }
    rescue RuntimeError
    end
    falsy "a screen that raises still restores the switch", $tik_state
  end
end
