# Infinite Fusion 2's secret base seats (sit_on_chair_event, SecretBaseItemBehaviors.rb): touching a chair, couch or
# stool jumps the player onto it, and only an arrow stands them up again, ending the seat's loop; the screen shows no
# text for either. Standing up is said as the loop returns, cutting in as the arrow that made it.
PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("sit_on_chair_event") do |_args, _r|
    seat = PokeAccess::I18n.t(:if2_seat)
    PokeAccess.speak(PokeAccess::Verbosity.with_hint(seat, PokeAccess::I18n.t(:if2_seat_hint)), false)
  end
  kernel("sit_on_chair_event", :after) { |_args, _r| PokeAccess.speak(PokeAccess::I18n.t(:if2_standing), true) }
end
