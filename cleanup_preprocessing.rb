require 'net/ftp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# clean up the ftp site if files were uploaded
uploaded_image_log = "#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt"
fileexist = Mcmlln::Tools.checkFileExist(uploaded_image_log)
fileempty = Mcmlln::Tools.checkFileEmpty(uploaded_image_log)

class Ftpfunctions
  @@ftp_username = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_username.txt")
  @@ftp_password = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
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
    files = ftp.chdir("/files/html/bookmaker/bookmakerimg/")
    ls = ftp.nlst()
    if ls.include?(parentfolder)
      files = ftp.chdir(parentfolder)
      ls = ftp.nlst()
      if ls.include?(childfolder)
        files = ftp.chdir(childfolder)
        filenames = ftp.nlst()
        filenames.each do |d|
          file = ftp.delete(d)
        end
      end
    end
    files = ftp.nlst()
    ftp.close
    return files
  end
end

Ftpfunctions.deleteFTP("#{project_dir}_#{stage_dir}", Metadata.pisbn)
