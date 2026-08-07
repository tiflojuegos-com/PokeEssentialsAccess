# Gen-6 move relearner. The harness ships no scene for it, and what this reader does is invisible to any
# "does it speak?" test.
#
# Muting the generic bare-name read is the point: the list is a Window_CommandPokemon whose plain move
# names the generic reader already voices, and this reader wants to say the whole detail instead. The
# obvious way to mute a window is @ignore_input, and on gen-6 that is a trap -- the command window gates
# its OWN navigation on that flag (050_SpriteWindow), so muting the read through it freezes the player's
# cursor on the screen. It sets @access_dedicated, the mod's own flag, which menus.rb honours without the
# engine ever seeing it. A test that only listens cannot tell the two apart; this one checks the flags.
Suite.define("gen-6 relearner: mutes the generic read without freezing the cursor") do
  mr = PokeAccess::MoveRelearnerGen6
  info = PokeAccess::MoveInfo
  saved = info.method(:by_id_via_data)
  made = false
  begin
    info.define_singleton_method(:by_id_via_data) { |id| "detalle de #{id}" }

    win = Object.new
    def win.index; @index; end
    def win.index=(v); @index = v; end
    win.index = 1

    scene = Object.new
    scene.instance_variable_set(:@sprites, { "commands" => win })
    scene.instance_variable_set(:@moves, [11, 22, 33])

    # Vanilla stores plain ids; the BetterMoveRelearner plugin stores [id, "MT"] pairs. Reading the pair
    # as an id would look up a move that does not exist and the screen would say nothing at all.
    eq "a plain id is read straight", mr.focused_id(scene), 22
    scene.instance_variable_set(:@moves, [[11, "MT"], [22, "MT"], [33, "MT"]])
    eq "and a [id, tag] pair is unwrapped to its id", mr.focused_id(scene), 22

    # A window with no selection reports -1, and moves[-1] in Ruby is the LAST element: without the lower
    # bound the screen would confidently speak a move the cursor is not on. Past the end is the harmless
    # half of the same guard -- it yields nil either way -- so the negative is the one worth asserting.
    win.index = -1
    eq "no selection speaks nothing, not the last move in the list", mr.focused_id(scene), nil
    win.index = 99
    eq "and neither does an index past the end", mr.focused_id(scene), nil
    win.index = 1

    SpeakCapture.clear
    mr.detail(scene)
    spoke "the focused move's full detail is spoken", /detalle de 22/

    # The two hook bodies from move_relearner_g6.rb, replayed on a real class the way plugins_smoke_spec
    # does: the registration in that file is gated on a class this harness does not have.
    Object.const_set(:MrG6SpecScene, Class.new) unless Object.const_defined?(:MrG6SpecScene)
    made = true
    MrG6SpecScene.send(:define_method, :pbStartScene) { nil }
    MrG6SpecScene.send(:define_method, :pbDrawMoveList) { nil }
    PokeAccess::Hooks.after_hook("MrG6SpecScene", :pbStartScene, :hook_container => true) do |s, _r, _a|
      w = PokeAccess.sprite(s, "commands")
      w.instance_variable_set(:@access_dedicated, true) if w
    end
    PokeAccess::Hooks.after_hook("MrG6SpecScene", :pbDrawMoveList) do |s, _r, _a|
      PokeAccess::MoveRelearnerGen6.detail(s)
    end

    live = MrG6SpecScene.new
    live.instance_variable_set(:@sprites, { "commands" => win })
    live.instance_variable_set(:@moves, [[11, "MT"], [22, "MT"], [33, "MT"]])
    SpeakCapture.clear
    live.pbStartScene

    truthy "opening the screen marks the list as owned by a dedicated reader",
           win.instance_variable_get(:@access_dedicated)
    falsy "and does NOT set @ignore_input, which would freeze the player's cursor",
          win.instance_variable_get(:@ignore_input)

    SpeakCapture.clear
    live.pbDrawMoveList
    spoke "each redraw speaks the focused move", /detalle de 22/
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
    Object.send(:remove_const, :MrG6SpecScene) if made && Object.const_defined?(:MrG6SpecScene)
    SpeakCapture.clear
  end
end
