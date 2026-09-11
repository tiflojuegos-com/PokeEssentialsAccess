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
  # The message-drawing methods these scenes use (names vary by scene and engine). pbShowCommands is the
  # QUESTION half of a yes/no: the answers are a command window the generic reader names, the question a
  # text window nobody read. Before, since it does not return until the player has answered. Two of the
  # scenes (the summary's action menu and the frontier swap screen) take the command list FIRST and no
  # message at all, which is why the shared body (say_screen_message) reads a String and nothing else.
  SCREEN_MSG_METHODS = [:pbDisplay, :pbDisplayPaused, :pbConfirm, :pbDisplayConfirm, :pbShowCommands]
end

# This is intentional over-binding (each scene uses only some of these methods, and the names vary by
# engine), declared :optional so the typo detector does not flag dozens of legitimate cross-engine
# absences as "possible typos". Behaviour is identical (an absent method was a no-op anyway).
PokeAccess::SCREEN_MSG_SCENES.each do |cname|
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    PokeAccess::Hooks.before_hook(cname, meth, :optional => true) do |_scene, args|
      PokeAccess.say_screen_message(args)
    end
  end
end

# The item-storage TITLE ("Withdraw item" / "Toss item"), the one thing that tells the two modes apart.
# Captured on open, and only the first row painted AS A CAPTION: the modern era refreshes the item list before
# it draws the title. Both spellings of the class, as SCREEN_MSG_SCENES lists them; the Withdraw/Toss
# subclasses override only initialize, so the parent covers them.
PokeAccess::Hooks.variants(["ItemStorageScene", "ItemStorage_Scene"], :pbStartScene) do |cname|
  PokeAccess::Hooks.around_hook(cname, :pbStartScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.arm(:itemstorage_title)
    begin
      nxt.call
    ensure
      rows = PokeAccess::PaintCapture.take(:itemstorage_title, :dtex)
      t = PokeAccess.clean(rows.is_a?(Array) ? rows.first.to_s : "")
      PokeAccess.speak(t, false)
    end
  end
end
