require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# run content conversions
htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")
Bkmkr::Tools.runnode(htmlmakerpostprocessingjs, Bkmkr::Paths.outputtmp_html)

# set html title to match JSON
title_js = File.join(Bkmkr::Paths.core_dir, "htmlmaker", "title.js")
Bkmkr::Tools.runnode(title_js, "#{Bkmkr::Paths.outputtmp_html} \"#{Metadata.booktitle}\"")