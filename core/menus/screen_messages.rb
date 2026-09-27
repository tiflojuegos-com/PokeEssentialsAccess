# Menu screens' own prompts and results (party, bag, storage, mart, save, relearner, summary, facility shops), drawn
# on their help window outside pbMessageDisplay, read through say_screen_message; battle scenes have their own.
module PokeAccess
  # The player-facing menu scene classes, in both gen-6 and modern naming (the hook guards on existence).
  SCREEN_MSG_SCENES = [
    "PokemonScreen_Scene", "PokemonParty_Scene", "PokemonBag_Scene", "PokemonStorageScene",
    "ItemStorageScene", "ItemStorage_Scene", "TossItemScene", "WithdrawItemScene",
    "PokemonSaveScene", "PokemonSave_Scene", "MoveRelearnerScene", "MoveRelearner_Scene",
    "PokemonMartScene", "PokemonMart_Scene", "BattlePointShop_Scene", "BattleSwapScene",
    "PurifyChamberScene", "RelicStoneScene", "PokemonSummary_Scene", "PokemonSummaryScene"
  ]
  # The message-drawing methods these scenes use; pbShowCommands carries a yes/no's question (read before, as it
  # blocks), and in two scenes a command list first, which say_screen_message skips by reading only a String.
  SCREEN_MSG_METHODS = [:pbDisplay, :pbDisplayPaused, :pbConfirm, :pbDisplayConfirm, :pbShowCommands]
end

# Deliberate over-binding (each scene has only some of these methods), hence :optional: absences are not typos.
PokeAccess::SCREEN_MSG_SCENES.each do |cname|
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    PokeAccess::Hooks.before_hook(cname, meth, :optional => true) do |_scene, args|
      PokeAccess.say_screen_message(args)
    end
  end
end

# The item-storage title (Withdraw or Toss), captured on open as the first caption painted (the modern era paints
# the list first), queued. The Withdraw/Toss subclasses override only initialize, so the parent covers them.
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

# The party screen's help line ("Move to where?"): said on change, queued, after the setter runs, since a screen
# hiding the line moves its window away there.
module PokeAccess
  # Says a party screen's help line when it changed, unless its help window is hidden or moved off screen.
  def self.say_party_help(scene, text)
    win = PokeAccess.sprite(scene, "helpwindow")
    return if win && (!(win.visible rescue true) || (win.y rescue 0).to_i >= Graphics.height)
    t = PokeAccess.clean(text.to_s)
    PokeAccess.speak(t, false) if !t.empty? && PokeAccess::Cursor.changed?(scene, :party_help, t)
  end
end

["PokemonScreen_Scene", "PokemonParty_Scene"].each do |cname|
  PokeAccess::Hooks.around_hook(cname, :pbSetHelpText, :optional => true) do |scene, nxt, args|
    r = nxt.call
    PokeAccess.say_party_help(scene, args[0])
    r
  end
end

# The pause menu's info box (pbShowInfo: Safari steps and balls, the contest's catch), queued before the focused
# command; PokemonMenu_Scene on gen-6, PokemonPauseMenu_Scene from v19.
module PokeAccess
  # Says the pause menu's info box, a line of the box per piece.
  def self.say_menu_info(text)
    return unless text.is_a?(String)
    parts = text.split(/\n/).map { |l| PokeAccess.clean(l) }.reject { |l| l.empty? }
    PokeAccess.speak(parts.join(", "), false) unless parts.empty?
  end
end

["PokemonMenu_Scene", "PokemonPauseMenu_Scene"].each do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbShowInfo, :optional => true) do |_scene, args|
    PokeAccess.say_menu_info(args[0])
  end
end
