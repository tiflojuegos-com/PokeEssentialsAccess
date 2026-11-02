# Essentials BES's move info screen (MoveInfoScene, opened with the L key over the fight menu and run by its own loop
# in main): one move's name, its type and category as pictures, and its figures, target and flags as text, switched
# with the arrows. The screen repaints every frame, so it is read when the move changes: the text it paints, in paint
# order, with the type and the category that it draws as pictures put after the name.
module PokeAccess
  module BesMoveInfo
    FLAG_MARK = /\A\*\s*/
    NO_VALUE = /:\s*---\z/
    # The first figure, the power, painted as the number that stands for a power that varies.
    VARYING_POWER = /:\s*1\z/
    NONE = "---"

    # The type name the screen draws for the move: the one the game's helper works out from the battler, the weather
    # and the field, else the move's own, as the screen does.
    def self.type_name(scene)
      battler = PokeAccess.ivar(scene, :@battler)
      data = PokeAccess.ivar(scene, :@movedata)
      index = PokeAccess.ivar(scene, :@current_index)
      battle = PokeAccess.ivar(scene, :@battle)
      shown = (::MoveTypeHelper.get_move_type(battler, battler.moves[index], battle) rescue nil)
      shown = (data.type rescue nil) if shown.nil?
      PokeAccess::Data.type_name(shown)
    end

    # What the figures leave to the words of the mod: a move with no power does no damage, one whose power is the
    # engine's 1 varies, one with no accuracy never misses; the screen paints dashes for the first and the last.
    def self.worded_figures(data)
      out = []
      power = (data.basedamage rescue 2).to_i
      out.push(PokeAccess::I18n.t(:mv_power, :p => PokeAccess::MoveInfo.power_phrase(power))) if power <= 1
      if (data.accuracy rescue 1).to_i <= 0
        out.push(PokeAccess::I18n.t(:mv_acc, :a => PokeAccess::MoveInfo.accuracy_phrase(0)))
      end
      out
    end

    # The painted texts split into the name, the label and value pairs the screen draws before the flags, past those
    # worded_figures says, and the flags with their label (a flag is painted after a star); nil flags where it paints
    # none.
    def self.split(texts)
      at = texts.index { |t| t =~ FLAG_MARK }
      head = PokeAccess::PaintCapture.pair_labels(at ? texts[0...(at - 1)] : texts)
      flags = at ? texts[at..-1].map { |t| t.sub(FLAG_MARK, "") }.reject { |t| t == NONE } : []
      name = head.shift
      head.shift if head[0] =~ VARYING_POWER
      [name, head.reject { |t| t =~ NO_VALUE }, flags.empty? ? nil : "#{texts[at - 1]} #{flags.join(', ')}"]
    end

    # The move on the screen as one line.
    def self.text(scene)
      rows = PokeAccess::PaintCapture.sample { scene.draw_info }
      name, figures, flags = split(rows.map { |r| PokeAccess.clean(r[0].to_s).strip }.reject { |t| t.empty? })
      data = PokeAccess.ivar(scene, :@movedata)
      type = type_name(scene)
      parts = [name, type ? PokeAccess::I18n.t(:mv_type, :t => type) : nil,
               PokeAccess::MoveInfo.category_word((data.category rescue nil))]
      parts.concat(worded_figures(data)).concat(figures)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences(parts + [flags]))
      parts.push(flags) if PokeAccess::Verbosity.keep?(:battle_move, :medium)
      PokeAccess.sentences(parts)
    end

    # The key and the line of the screen as it stands: the move under the arrows; the line is built when it changes.
    # For SceneWatcher.reader.
    def self.reading(scene)
      index = PokeAccess.ivar(scene, :@current_index)
      return nil unless index.is_a?(Integer)
      [[index], lambda { text(scene) }]
    end
  end
end

PokeAccess::SceneWatcher.reader("MoveInfoScene", :main, :bes_move_info, :optional => true) do |scene|
  PokeAccess::BesMoveInfo.reading(scene)
end

# The screen closed over the moves, whose cursor did not move: says the focused one again.
PokeAccess::Hooks.after_hook("FightMenuDisplay", :show_move_info, :optional => true, :hook_container => true) do |disp, _r, _a|
  PokeAccess::Cursor.reset(disp, :fight_move)
  PokeAccess::Battle.read_fight_move(disp, false)
end
