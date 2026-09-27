# Class-name aliases, a fork's old names declared as empty subclasses of the new: Engine.scene_class picks the
# ancestor, scene_classes drops covered subclasses, and era_scene lets the era decide only when both names exist.
Suite.define("scene aliases: hook the ancestral name, and let the ERA pick the content") do
  eng = PokeAccess::Engine

  Object.const_set(:PaSpecBase, Class.new) unless Object.const_defined?(:PaSpecBase)
  Object.const_set(:PaSpecAlias, Class.new(PaSpecBase)) unless Object.const_defined?(:PaSpecAlias)

  eq "with both present, the ANCESTOR wins, whichever order it is asked in",
     eng.scene_class("PaSpecAlias", "PaSpecBase"), "PaSpecBase"
  eq "and asking the other way round agrees",
     eng.scene_class("PaSpecBase", "PaSpecAlias"), "PaSpecBase"
  eq "a lone name is simply itself", eng.scene_class("PaSpecNope", "PaSpecAlias"), "PaSpecAlias"
  eq "and no name at all is nil", eng.scene_class("PaSpecNope", "PaSpecNeither"), nil

  Object.const_set(:PaSpecOther, Class.new) unless Object.const_defined?(:PaSpecOther)
  eq "a covered subclass is dropped",
     eng.scene_classes("PaSpecBase", "PaSpecAlias"), ["PaSpecBase"]
  eq "an unrelated class in the same list is kept",
     eng.scene_classes("PaSpecAlias", "PaSpecOther", "PaSpecBase").sort, ["PaSpecBase", "PaSpecOther"]
  eq "and names the game does not have simply are not there",
     eng.scene_classes("PaSpecNope", "PaSpecOther"), ["PaSpecOther"]

  mine    =eng.gen6? ? :gen6 : :gamedata
  theirs  = eng.gen6? ? :gamedata : :gen6
  gen6_run = eng.gen6?
  eq "only my alias exists: the gen-6 reader takes it on either engine, a GameData reader never on gen-6",
     [eng.era_scene(:gen6, "PaSpecOther", "PaSpecNope"), eng.era_scene(:gamedata, "PaSpecOther", "PaSpecNope")],
     ["PaSpecOther", gen6_run ? "" : "PaSpecOther"]
  eq "only the OTHER reader's alias exists: a gen-6 engine naming it the v17 way alone gives it to the gen-6 reader",
     [eng.era_scene(:gen6, "PaSpecNope", "PaSpecOther"), eng.era_scene(:gamedata, "PaSpecNope", "PaSpecOther")],
     [gen6_run ? "PaSpecOther" : "", ""]
  eq "both exist and it is my era: the ancestral name",
     eng.era_scene(mine, "PaSpecAlias", "PaSpecBase"), "PaSpecBase"
  eq "both exist and it is not: nothing, so the other reader has it to itself",
     eng.era_scene(theirs, "PaSpecAlias", "PaSpecBase"), ""
  eq "neither exists: nothing", eng.era_scene(mine, "PaSpecNope", "PaSpecNeither"), ""

  PaSpecBase.send(:define_method, :redraw) { |n| n }
  spoken = []
  PokeAccess::Hooks.after_hook(eng.scene_class("PaSpecAlias", "PaSpecBase"), :redraw) do |_s, r, _a|
    spoken.push(r)
  end
  PaSpecBase.new.redraw(1)
  PaSpecAlias.new.redraw(2)
  eq "the parent's instances are read, and the alias's too (it inherits)", spoken, [1, 2]

  gen6 = eng.gen6?
  modern = [PokeAccess::SummaryV21::SCENE, PokeAccess::MoveRelearnerV21::SCENE, PokeAccess::TrainerCardV21::SCENE]
  legacy = [PokeAccess::SummaryGen6::SCENE, PokeAccess::MoveRelearnerGen6::SCENE, PokeAccess::TrainerCard::SCENE]

  eq "off its era, every modern reader targets nothing",
     modern.map { |n| n.empty? }, [gen6, gen6, gen6]
  eq "no gen-6 reader resolves to its modern twin's name",
     legacy.each_with_index.map { |n, i| !n.empty? && n == modern[i] }, [false, false, false]

  eq "on the gen-6 engine the summary resolves to a real scene name",
     (gen6 ? !PokeAccess::SummaryGen6::SCENE.empty? : PokeAccess::SummaryGen6::SCENE.empty?), true

  before_missing = PokeAccess::Hooks.missing.length
  PokeAccess::Hooks.after_hook("", :whatever) { |_s, _r, _a| }
  eq "an empty name registers nothing at all", PokeAccess::Hooks.missing.length, before_missing
end
