# Load order for the generic game modules (no .rb), loaded after core. Edit to add/reorder.
# This profile is the FALLBACK for games nobody has written a profile for, so unlike every other manifest
# it cannot name the plugins it wants: it does not know which game it is running on. :auto asks the running
# game instead -- each plugin reader is loaded when the class that gives its plugin away is present.
#
# Naming them by hand here was the alternative and it was worse in both directions: the list had to grow to
# every plugin the mod knows (so an unknown game paid for all of them), and a plugin added later was silent
# on every unsupported fangame until somebody remembered this file.
{
  :modules => %w[
    constants
  ],
  :plugins => :auto
}
