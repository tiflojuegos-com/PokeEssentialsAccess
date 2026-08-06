# royal's League Cards list ([ROYAL] Tarjetas Liga -> class TarjetasLiga_Scene): a sprite grid, @index is
# the on-screen slot and @tarjeta_elegida the actual card index into TarjetasLiga.tarjetas (each card is an
# array: [id, name, ?, description]). actualizarTarjetasPantalla redraws on every cursor move, so read the
# focused card's name and description there, deduped by the chosen card index.
PokeAccess::Game.define("royal") do
  # A card you have not unlocked yet is drawn as "???" with no action, and reading its real name and lore
  # paragraph handed a blind player the very spoiler the screen withholds -- plus no hint as to why the
  # button only buzzes there. The screen's own gate is a global, tarjeta_desbloqueada?(index), so it is asked
  # rather than guessed. "???" is what a sighted player sees; spoken, it says nothing useful, so the locked
  # state is named instead.
  after("TarjetasLiga_Scene", :actualizarTarjetasPantalla) do |scn, _ret, _args|
    i = PokeAccess.ivar(scn, :@tarjeta_elegida)
    next unless PokeAccess::Cursor.changed?(scn, :tl, i)
    unless (tarjeta_desbloqueada?(i) rescue true)
      next PokeAccess.speak("Tarjeta bloqueada", true)
    end
    card = (TarjetasLiga.tarjetas[i] rescue nil)
    next unless card.is_a?(Array)
    name = card[1].to_s
    next if name.empty?
    # Only the name and the position, which is all the list paints. The lore in card[3] is a paragraph of
    # some five hundred characters that lives on the card VIEW, opened with USE -- read here it interrupted
    # itself on every arrow and made the grid impossible to sweep. It goes to the info key instead, which is
    # where the rest of the mod puts detail a keypress away.
    total = (TarjetasLiga.tarjetas.length rescue 0)
    PokeAccess.speak_clean(PokeAccess::I18n.t(:list_entry, :name => name, :n => i + 1, :tot => total), true)
    PokeAccess::Info.set_info(:text, card[3].to_s)
  end
end
