-- 
--  Copyright 2020 ThoughtWorks, Inc.
--  
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as
--  published by the Free Software Foundation, either version 3 of the
--  License, or (at your option) any later version.
--  
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--  
--  You should have received a copy of the GNU Affero General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
-- 
create sequence TABLE_SEQUENCES_SEQ;

create sequence MURMURS_SEQ;

create sequence MURMUR_CHANNELS_SEQ;

create sequence STALE_PROP_DEFS_SEQ;

create sequence OAUTH_CLIENTS_SEQ;

create sequence MURMURS_READ_COUNTS_SEQ;

create sequence CARD_MURMUR_LINKS_SEQ;

create sequence PROGRAM_DEPENDENCY_VIEWS_SEQ;

create sequence TABS_SEQ;

create sequence OAUTH_TOKENS_SEQ;

create sequence OAUTH_AUTHORIZATIONS_SEQ;

create sequence OBJECTIVE_TYPES_SEQ;

create sequence OBJ_PROP_MAPPINGS_SEQ;

create sequence OBJ_PROP_DEFS_SEQ;

create sequence GROUPS_SEQ;

create sequence LUAU_CONFIGS_SEQ;

create sequence CORRECTION_CHANGES_SEQ;

create sequence LOGIN_ACCESS_SEQ;

create sequence PROJECTS_L6DD567D8EC3E191C_SEQ;

create sequence LUAU_TRANSACTION_COUNTER NOCACHE ORDER;

create sequence OBJECTIVE_FILTERS_SEQ;

create sequence LUAU_GROUPS_MAPPINGS_SEQ;

create sequence OBJECTIVE_VERSIONS_SEQ;

create sequence MEMBER_ROLES_SEQ;

create sequence LUAU_GROUPS_SEQ;

create sequence LUAU_GROUP_USER_MAPPINGS_SEQ;

create sequence WORKS_SEQ;

create sequence BACKLOG_OBJECTIVES_SEQ;

create sequence USER_MEMBERSHIPS_SEQ;

create sequence LUAU_GROUP_MEMBERSHIPS_SEQ;

create sequence DELIVERABLES_SEQ;

create sequence LUAU_LOCK_FAIL_SEQ;

create sequence USER_FILTER_USAGES_SEQ;

create sequence OBJECTIVE_SNAPSHOTS_SEQ;

create sequence CACHE_KEYS_SEQ;

create sequence OBJECTIVES_SEQ;

create sequence BACKLOGS_SEQ;

create sequence PROGRAM_PROJECTS_SEQ;

create sequence PLANS_SEQ;

create sequence SAAS_TOS_SEQ;

create sequence TAB_POSITIONS_SEQ;

create sequence GITHUBS_SEQ;

create sequence USER_ENGAGEMENTS_SEQ;

create sequence TODOS_SEQ;

create sequence CONVERSATIONS_SEQ;

create sequence CHECKLIST_ITEMS_SEQ;

create sequence DEPENDENCIES_SEQ;

create sequence DEPENDENCY_RESOLVING_CARDS_SEQ;

create sequence DEPENDENCY_VIEWS_SEQ;

create sequence DEPENDENCY_VERSIONS_SEQ;

create sequence OBJ_PROP_VALUES_SEQ;

create sequence EXPORTS_SEQ;

create sequence OBJ_PROP_VALUE_MAPPINGS_SEQ;

create sequence GIT_CONFIGURATIONS_SEQ;

create sequence HG_CONFIGURATIONS_SEQ;

create sequence TFSSCM_CONFIGURATIONS_SEQ;

create sequence PERFORCE_CONFIGURATIONS_SEQ;

create sequence ATTACHINGS_SEQ;

create sequence ATTACHMENTS_SEQ;

create sequence CARD_LIST_VIEWS_SEQ;

create sequence CARD_REVISION_LINKS_SEQ;

create sequence CARD_VERSIONS_SEQ;

create sequence CARDS_SEQ;

create sequence CARD_TYPES_SEQ;

create sequence ENUMERATION_VALUES_SEQ;

create sequence HISTORY_SUBSCRIPTIONS_SEQ;

create sequence LICENSES_SEQ;

create sequence PAGE_VERSIONS_SEQ;

create sequence PAGES_SEQ;

create sequence FAVORITES_SEQ;

create sequence PROPERTY_DEFINITIONS_SEQ;

create sequence REVISIONS_SEQ;

create sequence TAGGINGS_SEQ;

create sequence TAGS_SEQ;

create sequence TRANSITION_ACTIONS_SEQ;

create sequence TRANSITION_PREREQUISITES_SEQ;

create sequence TRANSITIONS_SEQ;

create sequence SESSIONS_SEQ;

create sequence USERS_SEQ;

create sequence EVENTS_SEQ;

create sequence CHANGES_SEQ;

create sequence PROPERTY_TYPE_MAPPINGS_SEQ;

create sequence CARD_ID_SEQUENCE;

create sequence TREE_CONFIGURATIONS_SEQ;

create sequence SUBVERSION_CONFIGURATIONS_SEQ;

create sequence CARD_DEFAULTS_SEQ;

create sequence PROJECT_VARIABLES_SEQ;

create sequence TREE_BELONGINGS_SEQ;

create sequence ASYNCH_REQUESTS_SEQ;

create sequence USER_DISPLAY_PREFERENCES_SEQ;

create sequence VARIABLE_BINDINGS_SEQ;

create sequence CARD_VERSION_ID_SEQUENCE;

create table ASYNCH_REQUESTS (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 status varchar2(1020),
 progress_message varchar2(4000),
 error_count number(38,0) default 0  not null,
 warning_count number(38,0) default 0,
 total number(38,0) default 1  not null,
 completed number(38,0) default 0  not null,
 type varchar2(1020),
 message clob,
 deliverable_identifier varchar2(1020) not null,
 tmp_file varchar2(1020));

create table ATTACHINGS (
 id number(38,0) not null primary key ,
 attachment_id number(38,0) not null,
 attachable_id number(38,0) not null,
 attachable_type varchar2(1020));

create table ATTACHMENTS (
 id number(38,0) not null primary key ,
 "FILE" varchar2(1020) default ''  not null,
 path varchar2(1020) default ''  not null,
 project_id number(38,0) not null);

create table BACKLOGS (
 id number(38,0) not null primary key ,
 program_id number(38,0));

create table BACKLOG_OBJECTIVES (
 id number(38,0) not null primary key ,
 name varchar2(320),
 backlog_id number(38,0),
 position number(38,0),
 "SIZE" number(38,0) default 0  not null,
 value number(38,0) default 0  not null,
 "NUMBER" number(38,0),
 value_statement clob,
 program_id number(38,0));

create table CACHE_KEYS (
 id number(38,0) not null primary key ,
 deliverable_id number(38,0),
 structure_key varchar2(1020),
 created_at date,
 updated_at date,
 card_key varchar2(1020),
 feed_key varchar2(1020),
 deliverable_type varchar2(1020) default 'Project'  not null);

create table CARDS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 "NUMBER" number(38,0) not null,
 description clob,
 created_at date not null,
 updated_at date not null,
 version number(38,0),
 card_type_name varchar2(1020) not null,
 has_macros number(1,0) default 0  not null,
 project_card_rank number,
 caching_stamp number(38,0) default 0  not null,
 name varchar2(1020) not null,
 created_by_user_id number(38,0) not null,
 modified_by_user_id number(38,0) not null,
 redcloth number(1,0));

create table CARD_DEFAULTS (
 id number(38,0) not null primary key ,
 card_type_id number(38,0) not null,
 project_id number(38,0) not null,
 description clob,
 redcloth number(1,0));

create table CARD_LIST_VIEWS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 name varchar2(1020) default ''  not null,
 canonical_string clob default null,
 params clob,
 created_at date,
 updated_at date);

create table CARD_MURMUR_LINKS (
 id number(38,0) not null primary key ,
 card_id number(38,0),
 project_id number(38,0),
 murmur_id number(38,0));

create table CARD_REVISION_LINKS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 card_id number(38,0) not null,
 revision_id number(38,0) not null);

create table CARD_TYPES (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 name varchar2(1020) not null,
 color varchar2(1020),
 position number(38,0));

create table CARD_VERSIONS (
 id number(38,0) not null primary key ,
 card_id number(38,0),
 version number(38,0),
 project_id number(38,0),
 "NUMBER" number(38,0),
 name varchar2(1020) default '',
 description clob,
 created_at date,
 updated_at date,
 created_by_user_id number(38,0) default 0  not null,
 modified_by_user_id number(38,0) default 0  not null,
 "COMMENT" clob,
 card_type_name varchar2(1020) not null,
 has_macros number(1,0) default 0  not null,
 system_generated_comment clob,
 updater_id varchar2(1020),
 redcloth number(1,0));

create table CHANGES (
 id number(38,0) not null primary key ,
 event_id number(38,0) not null,
 type varchar2(1020) default ''  not null,
 old_value varchar2(1020),
 new_value varchar2(1020),
 attachment_id number(38,0),
 tag_id number(38,0),
 field varchar2(1020) default '');

create table CHECKLIST_ITEMS (
 id number(38,0) not null primary key ,
 text varchar2(1020),
 completed number(1,0),
 created_at date,
 updated_at date,
 card_id number(38,0),
 project_id number(38,0),
 position number(38,0),
 type varchar2(1020) default null);

create table CONVERSATIONS (
 id number(38,0) not null primary key ,
 created_at date,
 project_id number(38,0));

create table CORRECTION_CHANGES (
 id number(38,0) not null primary key ,
 event_id number(38,0),
 old_value varchar2(1020),
 new_value varchar2(1020),
 change_type varchar2(1020) not null,
 resource_1 number(38,0),
 resource_2 number(38,0));

create table DELIVERABLES (
 id number(38,0) not null primary key ,
 name varchar2(1020) default ''  not null,
 identifier varchar2(1020) default '' ,
 description clob,
 created_at date not null,
 updated_at date not null,
 icon varchar2(1020),
 created_by_user_id number(38,0),
 modified_by_user_id number(38,0),
 card_keywords varchar2(1020),
 template number(1,0),
 secret_key varchar2(1020),
 email_address varchar2(1020),
 email_sender_name varchar2(1020),
 hidden number(1,0) default 0,
 date_format varchar2(1020) default '%d %b %Y',
 time_zone varchar2(1020),
 precision number(38,0) default 2,
 anonymous_accessible number(1,0) default 0,
 corruption_checked number(1,0),
 corruption_info clob,
 auto_enroll_user_type varchar2(1020) default null,
 cards_table varchar2(1020),
 card_versions_table varchar2(1020),
 membership_requestable number(1,0),
 type varchar2(1020) not null,
 pre_defined_template number(1,0),
 landing_tab_id number(38,0),
 ordered_tab_identifiers clob,
 exclude_weekends_in_cta number(1,0) default 0  not null,
 accepts_dependencies number(1,0) default 0,
 last_export_date date);

create table DEPENDENCIES (
 id number(38,0) not null primary key ,
 name varchar2(1020) not null,
 description clob,
 desired_end_date date not null,
 resolving_project_id number(38,0),
 raising_project_id number(38,0) not null,
 "NUMBER" number(38,0),
 created_at date,
 raising_user_id number(38,0),
 status varchar2(1020) default 'NEW' not null,
 version number(38,0),
 raising_card_number number(38,0),
 updated_at date);

create table DEPENDENCY_RESOLVING_CARDS (
 id number(38,0) not null primary key ,
 dependency_id number(38,0) not null,
 dependency_type varchar2(1020),
 card_number number(38,0),
 project_id number(38,0) not null);

create table DEPENDENCY_VERSIONS (
 id number(38,0) not null primary key ,
 dependency_id number(38,0) not null,
 version number(38,0) not null,
 name varchar2(1020) not null,
 description clob,
 desired_end_date date not null,
 resolving_project_id number(38,0),
 raising_project_id number(38,0) not null,
 "NUMBER" number(38,0) not null,
 created_at date,
 updated_at date,
 raising_user_id number(38,0),
 status varchar2(1020) not null,
 raising_card_number number(38,0));

create table DEPENDENCY_VIEWS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 user_id number(38,0) not null,
 params varchar2(4000),
 created_at date,
 updated_at date);

create table ENUMERATION_VALUES (
 id number(38,0) not null primary key ,
 value varchar2(1020) default ''  not null,
 property_definition_id number(38,0),
 color varchar2(1020),
 position number(38,0));

create table EVENTS (
 id number(38,0) not null primary key ,
 type varchar2(1020) not null,
 origin_type varchar2(1020) not null,
 origin_id number(38,0) not null,
 created_at date not null,
 created_by_user_id number(38,0),
 deliverable_id number(38,0) not null,
 history_generated number(1,0) default 0,
 mingle_timestamp date default sys_extract_utc(CURRENT_TIMESTAMP) not null,
 deliverable_type varchar2(1020) default 'Project'  not null,
 details varchar2(4000));

create table EXPORTS (
 id number(38,0) not null primary key ,
 status varchar2(1020),
 user_id number(38,0),
 total number(38,0),
 completed number(38,0),
 export_file varchar2(1020),
 created_at date,
 updated_at date,
 config clob);

create table FAVORITES (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 favorited_type varchar2(1020) not null,
 favorited_id number(38,0) not null,
 tab_view number(1,0) default 0  not null,
 user_id number(38,0),
 created_at date,
 updated_at date);

create table GITHUBS (
 id number(38,0) not null primary key ,
 username varchar2(1020),
 repository varchar2(1020),
 project_id number(38,0),
 webhook_id number(38,0),
 created_at date,
 updated_at date);

create table GIT_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 repository_path varchar2(1020),
 username varchar2(1020),
 password varchar2(1020),
 initialized number(1,0),
 card_revision_links_invalid number(1,0),
 marked_for_deletion number(1,0) default 0);

create table GROUPS (
 id number(38,0) not null primary key ,
 name varchar2(1020),
 deliverable_id number(38,0),
 internal number(1,0) default 0  not null);

create table HG_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 repository_path varchar2(1020),
 username varchar2(1020),
 password varchar2(1020),
 initialized number(1,0),
 card_revision_links_invalid number(1,0),
 marked_for_deletion number(1,0) default 0);

create table HISTORY_SUBSCRIPTIONS (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 project_id number(38,0) not null,
 last_max_card_version_id number(38,0) not null,
 last_max_page_version_id number(38,0) not null,
 last_max_revision_id number(38,0) not null,
 hashed_filter_params varchar2(1020),
 filter_params clob,
 error_message varchar2(1020));

create table LICENSES (
 id number(38,0) not null primary key ,
 eula_accepted number(1,0),
 license_key clob);

create table LOGIN_ACCESS (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 login_token varchar2(1020),
 last_login_at date,
 lost_password_key varchar2(4000),
 lost_password_reported_at date,
 first_login_at date);

create table LUAU_CONFIGS (
 id number(38,0) not null primary key ,
 base_url varchar2(1020),
 submitted_at date,
 state varchar2(1020),
 client_key varchar2(1020),
 auth_state_explanation varchar2(1020),
 sync_status varchar2(1020),
 last_sync_time date,
 marked_for_deletion number(1,0),
 client_digest varchar2(1020),
 sync_forced number(38,0) default 0,
 last_successful_sync_time date);

create table LUAU_GROUPS (
 id number(38,0) not null primary key ,
 identifier varchar2(1020) not null,
 full_name varchar2(1020) not null,
 restricted_to_readonly number(1,0) default 0  not null,
 name varchar2(1020));

create table LUAU_GROUPS_MAPPINGS (
 id number(38,0) not null primary key ,
 parent_group_id number(38,0) not null,
 child_group_id number(38,0) not null,
 direct number(1,0) default 0  not null);

create table LUAU_GROUP_MEMBERSHIPS (
 id number(38,0) not null primary key ,
 luau_group_id number(38,0) not null,
 group_id number(38,0) not null);

create table LUAU_GROUP_USER_MAPPINGS (
 id number(38,0) not null primary key ,
 luau_group_id number(38,0),
 user_login varchar2(1020));

create table LUAU_LOCK_FAIL (
 id number(38,0) not null primary key ,
 lock_fail varchar2(1) not null);

create table MEMBER_ROLES (
 id number(38,0) not null primary key ,
 deliverable_id number(38,0) not null,
 member_type varchar2(1020) not null,
 member_id number(38,0) not null,
 permission varchar2(1020));

create table MURMURS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 packet_id varchar2(1020),
 jabber_user_name varchar2(1020),
 created_at date not null,
 author_id number(38,0),
 murmur clob,
 origin_type varchar2(1020),
 origin_id number(38,0),
 type varchar2(1020) default 'DefaultMurmur'  not null,
 conversation_id number(38,0),
 source varchar2(1020));

create table MURMURS_READ_COUNTS (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 project_id number(38,0) not null,
 read_count number(38,0) default 0);

create table MURMUR_CHANNELS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 jabber_chat_room_id varchar2(1020),
 jabber_chat_room_status varchar2(1020),
 enabled number(1,0),
 type varchar2(1020) default 'BuiltInChannel');

create table OAUTH_AUTHORIZATIONS (
 id number(38,0) not null primary key ,
 user_id varchar2(1020),
 oauth_client_id number(38,0),
 code varchar2(1020),
 expires_at number(38,0),
 created_at date,
 updated_at date);

create table OAUTH_CLIENTS (
 id number(38,0) not null primary key ,
 name varchar2(1020),
 client_id varchar2(1020),
 client_secret varchar2(1020),
 redirect_uri varchar2(1020),
 created_at date,
 updated_at date);

create table OAUTH_TOKENS (
 id number(38,0) not null primary key ,
 user_id varchar2(1020),
 oauth_client_id number(38,0),
 access_token varchar2(1020),
 refresh_token varchar2(1020),
 expires_at number(38,0),
 created_at date,
 updated_at date);

create table OBJECTIVES (
 id number(38,0) not null primary key ,
 plan_id number(38,0),
 name varchar2(320),
 start_at date,
 end_at date,
 vertical_position number(38,0),
 created_at date,
 updated_at date,
 identifier varchar2(160),
 "SIZE" number(38,0) default 0  not null,
 value number(38,0) default 0  not null,
 version number(38,0),
 modified_by_user_id number(38,0),
 "NUMBER" number(38,0),
 value_statement clob,
 program_id number(38,0),
 position number(38,0),
 status varchar2(1020) default 'PLANNED',
 objective_type_id number(38,0));

create table OBJECTIVE_FILTERS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 objective_id number(38,0),
 params varchar2(4000),
 created_at date,
 updated_at date,
 synced number(1,0));

create table OBJECTIVE_SNAPSHOTS (
 id number(38,0) not null primary key ,
 total number(38,0),
 completed number(38,0),
 project_id number(38,0),
 objective_id number(38,0),
 created_at date,
 updated_at date,
 dated date);

create table OBJECTIVE_TYPES (
 id number(38,0) not null primary key ,
 program_id number(38,0) not null,
 value_statement clob,
 name varchar2(1020),
 created_at date,
 updated_at date);

create table OBJECTIVE_VERSIONS (
 id number(38,0) not null primary key ,
 objective_id number(38,0),
 version number(38,0),
 plan_id number(38,0),
 vertical_position number(38,0),
 identifier varchar2(1020),
 "SIZE" number(38,0) default 0,
 value number(38,0) default 0,
 name varchar2(1020),
 start_at date,
 end_at date,
 created_at date,
 updated_at date,
 modified_by_user_id number(38,0),
 "NUMBER" number(38,0),
 value_statement clob,
 program_id number(38,0),
 position number(38,0),
 status varchar2(1020) default 'PLANNED',
 objective_type_id number(38,0));

