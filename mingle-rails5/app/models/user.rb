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

class User < ApplicationRecord
  auto_strip_attributes :name,:password, nullify: false
  default_scope -> { where(system: false) }


  include Deletion
  include UserAccess::PrivilegeLevel::UserExt
  include UserNotification

  has_one :login_access, :dependent => :destroy
  has_one :user_display_preference, :dependent => :destroy
  has_many :member_roles, :dependent => :destroy, :as => :member
  validate :validate
  validates_format_of     :login, :with => /\A[.+@_\w-]+\z/
  validates_uniqueness_of :login
  validates_length_of     :login, :within => 1..255
  validates_presence_of   :login
  before_validation       :downcase_login
  validates_presence_of  :name
  validates_exclusion_of :name, :in => [PropertyType::UserType::CURRENT_USER], :message => "cannot be set to #{PropertyType::UserType::CURRENT_USER}"

  validates_uniqueness_of   :email, :case_sensitive => false, :if => Proc.new { |user| !user.email.blank? }

  validates_length_of       :email, :if => Proc.new { |user| !user.email.blank? }, :within => 3..255
  validates_email_format_of :email, :if => Proc.new { |user| !user.email.blank? }

  # this is unfortunate, but necessary until we can move this attribute to project_membership
  validates_uniqueness_of :version_control_user_name, :allow_nil  => true
  before_validation       :trim_email_version_control_user_name

  validates_presence_of :password, :password_confirmation, :if => Proc.new {|user| user.password_changed?}
  validates_format_of :password, :with => /\A.*\W.*\z/, :message => 'needs at least one special character symbol (e.g. ".", "," or "-")',
                      :if => Proc.new {|user| user.password_changed? && Authenticator.strict_password_format?}
  validates_format_of :password, :with => /\A.*\d.*\z/, :message => 'needs at least one digit',
                      :if => Proc.new {|user| user.password_changed? && Authenticator.strict_password_format?}
  validates_length_of :password, :within => 5..40,
                      :if => Proc.new {|user| user.password_changed? && Authenticator.strict_password_format?}
  validates_confirmation_of :password,
                            :if => Proc.new {|user| user.password_changed?}

  validates_file_format_of_with_custom_message :icon, :in => %w(gif png jpg jpeg bmp tiff GIF PNG JPG JPEG BMP TIFF), :error_message => 'is an invalid format. Supported formats are BMP, GIF, JPEG and PNG.'

  validate_filesize_of_with_custom_message :icon, :in => 0..100.kilobytes, :size_bigger_warn => 'is larger than the allowed file size. Maximum file size is 100 KB.'

  after_create            { |user| user.login_access = LoginAccess.new }
  after_save              :remove_non_belonged_personal_favorites, :unless => :admin?
  after_save              { |user| ProfileServerUserSync.perform(user) }
  after_destroy              { |user| ProfileServerUserSync.perform(user, :delete) }
  before_destroy            :check_deletable?
  # before_destroy          :destroy_oauth_tokens
  # before_update           :destroy_oauth_tokens, :unsubscribe_all_history_mail, :if => proc { |user| user.newly_deactivated? }
  before_save :crypt_password, :set_admin_if_needed, :clear_admins_cache


  # use_database_limits_for_all_attributes
  # serializes_as :complete => [:id, :name, :login, :email, :light?, :icon_path, :icon_url],
  #               :compact => [:name, :login]
  # conditionally_serialize :last_login_at, :if => Proc.new { |inst| inst.last_login_at }
  # conditionally_serialize :activated, :admin?, :version_control_user_name, :if => Proc.new { User.current.project_admin? }
  #
  attr_accessor :reset_user_icon, :icon_path, :icon_url, :last_login_at
  scope :admins, -> { where admin:true }
  # named_scope :all

  if MingleConfiguration.public_icons?
    file_column :icon, :root_path => DataDir::Public.directory.pathname, :fix_file_extensions => false, :bucket_name => MingleConfiguration.icons_bucket_name, :public => true
  else
    file_column :icon, :root_path => DataDir::Public.directory.pathname, :fix_file_extensions => false
  end

  class << self
    def current
      Thread.current['user'] || User.anonymous
    end

    def current=(user)
      Thread.current['user'] = user
    end

    def find_by_email(email, *args, &block)
      where('lower(email) = ?', email.downcase).first unless email.blank?
    end

    # unscoped to include system users
    def find_from_ids(*args)
      unscoped { super }
    end

    # unscoped to include system users

    def find_by_login(login, *associations)
      unscoped { where(:login => login).includes(associations).first }
    end

    # unscoped to include system users
    def find_by_id(id, options={})
      unscoped { where options.merge(id:id) }.first
    end

    def find_by_id_exclude_system(id, options={})
      find(:first, options.merge(:conditions => {:id => id}))
    end

    def with_current(user)
      # access directly, we don't want the anonymous user
      previous = Thread.current['user']
      self.current = user
      yield(user)
    ensure
      self.current = previous
      nil
    end

    def with_current_by_id(user_id, &block)
      if user = User.find_by_id(user_id)
        with_current(user, &block)
      end
    end

    def activated_users
      where(['activated = ?', true]).count
    end

    def activated_full_users
      where(activated_full_users_conditions).count
    end

    def activated_full_users_conditions
      ['activated = ? and (light = ? or light is NULL) ', true, false]
    end

    def activated_light_users
      where(['activated = ? and light = ?', true, true]).count
    end

    def find_all_in_order
      all.smart_sort_by(&:login)
    end

    def first_admin
      admins.order('id asc').first or raise('Unable to find admin user.')
    end

    def sole_admin?(user)
      activated_admins.size == 1 && activated_admins[0].id == user.id
    end

    def activated_admins
      ThreadLocalCache.get('User.activated_admins') do
        admins.reload.select(&:activated)
      end
    end

    def with_first_admin
      unless Install::InitialSetup.need_install?
        User.first_admin.with_current do
          yield
        end
      end
    end


    def lock_against_delete(user_id)
      update_all({:locked_against_delete => true}, :id => user_id)
    end

    def release_all_user_locks
      update_all(:locked_against_delete => false)
    end

    def create_or_update_system_user(attributes)
      password = random_password
      unscoped() do
        attrs = {
            :system => true,
            :activated => false,
            :locked_against_delete => true,
            :password => password,
            :password_confirmation => password
        }.merge(attributes)
        if user = find_by_email(attrs[:email])
          user.update_attributes(attrs)
          user
        else
          create!(attrs)
        end
      end
    end

    def authenticate(login, password)
      return nil unless login
      if user = User.find_by_login(login.downcase)
        return nil if user.salt.blank? || user.password.blank?
        unscoped do
          where(login: login.downcase, password: sha_password(user.salt, password)).first
        end
      end
    end

    def sha_password(salt, password)
      (salt + sha1(password)).sha2
    end

    def no_users?
      User.count == 0
    end

    def anonymous
      User::AnonymousUser.new
    end

    def sha1(pass)
      "mingle--#{pass}--".sha1
    end

    def random_password
      password = '1,'
      schars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+}{[]\|:;/.,<>?'
      1.upto(8) { password += schars[rand(schars.length),1] }
      password
    end

    def search(query, page=nil, options={})
      users_search(query, page, options)
    end

    def search_count(query, options={})
      users_search_count(query, options)
    end

    def user_ids_has_a_team
      connection.select_values UserMembership.user_ids_sql(:distinct => true)
    end

    def create_from_email(email)
      login = email.split('@').first.downcase
      login = login.uniquify_with_succession(40) do |generated_login|
        find_by_login(generated_login)
      end

      options = { :email => email, :login => login, :name => email }

      generated_password = random_password
      create(options.merge(:password => generated_password,
                           :password_confirmation => generated_password))
    end

  end

  def admin_project_ids
    admin? ? Project.not_template.not_hidden.map(&:id) : self.member_roles.admin_project_ids
  end
  memoize :admin_project_ids

  def admin_in_any_project?
    !self.member_roles.where(permission: 'project_admin').empty?
  end
  memoize :admin_in_any_project?

  def signed_in_before?
    login_access.last_login_at.present?
  end

  def project_ids
    projects.select(:id)
  end

  def projects
    deliverables('project')
  end

  def project_names
    projects.map{|project| project.name}
  end

  def programs
    deliverables('program')
  end

  def deliverables(model)
    model = model.camelize.constantize
    deliverable_ids = UserMembership.select(:deliverable_id)
        .where(['user_memberships.user_id = ?', self.id])
        .joins(:group)
        .where(['user_memberships.group_id = groups.id AND groups.internal = ?', true]).to_sql
    model.all.where("#{model.quoted_table_name}.id IN (#{deliverable_ids})")
  end
  memoize :deliverables

  def reload(options = {})
    clear_cached_results_for :deliverables
    super(options)
  end

  def recent_users(project)
    return [] unless project
    display_preference.sort_by_recent_users(project.user_prop_values)
  end

  def current?
    self == self.class.current
  end

  def personal_views_for(project)
    personal_favorited_items_for(project, CardListView)
  end
  def personal_pages_for(project)
    personal_favorited_items_for(project, Page)
  end

  def personal_views
    personal_favorited_items_in_all_project(:personal_views_for)
  end

  def personal_pages
    personal_favorited_items_in_all_project(:personal_pages_for)
  end

  def personal_favorited_items_in_all_project(project_personal_favorited_items)
    results = favorited_project_ids.inject([]) do |views, project_id|
      Project.with_active_project(project_id) do |project|
        next if project.readonly_member?(self) && !self.admin?
        views << [project.name, send(project_personal_favorited_items, project)]
      end
      views
    end
    results.smart_sort_by{ |item| item[0] }.collect{|item| item[1].smart_sort_by(&:name) }.flatten
  end

  def personal_favorited_items_for(project, type)
    favorite_association = type == CardListView ? :favorite : :favorites
    type.find(:all, :include => favorite_association, :conditions => ['favorites.user_id = ? AND favorites.project_id = ?', id, project.id])
  end

  def favorited_project_ids
    ActiveRecord::Base.connection.select_values("(SELECT DISTINCT card_list_view.project_id FROM #{CardListView.table_name} card_list_view JOIN favorites favorite ON card_list_view.id = favorite.favorited_id AND favorite.user_id = #{id}) UNION (SELECT DISTINCT page.project_id FROM #{Page.table_name} page JOIN favorites favorite ON page.id = favorite.favorited_id AND favorite.user_id = #{id})").uniq
  end

  def update_last_login
    return if new_record?
    return unless activated?

    if (login_access.last_login_at.nil? || login_access.last_login_at.utc < (Clock.now - 1.hour).utc)
      login_access.update_attribute :last_login_at, Clock.now.utc
    end
    login_access.update_attribute :first_login_at, login_access.last_login_at unless login_access.first_login_at
  end

  def remember_me_in(container)
    login_token = "#{self.id}-#{self.password}-#{Time.now.to_i}".sha2
    self.login_access.update_attribute(:login_token, login_token)
    container['login'] = { :value => login_token, :expires => Time.now.next_year }
  end

  def forget_me(container)
    self.login_access.update_attribute(:login_token, nil)
    container.delete('login')
  end

  def full_text_search_index_string
    "#{login} #{name} #{email} #{version_control_user_name}"
  end

  def downcase_login
    self.write_attribute(:login, self.login.downcase) if self.login
  end

  def trim_email_version_control_user_name
    self.jabber_user_name = nil
    self.version_control_user_name = nil unless version_control_user_name?
    self.email = nil unless email?
  end

  def with_current(&proc)
    User.with_current(self, &proc)
  end

  def set_projects_to_admin
    if self.admin?
      self.projects.clear
      self.projects = Project.find(:all)
    end
  end

  def anonymous?
    false
  end

  def api_user?
    false
  end

  def admin_update_profile(values)
    if User.current.id == self.id && has_permission_attributes?(values)
      errors.add :base, 'You cannot update your own user permission attributes.'
      return false
    end
    update_attributes(values)
  end

  def update_profile(values)
    update_attributes(without_sensitive_field(values))
  end

  def change_password!(values)
    self.password = values[:password]
    self.password_confirmation = values[:password_confirmation]

    if save
      self.login_access.update_attributes(:lost_password_key => nil, :lost_password_reported_at => nil)
      return true
    else
      return false
    end
  end

  def password_changed?
    self.new_record? || self.password != User.find_by_id(self.id).password
  end

  def sole_admin?
    User.sole_admin?(self)
  end

  def value
    self
  end

  def accessible_projects
    Project.accessible_projects_for(self)
  end

  def accessible_templates
    Project.accessible_templates_for(self)
  end

  def all_accessible?(projects)
    projects.all?{|p| accessible?(p) }
  end

  def accessible?(project)
    project.accessible_for?(self)
  end

  def password_confirmation=(str)
    @password_confirmation = str.strip
  end

  after_update :update_on_login_change
  def update_on_login_change
    if !@old_login.blank? && (@old_login != self.login)
      projects.each do |project|
        project.with_active_project do |project|
          project.card_list_views.each do |view|
            project.user_property_definitions_with_hidden.each do |upd|
              view.rename_property_value(upd.name, @old_login, self.login) && view.save!
            end
          end
        end
      end
    end
  end

  def admin=(new_admin)
    self.write_attribute(:admin, new_admin)
    if self.admin?
      self.write_attribute(:light, false)
    end
  end

  def light=(new_light)
    self.write_attribute(:light, new_light)
    if self.light?
      self.write_attribute(:admin, false)
    end
  end

  def login=(new_login)
    @old_login = self.login
    self.write_attribute(:login, new_login)
  end

  def activation_state
    activated? ? 'activated' : 'deactivated'
  end

  def newly_deactivated?
    deactivated? && self.activated_changed?
  end

  def deactivated?
    !self.activated?
  end

  def destroy_oauth_tokens
    Oauth2::Provider::OauthToken.find_all_with(:user_id, self.id).map(&:destroy)
  end

  def member_of?(project)
    projects.include?(project)
  end

  #store is used by anonymous user
  def display_preference(store=nil)
    user_display_preference || UserDisplayPreference.default_for(self)
  end

  def murmur_author_name
    "#{name} (@#{login})"
  end

  def icon_path
    if self.icon
      url = ''
      url << '/'
      url << icon_options[:base_url] << '/'
      url << icon_relative_path
    end
  end

  def icon_url(options)
    if view_helper = options[:view_helper]
      view_helper.url_for_user_icon(self)
    end
  end

  def icon_image_options(icon_url)
    {:style => "background: #{Color.for(name)}"}
  end

  def write_boolean_attributes
    self.write_attribute(:admin, !!self.admin)
    self.write_attribute(:light, !!self.light)
    self.write_attribute(:activated, !!self.activated)
  end


  def project_admin?
    self.admin? || admin_in_any_project?
  end

  def github?
    self.login == 'github'
  end

  def project_role_candidates
    light? ? [MembershipRole[:readonly_member]] : MembershipRole.all(:project)
  end

  def invalid_role?(role)
    (light? && role != MembershipRole[:readonly_member]) || !MembershipRole.exist?(role)
  end

  def user_type=(user_type)
    @user_type = user_type
    if(user_type == 'light')
      self.light = true
    elsif(user_type == 'admin')
      self.admin = true
    end
  end

  def user_type
    @user_type || 'full'
  end

  def after_find
    # Need this method defined for observer to observe it.
  end

  def serialize_lightweight_attributes_to(serializer)
    serializer.user do
      serializer.name name
      serializer.login login
      serializer.version_control_user_name version_control_user_name
      serializer.email email
    end
  end

  def name_and_login
    "#{name} (#{login})"
  end

  def projects_visible_to(user)
    return self.projects if self == user
    self.projects.select{ |project| project.admin?(user) }
  end

  def generate_secret_key
    random_bytes = OpenSSL::Random.random_bytes(256)
    key = Base64.encode64(Digest::SHA2.new(256).digest(random_bytes))
  end

  def update_api_key
    update_attributes(:api_key => generate_secret_key)
  end

  def api_key_csv
    csv = ''
    csv_writer = MingleUpgradeHelper.ruby_1_9? ? CSV : CSV::Writer
    csv_writer.generate(csv) do |ret|
      ret << %w(access_key_id secret_access_key)
      ret << [login, api_key]
    end
    csv
  end

  def mark_trial_feedback_shown
    user_engagement.update_attributes(:trial_feedback_shown => true)
  end

  def trial_feedback_shown?
    user_engagement.trial_feedback_shown?
  end

  protected
  def validate
    if sole_admin?
      errors.add :base, "Administrator #{name} cannot be removed as they are the last admin" if !admin?
      errors.add :base, "Administrator #{name} cannot be deactivated as they are the last admin" if !activated?
    end
    validate_license
  end


  def crypt_password
    if password_changed?
      write_attribute :salt, SecureRandom.hex(32)
      write_attribute :password, self.class.sha_password(self.salt, password)
    end
  end

  before_validation :reset_icon
  def reset_icon
    if !self.icon_changed? && self.reset_user_icon == 'true'
      self.icon = nil
    end
  end

  def set_admin_if_needed
    self.admin = true if User.no_users?
  end

  def has_permission_attributes?(values)
    PERMISSION_FIELDS.each do |attribute|
      return true if values.has_key?(attribute)
    end
    false
  end

  def unsubscribe_all_history_mail
    self.projects.shift_each! do |project|
      project.history_subscriptions.all(:conditions => {:user_id => self.id}).each do |history_subscription|
        history_subscription.destroy
      end
    end
  end

  private

  def user_engagement
    UserEngagement.find_or_create_by_user_id self.id
  end

  def without_sensitive_field(attrs)
    attrs.reject do |key, value|
      SENSITIVE_FIELDS.include?(key.to_sym)
    end
  end

  def remove_non_belonged_personal_favorites
    Thread.new do
      Rails.logger.info "sleeping"
      sleep 10
      raise 'blahhhh'
      Rails.logger.info "wakin up"
    end
    favorited_project_ids.each do |project_id|
      Project.find_by_id(project_id).with_active_project do |project|
        personal_views_for(project).each(&:destroy)  unless project.member?(self)
        personal_pages_for(project).map { |page| page.favorites.personal(self) }.flatten.each(&:destroy)  unless project.member?(self)
      end
    end
  end

  def validate_license
    if User.no_users? || !activated? || system?
      return
    end
    @registration = CurrentLicense.registration

    # When the following formulas accept, it's valid license:
    #   (1) activated_light_user_size <= licensed_light_user_size + licensed_full_user_size
    #   (2) activated_full_user_size <= licensed_full_user_size
    #   (3) activated_full_user_size + activated_light_user_size <= licensed_light_user_size + licensed_full_user_size
    #
    # When we changed light from 'true' to 'false' and activated from 'false' to 'true', we need validate formula (1),
    #      and we should +1 activated user size
    # When we changed light from 'false' to 'true', we need validate formula (2),
    #      and we should +1 activated full user size
    # When we changed activated from 'false' to 'true', we need validate formula (3),
    #      and we should +1 activated user size

    formula2 = (User.activated_full_users + 1) <= @registration.max_active_full_users
    # if light changed to true (which also means it's in updating), we only care about formula (2)
    if self.changed.include?('light') && !light? && !formula2
      errors.add :base, license_warning_message(@registration)
      return
    end
    if new_record? || self.changed.include?('activated')
      activated_user_size = self.class.where(['activated = ?', true]).count + 1 # we need count self as activated
      licensed_user_size = @registration.max_active_light_users + @registration.max_active_full_users
      formula1 = User.activated_light_users <= licensed_user_size
      formula3 = activated_user_size <= licensed_user_size
      if light?
        # if it's light, validate formula (1) and (3)
        unless formula1 && formula3
          errors.add :base, license_warning_message(@registration)
        end
      else
        # if it's full, validate formula (2) and (3)
        unless formula2 && formula3
          errors.add :base, license_warning_message(@registration)
        end
      end
    end
  end

  def license_warning_message(reg)
    reg.license_warning_message || 'License validation failed'
  end

  def clear_admins_cache
    ThreadLocalCache.clear('User.activated_admins')
  end

end

class CreateFullUserWhileFullUserSeatsReachedException < StandardError
  def initialize(login)
    super("#{login} is not a registered Mingle user. Mingle was unable to create a new user as the active user count has reached the maximum user allowance. Please contact your Mingle administrator who can deactivate some of the existing users or increase the allowance.")
  end
end
