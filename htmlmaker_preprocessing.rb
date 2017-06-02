require 'fileutils'

require_relative '../bookmaker/core/header.rb'

# These commands should run immediately prior to htmlmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

filetype = Bkmkr::Project.filename_split.split(".").pop

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

get_template_version_py = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "getTemplateVersion.py")

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

def checktemplate_version(filetype, get_template_version_py, logkey='')
  template_version = ''
  unless filetype == "html"
    # get_template_version_py reads custom.xml inside the .docx to return custom doc property 'Version'
    template_version = Bkmkr::Tools.runpython(get_template_version_py, "#{Bkmkr::Paths.project_docx_file}").strip()
  else
    logstring = 'input file is html, skipping'
  end
  return template_version
rescue => logstring
  return ''
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

# get document version template number if it exists
template_version = checktemplate_version(filetype, get_template_version_py, 'check_docx_template_version')
@log_hash['template_version'] = template_version

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
