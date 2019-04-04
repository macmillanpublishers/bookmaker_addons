require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")

add_metatag_js = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "add_metatag.js")

# ---------------------- METHODS
def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
	Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def readOutputHtml(logkey='')
	filecontents = File.read(Bkmkr::Paths.outputtmp_html)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def fixNoteCallouts(html, super_cs, logkey='')
  # retag Note Callout as superscript spans
  filecontents = html.gsub(/(&lt;NoteCallout&gt;)(\w*)(&lt;\/NoteCallout&gt;)/, "<sup class=\"#{super_cs}\">\\2</sup>").gsub(/(<notecallout>)(\w*)(<\/notecallout>)/, "<sup class=\"#{super_cs}\">\\2</sup>")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteFile(path,filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
doctemplatetype = data_hash['doctemplatetype']
# setting names of hardcoded styles by template:
if doctemplatetype == 'rsuite'
  super_cs = 'supersup'
else
  super_cs = 'spansuperscriptcharacterssup'
end

# run content conversions
localRunNode(htmlmakerpostprocessingjs, "#{Bkmkr::Paths.outputtmp_html} #{doctemplatetype}", 'post-processing_js')

filecontents = readOutputHtml('read_output_html')
filecontents = fixNoteCallouts(filecontents, super_cs, 'fix_note_callouts')

overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents, 'overwrite_html')

# add meta tags to html with any custom info from submitted config.json
submitted_meta_items = [
  "author",
  "title",
  "subtitle",
  "imprint",
  "publisher"
]
for item in submitted_meta_items
  if data_hash[item] and data_hash[item] != "TK" and !data_hash[item].empty?
    localRunNode(add_metatag_js, "#{Bkmkr::Paths.outputtmp_html} \"#{item}\" \"#{data_hash[item]}\"", "add_#{item}_meta_tag")
  end
end

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
