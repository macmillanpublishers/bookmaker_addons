require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# ---------------------- METHODS

def fixISBNSpans(html)
  filecontents = html.gsub(/(<span class="spanISBNisbn">)(\D+)(\d)/, "\\2\\1\\3")
  filecontents = filecontents.gsub(/(<span class="spanISBNisbn">\s*978(\D?\d){10})((?!(<\/span>)).*?)(<\/span>)/, "\\1\\3\\2")
  return filecontents
end

# ---------------------- PROCESSES

# run content conversions
htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")
Bkmkr::Tools.runnode(htmlmakerpostprocessingjs, Bkmkr::Paths.outputtmp_html)

# set html title to match JSON
title_js = File.join(Bkmkr::Paths.core_dir, "htmlmaker", "title.js")
Bkmkr::Tools.runnode(title_js, "#{Bkmkr::Paths.outputtmp_html} \"#{Metadata.booktitle}\"")

filecontents = Mcmlln::Tools.readFile(Bkmkr::Paths.outputtmp_html)
filecontents = fixISBNSpans(filecontents)

Mcmlln::Tools.overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents)