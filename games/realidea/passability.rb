# Realidea's passability check (Game_Map#playerPassable?). It reads switch 182, the swim mode that lets the player
# onto water without surfing, which joins the probe's mode. And it acts on the floors it is asked about: a sound on
# puddles and water, a follower refresh and switches 169 and 170 on water, the lead's status on its status floors.
# While the mod asks it (World::Probe), the sounds and the refresh are skipped and the switches and the lead's status
# are put back. Nothing else an event sets is read, so an event's end keeps the probe's answers.
module PokeAccess
  module RealideaPassability
    SWIM_SWITCH = 182
    SWITCHES = [169, 170]

    # Runs the game's check, putting back afterwards the switches and the lead's status it may write.
    def self.kept
      lead = ($Trainer.party[0] rescue nil)
      status = lead ? lead.status : nil
      saved = SWITCHES.map { |s| $game_switches[s] }
      begin
        yield
      ensure
        lead.status = status if lead
        SWITCHES.each_with_index { |s, i| $game_switches[s] = saved[i] }
      end
    end
  end
end

PokeAccess::Game.define("realidea") do
  PokeAccess::World::Probe.mode_reader do
    ($game_switches[PokeAccess::RealideaPassability::SWIM_SWITCH] rescue nil) ? true : false
  end
  plain_passability
  kernel("pbSEPlay", :around) { |_args, nxt| PokeAccess::World::Probe.quiet? ? nil : nxt.call }
  around("DependentEvents", :refresh_sprite, :optional => true) do |_events, nxt, _args|
    PokeAccess::World::Probe.quiet? ? nil : nxt.call
  end
  around("Game_Map", :playerPassable?, :optional => true) do |_map, nxt, _args|
    PokeAccess::World::Probe.quiet? ? PokeAccess::RealideaPassability.kept { nxt.call } : nxt.call
  end
end
