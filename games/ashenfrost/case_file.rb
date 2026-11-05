# Ashen Frost's case file (Marin's Case System, edited: 3 - CaseUI.rb): the list of cases, with its main and side tabs, and
# the evidence of a case, one piece painted at a time, as bitmap text. The same evidence screen asks the player to present a
# piece (Evidence.chosen?), and a clue can be examined: a picture, transcribed or described in documents.rb.
module PokeAccess
  module AshenCase
    # The focused piece as its draw painted it, top to bottom: the name, where it was obtained, what it was for and its
    # description; said when the cursor lands on it, the info key keeping it whole.
    def self.entry(scene, rows)
      texts = PokeAccess::PaintCapture.laid_out(rows).map { |t| PokeAccess.clean(t.to_s) }.reject { |t| t.empty? }
      first = scene.instance_variable_get(:@access_case_open).nil?
      scene.instance_variable_set(:@access_case_open, true)
      return opening(scene, nil, nil) if first && texts.empty?
      return if texts.empty?
      line = PokeAccess::Verbosity.info_line(:ashen_evidence, parts(scene, texts))
      scene.instance_variable_set(:@access_case_row, PokeAccess::Info.info_text)
      opening(scene, line, texts) if first
      PokeAccess.speak(line, true) unless first
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The row's parts: the name and its place in the list, then the rest as its level asks, and the examine key on a clue.
    def self.parts(scene, texts)
      idx = PokeAccess.ivar_i(scene, :@top_index) + PokeAccess.ivar_i(scene, :@index)
      total = (PokeAccess.ivar(scene, :@evidence) || []).length
      name = PokeAccess::Verbosity.list_entry(texts[0], idx + 1, total)
      out = [[name, :brief]]
      texts[1..2].each { |t| out.push([t, :medium]) if t }
      out.push([texts[3], :full]) if texts[3]
      hint = examine_hint(scene)
      out.push([hint, :medium]) if hint && PokeAccess::Verbosity.hints?
      out
    end

    # What the examine box's picture shows while the piece can be examined: its key.
    def self.examine_hint(scene)
      box = (PokeAccess.ivar(scene, :@sprites)["examine"] rescue nil)
      return nil unless box && (box.visible rescue false)
      PokeAccess::I18n.t(:ashen_ev_examine, :key => PokeAccess::KeyHints.key(:a, "Z"))
    end

    # The screen's first words, ahead of its first piece: what it asks when it asks to present, and the count it paints.
    def self.opening(scene, line, _texts)
      found = PokeAccess.clean(((PokeAccess.ivar(scene, :@sprites)["found"].text rescue "")).to_s)
      lead = []
      lead.push(PokeAccess::I18n.t(:ashen_ev_present)) if PokeAccess.ivar(scene, :@picking)
      lead.push(found) unless found.empty?
      lead.push(line || PokeAccess::I18n.t(:ashen_ev_none))
      PokeAccess.speak(PokeAccess.sentences(lead), false)
    end

    # A clue under examination: the picture's words or its description, and the keys that close it.
    def self.examine(scene)
      list = PokeAccess.ivar(scene, :@evidence) || []
      name = list[PokeAccess.ivar_i(scene, :@top_index) + PokeAccess.ivar_i(scene, :@index)]
      text = PokeAccess::AshenDocuments.clue(name)
      return if text.nil? || text.empty?
      PokeAccess::Info.set_info(:text, text, text)
      close = PokeAccess::I18n.t(:ashen_doc_close, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(text, close), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The info key's line back on the piece, as the picture closes.
    def self.examined(scene)
      row = PokeAccess.ivar(scene, :@access_case_row)
      PokeAccess::Info.set_info(:text, row, row) if row
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The tab changed: the list's next read is a first one, queued, or a row other than the first would cut the new tab's title,
    # which ScreenTitle says on the next update.
    def self.tab_changed(scene)
      win = PokeAccess.sprite(scene, "casewindow")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
    end

    # Back on the list from a case its row is said again: on the way in, the fade's updates have read it already. The side
    # tab's keys once, where there is a side case to go to.
    def self.list_entered(scene)
      win = PokeAccess.sprite(scene, "casewindow")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win && scene.instance_variable_get(:@access_case_listed)
      scene.instance_variable_set(:@access_case_listed, true)
      return unless PokeAccess::Verbosity.hints? && !($PokemonGlobal.side_case.empty? rescue true)
      return unless PokeAccess::Cursor.changed?(scene, :ashen_case_tabs, true)
      PokeAccess.speak(PokeAccess::I18n.t(:ashen_case_tabs), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Verbosity.define_reading(:ashen_evidence, :vb_ashen_evidence, :vbh_ashen_evidence, :game)

PokeAccess::Game.define("ashenfrost") do
  before("CaseUI_Menu_Scene", :pbUpdate) { |scene, _args| PokeAccess::ScreenTitle.say(scene) }
  after("CaseUI_Menu_Scene", :switch_menu) { |scene, _ret, _args| PokeAccess::AshenCase.tab_changed(scene) }
  before("CaseUI_Menu_Scene", :pbScene) { |scene, _args| PokeAccess::AshenCase.list_entered(scene) }

  on_paint("CaseUI_Evidence", :draw_list) { |scene, rows, _args| PokeAccess::AshenCase.entry(scene, rows) }
  before("CaseUI_Evidence", :examine_evidence) { |scene, _args| PokeAccess::AshenCase.examine(scene) }
  after("CaseUI_Evidence", :examine_evidence, :hook_container => true) do |scene, _ret, _args|
    PokeAccess::AshenCase.examined(scene)
  end
  clear_info_on("CaseUI_Evidence", :dispose)
end
