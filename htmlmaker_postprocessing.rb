require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# ---------------------- METHODS

def fixISBNSpans(html)
  # move any preceding non-digit content out of the isbn span tag
  filecontents = html.gsub(/(<span class="spanISBNisbn">)(\D+)(\d)/, "\\2\\1\\3")
  # move any trailing non-digit content out of the isbn span tag
  filecontents = filecontents.gsub(/(<span class="spanISBNisbn">\s*978(\D?\d){10})((?!(<\/span>)).*?)(<\/span>)/, "\\1\\3\\2")
  return filecontents
end

def fixNoteCallouts(html)
  # retag Note Callout as superscript spans
  filecontents = html.gsub(/(&lt;NoteCallout&gt;)(\w*)(&lt;\/NoteCallout&gt;)/, "<sup class=\"spansuperscriptcharacterssup\">\\2</sup>")
  return filecontents
end



# ---------------------- PROCESSES

# run content conversions
htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")
Bkmkr::Tools.runnode(htmlmakerpostprocessingjs, Bkmkr::Paths.outputtmp_html)

filecontents = Mcmlln::Tools.readFile(Bkmkr::Paths.outputtmp_html)
filecontents = fixISBNSpans(filecontents)
filecontents = fixNoteCallouts(filecontents)

Mcmlln::Tools.overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents)