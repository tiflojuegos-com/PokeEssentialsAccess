# Every hook wrapper hands keyword arguments (Reborn's tts:, Rejuvenation's lowercase: and log:) on as keywords, not as
# one positional Hash; the dialogue reader's message wrapper too, reading the letter-by-letter flag beside them.

# A game class whose methods take optional positionals and a keyword: show and draw are hooked, narrate overridden.
class HookKwFixture
  def show(text, letters = true, extra = nil, tts: true)
    [text, letters, extra, tts]
  end

  def draw(text, letters = true, extra = nil, tts: true)
    [text, letters, extra, tts]
  end

  def narrate(text, interrupt = false, tts: true)
    [text, interrupt, tts]
  end
end

# A game module whose own function takes a keyword, replaced through Hooks.override.
module HookKwFixtureMod
  def self.pick(list, tts: true)
    [list, tts]
  end
end

# A game module whose own functions take a keyword, wrapped through Hooks.wrap_singleton: choose once, cycle twice.
module HookKwSingletonFixture
  def self.choose(list, cancel = -1, log: false)
    [list, cancel, log]
  end

  def self.cycle(list, log: false)
    [list, log]
  end
end

# A game's top-level functions that take a keyword, as bare defs define them (private on Object).
def hook_kw_fixture_fn(text, interrupt = false, lowercase: nil)
  [text, interrupt, lowercase]
end

def hook_kw_fixture_hidden_fn(text, lowercase: nil)
  [text, lowercase]
end

def hook_kw_fixture_bare_fn(text, lowercase: nil)
  [text, lowercase]
end

def hook_kw_fixture_twice_fn(text, lowercase: nil)
  [text, lowercase]
end

# A gen-6 game's Kernel functions that take a keyword: hook_kw_fixture_msg wrapped once, hook_kw_fixture_twice twice.
module Kernel
  def self.hook_kw_fixture_msg(message, commands = nil, tts: true)
    [message, commands, tts]
  end

  def self.hook_kw_fixture_twice(message, tts: true)
    [message, tts]
  end
end

class HookKeywordsTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  # A message window the dialogue reader can follow page by page: it answers whether it stands at a page break, and
  # keeps the characters it draws.
  class PagingWindow
    def initialize
      @textchars = []
    end

    def pausing?
      false
    end
  end

  test "a hooked instance method gets its keywords as keywords, and its defaults when none are given" do
    seen = []
    Hooks.before_hook("HookKwFixture", :show) { |_i, args| seen.push(args.dup) }
    f = HookKwFixture.new
    assert_equal ["hola", false, nil, false], f.show("hola", false, tts: false), "tts: handed on"
    assert_equal ["hola", true, nil, true], f.show("hola"), "nothing handed, the defaults"
    assert_equal [["hola", false, { :tts => false }], ["hola"]], seen,
                 "both calls went through the hook, whose body sees the keywords as one trailing Hash"
  end

  test "a positional Hash handed to a hooked method stays positional" do
    seen = []
    Hooks.after_hook("HookKwFixture", :draw) { |_i, result, _args| seen.push(result) }
    assert_equal ["hola", true, { :a => 1 }, true], HookKwFixture.new.draw("hola", true, { :a => 1 })
    assert_equal [["hola", true, { :a => 1 }, true]], seen, "through the hook"
  end

  test "a wrapped top-level function keeps its keywords" do
    seen = []
    Hooks.wrap_global("hook_kw_fixture_fn", "test_kw_global", :before) { |args, _r| seen.push(args.dup) }
    assert_equal ["x", true, true], hook_kw_fixture_fn("x", true, lowercase: true)
    assert_equal [["x", true, { :lowercase => true }]], seen, "through the wrapper"
  end

  test "a wrapped top-level function stays private, as the game's bare def left it" do
    seen = []
    Hooks.wrap_global("hook_kw_fixture_hidden_fn", "test_kw_hidden", :after) { |_args, r| seen.push(r) }
    assert_equal ["y", true], hook_kw_fixture_hidden_fn("y", lowercase: true), "a bare call reaches it"
    assert_equal [["y", true]], seen, "through the wrapper"
    assert_raises(NoMethodError, "a call with a receiver is refused") { Kernel.hook_kw_fixture_hidden_fn("y") }
  end

  test "a top-level function wrapped twice runs each body once and keeps its keywords" do
    seen = []
    [:first, :second].each do |body|
      Hooks.wrap_global("hook_kw_fixture_twice_fn", "test_kw_twice_fn", :before) { |a, _r| seen.push([body, a.dup]) }
    end
    assert_equal ["w", true], hook_kw_fixture_twice_fn("w", lowercase: true)
    assert_equal [[:first, ["w", { :lowercase => true }]], [:second, ["w", { :lowercase => true }]]], seen,
                 "one wrapper, both bodies"
  end

  test "a wrapped Kernel function keeps its keywords" do
    seen = []
    Hooks.wrap_kernel("hook_kw_fixture_msg", "test_kw_kernel", :around) { |args, nxt| seen.push(args.dup); nxt.call }
    assert_equal ["m", nil, false], Kernel.hook_kw_fixture_msg("m", tts: false)
    assert_equal [["m", { :tts => false }]], seen, "through the wrapper"
  end

  test "the Kernel wrap of a top-level function binds where the game's bare calls go, keywords and all" do
    seen = []
    Hooks.wrap_kernel("hook_kw_fixture_bare_fn", "test_kw_bare", :before) { |args, _r| seen.push(args.dup) }
    assert_equal ["z", false], hook_kw_fixture_bare_fn("z", lowercase: false)
    assert_equal [["z", { :lowercase => false }]], seen, "a bare call went through the wrapper"
  end

  test "a Kernel function wrapped twice runs each body once and keeps its keywords" do
    seen = []
    [:first, :second].each do |body|
      Hooks.wrap_kernel("hook_kw_fixture_twice", "test_kw_twice", :before) { |args, _r| seen.push([body, args.dup]) }
    end
    assert_equal ["m", false], Kernel.hook_kw_fixture_twice("m", tts: false)
    assert_equal [[:first, ["m", { :tts => false }]], [:second, ["m", { :tts => false }]]], seen,
                 "one wrapper, both bodies"
  end

  test "a wrapped game module function keeps its keywords" do
    seen = []
    Hooks.wrap_singleton("HookKwSingletonFixture", :choose, "test_kw_singleton", :after) { |_args, r| seen.push(r) }
    assert_equal [[1, 2], -1, true], HookKwSingletonFixture.choose([1, 2], log: true)
    assert_equal [[[1, 2], -1, true]], seen, "through the wrapper"
  end

  test "a game module function wrapped twice runs each body once and keeps its keywords" do
    seen = []
    [:first, :second].each do |body|
      Hooks.wrap_singleton("HookKwSingletonFixture", :cycle, "test_kw_cycle", :after) { |_a, r| seen.push([body, r]) }
    end
    assert_equal [[3], true], HookKwSingletonFixture.cycle([3], log: true)
    assert_equal [[:first, [[3], true]], [:second, [[3], true]]], seen, "one wrapper, both bodies"
  end

  test "an overridden game class method keeps its keywords" do
    seen = []
    Hooks.override("HookKwFixture", :narrate) { |_inst, original, args| seen.push(args.dup); original.call }
    assert_equal ["hola", false, false], HookKwFixture.new.narrate("hola", tts: false)
    assert_equal [["hola", { :tts => false }]], seen, "through the override"
  end

  test "an overridden module function keeps its keywords" do
    seen = []
    Hooks.override(HookKwFixtureMod, :pick) { |_mod, original, args| seen.push(args.dup); original.call }
    assert_equal [[1], false], HookKwFixtureMod.pick([1], tts: false)
    assert_equal [[[1], { :tts => false }]], seen, "through the override"
  end

  test "a message's keyword options reach the game's pbMessageDisplay beside its letter-by-letter flag" do
    with_reborn_message_display do |calls, _heard|
      assert_equal :shown, Kernel.pbMessageDisplay(nil, "Pican los peces", false, tts: false), "the game's answer"
      assert_equal [[false, nil, false]], calls, "the game got its flag and its keyword back"
    end
  end

  test "keywords alone leave the letter-by-letter flag at its default, and the line is still read" do
    with_reborn_message_display do |calls, _heard|
      Kernel.pbMessageDisplay(nil, "Ha picado algo", tts: false)
      assert_equal [[true, nil, false]], calls, "the keyword is not taken for the flag"
      assert_equal [["Ha picado algo", false]], SpeakCapture.log, "the line, queued"
    end
  end

  test "a message with keyword options counts one message deep while the game shows it" do
    outside = PokeAccess.message_depth
    with_reborn_message_display do |_calls, _heard, depths|
      Kernel.pbMessageDisplay(nil, "Tira con fuerza", tts: false)
      assert_equal [outside + 1], depths, "while the game shows it"
      assert_equal outside, PokeAccess.message_depth, "and no deeper once it is shown"
    end
  end

  test "a command proc handed after the flag still reaches the game as the command proc" do
    chooser = proc { |_w| :chose }
    with_reborn_message_display do |calls, _heard|
      assert_equal :chose, Kernel.pbMessageDisplay(nil, "Elige", true, chooser), "the game ran it"
      assert_equal [[true, chooser, true]], calls
    end
  end

  test "with pages on, a message whose only option is a keyword is followed page by page" do
    pages_on
    with_reborn_message_display do |_calls, heard|
      Kernel.pbMessageDisplay(PagingWindow.new, "Algo tira del sedal", tts: false)
      assert_equal [[]], heard, "nothing said before the window draws it"
      assert_equal [["Algo tira del sedal", false]], SpeakCapture.log, "said whole as the window it never paged closes"
    end
  end

  test "with pages on, a message drawn at once is read whole as it opens, though a keyword follows its flag" do
    pages_on
    with_reborn_message_display do |_calls, heard|
      Kernel.pbMessageDisplay(PagingWindow.new, "Se ha escapado", false, tts: false)
      assert_equal [["Se ha escapado"]], heard, "said before the game draws it"
      assert_equal [["Se ha escapado", false]], SpeakCapture.log, "and only then"
    end
  end

  private

  # Turns the dialogue_pages option on and leaves, once each, the messages still open, so a message the reader may
  # follow page by page begins with none open; a leave that closes none keeps the page refused instead of looping.
  def pages_on
    PokeAccess::Config.dialogue_pages = true
    PokeAccess.message_depth.times { PokeAccess.message_leave }
  end

  # Runs the block with the game's own pbMessageDisplay (the original the dialogue reader wraps) taking Reborn's tts:
  # keyword, yielding the [letterbyletter, commandProc, tts] of each call it gets, the lines said as each began and the
  # message depth during each; no head or tail is promised for the line, and the stub's original is put back after.
  def with_reborn_message_display
    PokeAccess.before_next_line(nil)
    PokeAccess.after_next_line(nil)
    sc = Kernel.singleton_class
    calls = []
    heard = []
    depths = []
    sc.send(:alias_method, :pa_kw_test_orig, :pbMessageDisplay__access_orig)
    sc.send(:define_method, :pbMessageDisplay__access_orig) do |win, _message, letters = true, cmd = nil, tts: true|
      calls.push([letters, cmd, tts])
      heard.push(SpeakCapture.lines)
      depths.push(PokeAccess.message_depth)
      cmd ? cmd.call(win) : :shown
    end
    yield calls, heard, depths
  ensure
    sc.send(:alias_method, :pbMessageDisplay__access_orig, :pa_kw_test_orig)
    sc.send(:remove_method, :pa_kw_test_orig)
  end
end
