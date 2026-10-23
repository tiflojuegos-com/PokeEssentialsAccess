# Rejuvenation's Voltorb Flip (Minigame/VoltorbFlip.rb) opens its notes with A, X or Y, where Reborn and Desolation
# use Ctrl: the board's key hint names the A button as the player has it, and the quit key as the core does.
PokeAccess::Game.define("rejuvenation") do
  override("PokeAccess::Minigames", :vf_keys) do |_mod, _original, _args|
    [PokeAccess::I18n.t(:mg_vf_memo_key, :key => PokeAccess::KeyHints.key(:a, "Z")),
     PokeAccess::I18n.t(:piano_exit, :key => PokeAccess::KeyHints.key(:b, "X"))].join(". ")
  end
end
