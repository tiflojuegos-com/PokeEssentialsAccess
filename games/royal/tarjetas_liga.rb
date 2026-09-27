# Royal's League Cards list (TarjetasLiga_Scene), a sprite grid: @tarjeta_elegida indexes TarjetasLiga.tarjetas,
# each card [id, name, ?, description].
PokeAccess::Game.define("royal") do
  # The focused card by name and place, its lore on the info key; a locked card is said as locked (the screen
  # draws "???"), with no lore. The grid repaints every frame, so the card is said again on the way back from it.
  after("TarjetasLiga_Scene", :actualizarTarjetasPantalla) do |scn, _ret, _args|
    i = PokeAccess.ivar(scn, :@tarjeta_elegida)
    back = PokeAccess::RoyalTarjetaInfo.back!
    next unless PokeAccess::Cursor.changed?(scn, :tl, i) || back
    total = (TarjetasLiga.tarjetas.length rescue 0)
    unless (tarjeta_desbloqueada?(i) rescue true)
      PokeAccess::Info.clear_text
      next PokeAccess.speak(PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(:rl_card_locked), i + 1, total), true)
    end
    card = (TarjetasLiga.tarjetas[i] rescue nil)
    next unless card.is_a?(Array)
    name = card[1].to_s
    next if name.empty?
    PokeAccess.speak_clean(PokeAccess::Verbosity.list_entry(name, i + 1, total), true)
    PokeAccess::Info.set_info(:text, card[3].to_s)
  end

  after("TarjetasLiga_Scene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
end

module PokeAccess
  # The single-card view (InfoTarjetasLiga_Scene): what pbStartScene paints (name, key hints), then the description
  # drawTextEx paints while pbStartActions runs; closing it sends the list back to its focused card.
  module RoyalTarjetaInfo
    def self.arm_desc; @desc = true; end
    def self.disarm; @desc = nil; end

    # Marks the card view closed, and answers (once) whether it was, for the list's next repaint.
    def self.closed; @back = true; end
    def self.back!
      b = @back
      @back = nil
      b
    end

    def self.desc_painted(text)
      return unless @desc
      t = PokeAccess.clean(text.to_s)
      PokeAccess.speak(t, true)
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
  after("InfoTarjetasLiga_Scene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::RoyalTarjetaInfo.closed }
end
