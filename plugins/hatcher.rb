# KYU's Hatcher, the incubator five games ship (anil, armonia, awakening, realidea, royal). The slot
# narration is PokeAccess::Incubator in core/field/incubator.rb, shared with the other incubator plugin.
#
# refresh is the whole reader. It runs on every cursor move AND once from the constructor, in all five games
# that ship this plugin (anil, armonia, awakening, realidea and royal), so it gives the opening read as well -- there is nothing left for a second hook to
# cover. update is the screen's blocking loop and was bound before it "for the opening read the loop never
# produces"; the loop does produce it, through the constructor, and that hook only ran announce into its own
# dedup on every frame of the screen.
PokeAccess::Hooks.after_hook("Hatcher", :refresh, :optional => true) { |scene, _result, _args| PokeAccess::Incubator.announce(scene) }
