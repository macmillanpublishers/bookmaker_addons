require 'fileutils'

require_relative '../bookmaker/core/header.rb'

# These commands should run immediately prior to htmlmaker

# ---------------------- VARIABLES
json_log_hash = Bkmkr::Paths.jsonlog_hash
json_log_hash[Bkmkr::Paths.thisscript] = {}
@log_hash = json_log_hash[Bkmkr::Paths.thisscript]

filetype = Bkmkr::Project.filename_split.split(".").pop

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

# ---------------------- METHODS

def convertDocToDocxPSscript(filetype, logkey, logstring=true)
  unless filetype == "html"
    doctodocx = "S:\\resources\\bookmaker_scripts\\bookmaker_addons\\htmlmaker_preprocessing.ps1"
    `PowerShell -NoProfile -ExecutionPolicy Bypass -Command "#{doctodocx} '#{Bkmkr::Paths.project_tmp_file}'"`
  else
		logstring = 'input file is html, skipping'
	end
rescue => logstring
ensure
  @log_hash[logkey] = logstring
end

def writeConfigJson(hash, json, logkey, logstring=true)
  Mcmlln::Tools.write_json(hash, json)
rescue => logstring
ensure
  @log_hash[logkey] = logstring
end

# ---------------------- PROCESSES

#convert .doc to .docx via powershell script, ignore html files
convertDocToDocxPSscript(filetype, 'convert_doc_to_docx')

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
@log_hash['completed'] = Time.now
Mcmlln::Tools.write_json(json_log_hash, Bkmkr::Paths.json_log)