create table OBJ_PROP_DEFS (
 id number(38,0) not null primary key ,
 name varchar2(1020) not null,
 program_id number(38,0),
 type varchar2(1020),
 created_at date,
 updated_at date,
 description clob);

create table OBJ_PROP_MAPPINGS (
 id number(38,0) not null primary key ,
 obj_prop_def_id number(38,0),
 objective_type_id number(38,0));

create table OBJ_PROP_VALUES (
 id number(38,0) not null primary key ,
 obj_prop_def_id number(38,0),
 value varchar2(1020),
 created_at date,
 updated_at date);

create table OBJ_PROP_VALUE_MAPPINGS (
 id number(38,0) not null primary key ,
 objective_id number(38,0),
 obj_prop_value_id number(38,0),
 created_at date,
 updated_at date);

create table PAGES (
 id number(38,0) not null primary key ,
 name varchar2(1020) default ''  not null,
 content clob,
 project_id number(38,0),
 created_at date not null,
 updated_at date not null,
 created_by_user_id number(38,0),
 modified_by_user_id number(38,0),
 version number(38,0),
 has_macros number(1,0) default 0  not null,
 redcloth number(1,0));

create table PAGE_VERSIONS (
 id number(38,0) not null primary key ,
 page_id number(38,0),
 version number(38,0),
 name varchar2(1020) default '',
 content clob,
 project_id number(38,0),
 created_at date,
 updated_at date,
 created_by_user_id number(38,0),
 modified_by_user_id number(38,0),
 has_macros number(1,0) default 0  not null,
 system_generated_comment clob,
 redcloth number(1,0));

create table PERFORCE_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 username varchar2(1020),
 password varchar2(1020),
 port varchar2(1020),
 host varchar2(1020),
 repository_path clob,
 initialized number(1,0),
 card_revision_links_invalid number(1,0),
 marked_for_deletion number(1,0) default 0);

create table PLANS (
 id number(38,0) not null primary key ,
 start_at date,
 end_at date,
 program_id number(38,0),
 precision number(38,0) default 2,
 created_at date,
 updated_at date);

create table PROGRAM_DEPENDENCY_VIEWS (
 id number(38,0) not null primary key ,
 program_id number(38,0) not null,
 user_id number(38,0) not null,
 params varchar2(4000),
 created_at date,
 updated_at date);

create table PROGRAM_PROJECTS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 done_status_id number(38,0),
 status_property_id number(38,0),
 program_id number(38,0),
 accepts_dependencies number(1,0) default 1);

create table PROJECTS_L6DD567D8EC3E191C (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 luau_group_id number(38,0) not null);

create table PROJECT_VARIABLES (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 data_type varchar2(1020) not null,
 name varchar2(1020) not null,
 value varchar2(1020),
 card_type_id number(38,0));

create table PROPERTY_DEFINITIONS (
 id number(38,0) not null primary key ,
 type varchar2(1020),
 project_id number(38,0) not null,
 name varchar2(1020) default ''  not null,
 description clob,
 column_name varchar2(1020) default ''  not null,
 hidden number(1,0) default 0  not null,
 restricted number(1,0) default 0  not null,
 transition_only number(1,0) default 0,
 valid_card_type_id number(38,0),
 is_numeric number(1,0) default 0,
 tree_configuration_id number(38,0),
 position number(38,0),
 formula clob default null,
 aggregate_target_id number(38,0),
 aggregate_type varchar2(1020),
 aggregate_card_type_id number(38,0),
 aggregate_scope_card_type_id number(38,0),
 ruby_name varchar2(1020) default null,
 dependant_formulas varchar2(4000),
 aggregate_condition clob default null,
 null_is_zero number(1,0) default 0,
 created_at date,
 updated_at date);

create table PROPERTY_TYPE_MAPPINGS (
 id number(38,0) not null primary key ,
 card_type_id number(38,0) not null,
 property_definition_id number(38,0) not null,
 position number(38,0));

create table REVISIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 "NUMBER" number(38,0) not null,
 commit_time date not null,
 commit_user varchar2(1020),
 commit_message clob default null,
 identifier varchar2(1020));

create table SAAS_TOS (
 id number(38,0) not null primary key ,
 user_email varchar2(1020),
 accepted number(1,0) default 0  not null,
 created_at date,
 updated_at date);

create table SCHEMA_MIGRATIONS (
 version varchar2(1020) not null primary key );

create table SESSIONS (
 id number(38,0) not null primary key ,
 session_id varchar2(1020) not null,
 data clob,
 updated_at date not null);

create table STALE_PROP_DEFS (
 id number(38,0) not null primary key ,
 card_id number(38,0) not null,
 prop_def_id number(38,0) not null,
 project_id number(38,0) not null);

create table SUBVERSION_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 username varchar2(1020),
 password varchar2(1020),
 repository_path clob,
 card_revision_links_invalid number(1,0),
 marked_for_deletion number(1,0) default 0,
 initialized number(1,0));

create table TABLE_SEQUENCES (
 id number(38,0) not null primary key ,
 name varchar2(1020),
 last_value number(38,0));

create table TABS (
 id number(38,0) not null primary key ,
 name varchar2(1020),
 position number(38,0),
 tab_type varchar2(1020) not null,
 target_type varchar2(1020),
 target_id number(38,0),
 project_id number(38,0) not null);

create table TAB_POSITIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 html_id varchar2(1020) not null,
 position number(38,0));

create table TAGGINGS (
 id number(38,0) not null primary key ,
 tag_id number(38,0) not null,
 taggable_id number(38,0) not null,
 taggable_type varchar2(1020) not null,
 position number(38,0) default 0  not null);

create table TAGS (
 id number(38,0) not null primary key ,
 name varchar2(1020) default ''  not null,
 project_id number(38,0) not null,
 deleted_at date,
 color varchar2(1020));

create table TEMPORARY_ID_STORAGES (
 session_id varchar2(1020),
 id_1 number(38,0),
 id_2 number(38,0));

create table TFSSCM_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0),
 initialized number(1,0),
 card_revision_links_invalid number(1,0),
 marked_for_deletion number(1,0) default 0,
 server_url varchar2(1020),
 username varchar2(1020),
 tfs_project varchar2(1020),
 password varchar2(1020),
 domain varchar2(1020),
 collection varchar2(1020));

create table TODOS (
 id number(38,0) not null primary key ,
 user_id number(38,0),
 done number(1,0) default 0,
 content varchar2(1020),
 position number(38,0),
 created_at date,
 updated_at date);

create table TRANSITIONS (
 id number(38,0) not null primary key ,
 project_id number(38,0) not null,
 name varchar2(1020) default ''  not null,
 card_type_id number(38,0),
 require_comment number(1,0) default 0);

create table TRANSITION_ACTIONS (
 id number(38,0) not null primary key ,
 executor_id number(38,0) not null,
 target_id number(38,0) not null,
 value varchar2(1020) default '',
 executor_type varchar2(1020) not null,
 type varchar2(1020),
 variable_binding_id number(38,0));

create table TRANSITION_PREREQUISITES (
 id number(38,0) not null primary key ,
 transition_id number(38,0) not null,
 type varchar2(1020) default ''  not null,
 user_id number(38,0),
 property_definition_id number(38,0),
 value varchar2(1020),
 project_variable_id number(38,0),
 group_id number(38,0));

create table TREE_BELONGINGS (
 id number(38,0) not null primary key ,
 tree_configuration_id number(38,0) not null,
 card_id number(38,0) not null);

create table TREE_CONFIGURATIONS (
 id number(38,0) not null primary key ,
 name varchar2(1020) not null,
 project_id number(38,0) not null,
 description varchar2(1020));

create table USERS (
 id number(38,0) not null primary key ,
 email varchar2(1020),
 password varchar2(1020),
 admin number(1,0),
 version_control_user_name varchar2(1020),
 login varchar2(1020) default ''  not null,
 name varchar2(1020),
 activated number(1,0) default 1,
 light number(1,0) default 0,
 icon varchar2(1020),
 jabber_user_name varchar2(1020),
 jabber_password varchar2(1020),
 salt varchar2(1020),
 locked_against_delete number(1,0) default 0,
 system number(1,0) default 0  not null,
 api_key varchar2(1020),
 read_notification_digest varchar2(1020),
 created_at date,
 updated_at date);

create table USER_DISPLAY_PREFERENCES (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 sidebar_visible number(1,0) not null,
 favorites_visible number(1,0) not null,
 recent_pages_visible number(1,0) not null,
 color_legend_visible number(1,0) not null,
 filters_visible number(1,0) not null,
 history_have_been_visible number(1,0) not null,
 history_changed_to_visible number(1,0) not null,
 excel_import_export_visible number(1,0) not null,
 include_description number(1,0) not null,
 show_murmurs_in_sidebar number(1,0) not null,
 personal_favorites_visible number(1,0),
 murmur_this_comment number(1,0) default 1  not null,
 explore_mingle_tab_visible number(1,0) default 1  not null,
 contextual_help clob default '--- {}
'  not null,
 export_all_columns number(1,0) default 0  not null,
 show_deactived_users number(1,0) default 1  not null,
 timeline_granularity varchar2(1020),
 grid_settings number(1,0) default 1  not null,
 preferences clob);

create table USER_ENGAGEMENTS (
 id number(38,0) not null primary key ,
 user_id number(38,0) not null,
 trial_feedback_shown number(1,0) default 0);

create table USER_FILTER_USAGES (
 id number(38,0) not null primary key ,
 filterable_id number(38,0),
 filterable_type varchar2(1020),
 user_id number(38,0));

create table USER_MEMBERSHIPS (
 id number(38,0) not null primary key ,
 group_id number(38,0),
 user_id number(38,0) not null);

create table VARIABLE_BINDINGS (
 id number(38,0) not null primary key ,
 project_variable_id number(38,0) not null,
 property_definition_id number(38,0) not null);

