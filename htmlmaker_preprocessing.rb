require 'fileutils'

require_relative '../bookmaker/core/header.rb'

# These commands should run immediately prior to htmlmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

filetype = Bkmkr::Project.filename_split.split(".").pop

getsymbolstring_py = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "getsymbolstring.py")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

# ---------------------- METHODS

def convertDocToDocxPSscript(filetype, logkey='')
  unless filetype == "html"
    doctodocx = "S:\\resources\\bookmaker_scripts\\bookmaker_addons\\htmlmaker_preprocessing.ps1"
    `PowerShell -NoProfile -ExecutionPolicy Bypass -Command "#{doctodocx} '#{Bkmkr::Paths.project_tmp_file}'"`
  else
    logstring = 'input file is html, skipping'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getContextforUnsupportedSymbols(filetype, symbolcodes, getsymbolstring_py, logkey='')
  allsymbolreplacements = {}
  unless filetype == "html"
    # cycle through each symbol we need to replace
    symbolcodes.each { |symbolname,codes|
      thissymbolreplacementset = []
      # get the before and after strings of any occurence of the wordsymcode in the .docx xml
      symbolstrings_hash = JSON.parse(Bkmkr::Tools.runpython(getsymbolstring_py, "#{Bkmkr::Paths.project_docx_file} #{codes['wordsymcode']}"))
      # for each set of before/after strings found, create search and replace strings and push them into an array for this symbol
      unless symbolstrings_hash.empty?
        symbolstrings_hash.each { |beforestring,afterstring|
          stringreplacementset = {}
          stringreplacementset['searchstring'] = "#{beforestring}#{afterstring}"
          stringreplacementset['replacementstring'] = "#{beforestring}#{codes['replacementhtml']}#{afterstring}"
          thissymbolreplacementset << stringreplacementset
        }
        # create a hash for this symbol with replacement strings as the value, to be logged
        allsymbolreplacements[symbolname] = thissymbolreplacementset
      end
    }
  else
    logstring = 'input file is html, skipping'
  end
  return allsymbolreplacements
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeConfigJson(hash, json, logkey='')
  Mcmlln::Tools.write_json(hash, json)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES

#convert .doc to .docx via powershell script, ignore html files
convertDocToDocxPSscript(filetype, 'convert_doc_to_docx')

# items in this hash represent characters that are 'word symbol' encodings ignored by mammoth when converting to html.
# add an item to this hash to scan for re-insertion post html conversion
# the 'wordsymcode' value can be found in the document.xml and confirmed here:
#     https://gist.github.com/ptsefton/1ce30879e9cfef289356#file-gistfile1-txt-L163
# the 'htmlcode' value is the html encoding for the desired replacement character (could also be a string)
symbolcodes = {
  "copyrightsymbol" => {
		"wordsymcode" => "F0D3",
		"htmlcode" => "&#xA9;"
	}
}

# check for occurrences of word symbol items in the symbolcodes hash; if any are found write output to the json logfile
allsymbolreplacements = getContextforUnsupportedSymbols(filetype, symbolcodes, getsymbolstring_py, 'get_context_for_unsupported_symbols')
unless allsymbolreplacements.empty?
  @log_hash['allsymbolreplacements'] = allsymbolreplacements
end


# Create a temp JSON file
datahash = {}
datahash.merge!(title: "TK")
datahash.merge!(subtitle: "TK")
datahash.merge!(author: "TK")
datahash.merge!(productid: "TK")
datahash.merge!(printid: "TK")
datahash.merge!(ebookid: "TK")
datahash.merge!(imprint: "TK")
datahash.merge!(publisher: "TK")
datahash.merge!(project: "TK")
datahash.merge!(stage: "TK")
datahash.merge!(printcss: "TK")
datahash.merge!(printjs: "TK")
datahash.merge!(ebookcss: "TK")
datahash.merge!(pod_toc: "TK")
datahash.merge!(frontcover: "TK")
datahash.merge!(epubtitlepage: "TK")
datahash.merge!(podtitlepage: "TK")

# Printing the final JSON object
writeConfigJson(datahash, configfile, 'write_config_jsonfile')

# ---------------------- LOGGING
# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
