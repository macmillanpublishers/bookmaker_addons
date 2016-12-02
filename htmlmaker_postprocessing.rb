require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# ---------------------- VARIABLES
json_log_hash = Bkmkr::Paths.jsonlog_hash
json_log_hash[Bkmkr::Paths.thisscript] = {}
@log_hash = json_log_hash[Bkmkr::Paths.thisscript]

htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")


# ---------------------- METHODS

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def htmlmakerRunNode(jsfile, args, logkey, logstring=true)
	Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  @log_hash[logkey] = logstring
end

def readOutputHtml(logkey, logstring=true)
	filecontents = File.read(Bkmkr::Paths.outputtmp_html)
	return filecontents
rescue => logstring
  return ''
ensure
  @log_hash[logkey] = logstring
end

def fixISBNSpans(html, logkey, logstring=true)
  # move any preceding non-digit content out of the isbn span tag
  filecontents = html.gsub(/(<span class="spanISBNisbn">)(\D+)(\d)/, "\\2\\1\\3")
  # move any trailing non-digit content out of the isbn span tag
  filecontents = filecontents.gsub(/(<span class="spanISBNisbn">\s*978(\D?\d){10})((?!(<\/span>)).*?)(<\/span>)/, "\\1\\3\\2")
  return filecontents
rescue => logstring
  return ''
ensure
  @log_hash[logkey] = logstring
end

def fixNoteCallouts(html, logkey, logstring=true)
  # retag Note Callout as superscript spans
  filecontents = html.gsub(/(&lt;NoteCallout&gt;)(\w*)(&lt;\/NoteCallout&gt;)/, "<sup class=\"spansuperscriptcharacterssup\">\\2</sup>")
  return filecontents
rescue => logstring
  return ''
ensure
  @log_hash[logkey] = logstring
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteFile(path,filecontents, logkey, logstring=true)
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  @log_hash[logkey] = logstring
end


# ---------------------- PROCESSES

# run content conversions
htmlmakerRunNode(htmlmakerpostprocessingjs, Bkmkr::Paths.outputtmp_html, 'post-processing_js')

filecontents = readOutputHtml('read_output_html')
filecontents = fixISBNSpans(filecontents, 'fix_ISBN_spans')
filecontents = fixNoteCallouts(filecontents, 'fix_note_callouts')

overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents, 'overwrite_html')

# ---------------------- LOGGING

# Write json log:
@log_hash['completed'] = Time.now
Mcmlln::Tools.write_json(json_log_hash, Bkmkr::Paths.json_log)
