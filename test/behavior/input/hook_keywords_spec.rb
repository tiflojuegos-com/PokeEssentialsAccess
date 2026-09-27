# Hooks around methods that take keyword arguments (the Reborn engine's tts:, Rejuvenation's lowercase: and log:):
# every wrapper hands them on as keywords, where Ruby 3 would pass one positional Hash and break the call.
class HookKwFixture
  def show(text, letters = true, extra = nil, tts: true)
    [text, letters, extra, tts]
  end
end

module HookKwFixtureMod
  def self.pick(list, tts: true); [list, tts]; end
end

def hook_kw_fixture_fn(text, interrupt = false, lowercase: nil); [text, interrupt, lowercase]; end

module Kernel
  def self.hook_kw_fixture_msg(message, commands = nil, tts: true); [message, commands, tts]; end
end

Suite.define("hooks: keyword arguments reach a hooked method as keywords") do
  seen = []
  PokeAccess::Hooks.before_hook("HookKwFixture", :show) { |_i, args| seen.push(args.length) }
  f = HookKwFixture.new
  eq "a class hook hands tts: on", f.show("hola", false, tts: false), ["hola", false, nil, false]
  eq "and leaves the default when none is given", f.show("hola"), ["hola", true, nil, true]
  eq "a positional Hash stays positional", f.show("hola", true, { :a => 1 }), ["hola", true, { :a => 1 }, true]
  eq "the body sees the keywords as one trailing argument", seen, [3, 1, 3]

  PokeAccess::Hooks.wrap_global("hook_kw_fixture_fn", "spec_kw_global", :before) { |_args, _r| nil }
  eq "a wrapped top-level function keeps its keywords", hook_kw_fixture_fn("x", true, lowercase: true), ["x", true, true]
  eq "and stays private, as the game defined it", Object.private_method_defined?(:hook_kw_fixture_fn), true

  PokeAccess::Hooks.wrap_kernel("hook_kw_fixture_msg", "spec_kw_kernel", :around) { |_args, nxt| nxt.call }
  eq "a wrapped Kernel function keeps its keywords", Kernel.hook_kw_fixture_msg("m", tts: false), ["m", nil, false]

  PokeAccess::Hooks.override(HookKwFixtureMod, :pick) { |_mod, original, _args| original.call }
  eq "an overridden module method keeps its keywords", HookKwFixtureMod.pick([1], tts: false), [[1], false]
end

# Reborn's fishing hands Kernel.pbMessageDisplay (msgwindow, message, false, tts: false): through the dialogue reader's
# wrapper the keyword must stay a keyword, or it lands in commandProc and the game calls a Hash.
Suite.define("dialogue: a message's keyword options reach the game's pbMessageDisplay") do
  sc = (class << Kernel; self; end)
  got = []
  sc.send(:alias_method, :pa_kw_spec_orig, :pbMessageDisplay__access_orig)
  sc.send(:define_method, :pbMessageDisplay__access_orig) do |msgwindow, message, letterbyletter = true, commandProc = nil, tts: true|
    got.push([letterbyletter, commandProc, tts])
    commandProc ? commandProc.call(msgwindow) : :shown
  end
  begin
    SpeakCapture.clear
    eq "a waiting line with tts: false is shown", Kernel.pbMessageDisplay(nil, "Pican los peces", false, tts: false), :shown
    eq "and the game gets its own flags back", got.last, [false, nil, false]
    Kernel.pbMessageDisplay(nil, "Ha picado algo", tts: false)
    eq "keywords alone leave letterbyletter at its default", got.last, [true, nil, false]
    spoke "the line itself is still read", /Ha picado algo/
    eq "a command proc still arrives as one", Kernel.pbMessageDisplay(nil, "Elige", true, proc { |_w| :chose }), :chose
  ensure
    sc.send(:alias_method, :pbMessageDisplay__access_orig, :pa_kw_spec_orig)
    sc.send(:remove_method, :pa_kw_spec_orig)
  end
end
