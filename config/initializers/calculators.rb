# Dedicated autoload root for calculator math, namespaced `Calculators::`.
# So `app/calculators/percentage.rb` defines `Calculators::Percentage` (a single
# directory, clean names). Adding a calculator is just adding a file here — no
# central registration (ARCHITECTURE.md §2–3).
#
# The namespace module must exist before push_dir is told to use it (a Zeitwerk
# requirement), so define it here.
module Calculators; end
Rails.autoloaders.main.push_dir(Rails.root.join("app/calculators"), namespace: Calculators)