create table WORKS (
 id number(38,0) not null primary key ,
 objective_id number(38,0),
 card_number number(38,0),
 created_at date,
 updated_at date,
 plan_id number(38,0),
 completed number(1,0),
 name varchar2(1020),
 bulk_updater_id varchar2(1020),
 project_id number(38,0));

create  index IDX_ASYNC_REQ_ON_USER_ID ON ASYNCH_REQUESTS("USER_ID");

create  index IDX_ASYNC_REQ_ON_USER_PROJ ON ASYNCH_REQUESTS("USER_ID","DELIVERABLE_IDENTIFIER");

create  index IDX_ATCHMNT_ON_PROJ_ID ON ATTACHMENTS("PROJECT_ID");

create  index IDX_ATTACHE183949FFBE607B7 ON ATTACHINGS("ATTACHABLE_ID","ATTACHABLE_TYPE");

create  index IDX_CARD_D6911CFEE2BDCE973 ON CARD_DEFAULTS("CARD_TYPE_ID","PROJECT_ID");

create  index IDX_CARD_TYPES_ON_PROJ_ID ON CARD_TYPES("PROJECT_ID");

create  index IDX_CML_ON_CARD_AND_MUR_ID ON CARD_MURMUR_LINKS("CARD_ID","MURMUR_ID");

create  index IDX_CRL_ON_CARD_AND_REV_ID ON CARD_REVISION_LINKS("CARD_ID","REVISION_ID");

create  index IDX_CTPD_ON_CT_AND_PD_ID ON PROPERTY_TYPE_MAPPINGS("CARD_TYPE_ID","PROPERTY_DEFINITION_ID");

create  index IDX_EVENTS_ON_PROJ_ID ON EVENTS("DELIVERABLE_ID");

create  index IDX_FAV_ON_TYPE_AND_ID ON FAVORITES("PROJECT_ID","FAVORITED_TYPE","FAVORITED_ID");

create  index IDX_HIST_SUB_ON_PROJ_USER ON HISTORY_SUBSCRIPTIONS("PROJECT_ID","USER_ID");

create  index IDX_PAGE_VER_ON_PAGE_VER ON PAGE_VERSIONS("PROJECT_ID","PAGE_ID","VERSION");

create  index IDX_REV_ON_COMMIT_TIME ON REVISIONS("COMMIT_TIME");

create  index IDX_REV_ON_NUMBER ON REVISIONS("NUMBER");

create  index IDX_REV_ON_PROJ_ID ON REVISIONS("PROJECT_ID");

create  index IDX_STAGG_1AF5C32B2309CC34 ON STALE_PROP_DEFS("PROJECT_ID","CARD_ID","PROP_DEF_ID");

create  index IDX_TACT_O2E74EC9763D89693 ON TRANSITION_ACTIONS("EXECUTOR_ID","EXECUTOR_TYPE");

create  index IDX_TAGGING_ON_ID_AND_TYPE ON TAGGINGS("TAGGABLE_ID","TAGGABLE_TYPE");

create  index IDX_TMP_SE82AD68A03B353347 ON TEMPORARY_ID_STORAGES("SESSION_ID","ID_1");

create  index IDX_TPRE_ON_TRANS_ID ON TRANSITION_PREREQUISITES("TRANSITION_ID");

create  index IDX_TRANS_ON_PROJ_ID ON TRANSITIONS("PROJECT_ID");

create  index IDX_VAR_BICC3F0BEDEF9D1880 ON VARIABLE_BINDINGS("PROJECT_VARIABLE_ID","PROPERTY_DEFINITION_ID");

create  index IDX_WORKS_4E9F1BF8EDBA6830 ON WORKS("PLAN_ID","OBJECTIVE_ID");

create  index IDX_WORKS_ON_PLAN_ID ON WORKS("PLAN_ID");

create  index IDX_WORKS_ON_PLAN_PROJ_ID ON WORKS("PLAN_ID","PROJECT_ID");

create  index IDX_WORKS_ON_PROJ_CARD_NUM ON WORKS("PROJECT_ID","CARD_NUMBER");

create  index IDX_WORKS_ON_PROJ_ID ON WORKS("PROJECT_ID");

create  index INDEX_ATTR4E559F4100C136FD ON PROPERTY_DEFINITIONS("PROJECT_ID");

create  index INDEX_ATTR50268FBDC646A9D7 ON PROPERTY_DEFINITIONS("COLUMN_NAME");

create  index INDEX_ATT_ON_ABLE_ID ON ATTACHINGS("ATTACHABLE_ID");

create  index INDEX_ATT_ON_ABLE_TYPE ON ATTACHINGS("ATTACHABLE_TYPE");

create  index INDEX_ATT_ON_A_ID ON ATTACHINGS("ATTACHMENT_ID");

create  index INDEX_CARDA3CA5D99BE0B8718 ON PROPERTY_TYPE_MAPPINGS("CARD_TYPE_ID");

create  index INDEX_CARDC919E2D6BEBFD35E ON PROPERTY_TYPE_MAPPINGS("PROPERTY_DEFINITION_ID");

create  index INDEX_CARDE8339381B4B15D05 ON CARD_LIST_VIEWS("PROJECT_ID");

create  index INDEX_CARDS_ON_NUMBER ON CARDS("NUMBER");

create  index INDEX_CARDS_ON_PROJECT_ID ON CARDS("PROJECT_ID");

create  index INDEX_CHEC028DE6EFCEEFA6D0 ON CHECKLIST_ITEMS("PROJECT_ID");

create  index INDEX_CHECBCAFBC4FB286536F ON CHECKLIST_ITEMS("CARD_ID");

create  index INDEX_CONVA30E80B3C5C83547 ON CONVERSATIONS("PROJECT_ID");

create  index INDEX_DEPE4DAEB5F3BA0AD371 ON DEPENDENCY_VIEWS("PROJECT_ID");

create  index INDEX_DEPE8436FB015FB3CCA5 ON DEPENDENCY_VERSIONS("DEPENDENCY_ID");

create  index INDEX_ENUM08C23FA6394E10EF ON ENUMERATION_VALUES("POSITION");

create  index INDEX_ENUM4744093CE8811B71 ON ENUMERATION_VALUES("PROPERTY_DEFINITION_ID");

create  index INDEX_ENUMF0F334234E406303 ON ENUMERATION_VALUES("VALUE");

create  index INDEX_EVEN1705845ACFBA476F ON EVENTS("ORIGIN_TYPE","ORIGIN_ID");

create  index INDEX_EVEN8A43CF8F7E08BE21 ON EVENTS("CREATED_BY_USER_ID");

create  index INDEX_EVENT_CHANGES ON CHANGES("EVENT_ID","TYPE");

create  index INDEX_MURM7002238B71A275E5 ON MURMURS("PROJECT_ID","CREATED_AT");

create  index INDEX_MURMB671A76C09C88001 ON MURMURS("CONVERSATION_ID");

create  index INDEX_PAGES_ON_NAME ON PAGES("NAME");

create  index INDEX_PAGES_ON_PROJECT_ID ON PAGES("PROJECT_ID");

create  index INDEX_PROG2A15BCB7D105FF67 ON PROGRAM_DEPENDENCY_VIEWS("PROGRAM_ID");

create  index INDEX_PROJ5B4BF876347668A8 ON DELIVERABLES("IDENTIFIER","TYPE");

create  index INDEX_REVIB097B84D191E03A1 ON REVISIONS("IDENTIFIER");

create  index INDEX_SESS95B3A212DE3678BA ON SESSIONS("SESSION_ID");

create  index INDEX_STRE6407C8350F4C3B3D ON OBJECTIVE_SNAPSHOTS("PROJECT_ID","OBJECTIVE_ID");

create  index INDEX_TAGG58C72DFD2AFC0C98 ON TAGGINGS("TAGGABLE_TYPE");

create  index INDEX_TAGGC7182CA32677EBBF ON TAGGINGS("TAGGABLE_ID");

create  index INDEX_TAGGINGS_ON_TAG_ID ON TAGGINGS("TAG_ID");

create  index INDEX_TAGS_ON_NAME ON TAGS("NAME");

create  index INDEX_TAGS_ON_PROJECT_ID ON TAGS("PROJECT_ID");

create  index INDEX_TEMPD0C7ABACEC5264ED ON TEMPORARY_ID_STORAGES("SESSION_ID");

create  index TODO_USER_ID_IDX ON TODOS("USER_ID");

create  index USER_MEMBE577ADE103C59F4E3 ON USER_MEMBERSHIPS("USER_ID");

create UNIQUE index BACKLOG_NUMBER_UNIQUE ON BACKLOG_OBJECTIVES("NUMBER","BACKLOG_ID");

create UNIQUE index IDX_CARD_WORK ON WORKS("OBJECTIVE_ID","CARD_NUMBER","PROJECT_ID");

create UNIQUE index IDX_LUAU_GAF551B23CFBD21D1 ON PROJECTS_L6DD567D8EC3E191C("PROJECT_ID","LUAU_GROUP_ID");

create UNIQUE index IDX_LUAU_GROUPS_ON_IDENT ON LUAU_GROUPS("IDENTIFIER");

create UNIQUE index IDX_OBJ_PROJ_DATED ON OBJECTIVE_SNAPSHOTS("OBJECTIVE_ID","PROJECT_ID","DATED");

create UNIQUE index IDX_PARENT_CHILD ON LUAU_GROUPS_MAPPINGS("PARENT_GROUP_ID","CHILD_GROUP_ID");

create UNIQUE index IDX_UNIQUE_MEMBER_ROLES ON MEMBER_ROLES("DELIVERABLE_ID","MEMBER_TYPE","MEMBER_ID");

create UNIQUE index INDEX_DEPEAEF3664F137E2497 ON DEPENDENCY_VIEWS("PROJECT_ID","USER_ID");

create UNIQUE index INDEX_OBJ_41DE0810630F428C ON OBJ_PROP_MAPPINGS("OBJ_PROP_DEF_ID","OBJECTIVE_TYPE_ID");

create UNIQUE index INDEX_OBJ_A872878E2F4B044C ON OBJ_PROP_VALUE_MAPPINGS("OBJ_PROP_VALUE_ID","OBJECTIVE_ID");

create UNIQUE index INDEX_OBJ_EA95F20D6E7F894E ON OBJ_PROP_VALUES("OBJ_PROP_DEF_ID","VALUE");

create UNIQUE index INDEX_OBJ_FD261E9A15065438 ON OBJ_PROP_DEFS("PROGRAM_ID","NAME");

create UNIQUE index INDEX_PROG02E3A5BA0A1F6DBA ON PROGRAM_DEPENDENCY_VIEWS("PROGRAM_ID","USER_ID");

create UNIQUE index INDEX_PROJ2B8C5459FE63E6A1 ON DELIVERABLES("NAME","TYPE");

create UNIQUE index INDEX_PROP010655CF95E28EEC ON PROPERTY_DEFINITIONS("PROJECT_ID","NAME");

create UNIQUE index INDEX_SEQUENCES_ON_NAME ON TABLE_SEQUENCES("NAME");

create UNIQUE index INDEX_USERS_ON_LOGIN ON USERS("LOGIN");

create UNIQUE index M20120821135500_idx ON PROPERTY_DEFINITIONS("PROJECT_ID","RUBY_NAME");

create UNIQUE index UNIQUE_CARD_IN_TREE ON TREE_BELONGINGS("TREE_CONFIGURATION_ID","CARD_ID");

create UNIQUE index UNIQUE_ENUMERATION_VALUES ON ENUMERATION_VALUES("VALUE","PROPERTY_DEFINITION_ID");

create UNIQUE index UNIQUE_TAG_NAMES ON TAGS("NAME","PROJECT_ID");

create UNIQUE index UNIQ_TREE_NAME_IN_PROJECT ON TREE_CONFIGURATIONS("PROJECT_ID","NAME");INSERT INTO schema_migrations (version) VALUES ('1-mingle_git_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-mingle_hg_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-perforce');

INSERT INTO schema_migrations (version) VALUES ('1-subversion');

INSERT INTO schema_migrations (version) VALUES ('100');

INSERT INTO schema_migrations (version) VALUES ('101');

INSERT INTO schema_migrations (version) VALUES ('102');

INSERT INTO schema_migrations (version) VALUES ('103');

INSERT INTO schema_migrations (version) VALUES ('104');

INSERT INTO schema_migrations (version) VALUES ('105');

INSERT INTO schema_migrations (version) VALUES ('106');

INSERT INTO schema_migrations (version) VALUES ('107');

INSERT INTO schema_migrations (version) VALUES ('108');

INSERT INTO schema_migrations (version) VALUES ('109');

INSERT INTO schema_migrations (version) VALUES ('110');

INSERT INTO schema_migrations (version) VALUES ('111');

INSERT INTO schema_migrations (version) VALUES ('112');

INSERT INTO schema_migrations (version) VALUES ('113');

INSERT INTO schema_migrations (version) VALUES ('114');

INSERT INTO schema_migrations (version) VALUES ('115');

INSERT INTO schema_migrations (version) VALUES ('116');

INSERT INTO schema_migrations (version) VALUES ('117');

INSERT INTO schema_migrations (version) VALUES ('118');

INSERT INTO schema_migrations (version) VALUES ('119');

INSERT INTO schema_migrations (version) VALUES ('120');

INSERT INTO schema_migrations (version) VALUES ('121');

INSERT INTO schema_migrations (version) VALUES ('122');

INSERT INTO schema_migrations (version) VALUES ('123');

INSERT INTO schema_migrations (version) VALUES ('124');

INSERT INTO schema_migrations (version) VALUES ('125');

INSERT INTO schema_migrations (version) VALUES ('126');

INSERT INTO schema_migrations (version) VALUES ('127');

INSERT INTO schema_migrations (version) VALUES ('128');

INSERT INTO schema_migrations (version) VALUES ('129');

INSERT INTO schema_migrations (version) VALUES ('130');

INSERT INTO schema_migrations (version) VALUES ('131');

INSERT INTO schema_migrations (version) VALUES ('132');

INSERT INTO schema_migrations (version) VALUES ('133');

INSERT INTO schema_migrations (version) VALUES ('134');

INSERT INTO schema_migrations (version) VALUES ('135');

INSERT INTO schema_migrations (version) VALUES ('136');

INSERT INTO schema_migrations (version) VALUES ('137');

INSERT INTO schema_migrations (version) VALUES ('138');

INSERT INTO schema_migrations (version) VALUES ('139');

INSERT INTO schema_migrations (version) VALUES ('140');

INSERT INTO schema_migrations (version) VALUES ('141');

INSERT INTO schema_migrations (version) VALUES ('142');

INSERT INTO schema_migrations (version) VALUES ('143');

INSERT INTO schema_migrations (version) VALUES ('144');

INSERT INTO schema_migrations (version) VALUES ('145');

INSERT INTO schema_migrations (version) VALUES ('146');

INSERT INTO schema_migrations (version) VALUES ('147');

INSERT INTO schema_migrations (version) VALUES ('148');

INSERT INTO schema_migrations (version) VALUES ('149');

INSERT INTO schema_migrations (version) VALUES ('150');

INSERT INTO schema_migrations (version) VALUES ('151');

INSERT INTO schema_migrations (version) VALUES ('152');

INSERT INTO schema_migrations (version) VALUES ('153');

INSERT INTO schema_migrations (version) VALUES ('154');

INSERT INTO schema_migrations (version) VALUES ('155');

INSERT INTO schema_migrations (version) VALUES ('156');

INSERT INTO schema_migrations (version) VALUES ('157');

INSERT INTO schema_migrations (version) VALUES ('158');

INSERT INTO schema_migrations (version) VALUES ('159');

INSERT INTO schema_migrations (version) VALUES ('160');

INSERT INTO schema_migrations (version) VALUES ('161');

INSERT INTO schema_migrations (version) VALUES ('162');

INSERT INTO schema_migrations (version) VALUES ('163');

INSERT INTO schema_migrations (version) VALUES ('164');

INSERT INTO schema_migrations (version) VALUES ('165');

INSERT INTO schema_migrations (version) VALUES ('166');

INSERT INTO schema_migrations (version) VALUES ('167');

INSERT INTO schema_migrations (version) VALUES ('168');

INSERT INTO schema_migrations (version) VALUES ('169');

INSERT INTO schema_migrations (version) VALUES ('170');

INSERT INTO schema_migrations (version) VALUES ('171');

INSERT INTO schema_migrations (version) VALUES ('172');

INSERT INTO schema_migrations (version) VALUES ('173');

INSERT INTO schema_migrations (version) VALUES ('174');

