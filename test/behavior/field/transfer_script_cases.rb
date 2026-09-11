# Shared body of transfer_script_spec (gen-6 pass) and transfer_script_gd_spec (gamedata pass): a door that
# transfers by calling a function of the GAME's own, which is core and happens in both eras. What is pinned:
# the two Essentials patterns still answer exactly as before, a registered pattern makes such an event an
# exit and names it by the map it captures, one that captures nothing is no transfer, and the registry is
# additive (the shipped two stay first, so a profile can never displace them).
module TransferCases
  # Snapshot/restore of the pattern list, a mutable constant: a leaked pattern would rewrite what counts as
  # a door for every suite after this one.
  def self.snapshot; PokeAccess::Locator::TRANSFER_SCRIPTS.dup; end

  def self.restore(saved)
    list = PokeAccess::Locator::TRANSFER_SCRIPTS
    list.clear
    saved.each { |re| list.push(re) }
    PokeAccess::Locator.clear_verdicts
  end

  # An event whose active page is a sprite-less touch tile running one script call, the shape of every
  # Reminiscencia dungeon entrance (and of the tile the player was standing next to when this was found).
  def self.script_tile(script, id = 91, name = "size(3,1)")
    page = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(355, [script])])
    ev = TestGameEvent.new(:id => id, :x => 6, :y => 8, :name => name, :pages => [page], :active_page => page)
    ($game_map.events[id] = ev) if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
    PokeAccess::Locator.clear_verdicts
    ev
  end

  # The same tile with its call split the way the editor stores a long one: the first line a 355 command
  # and every line after it a 655 continuation.
  def self.split_tile(lines, id = 93)
    cmds = [TestCmd.new(355, [lines[0]])] + lines[1..-1].map { |l| TestCmd.new(655, [l]) }
    page = TestPage.new(:trigger => 1, :sprite => "", :list => cmds)
    ev = TestGameEvent.new(:id => id, :x => 7, :y => 8, :name => "Entrada", :pages => [page], :active_page => page)
    ($game_map.events[id] = ev) if $game_map.respond_to?(:events) && $game_map.events.is_a?(Hash)
    PokeAccess::Locator.clear_verdicts
    ev
  end
end

def define_transfer_script_suites
  Suite.define("transfer by script: the shipped patterns answer as before, and a profile can add its own") do
    loc = PokeAccess::Locator
    saved = TransferCases.snapshot
    begin
      eq "the two Essentials patterns ship, in order", loc::TRANSFER_SCRIPTS.length, 2
      ev = TransferCases.script_tile("pbTransferPlayer(42,10,20)")
      eq "pbTransfer with a literal map is still read", loc.transfer_script_dest(ev), 42
      truthy "and it is an exit", loc.transfer_event?(ev)
      ev = TransferCases.script_tile("$game_temp.player_new_map_id = 17")
      eq "so is the raw player_new_map_id assignment", loc.transfer_script_dest(ev), 17

      ev = TransferCases.script_tile("getToDungeon(319)")
      falsy "a call the mod does not know is not a transfer", loc.transfer_event?(ev)
      falsy "and its destination is unknown", loc.transfer_script_dest(ev)
      falsy "so it is in no category: not an exit...", loc.in_category?(ev, :exits)
      falsy "...and not even in all, having no sprite to fall back on", loc.in_category?(ev, :all)

      loc.register_transfer_script(/\bgetTo\w*Dungeon\s*\(\s*(\d+)/)
      PokeAccess::Locator.clear_verdicts
      eq "once the profile declares it, the captured number is the destination", loc.transfer_script_dest(ev), 319
      truthy "the tile is an exit", loc.transfer_event?(ev)
      truthy "it is in the exits category", loc.in_category?(ev, :exits)
      truthy "and in all, which is the category the keys start on", loc.in_category?(ev, :all)
      match "it is spoken as an exit rather than by its editor note", loc.target_name(ev).to_s, /salida/i
      eq "the shipped patterns are still the first two", loc::TRANSFER_SCRIPTS[0, 2], saved

      ev = TransferCases.script_tile("getToHoennDungeon(208)")
      eq "the same pattern covers the Hoenn twin", loc.transfer_script_dest(ev), 208

      ev = TransferCases.script_tile("getToDungeon(dungeonmaps[selec])")
      falsy "a call whose destination is a variable captures nothing, so it is no transfer", loc.transfer_event?(ev)

      # A pattern with NO capture group at all. nil.to_i is 0, so the tile used to announce itself as an
      # exit to map 0 -- a map no game has, named after nothing, and a pathfinder target pointing at it.
      loc.register_transfer_script(/\bteleportHome\b/)
      PokeAccess::Locator.clear_verdicts
      ev = TransferCases.script_tile("teleportHome")
      falsy "a pattern that captures nothing declares no destination", loc.transfer_script_dest(ev)
      falsy "and therefore no exit", loc.transfer_event?(ev)

      ev = TransferCases.script_tile("pbSetTeleports(7)")
      falsy "a call nobody registered stays out even next to registered ones", loc.transfer_event?(ev)
    ensure
      TransferCases.restore(saved)
      World.clear_events
    end
  end

  # Realidea writes 1388 script calls, every pbTransferWithTransition it has over 1297 pages, as the call on
  # one line and the map id on the continuation line under it. Scanned line by line, neither half matched
  # the shipped pbTransfer pattern, so those tiles were neither listed, nor routed to, nor heard; only the
  # three hundred doors it opens with a Transfer command survived.
  Suite.define("transfer by script: a call split across a 355 line and its 655 continuations is read whole") do
    loc = PokeAccess::Locator
    saved = TransferCases.snapshot
    begin
      ev = TransferCases.split_tile(["pbTransferWithTransition(", "32,10,1,:DIRECTED)"])
      eq "the map id on the continuation line is the destination", loc.transfer_script_dest(ev), 32
      truthy "so the tile is an exit", loc.transfer_event?(ev)
      truthy "listed among the exits", loc.in_category?(ev, :exits)
      eq "and heard as a door", PokeAccess::Audio3D.type_of(ev), :door

      ev = TransferCases.split_tile(["pbTransferWithTransition(", "32,10,1,", ":DIRECTED, 8)"], 94)
      eq "however many continuation lines the call takes", loc.transfer_script_dest(ev), 32

      ev = TransferCases.split_tile(["pbMessage(\"...\")", "$game_temp.player_new_map_id = 17"], 95)
      eq "a continuation is read as part of its call, not lost", loc.transfer_script_dest(ev), 17
    ensure
      TransferCases.restore(saved)
      World.clear_events
    end
  end

  Suite.define("transfer by script: an autorun or parallel page is never a door, whatever it calls") do
    loc = PokeAccess::Locator
    saved = TransferCases.snapshot
    begin
      loc.register_transfer_script(/\bgetTo\w*Dungeon\s*\(\s*(\d+)/)
      [3, 4].each do |trig|
        page = TestPage.new(:trigger => trig, :sprite => "", :list => [TestCmd.new(355, ["getToDungeon(319)"])])
        ev = TestGameEvent.new(:id => 92, :x => 6, :y => 8, :name => "Setup", :pages => [page], :active_page => page)
        PokeAccess::Locator.clear_verdicts
        falsy "trigger #{trig} (the dungeon-chaining setup events) is not an exit", loc.transfer_event?(ev)
      end
    ensure
      TransferCases.restore(saved)
      World.clear_events
    end
  end
end
