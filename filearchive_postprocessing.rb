require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# Find supplemental titlepages
finalimagedir = File.join(Metadata.final_dir, "images")

# example: ["pre-sectionstart","sectionstart"]
# listed items, when found, will generate TEMPLATE_ERROR file in final_dir
obsolete_doctemplate_types = []
# could flag newer items, too, if we want folks to see that rsuite styles have been properly handled

helpurl = 'https://confluence.macmillan.com/display/PWG/Stylecheck+Help'

# full path to the version error file
version_error = File.join(Metadata.final_dir, "TEMPLATE_VERSION_ERROR.txt")


# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def archivePodTitlePage(finalimagedir, logkey='')
	if File.file?(Metadata.podtitlepage)
		ptpfilename = Metadata.podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
		podtitlepagearc = File.join(finalimagedir, ptpfilename)
		unless Metadata.podtitlepage == podtitlepagearc
			FileUtils.mv(Metadata.podtitlepage, podtitlepagearc)
		else
			logstring = "titlepage img is already in archival dir"
		end
	else
		logstring = "no file present"
	end
rescue => logstring
ensure
Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def archiveEpubTitlePage(finalimagedir, logkey='')
	if File.file?(Metadata.epubtitlepage)
		etpfilename = Metadata.epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
		epubtitlepagearc = File.join(finalimagedir, etpfilename)
		unless Metadata.epubtitlepage == epubtitlepagearc
			FileUtils.mv(Metadata.epubtitlepage, epubtitlepagearc)
		else
			logstring = "titlepage img is already in archival dir"
		end
	else
		logstring = "no file present"
	end
rescue => logstring
ensure
Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# If a version error file exists, delete it
## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def checkErrorFile(file, logkey='')
	if File.file?(file)
		Mcmlln::Tools.deleteFile(file)
	else
		logstring = 'n-a'
	end
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

def writeVersionErrfile(obsolete_doctemplate_types, doctemplatetype, errfile, helpurl, logkey='')
  if obsolete_doctemplate_types.include? doctemplatetype
  	File.open(errfile, 'w') do |output|
  		output.puts "This document was styled using the old Macmillan style template."
  		output.puts "\nThe bookmaker toolchain has been updated: to generate valid PDFs and ePubs you must attach the latest style template, and add Section Start styles to your document as needed."
      output.puts "\nYou can also use the Stylecheck-converter tool to update your manuscript."
      output.puts "\nFor more information please go to this page: #{helpurl}"
  	end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
doctemplate_version = data_hash['doctemplate_version']
doctemplatetype = data_hash['doctemplatetype']

# move podtitlepage to archival dir, if it exists & is not already there
archivePodTitlePage(finalimagedir, 'archive_podtitlepage')

# move epubtitlepage to archival dir, if it exists & is not already there
archiveEpubTitlePage(finalimagedir, 'archive_epubtitlepage')

# # # moving version template alert stiuff here from htmlmaker_postprocessing.rb, b/c that script pre-exists final_dir
# delete version error file if it exists
checkErrorFile(version_error, 'delete_version_errfile')

# if version error, write file for user (and email workflows? <-- not right now)
writeVersionErrfile(obsolete_doctemplate_types, doctemplatetype, version_error, helpurl, 'write_errfile_as_needed')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
