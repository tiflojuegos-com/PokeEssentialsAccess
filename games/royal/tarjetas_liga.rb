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
  # Only the name and the position are spoken, which is all the list paints: the lore in card[3] is a
  # five-hundred-character paragraph that lives on the card VIEW (opened with USE) and read here it
  # interrupted itself on every arrow, so it goes to the info key. A locked card also drops whatever the
  # info key held, or it would answer with the previous card's lore attributed to this one.
  after("TarjetasLiga_Scene", :actualizarTarjetasPantalla) do |scn, _ret, _args|
    i = PokeAccess.ivar(scn, :@tarjeta_elegida)
    next unless PokeAccess::Cursor.changed?(scn, :tl, i)
    unless (tarjeta_desbloqueada?(i) rescue true)
      PokeAccess::Info.clear_text
      next PokeAccess.speak(PokeAccess::I18n.t(:rl_card_locked), true)
    end
    card = (TarjetasLiga.tarjetas[i] rescue nil)
    next unless card.is_a?(Array)
    name = card[1].to_s
    next if name.empty?
    total = (TarjetasLiga.tarjetas.length rescue 0)
    PokeAccess.speak_clean(PokeAccess::I18n.t(:list_entry, :name => name, :n => i + 1, :tot => total), true)
    PokeAccess::Info.set_info(:text, card[3].to_s)
  end
end

module PokeAccess
  # The single-card view (InfoTarjetasLiga_Scene): pbStartScene paints the card name and the two key hints
  # (captured through PaintCapture), and the USE branch of its own loop paints the description with
  # drawTextEx mid-loop, so that one is spoken live while pbStartActions runs.
  module RoyalTarjetaInfo
    def self.arm_desc; @desc = true; end
    def self.disarm; @desc = nil; end

    def self.desc_painted(text)
      return unless @desc
      t = PokeAccess.clean(text.to_s).to_s.strip
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  around("InfoTarjetasLiga_Scene", :pbStartScene) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:royal_card, true) { nxt.call }
  end
  around("InfoTarjetasLiga_Scene", :pbStartActions) do |_s, nxt, _a|
    PokeAccess::RoyalTarjetaInfo.arm_desc
    begin; nxt.call; ensure; PokeAccess::RoyalTarjetaInfo.disarm; end
  end
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::RoyalTarjetaInfo.desc_painted(args[5]) }
end
