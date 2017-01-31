require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# Find supplemental titlepages
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")


# ---------------------- METHODS

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


# ---------------------- PROCESSES

# move podtitlepage to archival dir, if it exists & is not already there
archivePodTitlePage(finalimagedir, 'archive_podtitlepage')

# move epubtitlepage to archival dir, if it exists & is not already there
archiveEpubTitlePage(finalimagedir, 'archive_epubtitlepage')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
