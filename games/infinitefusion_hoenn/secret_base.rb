# Infinite Fusion 2's secret bases. The way in and the way out only call a script, and one map holds every base, each
# with its own way out, a tile below where the base lands the player: only the base the player is in has one listed.
# The seats (sit_on_chair_event, SecretBaseItemBehaviors.rb): touching a chair, couch or stool jumps the player onto it,
# and only an arrow stands them up again, ending the seat's loop; the screen shows no text for either. Standing up is
# said as the loop returns, cutting in as the arrow that made it.
module PokeAccess
  module IF2SecretBase
    LEAVING = /^\s*exitSecretBase\b/

    # True for the way out of a base the player is not in: with none entered, as in a game loaded inside one, the player's
    # own, as the game's way out takes it.
    def self.other_exit?(ev)
      return false unless ($game_map.map_id rescue nil) == PokeAccess.const_at("MAP_SECRET_BASES")
      base = (getEnteredSecretBase rescue nil) || (PokeAccess::Engine.player.secretBase rescue nil)
      at = (base.inside_entrance_position rescue nil)
      return false if !at.is_a?(Array) || (ev.x == at[0] && ev.y == at[1] + 1)
      PokeAccess::Locator.script_call_find(ev) { |s| s =~ LEAVING } ? true : false
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  transfer_script(/^\s*enterSecretBase\b/) { |_m| PokeAccess.const_at("MAP_SECRET_BASES") }
  transfer_script(PokeAccess::IF2SecretBase::LEAVING)
  event_hidden { |ev| PokeAccess::IF2SecretBase.other_exit?(ev) }
  kernel("sit_on_chair_event") do |_args, _r|
    seat = PokeAccess::I18n.t(:if2_seat)
    PokeAccess.speak(PokeAccess::Verbosity.with_hint(seat, PokeAccess::I18n.t(:if2_seat_hint)), false)
  end
  kernel("sit_on_chair_event", :after) { |_args, _r| PokeAccess.speak(PokeAccess::I18n.t(:if2_standing), true) }
end
