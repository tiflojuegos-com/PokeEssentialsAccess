# Hidden Axis Lab (map 145), Aelita's illusions: in the scene of event 23 Delpha asks which of two Ericks and then which
# of two Aelitas is the impostor: the second Erick and the first Aelita. A wrong pick hurts the party; each branch
# writes its affection (Erick 482, Aelita 383), so the answer is said as Choose an imposter! is picked.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 145, :part => :impostors) do
    auto
    on_reach 23, { :choice => /\AChoose an imposter/i }, :rjg_ax_erick, :assist => true
    right_choice 23, :avoids => { :var => 383 }
  end
end
