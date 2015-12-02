require 'net/ftp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

data_hash = Bkmkr::Tools.readjson(Metadata.configfile)
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# clean up the ftp site if files were uploaded
uploaded_image_log = "#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt"
fileexist = Bkmkr::Tools.checkFileExist(uploaded_image_log)
fileempty = Bkmkr::Tools.checkFileEmpty(uploaded_image_log)

class Ftpfunctions
  @@ftp_username = Bkmkr::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_username.txt")
  @@ftp_password = Bkmkr::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
  @@ftp_url = "142.54.232.104"

  def self.loginFTP(url, uname, pwd)
    ftp = Net::FTP.new("#{url}")
    ftp.login(user = "#{uname}", passwd = "#{pwd}")
    return ftp
  end

  def self.checkFTP(parentfolder, childfolder)
    ftp = Ftpfunctions.loginFTP(@@ftp_url, @@ftp_username, @@ftp_password)
    files = ftp.chdir("/files/html/bookmaker/bookmakerimg/#{parentfolder}/#{childfolder}")
    filenames = ftp.nlst()
    filenames
  end

  def self.deleteFTP(parentfolder, childfolder)
    ftp = Ftpfunctions.loginFTP(@@ftp_url, @@ftp_username, @@ftp_password)
    files = ftp.chdir("/files/html/bookmaker/bookmakerimg/#{parentfolder}/#{childfolder}")
    filenames = ftp.nlst()
    puts filenames #for testing
    filenames.each do |d|
      file = ftp.delete(d)
    end
    files = ftp.nlst()
    ftp.close
    files
    puts "final check after deletion: #{files}" #for testing
  end
end

ftpstatus = Ftpfunctions.checkFTP("#{project_dir}_#{stage_dir}", Metadata.pisbn)

unless ftpstatus.empty?
  Ftpfunctions.deleteFTP("#{project_dir}_#{stage_dir}", Metadata.pisbn)
end