INSERT INTO schema_migrations (version) VALUES ('2-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('20090113234524');

INSERT INTO schema_migrations (version) VALUES ('20090114233821');

INSERT INTO schema_migrations (version) VALUES ('20090115183706');

INSERT INTO schema_migrations (version) VALUES ('20090115195731');

INSERT INTO schema_migrations (version) VALUES ('20090116004412');

INSERT INTO schema_migrations (version) VALUES ('20090116193934');

INSERT INTO schema_migrations (version) VALUES ('20090121014557');

INSERT INTO schema_migrations (version) VALUES ('20090122234230');

INSERT INTO schema_migrations (version) VALUES ('20090127182819');

INSERT INTO schema_migrations (version) VALUES ('20090128173321');

INSERT INTO schema_migrations (version) VALUES ('20090129002230');

INSERT INTO schema_migrations (version) VALUES ('20090129190713');

INSERT INTO schema_migrations (version) VALUES ('20090212082808');

INSERT INTO schema_migrations (version) VALUES ('20090212215531');

INSERT INTO schema_migrations (version) VALUES ('20090214025103');

INSERT INTO schema_migrations (version) VALUES ('20090215083334');

INSERT INTO schema_migrations (version) VALUES ('20090216085452');

INSERT INTO schema_migrations (version) VALUES ('20090225091006');

INSERT INTO schema_migrations (version) VALUES ('20090308210145');

INSERT INTO schema_migrations (version) VALUES ('20090310150929');

INSERT INTO schema_migrations (version) VALUES ('20090311203604');

INSERT INTO schema_migrations (version) VALUES ('20090317233420');

INSERT INTO schema_migrations (version) VALUES ('20090320180457');

INSERT INTO schema_migrations (version) VALUES ('20090320212835');

INSERT INTO schema_migrations (version) VALUES ('20090323180534');

INSERT INTO schema_migrations (version) VALUES ('20090330082548');

INSERT INTO schema_migrations (version) VALUES ('20090403201123');

INSERT INTO schema_migrations (version) VALUES ('20090403202000');

INSERT INTO schema_migrations (version) VALUES ('20090403211123');

INSERT INTO schema_migrations (version) VALUES ('20090405165301');

INSERT INTO schema_migrations (version) VALUES ('20090414033742');

INSERT INTO schema_migrations (version) VALUES ('20090414184720');

INSERT INTO schema_migrations (version) VALUES ('20090417234336');

INSERT INTO schema_migrations (version) VALUES ('20090429195156');

INSERT INTO schema_migrations (version) VALUES ('20090430225241');

INSERT INTO schema_migrations (version) VALUES ('20090430225248');

INSERT INTO schema_migrations (version) VALUES ('20090430225250');

INSERT INTO schema_migrations (version) VALUES ('20090430225260');

INSERT INTO schema_migrations (version) VALUES ('20090501000152');

INSERT INTO schema_migrations (version) VALUES ('20090607010000');

INSERT INTO schema_migrations (version) VALUES ('20090608091640');

INSERT INTO schema_migrations (version) VALUES ('20090617080845');

INSERT INTO schema_migrations (version) VALUES ('20090617182953');

INSERT INTO schema_migrations (version) VALUES ('20090618211257');

INSERT INTO schema_migrations (version) VALUES ('20090706195912');

INSERT INTO schema_migrations (version) VALUES ('20090707182022');

INSERT INTO schema_migrations (version) VALUES ('20090710074211');

INSERT INTO schema_migrations (version) VALUES ('20090721212102');

INSERT INTO schema_migrations (version) VALUES ('20090722185208');

INSERT INTO schema_migrations (version) VALUES ('20090724093228');

INSERT INTO schema_migrations (version) VALUES ('20090724220437');

INSERT INTO schema_migrations (version) VALUES ('20090728032250');

INSERT INTO schema_migrations (version) VALUES ('20090803043954');

INSERT INTO schema_migrations (version) VALUES ('20090803093249');

INSERT INTO schema_migrations (version) VALUES ('20090804054505');

INSERT INTO schema_migrations (version) VALUES ('20090804093656');

INSERT INTO schema_migrations (version) VALUES ('20090807011829');

INSERT INTO schema_migrations (version) VALUES ('20090810024628');

INSERT INTO schema_migrations (version) VALUES ('20090810092802');

INSERT INTO schema_migrations (version) VALUES ('20090810100937');

INSERT INTO schema_migrations (version) VALUES ('20090811040153');

INSERT INTO schema_migrations (version) VALUES ('20090814064554');

INSERT INTO schema_migrations (version) VALUES ('20090817094457');

INSERT INTO schema_migrations (version) VALUES ('20090901174621');

INSERT INTO schema_migrations (version) VALUES ('20090902205508');

INSERT INTO schema_migrations (version) VALUES ('20090902205601');

INSERT INTO schema_migrations (version) VALUES ('20090909090606');

INSERT INTO schema_migrations (version) VALUES ('20090909183733');

INSERT INTO schema_migrations (version) VALUES ('20090909190019');

INSERT INTO schema_migrations (version) VALUES ('20090911210758');

INSERT INTO schema_migrations (version) VALUES ('20090912012759');

INSERT INTO schema_migrations (version) VALUES ('20090915063149');

INSERT INTO schema_migrations (version) VALUES ('20090917213426');

INSERT INTO schema_migrations (version) VALUES ('20090924080838');

INSERT INTO schema_migrations (version) VALUES ('20091006205953');

INSERT INTO schema_migrations (version) VALUES ('20091012061534');

INSERT INTO schema_migrations (version) VALUES ('20091021173849');

INSERT INTO schema_migrations (version) VALUES ('20091031003020');

INSERT INTO schema_migrations (version) VALUES ('20091209081625');

INSERT INTO schema_migrations (version) VALUES ('20091215214430');

INSERT INTO schema_migrations (version) VALUES ('20091215231859');

INSERT INTO schema_migrations (version) VALUES ('20091228211257');

INSERT INTO schema_migrations (version) VALUES ('20091230224925');

INSERT INTO schema_migrations (version) VALUES ('20100106194628');

INSERT INTO schema_migrations (version) VALUES ('20100111194628');

INSERT INTO schema_migrations (version) VALUES ('20100122184805');

INSERT INTO schema_migrations (version) VALUES ('20100216235642');

INSERT INTO schema_migrations (version) VALUES ('20100304032206');

INSERT INTO schema_migrations (version) VALUES ('20100322212204');

INSERT INTO schema_migrations (version) VALUES ('20100322212205');

INSERT INTO schema_migrations (version) VALUES ('20100412223440');

INSERT INTO schema_migrations (version) VALUES ('20100421214257');

INSERT INTO schema_migrations (version) VALUES ('20100422183418');

INSERT INTO schema_migrations (version) VALUES ('20100429213636');

INSERT INTO schema_migrations (version) VALUES ('20100510175420');

INSERT INTO schema_migrations (version) VALUES ('20100519175247');

INSERT INTO schema_migrations (version) VALUES ('20100521204901');

INSERT INTO schema_migrations (version) VALUES ('20100527213332');

INSERT INTO schema_migrations (version) VALUES ('20100528202718');

INSERT INTO schema_migrations (version) VALUES ('20100601182323');

INSERT INTO schema_migrations (version) VALUES ('20100601185248');

INSERT INTO schema_migrations (version) VALUES ('20100601231859');

INSERT INTO schema_migrations (version) VALUES ('20100602001528');

INSERT INTO schema_migrations (version) VALUES ('20100602202716');

INSERT INTO schema_migrations (version) VALUES ('20100622185418');

INSERT INTO schema_migrations (version) VALUES ('20100623012305');

INSERT INTO schema_migrations (version) VALUES ('20100624185629');

INSERT INTO schema_migrations (version) VALUES ('20100624212512');

INSERT INTO schema_migrations (version) VALUES ('20100716170710');

INSERT INTO schema_migrations (version) VALUES ('20100716232520');

INSERT INTO schema_migrations (version) VALUES ('20100720195859');

INSERT INTO schema_migrations (version) VALUES ('20100720220121');

INSERT INTO schema_migrations (version) VALUES ('20100720222510');

INSERT INTO schema_migrations (version) VALUES ('20100720222511');

INSERT INTO schema_migrations (version) VALUES ('20100720222512');

INSERT INTO schema_migrations (version) VALUES ('20100720222513');

INSERT INTO schema_migrations (version) VALUES ('20100816183600');

INSERT INTO schema_migrations (version) VALUES ('20100816183700');

INSERT INTO schema_migrations (version) VALUES ('20100819001536');

INSERT INTO schema_migrations (version) VALUES ('20100901001555');

INSERT INTO schema_migrations (version) VALUES ('20100901182559');

INSERT INTO schema_migrations (version) VALUES ('20100901200902');

INSERT INTO schema_migrations (version) VALUES ('20100914004239');

INSERT INTO schema_migrations (version) VALUES ('20100915183400');

INSERT INTO schema_migrations (version) VALUES ('20100916021535');

INSERT INTO schema_migrations (version) VALUES ('20100919041948');

INSERT INTO schema_migrations (version) VALUES ('20100922185829');

INSERT INTO schema_migrations (version) VALUES ('20100922235407');

INSERT INTO schema_migrations (version) VALUES ('20100930214159');

INSERT INTO schema_migrations (version) VALUES ('20101004174136');

INSERT INTO schema_migrations (version) VALUES ('20101005183614');

INSERT INTO schema_migrations (version) VALUES ('20101005231441');

INSERT INTO schema_migrations (version) VALUES ('20101018184655');

INSERT INTO schema_migrations (version) VALUES ('20101020190521');

INSERT INTO schema_migrations (version) VALUES ('20101020215932');

INSERT INTO schema_migrations (version) VALUES ('20101102181625');

INSERT INTO schema_migrations (version) VALUES ('20101108200841');

INSERT INTO schema_migrations (version) VALUES ('20101214200858');

INSERT INTO schema_migrations (version) VALUES ('20101221221533');

INSERT INTO schema_migrations (version) VALUES ('20101229213516');

INSERT INTO schema_migrations (version) VALUES ('20101230003807');

INSERT INTO schema_migrations (version) VALUES ('20101230012901');

INSERT INTO schema_migrations (version) VALUES ('20110105175420');

INSERT INTO schema_migrations (version) VALUES ('20110107222440');

INSERT INTO schema_migrations (version) VALUES ('20110131191815');

INSERT INTO schema_migrations (version) VALUES ('20110217223014');

INSERT INTO schema_migrations (version) VALUES ('20110218203626');

INSERT INTO schema_migrations (version) VALUES ('20110218203630');

INSERT INTO schema_migrations (version) VALUES ('20110219010714');

INSERT INTO schema_migrations (version) VALUES ('20110222005051');

INSERT INTO schema_migrations (version) VALUES ('20110222185131');

INSERT INTO schema_migrations (version) VALUES ('20110223000940');

INSERT INTO schema_migrations (version) VALUES ('20110308011508');

INSERT INTO schema_migrations (version) VALUES ('20110311010508');

INSERT INTO schema_migrations (version) VALUES ('20110324184712');

INSERT INTO schema_migrations (version) VALUES ('20110325035333');

INSERT INTO schema_migrations (version) VALUES ('20110325041304');

INSERT INTO schema_migrations (version) VALUES ('20110325182824');

INSERT INTO schema_migrations (version) VALUES ('20110329222927');

INSERT INTO schema_migrations (version) VALUES ('20110402001334');

INSERT INTO schema_migrations (version) VALUES ('20110402144833');

INSERT INTO schema_migrations (version) VALUES ('20110402151838');

INSERT INTO schema_migrations (version) VALUES ('20110411225109');

INSERT INTO schema_migrations (version) VALUES ('20110412233613');

INSERT INTO schema_migrations (version) VALUES ('20110413213627');

INSERT INTO schema_migrations (version) VALUES ('20110414210420');

INSERT INTO schema_migrations (version) VALUES ('20110415222210');

INSERT INTO schema_migrations (version) VALUES ('20110416183317');

INSERT INTO schema_migrations (version) VALUES ('20110418212110');

INSERT INTO schema_migrations (version) VALUES ('20110502183359');

INSERT INTO schema_migrations (version) VALUES ('20110504222111');

INSERT INTO schema_migrations (version) VALUES ('20110504222112');

INSERT INTO schema_migrations (version) VALUES ('20110520215151');

INSERT INTO schema_migrations (version) VALUES ('20110524022043');

INSERT INTO schema_migrations (version) VALUES ('20110527001759');

INSERT INTO schema_migrations (version) VALUES ('20110527211656');

INSERT INTO schema_migrations (version) VALUES ('20110527211931');

INSERT INTO schema_migrations (version) VALUES ('20110527214529');

INSERT INTO schema_migrations (version) VALUES ('20110528005252');

INSERT INTO schema_migrations (version) VALUES ('20110606191448');

INSERT INTO schema_migrations (version) VALUES ('20110607203154');

INSERT INTO schema_migrations (version) VALUES ('20110615190109');

INSERT INTO schema_migrations (version) VALUES ('20110620181447');

INSERT INTO schema_migrations (version) VALUES ('20110623214059');

INSERT INTO schema_migrations (version) VALUES ('20110630181537');

INSERT INTO schema_migrations (version) VALUES ('20110705182730');

INSERT INTO schema_migrations (version) VALUES ('20110706195316');

INSERT INTO schema_migrations (version) VALUES ('20110706214919');

INSERT INTO schema_migrations (version) VALUES ('20110706231705');

INSERT INTO schema_migrations (version) VALUES ('20110712150000');

INSERT INTO schema_migrations (version) VALUES ('20110713000742');

INSERT INTO schema_migrations (version) VALUES ('20110714170636');

INSERT INTO schema_migrations (version) VALUES ('20110721001038');

INSERT INTO schema_migrations (version) VALUES ('20110726181809');

INSERT INTO schema_migrations (version) VALUES ('20110803235312');

INSERT INTO schema_migrations (version) VALUES ('20110808210333');

INSERT INTO schema_migrations (version) VALUES ('20110808233335');

INSERT INTO schema_migrations (version) VALUES ('20110809210303');

INSERT INTO schema_migrations (version) VALUES ('20110810191330');

INSERT INTO schema_migrations (version) VALUES ('20110817190551');

INSERT INTO schema_migrations (version) VALUES ('20110818181830');

INSERT INTO schema_migrations (version) VALUES ('20110822161524');

INSERT INTO schema_migrations (version) VALUES ('20110909175434');

INSERT INTO schema_migrations (version) VALUES ('20110913211458');

INSERT INTO schema_migrations (version) VALUES ('20110920182055');

INSERT INTO schema_migrations (version) VALUES ('20110920233151');

INSERT INTO schema_migrations (version) VALUES ('20110927221924');

INSERT INTO schema_migrations (version) VALUES ('20110927234919');

INSERT INTO schema_migrations (version) VALUES ('20110928165008');

INSERT INTO schema_migrations (version) VALUES ('20111012213849');

INSERT INTO schema_migrations (version) VALUES ('20111019233347');

INSERT INTO schema_migrations (version) VALUES ('20111031213508');

INSERT INTO schema_migrations (version) VALUES ('20111109222341');

INSERT INTO schema_migrations (version) VALUES ('20111116223915');

INSERT INTO schema_migrations (version) VALUES ('20111117220320');

INSERT INTO schema_migrations (version) VALUES ('20111117222857');

INSERT INTO schema_migrations (version) VALUES ('20111123002953');

INSERT INTO schema_migrations (version) VALUES ('20111123182747');

INSERT INTO schema_migrations (version) VALUES ('20111123225847');

INSERT INTO schema_migrations (version) VALUES ('20111213010311');

INSERT INTO schema_migrations (version) VALUES ('20120125205205');

INSERT INTO schema_migrations (version) VALUES ('20120203185333');

INSERT INTO schema_migrations (version) VALUES ('20120215191747');

INSERT INTO schema_migrations (version) VALUES ('20120217200829');

INSERT INTO schema_migrations (version) VALUES ('20120217222410');

INSERT INTO schema_migrations (version) VALUES ('20120312200419');

INSERT INTO schema_migrations (version) VALUES ('20120319224443');

INSERT INTO schema_migrations (version) VALUES ('20120325040432');

INSERT INTO schema_migrations (version) VALUES ('20120426180355');

INSERT INTO schema_migrations (version) VALUES ('20120509002838');

INSERT INTO schema_migrations (version) VALUES ('20120511230002');

INSERT INTO schema_migrations (version) VALUES ('20120517192314');

INSERT INTO schema_migrations (version) VALUES ('20120529231940');

INSERT INTO schema_migrations (version) VALUES ('20120614231638');

INSERT INTO schema_migrations (version) VALUES ('20120627173723');

INSERT INTO schema_migrations (version) VALUES ('20120703000606');

INSERT INTO schema_migrations (version) VALUES ('20120717214616');

INSERT INTO schema_migrations (version) VALUES ('20120727191925');

INSERT INTO schema_migrations (version) VALUES ('20120815221020');

INSERT INTO schema_migrations (version) VALUES ('20120820184628');

INSERT INTO schema_migrations (version) VALUES ('20120821135500');

INSERT INTO schema_migrations (version) VALUES ('20120829201115');

INSERT INTO schema_migrations (version) VALUES ('20120913235233');

INSERT INTO schema_migrations (version) VALUES ('20120918202519');

INSERT INTO schema_migrations (version) VALUES ('20120918202629');

INSERT INTO schema_migrations (version) VALUES ('20120921182337');

INSERT INTO schema_migrations (version) VALUES ('20120921183226');

INSERT INTO schema_migrations (version) VALUES ('20120921185201');

INSERT INTO schema_migrations (version) VALUES ('20120924183130');

INSERT INTO schema_migrations (version) VALUES ('20120925175120');

INSERT INTO schema_migrations (version) VALUES ('20120925211936');

INSERT INTO schema_migrations (version) VALUES ('20120928221937');

INSERT INTO schema_migrations (version) VALUES ('20121001182118');

INSERT INTO schema_migrations (version) VALUES ('20121002172101');

INSERT INTO schema_migrations (version) VALUES ('20121017223709');

INSERT INTO schema_migrations (version) VALUES ('20121018202800');

INSERT INTO schema_migrations (version) VALUES ('20121019175414');

INSERT INTO schema_migrations (version) VALUES ('20121022184511');

INSERT INTO schema_migrations (version) VALUES ('20121024235737');

INSERT INTO schema_migrations (version) VALUES ('20121029184501');

INSERT INTO schema_migrations (version) VALUES ('20121102185953');

INSERT INTO schema_migrations (version) VALUES ('20121102185954');

INSERT INTO schema_migrations (version) VALUES ('20121105225817');

INSERT INTO schema_migrations (version) VALUES ('20121106003104');

INSERT INTO schema_migrations (version) VALUES ('20121109175310');

INSERT INTO schema_migrations (version) VALUES ('20121113014111');

INSERT INTO schema_migrations (version) VALUES ('20121114192655');

INSERT INTO schema_migrations (version) VALUES ('20121116200510');

INSERT INTO schema_migrations (version) VALUES ('20121119221200');

INSERT INTO schema_migrations (version) VALUES ('20121120130000');

INSERT INTO schema_migrations (version) VALUES ('20121126194400');

INSERT INTO schema_migrations (version) VALUES ('20121126224643');

INSERT INTO schema_migrations (version) VALUES ('20121128213208');

INSERT INTO schema_migrations (version) VALUES ('20121129205134');

INSERT INTO schema_migrations (version) VALUES ('20121204183853');

INSERT INTO schema_migrations (version) VALUES ('20121206001403');

INSERT INTO schema_migrations (version) VALUES ('20121213000420');

INSERT INTO schema_migrations (version) VALUES ('20130129221516');

INSERT INTO schema_migrations (version) VALUES ('20130130191634');

INSERT INTO schema_migrations (version) VALUES ('20130131000450');

INSERT INTO schema_migrations (version) VALUES ('20130131002543');

INSERT INTO schema_migrations (version) VALUES ('20130131002623');

INSERT INTO schema_migrations (version) VALUES ('20130212193447');

INSERT INTO schema_migrations (version) VALUES ('20130214000000');

INSERT INTO schema_migrations (version) VALUES ('20130214105300');

INSERT INTO schema_migrations (version) VALUES ('20130228193814');

INSERT INTO schema_migrations (version) VALUES ('20130228204141');

INSERT INTO schema_migrations (version) VALUES ('20130301000931');

INSERT INTO schema_migrations (version) VALUES ('20130308234747');

INSERT INTO schema_migrations (version) VALUES ('20130311230741');

INSERT INTO schema_migrations (version) VALUES ('20130312215202');

INSERT INTO schema_migrations (version) VALUES ('20130323000934');

INSERT INTO schema_migrations (version) VALUES ('20130503220125');

INSERT INTO schema_migrations (version) VALUES ('20130507001656');

INSERT INTO schema_migrations (version) VALUES ('20130507213804');

INSERT INTO schema_migrations (version) VALUES ('20130716001915');

INSERT INTO schema_migrations (version) VALUES ('20130718220559');

INSERT INTO schema_migrations (version) VALUES ('20130801173626');

INSERT INTO schema_migrations (version) VALUES ('20130813220740');

INSERT INTO schema_migrations (version) VALUES ('20130905211545');

INSERT INTO schema_migrations (version) VALUES ('20131120192025');

INSERT INTO schema_migrations (version) VALUES ('20131207010403');

INSERT INTO schema_migrations (version) VALUES ('20140205202107');

INSERT INTO schema_migrations (version) VALUES ('20140314181652');

INSERT INTO schema_migrations (version) VALUES ('20140327192231');

INSERT INTO schema_migrations (version) VALUES ('20140328232459');

INSERT INTO schema_migrations (version) VALUES ('20140402220453');

INSERT INTO schema_migrations (version) VALUES ('20140403200916');

INSERT INTO schema_migrations (version) VALUES ('20140404200916');

INSERT INTO schema_migrations (version) VALUES ('20140407211752');

INSERT INTO schema_migrations (version) VALUES ('20140414232603');

INSERT INTO schema_migrations (version) VALUES ('20140422182645');

INSERT INTO schema_migrations (version) VALUES ('20140602190508');

INSERT INTO schema_migrations (version) VALUES ('20140610190508');

INSERT INTO schema_migrations (version) VALUES ('20140619000000');

INSERT INTO schema_migrations (version) VALUES ('20140820000000');

INSERT INTO schema_migrations (version) VALUES ('20140827000000');

INSERT INTO schema_migrations (version) VALUES ('20140916000000');

INSERT INTO schema_migrations (version) VALUES ('20140916010101');

INSERT INTO schema_migrations (version) VALUES ('20140918000000');

INSERT INTO schema_migrations (version) VALUES ('20141001000000');

INSERT INTO schema_migrations (version) VALUES ('20141007000000');

INSERT INTO schema_migrations (version) VALUES ('20150126192138');

INSERT INTO schema_migrations (version) VALUES ('20150316150000');

INSERT INTO schema_migrations (version) VALUES ('20150331171837');

INSERT INTO schema_migrations (version) VALUES ('20150331180353');

INSERT INTO schema_migrations (version) VALUES ('20150515214217');

INSERT INTO schema_migrations (version) VALUES ('20150519203625');

INSERT INTO schema_migrations (version) VALUES ('20150820008847');

INSERT INTO schema_migrations (version) VALUES ('20150909004346');

INSERT INTO schema_migrations (version) VALUES ('20150909221355');

INSERT INTO schema_migrations (version) VALUES ('20150915235156');

INSERT INTO schema_migrations (version) VALUES ('20150916212157');

INSERT INTO schema_migrations (version) VALUES ('20150917003541');

INSERT INTO schema_migrations (version) VALUES ('20150924000145');

INSERT INTO schema_migrations (version) VALUES ('20150925223555');

INSERT INTO schema_migrations (version) VALUES ('20150925233705');

INSERT INTO schema_migrations (version) VALUES ('20150929173025');

INSERT INTO schema_migrations (version) VALUES ('20150930173558');

INSERT INTO schema_migrations (version) VALUES ('20151028182239');

INSERT INTO schema_migrations (version) VALUES ('20151102184136');

INSERT INTO schema_migrations (version) VALUES ('20151103202605');

INSERT INTO schema_migrations (version) VALUES ('20151103223304');

INSERT INTO schema_migrations (version) VALUES ('20151103233019');

INSERT INTO schema_migrations (version) VALUES ('20151104194119');

INSERT INTO schema_migrations (version) VALUES ('20151118230731');

INSERT INTO schema_migrations (version) VALUES ('20151201232718');

INSERT INTO schema_migrations (version) VALUES ('20160104211513');

INSERT INTO schema_migrations (version) VALUES ('20160105192943');

INSERT INTO schema_migrations (version) VALUES ('20160105194921');

INSERT INTO schema_migrations (version) VALUES ('20160106191512');

INSERT INTO schema_migrations (version) VALUES ('20160107221934');

INSERT INTO schema_migrations (version) VALUES ('20160203230248');

INSERT INTO schema_migrations (version) VALUES ('20160212233153');

INSERT INTO schema_migrations (version) VALUES ('20160215233957');

INSERT INTO schema_migrations (version) VALUES ('20160224183108');

INSERT INTO schema_migrations (version) VALUES ('20160224204359');

INSERT INTO schema_migrations (version) VALUES ('20160224204631');

INSERT INTO schema_migrations (version) VALUES ('20160226202053');

INSERT INTO schema_migrations (version) VALUES ('20160314204729');

INSERT INTO schema_migrations (version) VALUES ('20160324194445');

INSERT INTO schema_migrations (version) VALUES ('20160328192857');

INSERT INTO schema_migrations (version) VALUES ('20160407233047');

INSERT INTO schema_migrations (version) VALUES ('20160414182225');

INSERT INTO schema_migrations (version) VALUES ('20160419073419');

INSERT INTO schema_migrations (version) VALUES ('20160616072935');

INSERT INTO schema_migrations (version) VALUES ('20160616101222');

INSERT INTO schema_migrations (version) VALUES ('20160620063359');

INSERT INTO schema_migrations (version) VALUES ('20160727053716');

INSERT INTO schema_migrations (version) VALUES ('20160817083118');

INSERT INTO schema_migrations (version) VALUES ('20160901064736');

INSERT INTO schema_migrations (version) VALUES ('20160906063751');

INSERT INTO schema_migrations (version) VALUES ('20161003115959');

INSERT INTO schema_migrations (version) VALUES ('20170509071927');

INSERT INTO schema_migrations (version) VALUES ('20170809112231');

INSERT INTO schema_migrations (version) VALUES ('20170816114316');

INSERT INTO schema_migrations (version) VALUES ('20170828164349');

INSERT INTO schema_migrations (version) VALUES ('20180206042522');

INSERT INTO schema_migrations (version) VALUES ('20180305063522');

INSERT INTO schema_migrations (version) VALUES ('20180319173133');

INSERT INTO schema_migrations (version) VALUES ('20180329114803');

INSERT INTO schema_migrations (version) VALUES ('20180405055539');

INSERT INTO schema_migrations (version) VALUES ('20180406120539');

INSERT INTO schema_migrations (version) VALUES ('20180406120605');

INSERT INTO schema_migrations (version) VALUES ('20180410054443');

INSERT INTO schema_migrations (version) VALUES ('20180503142118');

INSERT INTO schema_migrations (version) VALUES ('20180509060807');

INSERT INTO schema_migrations (version) VALUES ('20180613063953');

INSERT INTO schema_migrations (version) VALUES ('20180619065017');

INSERT INTO schema_migrations (version) VALUES ('20180621103427');

INSERT INTO schema_migrations (version) VALUES ('20180621111303');

INSERT INTO schema_migrations (version) VALUES ('20180627054717');

INSERT INTO schema_migrations (version) VALUES ('20180628052539');

INSERT INTO schema_migrations (version) VALUES ('20180628133407');

INSERT INTO schema_migrations (version) VALUES ('20180703120001');

INSERT INTO schema_migrations (version) VALUES ('20180704063645');

INSERT INTO schema_migrations (version) VALUES ('20180704124955');

INSERT INTO schema_migrations (version) VALUES ('20180705071855');

INSERT INTO schema_migrations (version) VALUES ('20180705072822');

INSERT INTO schema_migrations (version) VALUES ('20180705094240');

INSERT INTO schema_migrations (version) VALUES ('20180705102647');

INSERT INTO schema_migrations (version) VALUES ('20180706093638');

INSERT INTO schema_migrations (version) VALUES ('20180716105803');

INSERT INTO schema_migrations (version) VALUES ('20180720054016');

INSERT INTO schema_migrations (version) VALUES ('20180724085721');

INSERT INTO schema_migrations (version) VALUES ('20180906054024');

INSERT INTO schema_migrations (version) VALUES ('3-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('4-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('41');

INSERT INTO schema_migrations (version) VALUES ('42');

INSERT INTO schema_migrations (version) VALUES ('43');

INSERT INTO schema_migrations (version) VALUES ('44');

INSERT INTO schema_migrations (version) VALUES ('45');

INSERT INTO schema_migrations (version) VALUES ('46');

INSERT INTO schema_migrations (version) VALUES ('47');

INSERT INTO schema_migrations (version) VALUES ('48');

INSERT INTO schema_migrations (version) VALUES ('49');

INSERT INTO schema_migrations (version) VALUES ('5-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('50');

INSERT INTO schema_migrations (version) VALUES ('51');

INSERT INTO schema_migrations (version) VALUES ('52');

INSERT INTO schema_migrations (version) VALUES ('53');

INSERT INTO schema_migrations (version) VALUES ('54');

INSERT INTO schema_migrations (version) VALUES ('55');

INSERT INTO schema_migrations (version) VALUES ('56');

INSERT INTO schema_migrations (version) VALUES ('57');

INSERT INTO schema_migrations (version) VALUES ('58');

INSERT INTO schema_migrations (version) VALUES ('59');

INSERT INTO schema_migrations (version) VALUES ('6-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('60');

INSERT INTO schema_migrations (version) VALUES ('61');

INSERT INTO schema_migrations (version) VALUES ('62');

INSERT INTO schema_migrations (version) VALUES ('63');

INSERT INTO schema_migrations (version) VALUES ('64');

INSERT INTO schema_migrations (version) VALUES ('65');

INSERT INTO schema_migrations (version) VALUES ('66');

INSERT INTO schema_migrations (version) VALUES ('67');

INSERT INTO schema_migrations (version) VALUES ('68');

INSERT INTO schema_migrations (version) VALUES ('69');

INSERT INTO schema_migrations (version) VALUES ('7-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('70');

INSERT INTO schema_migrations (version) VALUES ('71');

INSERT INTO schema_migrations (version) VALUES ('72');

INSERT INTO schema_migrations (version) VALUES ('73');

INSERT INTO schema_migrations (version) VALUES ('74');

INSERT INTO schema_migrations (version) VALUES ('75');

INSERT INTO schema_migrations (version) VALUES ('76');

INSERT INTO schema_migrations (version) VALUES ('77');

INSERT INTO schema_migrations (version) VALUES ('78');

INSERT INTO schema_migrations (version) VALUES ('79');

INSERT INTO schema_migrations (version) VALUES ('80');

INSERT INTO schema_migrations (version) VALUES ('81');

INSERT INTO schema_migrations (version) VALUES ('82');

INSERT INTO schema_migrations (version) VALUES ('83');

INSERT INTO schema_migrations (version) VALUES ('84');

INSERT INTO schema_migrations (version) VALUES ('85');

INSERT INTO schema_migrations (version) VALUES ('86');

INSERT INTO schema_migrations (version) VALUES ('87');

INSERT INTO schema_migrations (version) VALUES ('88');

INSERT INTO schema_migrations (version) VALUES ('89');

INSERT INTO schema_migrations (version) VALUES ('90');

INSERT INTO schema_migrations (version) VALUES ('91');

INSERT INTO schema_migrations (version) VALUES ('92');

INSERT INTO schema_migrations (version) VALUES ('93');

INSERT INTO schema_migrations (version) VALUES ('94');

INSERT INTO schema_migrations (version) VALUES ('95');

INSERT INTO schema_migrations (version) VALUES ('96');

INSERT INTO schema_migrations (version) VALUES ('97');

INSERT INTO schema_migrations (version) VALUES ('98');

INSERT INTO schema_migrations (version) VALUES ('99');

-- vendor oracle;



-- version 20180906054024