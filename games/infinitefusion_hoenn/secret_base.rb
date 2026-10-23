# Infinite Fusion 2's secret base seats (sit_on_chair_event, SecretBaseItemBehaviors.rb): touching a chair, couch or
# stool jumps the player onto it, and only an arrow stands them up again; the screen shows no text for either.
PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("sit_on_chair_event") do |_args, _r|
    seat = PokeAccess::I18n.t(:if2_seat)
    PokeAccess.speak(PokeAccess::Verbosity.with_hint(seat, PokeAccess::I18n.t(:if2_seat_hint)), false)
  end
end
