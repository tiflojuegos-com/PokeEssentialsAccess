# Class-name ALIASES, and the silent failure they cause. A fork can ship a compatibility file that declares
# the old Essentials class names as empty SUBCLASSES of the new ones -- Awakening's BES-T layer does it for
# 23 screens -- and then instantiate only the new name. A reader hooked on the old name binds to a class the
# game never constructs: it says nothing, raises nothing, and never reaches Hooks.missing either, because the
# class does exist. Two of the mod's screens were lost that way (the summary and the move relearner), and the
# modern reader, matching the new name, bound in their place and read gen-6 data through the GameData API.
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

  # The list form is what the files registering ONE body over several candidate names use. Registering on
  # both a class and its subclass makes a subclass instance read TWICE, which is the same bug seen from the
  # other side; unrelated screens that merely share a list must all survive.
  Object.const_set(:PaSpecOther, Class.new) unless Object.const_defined?(:PaSpecOther)
  eq "a covered subclass is dropped",
     eng.scene_classes("PaSpecBase", "PaSpecAlias"), ["PaSpecBase"]
  eq "an unrelated class in the same list is kept",
     eng.scene_classes("PaSpecAlias", "PaSpecOther", "PaSpecBase").sort, ["PaSpecBase", "PaSpecOther"]
  eq "and names the game does not have simply are not there",
     eng.scene_classes("PaSpecNope", "PaSpecOther"), ["PaSpecOther"]

  # era_scene, the four cases. The NAME decides while only one alias is around, which is what keeps every
  # game that already worked working -- era and class name are independent in the wild (one fangame ships
  # GameData with the v16 names and a gen-6 scene shape, and gating on the era alone left it with NEITHER
  # reader bound and the summary silent). The era only breaks the tie once a compatibility layer has put
  # both names in play and the name has stopped discriminating.
  mine    = eng.gen6? ? :gen6 : :gamedata
  theirs  = eng.gen6? ? :gamedata : :gen6
  eq "only my alias exists: I take it, whatever the era says",
     [eng.era_scene(mine, "PaSpecOther", "PaSpecNope"), eng.era_scene(theirs, "PaSpecOther", "PaSpecNope")],
     ["PaSpecOther", "PaSpecOther"]
  eq "only the OTHER reader's alias exists: not mine, either era",
     [eng.era_scene(mine, "PaSpecNope", "PaSpecOther"), eng.era_scene(theirs, "PaSpecNope", "PaSpecOther")],
     ["", ""]
  eq "both exist and it is my era: the ancestral name",
     eng.era_scene(mine, "PaSpecAlias", "PaSpecBase"), "PaSpecBase"
  eq "both exist and it is not: nothing, so the other reader has it to itself",
     eng.era_scene(theirs, "PaSpecAlias", "PaSpecBase"), ""
  eq "neither exists: nothing", eng.era_scene(mine, "PaSpecNope", "PaSpecNeither"), ""

  # The point of picking the ancestor: the hook has to fire for the class the GAME builds, which here is the
  # parent. Hooking the empty subclass instead is exactly the bug -- it binds, and never runs.
  PaSpecBase.send(:define_method, :redraw) { |n| n }
  spoken = []
  PokeAccess::Hooks.after_hook(eng.scene_class("PaSpecAlias", "PaSpecBase"), :redraw) do |_s, r, _a|
    spoken.push(r)
  end
  PaSpecBase.new.redraw(1)
  PaSpecAlias.new.redraw(2)
  eq "the parent's instances are read, and the alias's too (it inherits)", spoken, [1, 2]

  # The era gate is the other half: on a gen-6 engine the modern readers must NOT bind to the shared name,
  # and on a GameData engine the gen-6 ones must not. Each side resolves to "" off its own era, and an empty
  # name binds nothing -- the same silent no-op an absent class already is.
  gen6 = eng.gen6?
  modern = [PokeAccess::SummaryV21::SCENE, PokeAccess::MoveRelearnerV21::SCENE, PokeAccess::TrainerCardV21::SCENE]
  legacy = [PokeAccess::SummaryGen6::SCENE, PokeAccess::MoveRelearnerGen6::SCENE, PokeAccess::TrainerCard::SCENE]

  eq "off its era, every modern reader targets nothing",
     modern.map { |n| n.empty? }, [gen6, gen6, gen6]
  # The old form -- `n.empty? && !gen6` against `[!gen6, ...]` -- compared [false, false, false] with itself
  # under the only engine this file runs on, and never read a single SCENE value. What can be pinned without
  # a stand-in for every class is the invariant era_scene exists for: a gen-6 reader that DOES resolve must
  # never resolve to its modern twin's name, which is the cross-era bind that reads a v21 screen with a
  # gen-6 reader and says nothing.
  eq "no gen-6 reader resolves to its modern twin's name",
     legacy.each_with_index.map { |n, i| !n.empty? && n == modern[i] }, [false, false, false]

  # On its own era a reader still needs the class to BE there. The stub only carries the summary scene, so
  # that is the one where "right era" can be shown to actually resolve to a name -- the gen-6 relearner and
  # trainer card have no stand-in in the harness at all, which is a coverage gap, not a gate failing.
  eq "on the gen-6 engine the summary resolves to a real scene name",
     (gen6 ? !PokeAccess::SummaryGen6::SCENE.empty? : PokeAccess::SummaryGen6::SCENE.empty?), true

  # The old form asserted the literal `true`, so only an exception could fail it -- and an exception is
  # reported as "suite raised", not as this assertion. What must hold is that an empty name leaves no trace:
  # it is not a typo to be recorded, it is a reader whose era simply is not running.
  before_missing = PokeAccess::Hooks.missing.length
  PokeAccess::Hooks.after_hook("", :whatever) { |_s, _r, _a| }
  eq "an empty name registers nothing at all", PokeAccess::Hooks.missing.length, before_missing
end
