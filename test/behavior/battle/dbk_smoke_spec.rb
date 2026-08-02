# The four core/battle/skyflyer/dbk_*.rb readers (Deluxe Battle Kit, the battle plugin La Base de Sky
# bundles) had ZERO assertions: nothing in CI ever executed a line of them. They are pure hook bodies --
# every one binds with :optional => true against a class the test stubs do not have, so they bind nothing
# at load and stay invisible even to a load error. A typo in any of them is a battle screen that says
# nothing on a DBK fangame, and the suite stays green.
#
# This suite gives them the classes they hook (a Sky-shaped Battle + Battle::Scene, defined right here),
# re-evaluates the four files so the hooks bind for real -- binding happens once at load, so a class that
# appears afterwards needs the registration replayed -- and then drives each hooked method the way the
# plugin does, asserting the reader speaks and that its DEDUP is real: the same cursor position stays
# silent, a move speaks, and reopening the panel on the SAME position reads again (each of those three
# hooks resets its dedup on open precisely so a reopen is not mute).
#
# Scope, honestly: under the gen-6 stubs there is no GameData layer, so the branches that turn an id into a
# NAME (the ball's item, the battler's status, the move's type) fall back and cannot be asserted here --
# defining a GameData stand-in is not an option, it would flip Engine.gamedata? for the whole run. What is
# covered is every hook's installation, its speech, its dedup and its reset, plus the text builders that do
# not need the data layer. ::Battle is created and removed inside this one suite: Engine's :battle_scene
# capability probes exactly that constant, so leaving it behind would silently change what later gen-6
# suites believe the engine can do.
Suite.define("dbk: the Sky battle-plugin hooks bind, speak, dedup and reset on reopen") do
  t = lambda { |key, vars| PokeAccess::I18n.t(key, vars) }
  rx = lambda { |s| /#{Regexp.escape(s.to_s)}/ }

  # A battler as the plugin hands it over: the plugin's own objects answer far more, and every reader
  # rescues what is missing, so the minimum is what proves the fallbacks hold.
  mk_battler = lambda do |nm, idx, moves|
    b = Object.new
    b.define_singleton_method(:name) { nm }
    b.define_singleton_method(:index) { idx }
    b.define_singleton_method(:level) { 42 }
    b.define_singleton_method(:hp) { 30 }
    b.define_singleton_method(:totalhp) { 60 }
    b.define_singleton_method(:moves) { moves }
    b
  end
  mk_move = lambda do |nm, pw, acc, cat|
    m = Object.new
    m.define_singleton_method(:name) { nm }
    m.define_singleton_method(:power) { pw }
    m.define_singleton_method(:accuracy) { acc }
    m.define_singleton_method(:category) { cat }
    m
  end

  battle_cls = Class.new do
    attr_accessor :registered
    def pbToggleSpecialActions(_idx, _cmd); :toggled; end
    def pbBattleMechanicIsRegistered?(_idx, _cmd); @registered; end
  end
  scene_cls = Class.new do
    def pbSelectBallInfo(*_a); :ball_opened; end
    def pbUpdateBallSelection(_items, _index, _show = false); :ball_drawn; end
    def pbSelectBattlerInfo(*_a); :bsel_opened; end
    def pbUpdateBattlerSelection(_side, _poke, _select = true); :bsel_drawn; end
    def pbUpdateBattlerInfo(_battler, _effects, _idx = 0); :binfo_drawn; end
    def pbUpdateMoveInfoWindow(_battler, _special, _cw); :minfo_drawn; end
  end

  begin
    Object.const_set(:Battle, battle_cls) unless Object.const_defined?(:Battle)
    Battle.const_set(:Scene, scene_cls) unless Battle.const_defined?(:Scene)
    verbose = $VERBOSE
    begin
      # eval is the harness's own loading mechanism (see test/support/harness.rb): it evaluates THIS repo's
      # trusted source files, addressed by absolute path under Harness::ROOT, never any external input. It
      # is what replays a hook registration that ran, and bound nothing, before these classes existed.
      $VERBOSE = nil   # re-evaluating a file re-assigns its constants; that warning is noise here
      %w[dbk_battle dbk_moveinfo dbk_battlerinfo dbk_selectors].each do |f|
        path = File.join(Harness::ROOT, "core", "battle", "skyflyer", "#{f}.rb")
        eval(File.read(path), TOPLEVEL_BINDING, path)
      end
    ensure
      $VERBOSE = verbose
    end
    truthy "the four DBK files bound to the Sky-shaped classes, none reported as a typo",
           PokeAccess::Hooks.missing.none? { |m| m =~ /\ABattle(::Scene)?#pb/ }

    #--- dbk_battle: the special-mechanic toggle, shown only as an icon in the plugin ---
    battle = Battle.new
    battle.registered = true
    SpeakCapture.clear
    eq "the toggle hook preserves the plugin's own return value",
       battle.pbToggleSpecialActions(0, :mega), :toggled
    spoke "turning a mechanic ON is announced by name",
          rx.call(t.call(:dbk_on, { :m => t.call(:dbk_mega, nil) }))
    battle.registered = false
    SpeakCapture.clear
    battle.pbToggleSpecialActions(0, :mega)
    spoke "and turning it OFF says so, not the same line",
          rx.call(t.call(:dbk_off, { :m => t.call(:dbk_mega, nil) }))
    not_spoke "the off line is not the on line", rx.call(t.call(:dbk_on, { :m => t.call(:dbk_mega, nil) }))
    SpeakCapture.clear
    battle.pbToggleSpecialActions(0, nil)
    silent "a toggle with no mechanic named says nothing"

    #--- dbk_selectors: the Poke Ball picker (sprite cursor, no command window) ---
    scene = Battle::Scene.new
    items = [[:POKEBALL, 5], [:ULTRABALL, 2]]
    SpeakCapture.clear
    scene.pbSelectBallInfo
    eq "the ball selector hook preserves its return value",
       scene.pbUpdateBallSelection(items, 0, false), :ball_drawn
    truthy "the focused ball is read on open", SpeakCapture.lines.length == 1
    SpeakCapture.clear
    scene.pbUpdateBallSelection(items, 0, false)
    silent "redrawing the SAME ball index stays silent (dedup)"
    scene.pbUpdateBallSelection(items, 1, false)
    truthy "moving to another ball reads again", SpeakCapture.lines.length == 1
    SpeakCapture.clear
    scene.pbUpdateBallSelection(items, 99, false)
    silent "an index with no entry behind it reads nothing instead of guessing"
    scene.pbUpdateBallSelection(items, 1, false)
    SpeakCapture.clear
    scene.pbSelectBallInfo
    scene.pbUpdateBallSelection(items, 1, false)
    truthy "REOPENING the selector re-reads the index it closed on (the open resets the dedup)",
           SpeakCapture.lines.length == 1

    #--- dbk_selectors: the battler-selection grid ---
    mine = mk_battler.call("Sparky", 0, [])
    theirs_near = mk_battler.call("Nearby", 1, [])
    theirs_far = mk_battler.call("Faraway", 3, [])
    owner = Object.new
    owner.define_singleton_method(:name) { "Rojo" }
    btl = Object.new
    btl.define_singleton_method(:allSameSideBattlers) { [mine] }
    btl.define_singleton_method(:allOtherSideBattlers) { [theirs_near, theirs_far] }
    btl.define_singleton_method(:pbGetOwnerFromBattlerIndex) { |_i| owner }
    scene.instance_variable_set(:@battle, btl)

    SpeakCapture.clear
    scene.pbSelectBattlerInfo
    scene.pbUpdateBattlerSelection(0, 0, true)
    spoke "the focused battler is read with its owner",
          rx.call(t.call(:dbk_owner, { :name => "Sparky", :owner => "Rojo" }))
    SpeakCapture.clear
    scene.pbUpdateBattlerSelection(0, 0, true)
    silent "the same grid cell stays silent (dedup on the side/slot pair)"
    scene.pbUpdateBattlerSelection(1, 0, true)
    spoke "the other side's first cell is its LAST battler (the grid lays that side out reversed)",
          rx.call("Faraway")
    not_spoke "so it is not the near one", rx.call("Nearby")
    SpeakCapture.clear
    scene.pbUpdateBattlerSelection(1, 5, true)
    silent "a cell with no battler behind it reads nothing"

    #--- dbk_battlerinfo: the battler detail overlay (summary + focused effect) ---
    effects = [["Drenadoras", "3", "Roba PS cada turno"], ["Toxico", "--", "Dano creciente"]]
    scene.instance_variable_set(:@enhancedUIToggle, :battler)
    SpeakCapture.clear
    eq "the battler-info hook preserves its return value",
       scene.pbUpdateBattlerInfo(mine, effects, 0), :binfo_drawn
    spoke "the summary names the battler", rx.call("Sparky")
    spoke "with its level", rx.call(t.call(:dbk_level, { :n => 42 }))
    spoke "and its HP", rx.call(t.call(:dbk_hp, { :hp => 30, :tot => 60 }))
    spoke "and the focused effect is read too", rx.call("Drenadoras")
    SpeakCapture.clear
    scene.pbUpdateBattlerInfo(mine, effects, 0)
    silent "redrawing the same battler and effect stays silent"
    scene.pbUpdateBattlerInfo(mine, effects, 1)
    spoke "moving down the effects reads the new one", rx.call("Toxico")
    not_spoke "without repeating the whole summary", rx.call(t.call(:dbk_level, { :n => 42 }))
    not_spoke "and the placeholder tick is dropped, never spoken", /--/
    SpeakCapture.clear
    scene.pbUpdateBattlerInfo(theirs_near, effects, 1)
    spoke "switching battler reads the new one's summary", rx.call("Nearby")
    SpeakCapture.clear
    scene.pbUpdateBattlerInfo(mine, effects, 0)
    spoke "and switching back reads that one", rx.call("Sparky")
    SpeakCapture.clear
    scene.instance_variable_set(:@enhancedUIToggle, nil)
    scene.pbUpdateBattlerInfo(mine, effects, 0)
    silent "with the overlay closed the panel says nothing"
    scene.instance_variable_set(:@enhancedUIToggle, :battler)
    scene.pbUpdateBattlerInfo(mine, effects, 0)
    spoke "REOPENING on the very same battler reads again (closing reset the dedup)", rx.call("Sparky")

    #--- dbk_moveinfo: the move-detail overlay over the fight menu ---
    bolt = mk_move.call("Rayo", 90, 100, 0)
    swap = mk_move.call("Cambio", 0, 0, 2)
    fighter = mk_battler.call("Sparky", 0, [bolt, swap])
    cw = Object.new
    cw_index = 0
    cw.define_singleton_method(:index) { cw_index }
    cw.define_singleton_method(:mode) { 0 }
    scene.instance_variable_set(:@enhancedUIToggle, :move)
    SpeakCapture.clear
    eq "the move-info hook preserves its return value",
       scene.pbUpdateMoveInfoWindow(fighter, nil, cw), :minfo_drawn
    spoke "the focused move is named", rx.call("Rayo")
    spoke "with its category", rx.call(t.call(:mv_category, { :c => t.call(:cat_physical, nil) }))
    spoke "its power", rx.call(t.call(:mv_power, { :p => "90" }))
    spoke "and its accuracy", rx.call(t.call(:mv_acc, { :a => 100 }))
    SpeakCapture.clear
    scene.pbUpdateMoveInfoWindow(fighter, nil, cw)
    silent "redrawing the same move stays silent"
    cw_index = 1
    scene.pbUpdateMoveInfoWindow(fighter, nil, cw)
    spoke "moving to another move reads it", rx.call("Cambio")
    not_spoke "a status move announces no power at all, in any wording",
              rx.call(t.call(:mv_power, {}))
    spoke "but still its accuracy", rx.call(t.call(:mv_acc, { :a => t.call(:mv_acc_perfect, nil) }))
    SpeakCapture.clear
    scene.instance_variable_set(:@enhancedUIToggle, nil)
    scene.pbUpdateMoveInfoWindow(fighter, nil, cw)
    silent "with the overlay closed the move panel says nothing"
    scene.instance_variable_set(:@enhancedUIToggle, :move)
    scene.pbUpdateMoveInfoWindow(fighter, nil, cw)
    spoke "REOPENING on the very same move reads again", rx.call("Cambio")
  ensure
    Object.send(:remove_const, :Battle) if Object.const_defined?(:Battle)
    SpeakCapture.clear
  end
end
