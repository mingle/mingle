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


class String
  def to_path_id
    P4.remove_path_wildcards(self).gsub(/^\/+/, '').gsub(/\/$/, '')
  end
end

class NilClass
  def to_path_id
  end
end

class PerforceRepository
    
  def self.create_depots(paths)
    if paths =~ / /
      DepotPaths.new(paths.split(' ').collect { |path| DepotPath.new(path) })
    else
      DepotPath.new(paths)
    end
  end
  
  module PathUtils
    def p4_root_path?(path)
      path.to_s =~ /^\/{0,2}$/
    end
    
    def root_path?(path)
      p4_root_path?(path) || root_path(path).to_path_id == path.to_path_id
    end
  end
  
  class DepotPaths
    include PathUtils
    
    def initialize(paths)
      @paths = paths
    end
    
    def path
      @paths.collect(&:path).join(' ')
    end
    
    def root_path(path=P4::ROOT_PATH)
      path = correct_path(path)
      if p4_root_path?(path)
        P4::ROOT_PATH
      else
        path = @paths.collect { |depot_path| depot_path.root_path(path) }.compact.first
        if path
          parent_path = path.gsub(/[^\/]+\/?$/, '')
          "//#{parent_path.to_path_id}" 
        end
      end
    end
    
    def root_node(repository, changelist_number)
      children = @paths.collect{|path|path.root_node(repository, changelist_number)}.compact
      children.each(&:display_full_path_as_name)
      raise Repository::NoSuchRevisionError.new("No such revision(#{changelist_number}) of '#{path}'.") if children.empty?
      RootNode.new(repository, root_path, changelist_number, children)
    end

    def node(repository, path, changelist_number)
      path = correct_path(path)
      if root_path?(path)
        root_node(repository, changelist_number)
      else
        if depot_path = @paths.detect { |depot_path| depot_path.root_path(path) }
          depot_path.node(repository, path, changelist_number)
        else
          root_node(repository, changelist_number)
        end
      end
    end
    
    def correct_path(path)
      "//#{path.to_path_id}"
    end
  end
  
  class DepotPath
    include PathUtils
    
    attr_reader :path
    
    def initialize(path)
      @depot_path = path =~ /^#{P4::ROOT_PATH}/ ? path : "//#{path.gsub(/^\//, '')}"
      
      if @depot_path =~ /\.{1,2}$/
        @depot_path = @depot_path.gsub(/\.+$/, '') + '...'
      end
    end
    
    def path
      @depot_path
    end

    def root_path(path=P4::ROOT_PATH)
      path = correct_path(path)
      if p4_root_path?(path) || path.to_path_id =~ /^#{@depot_path.to_path_id}/
        "//#{@depot_path.to_path_id}"
      end
    end
    
    def root_node(repository, changelist_number)
      if repository.p4_file?(root_path, changelist_number)
        file_info = repository.p4_fstat(root_path, changelist_number).first
        FileNode.new(repository, file_info)
      elsif repository.p4_dir?(root_path, changelist_number)
        DirNode.new(repository, root_path, changelist_number)
      end
    end
    
    def node(repository, path, changelist_number)
      unless root_path(path)
        raise Repository::NoSuchRevisionError.new("No such revision(#{changelist_number}) of '#{path}'.")
      end
      if root_path?(path)
        result = root_node(repository, changelist_number)
        raise Repository::NoSuchRevisionError.new("No such revision(#{changelist_number}) of '#{path}'.") unless result
        result
      else
        path = correct_path(path)
        if repository.p4_dir?(path, changelist_number)
          DirNode.new(repository, path, changelist_number)
        elsif repository.p4_file?(path, changelist_number)
          file_info = repository.p4_fstat(path, changelist_number).first
          FileNode.new(repository, file_info)
        else
          raise Repository::NoSuchRevisionError.new("No such revision(#{changelist_number}) of '#{path}'.")
        end
      end
    end
    
    private
    def correct_path(path)
      return path if path =~ /^\/\//
      path = path.gsub(/^\/+/, '')
      depot_path_location = P4.to_location(@depot_path)
      path.to_path_id =~ /^#{@depot_path.to_path_id}/ ? "#{P4::ROOT_PATH}#{path}" : File.join(depot_path_location, path)
    end
  end

  attr_reader :version_control_users

  def initialize(version_control_users={}, username=nil, password=nil, repository_path='//depot/...', host='localhost', port='1666')
    @p4 = P4.new(:username => username, :password => password, :host => host, :port => port)
    raise "There is no perforce server running!" unless @p4.server_running?
    @depots = self.class.create_depots(repository_path)
    @version_control_users = version_control_users
  end

  def path
    @depots.path
  end
  
  def empty?
    youngest_revision.nil?
  end
  
  def next_changelists(skip_up_to, limit)
    return [] if empty?
    return [] if skip_up_to && skip_up_to.number == youngest_revision.number
    
    from = skip_up_to.nil? ? 1 : skip_up_to.number + 1
    to = [from + limit - 1, youngest_revision.number].min
    load_changelists(from, to)
  end
  
  def revision(number)
    load_changelists(number.to_i, number.to_i).first || (raise Repository::NoSuchRevisionError.new)
  end
  
  alias_method :next_revisions, :next_changelists
  
  def root_node(changelist_number)
    @depots.root_node(self, changelist_number)
  end
  
  def root_path(path)
    @depots.root_path(path)
  end

  def node(path = P4::ROOT_PATH, changelist_number = P4::HEAD)
    changelist_number = P4::HEAD if changelist_number == 'HEAD'
    @depots.node(self, path, changelist_number)
  end
  
  def method_missing(method, *args, &block)
    if method.to_s =~ /^p4_(.*)/
      @p4.send($1, *args, &block)
    else
      super
    end
  end
  
  private
    
  def youngest_revision
    if changelist = @p4.youngest_changelist(path)
      Changelist.new(changelist, self)
    end
  end
  
  def load_changelists(from, to)
    changelists = @p4.changelists(path, from, to)
    changelists.sort!.collect do |changelist|
      Changelist.new(changelist, self)
    end
  end

  #this is the revision instance class which is named changelist in perforce
  class Changelist
    class ChangedPath

      def initialize(revision, change)
        @revision = revision
        @change = change
      end

      def action
        @change.status
      end

      def path
        @change.path
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

      def action_class
        case action
        when 'A' then
          'added'
        when 'D' then
          'deleted'
        when 'R' then
          'replaced'
        when 'M' then
          'modified'
        else
          'unknown'
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
          @node ||= repository.node(path, @revision.number)
        end
      end

      def unified_diff
        node.diff
      end

      def diff_chunks
        UnifiedDiffParser.new(unified_diff).chunks
      end

      def html_diff
        return '' if node.nil? || node.dir? || node.binary?
        chunks_html = diff_chunks.collect do |chunk|
          chunk.lines.collect do |line|
            html_class =
                    case
                    when line.added? then
                      'new'
                    when line.removed? then
                      'old'
                    else
                      'context'
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
        "<table class='diff reset-table'><caption>#{path}</caption>#{chunks_html}</table>"
      end
    end

    def initialize(changelist, repository)
      @changelist = changelist
      @repository = repository
    end

    def version_control_user
      @changelist.developer.gsub(/@.*/, '')
    end

    def changed_paths
      @changelist.files.select { |file| @repository.root_path(file.path)}.collect{|file| ChangedPath.new(self, file)}
    end

    def user
      if mingle_user = repository.version_control_users[version_control_user]
        mingle_user.respond_to?(:name) ? mingle_user.name : mingle_user
      else
        version_control_user
      end
    end

    def number
      @changelist.number
    end

    def message
      @changelist.message
    end

    def time
      @changelist.time
    end

    def repository
      @repository
    end

    def name
      "Changelist #{number}"
    end

    def last?
      repository.youngest_revision.number == number
    end

    alias_method :commit_time, :time
    alias_method :commit_message, :message
  end
  
  class Path
    attr_reader :path, :root_path
    
    def initialize(path, root_path)
      @path = path
      @root_path = root_path
    end
    
    def root_node?
      path.to_path_id == root_path.to_path_id || path_components.empty?
    end

    def path_components
      path.gsub(/^\/+/, '').split('/')
    end
    
    def parent_path_components
      path_components[0..-2]
    end
    
    def parent_path
      return root_path if root_node?
      "//#{parent_path_components.join('/')}"
    end
    
    def name
      return root_path if root_node?
      return full_path if display_full_path_as_name?
      path_components.last
    end
    
    def display_full_path_as_name
      @display_full_path_as_name = true
    end
    
    def display_full_path_as_name?
      @display_full_path_as_name
    end

    def full_path
      path
    end

    def parent_display_path
      '//' + display_path.to_path_id.gsub(/#{name}$/, '').to_path_id
    end
    
    def display_path
      '//' + path.to_path_id
    end

  end

  class DirNode < Path
    
    def initialize(repository, path, changelist_number)
      super(path, repository.root_path(path))
      @changelist_number = changelist_number
      @repository = repository
    end
    
    def dir?
      true
    end

    def file?
      false
    end

    def binary?
      false
    end
    
    def diff
    end
    
    def file_length
    end
    
    def file_contents(output=nil)
    end
    
    def revision
    end
    
    def children
      children_matcher = P4.to_location(full_path) + '*'
      dirs = @repository.p4_dirs(children_matcher, @changelist_number).split.collect do |dir|
        DirNode.new(@repository, dir, @changelist_number)
      end
      files = @repository.p4_fstat(children_matcher, @changelist_number).reject do |file_info|
        file_info.head_action == 'delete'
      end.collect do |file_info|
        FileNode.new(@repository, file_info)
      end
      dirs + files
    end
  end
  
  class RootNode < DirNode
    def initialize(repository, path, changelist_number, children)
      super(repository, path, changelist_number)
      @children = children
    end
    
    def children
      @children
    end
    
    def display_path
      '/'
    end
  end
  
  #FileNode doesn't handle old version of file node yet.
  class FileNode < Path
    attr_reader :file_info
    def initialize(repository, file_info)
      super(file_info.depot_file, repository.root_path(file_info.depot_file))
      @repository = repository
      @file_info = file_info
    end

    def dir?
      false
    end
    
    def file?
      true
    end

    def binary?
      @file_info.head_type =~ /binary/i
    end
    
    def diff
      @repository.p4_diff2(full_path, @file_info.head_rev)
    end

    def file_contents(output=nil)
      @repository.p4_file_contents(full_path, @file_info.head_rev, output)
    end
    
    def file_length
      @file_info.file_size.to_i
    end
    
    def revision_number
      @file_info.head_change
    end
    
    def revision
      @revision ||= @repository.revision(revision_number)
    end
    
    def last_modified_time
      Time.at(@file_info.head_time.to_i)
    end
    
    def children
      []
    end
  end

end
