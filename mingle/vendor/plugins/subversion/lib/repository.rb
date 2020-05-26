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

Dir.glob(File.join(File.dirname(__FILE__), "*.jar")) { |jar| require jar }

org.tmatesoft.svn.core.internal.io.fs.FSRepositoryFactory.setup
org.tmatesoft.svn.core.internal.io.dav.DAVRepositoryFactory.setup
org.tmatesoft.svn.core.internal.io.svn.SVNRepositoryFactoryImpl.setup

class Repository

  ONE_MB = 1048576

  class NoSuchRevisionError < StandardError; end
  class DiffTooLargeException < Exception; end

  attr_reader :connection, :notice, :root_path

  def self.available?
    true
  end

  def initialize(path, version_control_users={}, name=nil, password=nil)
    url = if (path =~ /^([\w\+]+):/) && /(svn)|(http)/ =~ $1
      org.tmatesoft.svn.core.SVNURL.parseURIDecoded(path)
    else
      org.tmatesoft.svn.core.SVNURL.fromFile(java.io.File.new(path))
    end
    @connection = org.tmatesoft.svn.core.io.SVNRepositoryFactory.create(url)

    begin
      @authentication_manager = org.tmatesoft.svn.core.wc.SVNWCUtil.createDefaultAuthenticationManager(name, password)
      @location = connect_to_repository(@connection, @authentication_manager)
    rescue Exception => e
      @authentication_manager = org.tmatesoft.svn.core.wc.SVNWCUtil.createDefaultAuthenticationManager
      @location = connect_to_repository(@connection, @authentication_manager)
    end

    path = url.to_s
    @root_path = @location == "/" ? "/" : path[@connection.repository_root.to_s.size, path.size]
    @version_control_users = version_control_users
  end

  def resolve_first_revision_for_path
    first_revision=nil
    proc = Proc.new { |log| first_revision = log }
    @connection.log([self.root_path].to_java(:string),1, repository_youngest_revision_number, true, true, 1, proc)
    first_revision.revision
  end

  def close
    @connection.close_session
  end

  def empty?
    youngest_revision_number == 0
  end

  def to_path(svn_url)
    path = svn_url.getPath[@connection.location.get_path.length..-1]
    if path.blank?
      path = @root_path
    else
      root_path_is_absolute? ? path : path.gsub(/^\//, "")
    end
  end

  def path
    @connection.location
  end

  def outside_location?(changed_path)
    !@connection.getFullPath(changed_path.path).starts_with?(@connection.getLocation.get_path)
  end

  def revision_log(revision_number)
    @connection.getRevisionPropertyValue(revision_number, org.tmatesoft.svn.core.SVNRevisionProperty::LOG).getString()
  end

  def mingle_user_for(author)
    @version_control_users[author]
  end

  def path_exists_in_revision?(path, revision_number)
    !!@connection.info(path, revision_number)
  end

  def get_location(path, revision, pegRevision=youngest_revision_number)
    @connection.getLocations(path, nil, pegRevision, [revision].to_java(:long)).map do |location_entry|
      # alarm of weird code: on windows location_entry is something like [revision_number, SVNLocationEntry]
      # but on unix it is a plain SVNLocationEntry
      location_entry = location_entry[1] if location_entry.is_a?(Array)
      return location_entry.getPath
    end
  end

  def next_revisions(skip_up_to, limit)
    return [] if empty?
    return [] if skip_up_to && skip_up_to.number == youngest_revision_number

    from = skip_up_to.nil? ? resolve_first_revision_for_path : skip_up_to.number + 1
    fetch_repos_revisions(from, limit)
  end

  def revision(number)
    number = number.to_i
    fetch_repos_revisions(number, 1).first || (raise NoSuchRevisionError.new("revision #{number} does not exist"))
  end

  def ==(other)
    return false unless other.kind_of?(Repository)
    self.path == other.path
  end

  def node(path = root_path, revision_number = 'HEAD', options={})
    revision_number = repository_youngest_revision_number if revision_number == 'HEAD'
    revision_number = revision_number.to_i
    if revision_number < 1 or revision_number > repository_youngest_revision_number
      raise NoSuchRevisionError.new
    end

    path ||= self.root_path

    assert_path_in_the_location(path) unless options[:bypass_location_validation]

    begin
      svn_node = @connection.info(path, revision_number)
      raise "Node #{path} does not exist" unless svn_node
      Node.new(self, svn_node)
    rescue => e
      puts e.backtrace.join("\n") unless RAILS_ENV == 'test'
      raise NoSuchRevisionError.new(e.message)
    end
  end

  def check_revision(node)
    begin
      node.revision_number
    rescue Svn::Error
      raise NoSuchRevisionError.new
    end
    node
  end

  private

  def youngest_revision_number
    number = repository_youngest_revision_number
    if root_path_is_absolute? || number == 0
      number
    else
      node.revision_number
    end
  end

  def repository_youngest_revision_number
    @connection.latest_revision
  end

  def fetch_repos_revisions(from, limit)
    revisions= []
    map_revision_log_to_repository_revision = Proc.new do |log|
      revision = Revision.new(self)
      revision.number = log.revision
      revision.version_control_user = log.author
      revision.time = Time.from_java_date(log.date) if log.date
      revision.message = log.message
      revision.mingle_user = mingle_user_for log.author
      revision.changed_paths = log.changed_paths.collect do |path, action|
        change = Revision::ChangedPath.new(revision, @authentication_manager)
        change.path = path
        change.action = [action.type].pack('C') # convert Java character into Ruby String
        change
      end
      revision.changed_paths = revision.changed_paths.reject(&:outside_repository_location?)
      revisions << revision
    end
    @connection.log([self.root_path].to_java(:string), from, repository_youngest_revision_number, true, true, limit, map_revision_log_to_repository_revision)
    revisions
  end

  def connect_to_repository(connection, auth_manager)
    connection.authentication_manager = auth_manager
    connection.test_connection
    #make sure can get youngest revision, for user may have sub-directory access privilege which can access the connection test
    connection.info('', repository_youngest_revision_number)
    connection.get_repository_path('')
  end

  def root_path_is_absolute?
    @root_path == "/"
  end

  def assert_path_in_the_location(path)
    unless path =~ /^\//
      path = @connection.getRepositoryPath(path)
    end

    raise NoSuchRevisionError.new("Path(#{path}) is not in the location(#{@location})") unless path.gsub(/^\//, '') =~ /^#{@location.gsub(/^\//, '')}/
  end

  class Node
    attr_reader :svn_root, :entry

    def initialize(repository, entry)
      @repository = repository
      @entry = entry
    end

    def path
      @repository.to_path(@entry.get_url)
    end

    def display_path
      path.gsub(/^\/?/, '/')
    end

    def path_components
      path.gsub(/^\//, '').split('/')
    end

    def parent_path_components
      path_components[0..-2]
    end

    def parent_display_path
      parent_path_components.join('/')
    end

    def children
      revision = revision_number
      if !path_exist?(path, revision)
        revision = head_revision_number
      end

      if path_exist?(path, revision)
        result = []
        @repository.connection.getDir(path, revision, nil, result)
        result.collect {|svn_dir_entry| Node.new(@repository, svn_dir_entry)}
      else
        raise Exception.new("Path #{path.inspect} with revision #{revision} is not exist.")
      end
    end

    def binary?
      if file?
        org.tmatesoft.svn.core.SVNProperty.isBinaryMimeType(get_file_properties.getStringValue("svn:mime-type"))
      end
    end

    def file_contents(output=nil)
      if file?
        output ? write_file_content_to_stream(output) : get_file_content_as_str
      end
    end

    def file?
      @entry.kind == org.tmatesoft.svn.core.SVNNodeKind::FILE
    end

    def file_length
      @entry.size if file?
    end

    def revision_number
      @entry.revision
    end

    def revision_user
      if mingle_user = @repository.mingle_user_for(@entry.author)
        mingle_user.name
      else
        @entry.author
      end
    end

    def revision_log
      @repository.revision_log(revision_number)
    end

    def revision_time
      Time.from_java_date(@entry.date) if @entry.date
    end

    def previous_revision_node
      @repository.node(@path, revision_number - 1)
    end

    def revision
      @revision ||= @repository.revision(revision_number)
    end

    def dir?
      @entry.kind == org.tmatesoft.svn.core.SVNNodeKind::DIR
    end

    def parent_path
      return @repository.root_path if root_node?
      path.slice(0, path.rindex(name))
    end

    def name
      return @repository.root_path if root_node?
      path_components.last
    end

    def root_node?
      path_components.empty?
    end

    def path_exist?(path, revision)
      @repository.connection.checkPath(path, revision) != org.tmatesoft.svn.core.SVNNodeKind::NONE
    end

    def head_revision_number
      -1
    end

    private

    def get_file_properties
      prop = org.tmatesoft.svn.core.SVNProperties.new
      @repository.connection.getFile(content_location, revision_number, prop, nil)
      prop
    end

    def get_file_content_as_str
      stream = StringIO.new
      write_file_content_to_stream(stream)
      stream.rewind
      stream.read
    end

    def write_file_content_to_stream(stream)
      @repository.connection.getFile(content_location, revision_number, nil, org.jruby.util.IOOutputStream.new(stream))
    end

    # the real content location could be different from path, because the node may be a result of 'svn copy'
    def content_location
      return @__content_location if @__content_location
      if @repository.path_exists_in_revision?(path, revision_number)
        @repository.get_location(path, revision_number, revision_number)
      else
        @repository.get_location(path, revision_number)
      end
    end

  end

  class Revision
    class ChangedPath
      attr_accessor :path
      attr_accessor :action # 'A'dd, 'D'elete, 'R'eplace, 'M'odify

      def initialize(revision, authentication_manager)
        @revision, @authentication_manager = revision, authentication_manager
      end

      def outside_repository_location?
        repository.outside_location?(self)
      end

      def action_class
        case action.upcase
        when 'A' then 'added'
        when 'D' then 'deleted'
        when 'R' then 'replaced'
        when 'M' then 'modified'
        else 'unknown'
        end
      end

      def deleted?
        action == 'D'
      end

      def modification?
        action == 'M'
      end

      def add?
        action == 'A'
      end

      def repository
        @revision.repository
      end

      def node
        if add? || modification?
          repository.node(@path, @revision.number, :bypass_location_validation => true)
        end
      end

      def file?
        node && node.file?
      end

      def binary?
        node && node.binary?
      end

      def path_components
        node.path_components
      end

      def diff
        Svn::Fs::FileDiff.new(node.previous_revision_node.svn_root, path, node.svn_root, path)
      end

      def unified_diff
        diff_file_name = "tmp_diff_#{@revision.number}.diff"
        diff_file = Tempfile.new(diff_file_name)
        diff_stream = java.io.FileOutputStream.new(diff_file.path)

        from = org.tmatesoft.svn.core.wc.SVNRevision.create(node.previous_revision_node.revision_number)
        to = org.tmatesoft.svn.core.wc.SVNRevision.create(@revision.number)
        options = org.tmatesoft.svn.core.wc.SVNWCUtil.createDefaultOptions(true)
        diff_client = org.tmatesoft.svn.core.wc.SVNDiffClient.new(@authentication_manager, options)
        diff_client.doDiff(node.entry.getURL, from, from, to, false, true, diff_stream)
        raise DiffTooLargeException if diff_file.size >= ONE_MB
        diff_file.read
      rescue NoSuchRevisionError => e
        ""
      ensure
        diff_stream.close
        diff_file.close!
      end

      def diff_chunks
        UnifiedDiffParser.new(unified_diff).chunks
      end

      def html_diff
        return '' if node.nil? || node.dir? || node.binary?
        chunks_html = diff_chunks.collect do |chunk|
          chunk.lines.collect do |line|
            html_class = case
              when line.added? then 'new'
              when line.removed? then 'old'
              else 'context'
            end
            "<tr>" +
            "<th class='#{html_class}'>#{line.old_lineno || '&nbsp;'}</th>" +
            "<th class='#{html_class}'>#{line.new_lineno || '&nbsp;'}</th>" +
            "<td class='#{html_class}'><pre>#{CGI.escapeHTML(line.content)}</pre></td>" +
            "</tr>"
          end.join
        end.join(%{
          <tr>
            <td colspan='3' class='separator'>&nbsp;</td>
          </tr>
        })
        "<table class='diff reset-table'><caption>#{@path}</caption>#{chunks_html}</table>"
      rescue DiffTooLargeException
        html_diff_too_large
      end

      def html_diff_too_large
        "<table class='diff reset-table'><caption>#{@path}</caption><tr><th>The diff is too large to display in Mingle</th></tr></table>"
      end

    end

    attr_accessor :version_control_user, :mingle_user, :message, :number, :time, :changed_paths
    attr_reader :repository
    alias updated_at time

    def user
      mingle_user ? mingle_user.name : version_control_user
    end

    def initialize(repository)
      @repository = repository
    end

    def event_type
      :revision
    end

    def ==(other_rev)
      return false unless other_rev.kind_of?(Revision)
      other_rev.number == self.number and other_rev.repository == self.repository
    end

    def name
      "Revision #{number}"
    end

    def to_i
      number
    end

    alias commit_message message
    alias commit_time time
  end
end
