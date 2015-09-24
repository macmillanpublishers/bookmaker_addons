require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# run content conversions
htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")
args = "\"#{Bkmkr::Paths.outputtmp_html}\""
Bkmkr::Tools.runnode(htmlmakerpostprocessingjs, args)