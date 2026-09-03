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

      ev = TransferCases.script_tile("pbSetTeleports(7)")
      falsy "a call nobody registered stays out even next to registered ones", loc.transfer_event?(ev)
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
