# Deliberate TWINS: the same reader copied into two profiles on purpose. Declared once, here, because TWO
# static guards need the same definition and they must not disagree -- twins_spec checks the copies stay
# identical, and coupling_spec must not mistake a twin for a profile referencing another profile.
#
# Why duplicate at all: some screens are shared by a SAGA, not by Essentials. Infinite Fusion's fusion
# chooser is in both its games, but fusion is not something every fangame has, so it does not belong in the
# core (which is for what any Essentials game ships) -- parking one saga's mechanic there would tie it in
# permanently, and leave us entangled if that saga's authors ever asked us to drop it. Profiles cannot load
# each other either. So: duplicate, and let a test carry the cost.
#
# Adding a twin is one line. If two copies must genuinely diverge, they stop being twins -- rename them and
# take them off this list, on purpose.
TWINS = [
  %w[games/infinitefusion/fusion_preview.rb games/infinitefusion_hoenn/fusion_preview.rb],
  %w[games/infinitefusion/storage_fusion.rb games/infinitefusion_hoenn/storage_fusion.rb]
]

# True when two repo-relative paths are declared copies of each other, so sharing a constant name between
# them is expected rather than a coupling violation.
def twin_pair?(a, b)
  TWINS.any? { |group| group.include?(a) && group.include?(b) }
end
