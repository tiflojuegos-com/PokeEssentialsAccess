# World Frontier's starter teams (StarterTeamSelector_Scene, pbChooseStarterTeam at the Pokemon Center): a list of
# team panels, each its name and the icons of its six Pokemon. The focused team is said with its place and the
# Pokemon its icons show, the title first as it opens.
module PokeAccess
  module WfStarterTeam
    # The focused team's line: its painted name, its place among the teams and its Pokemon.
    def self.line(scene)
      idx = PokeAccess.ivar(scene, :@index)
      teams = (StarterTeams::TEAMS rescue nil)
      return nil unless idx.is_a?(Integer) && teams.is_a?(Array) && teams[idx]
      name = (StarterTeams::TEAM_NAMES[idx] rescue nil) || _INTL("Equipo {1}", idx + 1)
      mons = (0...teams[idx].length).map { |j| (scene.get_cached_pokemon(idx, j) rescue nil) }.compact
      head = PokeAccess::Verbosity.list_entry(name.to_s, idx + 1, teams.length)
      names = mons.map { |pk| PokeAccess::WfSpecies.name(pk.species, (pk.form rescue 0)) }
      mons.empty? ? head : "#{head}: #{names.join(', ')}"
    end

    # After each repaint: the title as the list opens, then the focused team when it moves.
    def self.refresh(scene)
      opening = PokeAccess::Cursor.pending?(scene, :wf_starter)
      text = line(scene)
      return unless text
      PokeAccess::Info.set_info(:text, PokeAccess.clean(text))
      return unless PokeAccess::Cursor.changed?(scene, :wf_starter, PokeAccess.ivar(scene, :@index))
      text = PokeAccess.sentences([_INTL("ELIGE TU EQUIPO INICIAL"), text]) if opening
      PokeAccess.speak_clean(text, !opening)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("StarterTeamSelector_Scene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfStarterTeam.refresh(scene) }
end
