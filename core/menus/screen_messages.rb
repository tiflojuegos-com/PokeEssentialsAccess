# Menu screens (party, bag, storage, mart, save, relearner, summary, facility shops) draw their prompts
# and results onto their own help window, not through pbMessageDisplay, so the dialogue hook never sees
# them (e.g. the "X already holds Y, swap?" confirm was silent). These read those scene messages too,
# routed through say_dialogue (which dedupes an identical line within half a second). The yes/no list is
# read by the generic command-window hook. Battle scenes are excluded -- their messages have own readers.
module PokeAccess
  # The player-facing menu scene classes, in both gen-6 and modern naming (the hook guards on existence).
  SCREEN_MSG_SCENES = [
    "PokemonScreen_Scene", "PokemonParty_Scene", "PokemonBag_Scene", "PokemonStorageScene",
    "ItemStorageScene", "ItemStorage_Scene", "TossItemScene", "WithdrawItemScene",
    "PokemonSaveScene", "PokemonSave_Scene", "MoveRelearnerScene", "MoveRelearner_Scene",
    "PokemonMartScene", "PokemonMart_Scene", "BattlePointShop_Scene", "BattleSwapScene",
    "PurifyChamberScene", "RelicStoneScene", "PokemonSummary_Scene", "PokemonSummaryScene"
  ]
  # The message-drawing methods these scenes use (names vary by scene and engine).
  SCREEN_MSG_METHODS = [:pbDisplay, :pbDisplayPaused, :pbConfirm, :pbDisplayConfirm]
end

# This is intentional over-binding (each scene uses only some of these methods, and the names vary by
# engine), declared :optional so the typo detector does not flag dozens of legitimate cross-engine
# absences as "possible typos". Behaviour is identical (an absent method was a no-op anyway).
PokeAccess::SCREEN_MSG_SCENES.each do |cname|
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    PokeAccess::Hooks.before_hook(cname, meth, :optional => true) do |_scene, args|
      PokeAccess.say_dialogue(args[0].to_s) if args[0] && !args[0].to_s.empty?
    end
  end
end

# The item-storage TITLE ("Withdraw item" / "Toss item"): painted once by the opening refresh and the one
# thing that tells the two modes apart -- same class, same window, same list. Captured on open, so it says
# whatever this build says. Only the FIRST row: the same refresh goes on to paint the focused item's
# description, which the row reader says in its turn.
PokeAccess::Hooks.around_hook("ItemStorageScene", :pbStartScene, :optional => true) do |_s, nxt, _a|
  PokeAccess::PaintCapture.arm(:itemstorage_title)
  begin
    nxt.call
  ensure
    rows = PokeAccess::PaintCapture.take(:itemstorage_title)
    t = PokeAccess.clean(rows.is_a?(Array) ? rows.first.to_s : "").to_s.strip
    PokeAccess.speak(t, false) unless t.empty?
  end
end
