module PokeAccess
  # Dark Horizon's Trainer Abilities (TrainerAbility, from the pause menu): five ability slots along a row, moved with
  # left and right, and Cancel below them. The focused slot is said by the name and lines the screen paints under the
  # row; the opening is led by the title and Shadow level it paints and the progress its bar shows. Unlocking one
  # (pbLevelUpSelection, a reel of the abilities on offer) is read the same way, and the level it repaints after. The
  # game defines the screen's helpers at top level, so they are hooked on TrainerAbility, the class that runs them.
  module DHAbilities
    # The slots along the row; @sel goes past ten on Cancel.
    SLOTS = 5
    # The highest Shadow level; at it the bar stays full with nothing left to unlock.
    TOP_LEVEL = 5

    # Arms the capture of what the screen paints at its top: the title and level as it opens, or, after an unlock
    # (relevel), the level it repaints, said without the title.
    def self.arm(relevel = false)
      @relevel = relevel
      PokeAccess::PaintCapture.arm(:dh_ta_open)
    end

    # The opening, queued ahead of the first slot: what pbStartScene painted (the title and "Lv: n"), the bar's
    # progress and, with a level ready, that an ability can be unlocked; after an unlock, the same without the title.
    def self.opened(scene)
      rows = PokeAccess::PaintCapture.take(:dh_ta_open, :positions)
      return if rows.nil?
      parts = rows.map { |r| PokeAccess.clean(r) }
      parts.shift if @relevel && parts.length > 1
      @relevel = false
      parts.push(PokeAccess::I18n.t(:dh_ta_progress, :n => PokeAccess.ivar_i(scene, :@shadowExp)))
      ready = PokeAccess.ivar(scene, :@levelUp) && PokeAccess.ivar_i(scene, :@shadowLevel) < TOP_LEVEL
      parts.push(PokeAccess::I18n.t(:dh_ta_unlock_ready)) if ready
      PokeAccess.speak(PokeAccess.sentences(parts), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The lines an ability paints, cleaned and in reading order, a title of only question marks (a locked slot's)
    # left out, so its line names it.
    def self.texts(rows)
      t = PokeAccess::PaintCapture.laid_out(rows).map { |r| PokeAccess.clean(r) }.reject { |r| r.empty? }
      t.shift if t.first =~ /\A\?+\z/
      t
    end

    # An ability as said: its name with its place among count, then its lines run together.
    def self.entry(lines, n, count)
      return nil if lines.empty?
      PokeAccess.sentences([PokeAccess::Verbosity.list_entry(lines[0], n, count), lines[1..-1].join(" ")])
    end

    # Runs a frame's paint of the focused slot, the block, and says the slot (say_slot); answers the paint's value.
    def self.slot(scene)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say_slot(scene, rows)
      ret
    end

    # The focused slot, when it or what it shows changed: Cancel below the row, else its ability; the first read of the
    # screen and the one after the reel queued, the screen's first one followed by the keys while hints are said, the
    # others cutting in. The info key keeps it.
    def self.say_slot(scene, rows)
      sel = PokeAccess.ivar_i(scene, :@sel)
      lines = texts(rows)
      PokeAccess::Cursor.announce(scene, :dh_ta_slot, sel > SLOTS ? :cancel : [sel, lines], true, false) do
        t = sel > SLOTS ? PokeAccess::I18n.t(:pc_cancel) : entry(lines, sel, SLOTS)
        PokeAccess::Info.set_info(:text, t, t) if t
        if t && !PokeAccess.ivar(scene, :@access_dh_ta_keys)
          scene.instance_variable_set(:@access_dh_ta_keys, true)
          t = PokeAccess::DarkHorizon.hinted(t, PokeAccess::I18n.t(:dh_ta_keys))
        end
        t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the reel, the block: its title is captured for its first read, and once it closes, chosen or given up, the
    # slot under the cursor is said again; answers the reel's value.
    def self.reel_run(scene)
      PokeAccess::Cursor.reset(scene, :dh_ta_reel)
      PokeAccess::PaintCapture.arm(:dh_ta_reel)
      begin
        yield
      ensure
        PokeAccess::PaintCapture.take(:dh_ta_reel)
        PokeAccess::Cursor.reset(scene, :dh_ta_slot)
      end
    end

    # Runs a frame's paint of the reel's focused ability, the block, and says it (say_reel); answers the paint's value.
    def self.reel(scene)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say_reel(scene, rows)
      ret
    end

    # The reel's focused ability when it changed, its place among those on offer; the first read, led by the title
    # pbLevelUpSelection painted and followed by the keys while hints are said, queued, later ones cutting in.
    def self.say_reel(scene, rows)
      lines = texts(rows)
      n = PokeAccess.ivar_i(scene, :@selLevelUp)
      title = PokeAccess::PaintCapture.take(:dh_ta_reel, :positions)
      PokeAccess::Cursor.announce(scene, :dh_ta_reel, [n, lines], true, false) do
        t = entry(lines, n, (PokeAccess.ivar(scene, :@data) || []).length)
        if t && title
          hint = PokeAccess::I18n.t(:dh_ta_reel_keys, :key => PokeAccess::KeyHints.key(:c, "C"))
          t = PokeAccess::DarkHorizon.hinted(PokeAccess.sentences(title.map { |r| PokeAccess.clean(r) } + [t]), hint)
        end
        PokeAccess::Info.set_info(:text, t, t) if t
        t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  # pbStartScene paints the title and level, then runs pbLevelUpUpdate once before the screen's loop.
  before("TrainerAbility", :pbStartScene) { |_scene, _a| PokeAccess::DHAbilities.arm }
  # An unlock repaints the level (pbLevelUpLvlUpdate), then the bar, then runs pbLevelUpUpdate again.
  before("TrainerAbility", :pbLevelUpLvlUpdate) { |_scene, _a| PokeAccess::DHAbilities.arm(true) }
  before("TrainerAbility", :pbLevelUpUpdate) { |scene, _a| PokeAccess::DHAbilities.opened(scene) }

  # The loop repaints the focused slot every frame.
  around("TrainerAbility", :pbTrainerAbilityChoiceUpdate) do |scene, nxt, _a|
    PokeAccess::DHAbilities.slot(scene) { nxt.call }
  end

  # pbLevelUpSelection paints the reel's title, fades it in and runs the reel's loop, which repaints the focused
  # ability every frame.
  around("TrainerAbility", :pbLevelUpSelection) do |scene, nxt, _a|
    PokeAccess::DHAbilities.reel_run(scene) { nxt.call }
  end
  around("TrainerAbility", :pbTrainerAbilityChoiceUpdateLevelUp) do |scene, nxt, _a|
    PokeAccess::DHAbilities.reel(scene) { nxt.call }
  end

  before("TrainerAbility", :pbEndScene) { |_scene, _a| PokeAccess::Info.clear_text }
end
