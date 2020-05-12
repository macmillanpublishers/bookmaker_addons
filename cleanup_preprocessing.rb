require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/ftp_functions.rb'


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

uploaded_image_log = "#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt"


# ---------------------- METHODS
def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def localCheckFileExist(file, logkey='')
  fileexist = Mcmlln::Tools.checkFileExist(file)
  logstring = fileexist
  return fileexist
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def localCheckFileEmpty(file, logkey='')
  fileempty = Mcmlln::Tools.checkFileEmpty(file)
  logstring = fileempty
  return fileempty
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

#wrapping ftp class method in its own separate method: to write to jsonlog here and leave class methods more general.
def ftpDeleteDir(parentfolder, childfolder, logkey='')
  Ftpfunctions.deleteFTP(parentfolder, childfolder)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def mvDocxToDone(data_hash, tmpdir_docx, done_dir, logkey='')
  if data_hash['from_rsuite'] == true && File.file?(tmpdir_docx)
		Mcmlln::Tools.moveFile(tmpdir_docx, done_dir)
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
project_dir = data_hash['project']
stage_dir = data_hash['stage']

### Commenting these out, since nothing is going to FTP.
### mvDocxToDone is really the only item left here for the RSuite toolchain. For now keeping separate,
###   but eventually may combine with cleanup or other addons-repo script
# # clean up the ftp site if files were uploaded
# fileexist = localCheckFileExist(uploaded_image_log, 'ftp_upload_image_log_exist?')
# fileempty = localCheckFileEmpty(uploaded_image_log, 'ftp_upload_image_log_empty?')
#
# ftpDeleteDir("#{project_dir}_#{stage_dir}", Metadata.pisbn, 'delete_images_off_ftp')

mvDocxToDone(data_hash, Bkmkr::Paths.project_docx_file, Metadata.final_dir, 'mv_rsuite_docx_to_done')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
