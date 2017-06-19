require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after htmlmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

htmlmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "htmlmaker_postprocessing.js")


# ---------------------- METHODS

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

def fixNoteCallouts(html, logkey='')
  # retag Note Callout as superscript spans
  filecontents = html.gsub(/(&lt;NoteCallout&gt;)(\w*)(&lt;\/NoteCallout&gt;)/, "<sup class=\"spansuperscriptcharacterssup\">\\2</sup>")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def fixLongHyphenatedWords(html, logkey='')
  filecontents = html
  # tag & alter long-hyphen phrases that are parts or hyperlinks (so they are bypassed by the next block)
  longhyphenhyperlinks = html.scan(/(<a href="(?:(?!<a href).)*?(([a-zA-Z]+-){4,}).*?<\/a>)/)
  longhyphenhyperlinks.each do |lh|
    source = lh[0]
    newstring = lh[0].gsub(/(^.*$)/, 'LONGHYPHENHYPERLINK\1ENDLONGHYPHENHYPERLINK').gsub(/-/, "zzzzz") #(placeholders for easy cleanup gsubs)
    filecontents = filecontents.gsub(source, newstring)
  end

  # capture and replace all other long-hyphen phrases
  longstrings = html.scan(/(([a-zA-Z]+-){4,})/)
  longstrings.each do |l|
    source = l[0]
    newstring = l[0].gsub(/-/, "<span style='font-size: 2pt;'> </span>-<span style='font-size: 2pt;'> </span>")
    filecontents = filecontents.gsub(source, newstring)
  end

  # return long-hyphen-hypen strings in hyperlinks to their previous state
  taggedhyphenhyperlinks = filecontents.scan(/LONGHYPHENHYPERLINK.*?ENDLONGHYPHENHYPERLINK/)
  taggedhyphenhyperlinks.each do |th|
    source = th
    newstring = th.gsub(/LONGHYPHENHYPERLINK(.*?)ENDLONGHYPHENHYPERLINK/, '\1').gsub(/zzzzz/, "-") #(placeholders for easy cleanup gsubs)
    filecontents = filecontents.gsub(source, newstring)
  end

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

# run content conversions
localRunNode(htmlmakerpostprocessingjs, Bkmkr::Paths.outputtmp_html, 'post-processing_js')

filecontents = readOutputHtml('read_output_html')
filecontents = fixNoteCallouts(filecontents, 'fix_note_callouts')
filecontents = fixLongHyphenatedWords(filecontents, 'fix_long_hyphenated_phrases')

overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents, 'overwrite_html')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
