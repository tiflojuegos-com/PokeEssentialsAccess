# Multiple save (v.19) (ScreenChooseFileSave), Fire Ash's save-file picker, all painted: read from its three
# repaints, the row list, the file's page and the load page's option highlight; and its save menu, whose Cancel
# builds the summary panel and closes it unseen.
module PokeAccess
  module MultiSaveV19
    # The file page's lower edge (drawn at y 32, 222 high): the rows painted under it are the load page's options.
    PANEL_BOTTOM = 254

    # The focused file and where it sits among them. The first read of a picker queues, so it follows the
    # question that opened it; moving interrupts.
    def self.say_row(screen)
      pos = PokeAccess.ivar_i(screen, :@position)
      PokeAccess::Cursor.announce(screen, :msv_row, pos, true, false) do
        if PokeAccess::Verbosity.keep?(:positions, :medium)
          PokeAccess::I18n.t(:load_slot, :n => pos + 1, :tot => PokeAccess.ivar_i(screen, :@count))
        else
          PokeAccess::I18n.t(:load_slot_bare, :n => pos + 1)
        end
      end
    end

    # The chosen file's page as drawInfor paints it, line by line: the title (first row) on its own, the page's
    # lines and team, then the options painted under the page. Read off the paint, since rebuilding it would load
    # the save file again.
    # param pairs the page's paint, as PaintCapture.sample gives it
    # param team the team line (team_text), or nil
    def self.page_text(pairs, team = nil)
      rows = Array(pairs)
      return nil if rows.empty?
      below, inside = rows[1..-1].partition { |r| r[3].is_a?(Numeric) && r[3] > PANEL_BOTTOM }
      lines = [PokeAccess.clean(rows[0][0].to_s)] + PokeAccess::PaintCapture.lines(inside) + [team.to_s] +
              PokeAccess::PaintCapture.lines(below)
      lines = lines.reject { |l| l.empty? }
      lines.empty? ? nil : lines.join(". ")
    rescue StandardError
      nil
    end

    # The saved team as the page's icons (party0, party1...) draw it, worded as the load screen words it; nil for
    # a save with no team.
    def self.team_text(screen)
      party = []
      while (icon = PokeAccess.sprite(screen, "party#{party.length}"))
        party.push((icon.pokemon rescue nil))
      end
      PokeAccess::LoadPanel.team_line(party.compact)
    end

    # The load page's highlight: the page itself continues the game, the row under it opens the Mystery
    # Gift (drawn only once the save has unlocked it).
    def self.option_text(screen)
      PokeAccess::I18n.t(PokeAccess.ivar_i(screen, :@posinfor) == 0 ? :msv_continue : :msv_gift)
    end

    # Remembers the save menu's latest answer, which is its first question's when pbStartScreen runs: 0 Save,
    # 1 Delete, 2 Cancel or back.
    def self.note_answer(answer); @answer = answer; end

    # Whether the summary panel pbStartScreen has just built will be seen: Cancel closes it before a frame is
    # drawn. With no answer seen, it will.
    def self.panel_shown?
      @answer.nil? || @answer == 0
    end
  end
end

PokeAccess::Hooks.after_hook("ScreenChooseFileSave", :textPanel, :optional => true) do |screen, _r, _a|
  PokeAccess::MultiSaveV19.say_row(screen)
end

# The page is drawn once per visit; going back to the list forgets the row, so it is read again on return.
PokeAccess::Hooks.around_hook("ScreenChooseFileSave", :drawInfor, :optional => true) do |screen, nxt, _a|
  ret = nil
  pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
  PokeAccess::Cursor.reset(screen, :msv_row)
  PokeAccess.speak(PokeAccess::MultiSaveV19.page_text(pairs, PokeAccess::MultiSaveV19.team_text(screen)), true)
  ret
end

PokeAccess::Hooks.after_hook("ScreenChooseFileSave", :choosePanelInfor, :optional => true) do |screen, _r, _a|
  PokeAccess.speak(PokeAccess::MultiSaveV19.option_text(screen), true)
end

# The save menu's questions: the first one's answer decides whether the summary panel is seen.
PokeAccess::Hooks.wrap_global("pbCustomMessageForSave", "plugin_multi_save_v19", :after) do |_args, answer|
  PokeAccess::MultiSaveV19.note_answer(answer)
end

# The summary panel is read only when it will be seen.
PokeAccess::Hooks.override(PokeAccess::SavePanel, :say, :tag => "multi_save_v19") do |_m, original, _args|
  original.call if PokeAccess::MultiSaveV19.panel_shown?
end
