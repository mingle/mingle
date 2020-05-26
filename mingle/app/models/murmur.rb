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

class Murmur < ActiveRecord::Base
  include UrlWriterWithFullPath, ::API::XMLSerializer, Messaging::MessageProvider
  include MurmurReplyTemplate

  class InvalidArgumentError < StandardError
  end

  attr_accessor :session_id, :replying_to_murmur_id

  belongs_to :project
  belongs_to :conversation
  belongs_to :author, :class_name => "User", :foreign_key => 'author_id'

  named_scope :order_by_origin_id_and_created_at, :order => 'origin_id ASC, created_at DESC'

  validates_presence_of :murmur
  alias :author_without_check :author

  after_create :create_conversation
  before_save :strip_murmur

  serializes_as :complete => [:id, :author, :body, :created_at, :is_truncated, :stream], :element_name => 'murmur'

  elastic_searchable :json => { :only  => [:murmur, :project_id],
    :include => { :author => {:only => [:name, :email, :login, :version_control_user_name] } } },
  :index_name => Project.index_name

  class << self
    def default_url_options; {}; end

    def query_without_cursor(params={})
      query(params.merge(:since_id => nil, :before_id => nil))
    end

    def query(params={})
      order = params[:since_id] ? "ASC" : "DESC"
      page = params[:page]

      murmurs = paginate(:all, :per_page => PAGINATION_PER_PAGE_SIZE, :page => page, :order => "#{quoted_table_name}.id #{order}", :include => 'author', :conditions => cursor_conditions(params[:since_id], params[:before_id]))
      murmurs = murmurs.reverse if order == "ASC"

      (page.to_i > murmurs.total_pages.to_i) ? [] : murmurs
    end

    def cursor_conditions(since_id, before_id)
      conditions = []
      bindings = []
      if since_id
        raise InvalidArgumentError.new('since_id is invalid') unless since_id.to_s =~ /\d+/
        conditions << "#{quoted_table_name}.id > ?"
        bindings << since_id
      end

      if before_id
        raise InvalidArgumentError.new('before_id is invalid') unless before_id.to_s =~ /\d+/
        conditions << "#{quoted_table_name}.id < ?"
        bindings << before_id
      end

      [conditions.join(" AND "), *bindings]
    end
  end

  def author
    author_without_check
  end

  def user_display_name
    author.try(:name)
  end

  def stream
    Murmur::Stream.default
  end

  def describe_context; ''; end

  def posting_info(view_helper)
    "murmured #{view_helper.date_time_lapsed_in_words_for_project(created_at, project)}"
  end

  def created_from_email?
    self.source == 'email'
  end

  def created_by_user
    author
  end

  def is_truncated(options)
    body(options) != murmur
  end

  def body(options)
    options[:truncate] ? truncated_body : murmur
  end

  def truncated_body
    murmur[0..996]
  end

  def body=(body)
    self.murmur = body
  end

  def describe_origin
  end

  def page_number
    (Murmur.connection.select_value("select count(*) from #{Murmur.table_name} where id >= #{id} and project_id = #{project.id}").to_f / PAGINATION_PER_PAGE_SIZE.to_f).ceil
  end

  def mentioned_current_user?
    mentioned_users.include?(User.current)
  end

  def mentioned_users
    user_mentions.users
  end

  def create_conversation
    unless replying_to_murmur_id.blank?
      parent_murmur = project.murmurs.find(replying_to_murmur_id)
      conversation = parent_murmur.conversation || project.conversations.create
      conversation.murmurs << parent_murmur
      conversation.murmurs << self
    end
  end

  def mentions
    user_mentions.mentions
  end

  def origin_type_description
    self.origin_type && self.origin ? "##{self.origin.number}" : 'Project'
  end

  private

  def user_mentions
    @mention ||= MurmurUserMentions.new(Project.current || self.project, self.murmur)
  end

  def strip_murmur
    self.murmur = murmur.strip
  end

  class Stream
    include API::XMLSerializer
    uses_custom_serialization

    attr_reader :murmur_type, :origin

    COMMENT_TYPE = 'comment'
    DEFAULT_TYPE = 'default'

    class << self
      def comment(origin)
        self.new(COMMENT_TYPE, origin)
      end

      def default
        self.new(DEFAULT_TYPE)
      end
    end

    def initialize(murmur_type, origin = nil)
      @murmur_type, @origin = murmur_type, origin
    end

    def to_xml(options = {})
      b = options[:builder]
      b.tag!('stream', 'type' => murmur_type) do
        next unless murmur_type == COMMENT_TYPE
        if origin
          origin.to_xml(options.merge(:element_name => 'origin'))
        else
          b.tag! 'origin', :nil => true
        end
      end
    end
  end
end
