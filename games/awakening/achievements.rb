# The achievements screen: page 0 is a strip of icons whose earned state exists ONLY as sprite opacity
# (255 earned, 50 not), read from the ivars plus that opacity; page 1 paints name and description, read
# by capture. The strip's Logro objects are built with the placeholder "nombre": the titles live in the
# scene's @nombrelogro (NOMBRES_LOGRO), by the same index.
module PokeAccess
  module AwkAchievements
    def self.poll(scene)
      page = PokeAccess.ivar(scene, :@page)
      sel = PokeAccess.ivar(scene, :@select)
      PokeAccess::Cursor.reset(scene, :awk_ach_detail) if page.to_i == 0
      return unless page.to_i == 0 && sel.is_a?(Integer)
      logros = PokeAccess.ivar(scene, :@logros)
      return unless logros.is_a?(Array) && sel >= 0 && sel < logros.length
      l = logros[sel]
      earned = ((l.icono.opacity rescue 0).to_i >= 255)
      PokeAccess::Cursor.announce(scene, :awk_ach, [sel, earned], true) do
        names = PokeAccess.ivar(scene, :@nombrelogro)
        name = names.is_a?(Array) ? names[sel] : nil
        name = PokeAccess.ivar(l, :@nombre) if name.nil? || name.to_s.empty?
        name = PokeAccess.clean(name.to_s).to_s.strip
        head = PokeAccess::I18n.t(:list_entry, :name => name, :n => sel + 1, :tot => logros.length)
        state = PokeAccess::I18n.t(earned ? :awk_ach_earned : :awk_ach_unearned)
        "#{head}, #{state}"
      end
    rescue StandardError
      nil
    end

    # The detail page's paint, spoken once per achievement: the game calls textoLogro twice per page turn
    # (switchPage and pbInput both call it) and once more on the way BACK to the strip, into the overlay it
    # has just hidden -- so page 0 is skipped and the read is keyed on the selection, which poll forgets.
    def self.detail(scene, rows)
      return unless PokeAccess.ivar(scene, :@page).to_i == 1
      sel = PokeAccess.ivar(scene, :@select)
      PokeAccess::Cursor.announce(scene, :awk_ach_detail, sel, true) { PokeAccess::PaintCapture.text(rows) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("Pokemon_Achievements_Scene", :update, :optional => true) do |scene, _r, _a|
    PokeAccess::AwkAchievements.poll(scene)
  end
  around("Pokemon_Achievements_Scene", :textoLogro, :optional => true) do |s, nxt, _a|
    PokeAccess::PaintCapture.arm(:awk_ach_detail)
    begin
      nxt.call
    ensure
      PokeAccess::AwkAchievements.detail(s, PokeAccess::PaintCapture.take(:awk_ach_detail))
    end
  end
end
