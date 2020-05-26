#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

java_import "com.thoughtworks.mingle.util.ShellOut"
java_import "org.tmatesoft.svn.core.io.SVNRepositoryFactory"

class RepositoryDriver
  CACHE = false unless defined?(CACHE)

  include Test::Unit::Assertions

  attr_accessor :user

  def initialize(name, cache = CACHE)
    @user = 'ice_user'
    @name = name.gsub(/\W/, '_')
    if !cache
      FileUtils.rm_rf(repos_dir)
      FileUtils.rm_rf(wc_dir)
    end
    @not_initialized = false
    if !File.exists?(repos_dir)
      @not_initialized = true
      yield self if block_given?
    end
  end

  def unless_initialized
    if @not_initialized
      yield self if block_given?
    end
  end

  def not_initialized_from_cache
    @not_initialized
  end

  def svnserve_conf
    File.open(repos_dir + "/conf/svnserve.conf", 'w') do |io|
      yield io
    end
  end

  def windows?
    Config::CONFIG['host_os'] =~ /mswin32/i || Config::CONFIG['host_os'] =~ /Windows/i
  end

  def start_service
    if windows?
      t = Thread.start do
        system("#{File.join(File.dirname(__FILE__), 'svnserve.exe').inspect} -d -r #{repos_dir}") rescue nil
      end
      t.wakeup
      sleep 5 # wait svnserve start
    else
      system("svnserve -d -r #{repos_dir}") rescue nil
    end
  rescue
  end

  def stop_service
    if windows?
      %x[taskkill /F /T /IM svnserve.exe] rescue nil
    else
      %x[killall -9 svnserve 2>/dev/null] rescue nil
    end
  end

  def passwd_conf
    File.open(repos_dir + "/conf/passwd", 'w') do |io|
      yield io
    end
  end

  def authz_conf
    File.open(repos_dir + "/conf/authz", 'w') do |io|
      yield io
    end
  end

  def repos_dir
    @repos_dir ||= RailsTmpDir::RepositoryDriver.repos(@name).pathname
    @repos_dir
  end

  def wc_dir
    @wc_dir ||= RailsTmpDir::RepositoryDriver.wc(@name).pathname
    @wc_dir
  end

  def repos_url
    "file:///#{repos_dir}"
  end

  def create
    FileUtils.rm_rf(repos_dir)
    FileUtils.mkdir_p(repos_dir)
    puts "Creating SVN Repository at: #{repos_dir.inspect}"
    SVNRepositoryFactory.createLocalRepository(java.io.File.new(repos_dir), false, true)
  end

  def import(local_path, message="Initial import")
    svn %{import "#{local_path}" "file:///#{repos_dir}" -m "#{message}" --username #{@user}}
  end

  def checkout
    FileUtils.rm_rf wc_dir
    svn %{co "#{repos_url}" "#{wc_dir}"}
    assert File.exists?(wc_dir)
  end

  def delete_file(file)
    file = File.join(wc_dir, file)
    svn %{del "#{file}"}
  end

  def add_file(file, content)
    file = File.join(wc_dir, file)
    File.open(file, "w+") do |io|
      io << content
    end
    svn %{add "#{file}"}
  end

  def add_directory(name)
    dir_path = File.join(wc_dir, name)
    FileUtils.mkdir_p File.expand_path(dir_path)
    svn %{add "#{dir_path}"}
  end

  def append_to_file(file, content)
    file = File.join(wc_dir, file)
    wait_for_file_actually_changed(file) do
      File.open(file, "a+") do |io|
        io << "\n" << content
      end
    end
  end

  def propset(path, property, value)
     svn %{propset #{property} "#{value}" "#{File.join(@wc_dir, path)}"}
  end

  def edit_file(file, content)
    file = File.join(wc_dir, file)
    wait_for_file_actually_changed(file) do
      File.open(file, "w") do |io|
        io << content
      end
    end
  end

  def commit(message)
    svn %{commit "#{wc_dir}" -m "#{message}" --username #{@user}}
  end

  def svn_copy(from_path, to_path)
    copy_from = File.join(repos_url, from_path)
    copy_to = File.join(repos_url, to_path)
    svn %{copy #{copy_from} #{copy_to} -m 'branching' }
  end

  def initialize_with_test_data_and_checkout
    create
    import(File.join(Rails.root, "test", "data", "test_repository"))
    checkout
    assert File.exists?(File.join(wc_dir, "a.txt"))
  end

  def commit_file_with_comment(file_name, file_content, comment)
    add_file(file_name, file_content)
    commit comment
  end

  def commit_dir_with_comment(dir_name, comment)
    add_directory(dir_name)
    commit comment
  end

  def update_file_with_comment(file_name, file_content, comment)
    append_to_file(file_name, file_content)
    commit comment
  end

  def repository
    Repository.new(repos_dir)
  end

  private
  def wait_for_file_actually_changed(file, &block)
    stamp_before = File.exist?(file) ? File.mtime(file) : nil
    sleep 1 # make sure there is interval away from last change
    yield
    timeout(30) do
      while File.mtime(file) == stamp_before
        sleep 0.1
      end
    end
  end

  def svn(*args)
    system("svn --quiet #{args.join(' ')}")
  end

  def system(cmd)
    ShellOut.INSTANCE.system("echo #{cmd.inspect} >> log/cmd.log")
    ret = ShellOut.INSTANCE.system("#{cmd} >> log/cmd.log 2>&1")
    ShellOut.INSTANCE.system("echo return code: #{ret} >> log/cmd.log")
    raise "#{cmd} failed with code #{ret}! Error: #{$!}" unless ret == 0
  end
end

