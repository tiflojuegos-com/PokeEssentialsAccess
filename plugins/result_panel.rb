module PokeAccess
  # Result Panel: a tournament's bracket (ResultPanelScene) whose cursor walks the competitors and the matches already
  # played, each opening a page of details on accept (DetailsScene). Competitors are numbered from 1 as the panel lists
  # them; the positions after them are the matches, round by round.
  module ResultPanel
    # A competitor by number as the panel shows it: "Player" is the player, a double panel's team its two members.
    def self.name_of(scene, id)
      t = PokeAccess.ivar(scene, :@trainers)[id - 1]
      names = t.is_a?(Array) ? t : [t]
      names.map { |n| n.to_s == "Player" ? PokeAccess::Engine.player.name : n.to_s }.join(" & ")
    end

    # The numbers of who passed a round (0 the first), without the title its list ends in.
    def self.passed(scene, round)
      (PokeAccess.ivar(scene, :@classified)[round] || []).select { |x| x.is_a?(Integer) }
    end

    # Who is still in as the panel shows this round: everyone in the first, those who passed the last one after it.
    def self.still_in(scene)
      round = PokeAccess.ivar_i(scene, :@round)
      return (1..PokeAccess.ivar(scene, :@trainers).length).to_a if round <= 1
      passed(scene, round - 2)
    end

    # This round's matches, paired as the bracket pairs them, or the winner once only one is left.
    def self.round_lines(scene)
      ids = still_in(scene)
      return [PokeAccess::I18n.t(:rpanel_winner, :name => name_of(scene, ids[0]))] if ids.length == 1
      (0...ids.length / 2).map { |k| versus(scene, ids[2 * k], ids[2 * k + 1]) }
    end

    # Two competitors facing each other.
    def self.versus(scene, a, b)
      PokeAccess::I18n.t(:rpanel_vs, :a => name_of(scene, a), :b => name_of(scene, b))
    end

    # A position: a competitor, with whether they are out, or a match with who won it.
    def self.entry(scene, pos)
      total = PokeAccess.ivar(scene, :@trainers).length
      return nil if pos < 1
      return match(scene, pos, total) if pos > total
      name = name_of(scene, pos)
      out = PokeAccess.ivar_i(scene, :@round) > 1 && !still_in(scene).include?(pos)
      out ? PokeAccess::I18n.t(:rpanel_out, :name => name) : name
    end

    # A match by position: each round's are half as many as the last's, the first pairing the competitors in order and
    # the next ones those who passed the round before.
    def self.match(scene, pos, total)
      round = 0
      start = total
      size = total / 2
      while pos > start + size && size > 1
        start += size
        size /= 2
        round += 1
      end
      k = pos - start - 1
      a, b = round == 0 ? [2 * k + 1, 2 * k + 2] : passed(scene, round - 1)[2 * k, 2]
      won = passed(scene, round)[k]
      return versus(scene, a, b) unless won
      PokeAccess::I18n.t(:rpanel_match, :a => name_of(scene, a), :b => name_of(scene, b), :winner => name_of(scene, won))
    end

    # The panel opened: its title and this round's matches, queued with its keys, then the entry the cursor starts on.
    def self.opened(scene)
      cursor = PokeAccess.const_at("Settings::CURSORFUNCTIONS")
      t = PokeAccess.sentences([PokeAccess.ivar(scene, :@title)] + round_lines(scene))
      t = PokeAccess::Verbosity.with_hint(t, PokeAccess::I18n.t(:rpanel_hint)) if cursor
      PokeAccess.speak(PokeAccess.clean(t), false)
      say_entry(scene) if cursor
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the entry under the cursor when it moved, queued the first time; the info key gets it either way, as the
    # details left theirs.
    def self.say_entry(scene)
      pos = PokeAccess.ivar_i(scene, :@cursor_position)
      t = entry(scene, pos)
      return unless t
      PokeAccess::Info.set_info(:text, t, t)
      PokeAccess::Cursor.announce(scene, :result_panel, pos, true, false) { t }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A page of details: what it paints but for its "-" placeholders, then the team its icons show; the first one said
    # with its keys, queued, the next ones cutting in.
    # param rows what the page painted, as PaintCapture.sample gives it
    def self.details(scene, rows)
      lines = rows.map { |r| r[0].to_s }.reject { |t| t =~ /\A[\s\-]*\z/ }
      t = PokeAccess.clean(PokeAccess.sentences(lines + [team(scene)]))
      PokeAccess::Info.set_info(:text, t, t)
      first = PokeAccess::Cursor.pending?(scene, :result_details)
      PokeAccess::Cursor.announce(scene, :result_details, PokeAccess.ivar_i(scene, :@cursor_position), true, false) do
        first ? PokeAccess::Verbosity.with_hint(t, PokeAccess::I18n.t(:rpanel_details_hint)) : t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Pokémon of a competitor's page by name, or that they are hidden where it draws a placeholder for each; nil on
    # a match's page, which draws none.
    def self.team(scene)
      icons = (1..6).map { |i| PokeAccess.sprite(scene, "pokemon#{i}") }.compact.reject { |s| s.disposed? }
      return nil if icons.empty?
      names = icons.map { |s| (s.pokemon.name rescue nil) }.compact
      return PokeAccess::I18n.t(:rpanel_team_hidden) if names.empty?
      PokeAccess::I18n.t(:rpanel_team, :list => names.join(", "))
    end
  end
end

PokeAccess::Hooks.after_hook("ResultPanelScene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::ResultPanel.opened(scene)
end
# With no direction the game is back from a page of details, and the entry is said again.
PokeAccess::Hooks.after_hook("ResultPanelScene", :pbUpdateCursor, :optional => true) do |scene, _r, args|
  PokeAccess::Cursor.reset(scene, :result_panel) if args[0].to_s.empty?
  PokeAccess::ResultPanel.say_entry(scene)
end
PokeAccess::Hooks.clear_info_on("ResultPanelScene", :pbEndScene)

PokeAccess::Hooks.around_hook("DetailsScene", :pbUpdateTrainerInfo, :optional => true) do |scene, nxt, _a|
  ret = nil
  rows = PokeAccess::PaintCapture.sample { ret = nxt.call }
  PokeAccess::ResultPanel.details(scene, rows)
  ret
end
