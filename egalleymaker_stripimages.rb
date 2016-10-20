require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker_postprocessing

# ---------------------- METHODS

# ---------------------- PROCESSES

# run content conversions
stripimagesjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-images.js")
Bkmkr::Tools.runnode(stripimagesjs, Bkmkr::Paths.outputtmp_html)