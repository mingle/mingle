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
--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--






SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: asynch_requests; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE asynch_requests (
    id integer NOT NULL,
    user_id integer NOT NULL,
    status character varying(255),
    progress_message character varying(4000),
    error_count integer DEFAULT 0 NOT NULL,
    warning_count integer DEFAULT 0,
    total integer DEFAULT 1 NOT NULL,
    completed integer DEFAULT 0 NOT NULL,
    type character varying(255),
    message text,
    deliverable_identifier character varying(255) NOT NULL,
    tmp_file character varying(255)
);


--
-- Name: asynch_requests_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE asynch_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: asynch_requests_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE asynch_requests_id_seq OWNED BY asynch_requests.id;


--
-- Name: attachings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE attachings (
    id integer NOT NULL,
    attachment_id integer,
    attachable_id integer,
    attachable_type character varying(255)
);


--
-- Name: attachings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE attachings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE attachings_id_seq OWNED BY attachings.id;


--
-- Name: attachments; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE attachments (
    id integer NOT NULL,
    file character varying(255) DEFAULT ''::character varying NOT NULL,
    path character varying(255) DEFAULT ''::character varying NOT NULL,
    project_id integer NOT NULL
);


--
-- Name: attachments_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachments_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE attachments_id_seq OWNED BY attachments.id;


--
-- Name: backlog_objectives; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE backlog_objectives (
    id integer NOT NULL,
    name character varying(80),
    backlog_id integer,
    "position" integer,
    size integer DEFAULT 0,
    value integer DEFAULT 0,
    value_statement character varying(750)
);


--
-- Name: backlog_objectives_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE backlog_objectives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backlog_objectives_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE backlog_objectives_id_seq OWNED BY backlog_objectives.id;


--
-- Name: backlogs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE backlogs (
    id integer NOT NULL,
    program_id integer
);


--
-- Name: backlogs_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE backlogs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backlogs_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE backlogs_id_seq OWNED BY backlogs.id;


--
-- Name: cache_keys; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE cache_keys (
    id integer NOT NULL,
    deliverable_id integer,
    structure_key character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    card_key character varying(255),
    feed_key character varying(255),
    deliverable_type character varying(255) DEFAULT 'Project'::character varying NOT NULL
);


--
-- Name: card_defaults; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_defaults (
    id integer NOT NULL,
    card_type_id integer NOT NULL,
    project_id integer NOT NULL,
    description text,
    redcloth boolean
);


--
-- Name: card_defaults_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_defaults_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_defaults_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_defaults_id_seq OWNED BY card_defaults.id;


--
-- Name: card_id_sequence; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_id_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_list_views; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_list_views (
    id integer NOT NULL,
    project_id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    params text,
    canonical_string text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: card_list_views_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_list_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_list_views_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_list_views_id_seq OWNED BY card_list_views.id;


--
-- Name: card_murmur_links; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_murmur_links (
    id integer NOT NULL,
    card_id integer,
    project_id integer,
    murmur_id integer
);


--
-- Name: card_murmur_links_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_murmur_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_murmur_links_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_murmur_links_id_seq OWNED BY card_murmur_links.id;


--
-- Name: card_revision_links; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_revision_links (
    id integer NOT NULL,
    project_id integer NOT NULL,
    card_id integer NOT NULL,
    revision_id integer NOT NULL
);


--
-- Name: card_revision_links_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_revision_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_revision_links_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_revision_links_id_seq OWNED BY card_revision_links.id;


--
-- Name: tree_belongings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tree_belongings (
    id integer NOT NULL,
    tree_configuration_id integer NOT NULL,
    card_id integer NOT NULL
);


--
-- Name: card_trees_cards_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_trees_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_trees_cards_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_trees_cards_id_seq OWNED BY tree_belongings.id;


--
-- Name: tree_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tree_configurations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    project_id integer NOT NULL,
    description character varying(255)
);


--
-- Name: card_trees_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_trees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_trees_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_trees_id_seq OWNED BY tree_configurations.id;


--
-- Name: card_types; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_types (
    id integer NOT NULL,
    project_id integer,
    name character varying(255) NOT NULL,
    color character varying(255),
    "position" integer
);


--
-- Name: card_types_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_types_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_types_id_seq OWNED BY card_types.id;


--
-- Name: property_type_mappings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE property_type_mappings (
    id integer NOT NULL,
    card_type_id integer NOT NULL,
    property_definition_id integer NOT NULL,
    "position" integer
);


--
-- Name: card_types_property_definitions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_types_property_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_types_property_definitions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_types_property_definitions_id_seq OWNED BY property_type_mappings.id;


--
-- Name: card_version_id_sequence; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_version_id_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_versions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE card_versions (
    id integer NOT NULL,
    card_id integer,
    version integer,
    project_id integer,
    number integer,
    name character varying(255) DEFAULT ''::character varying,
    description text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    created_by_user_id integer DEFAULT 0 NOT NULL,
    modified_by_user_id integer DEFAULT 0 NOT NULL,
    comment text,
    card_type_name character varying(255) NOT NULL,
    has_macros boolean DEFAULT false,
    system_generated_comment text,
    updater_id character varying(255),
    redcloth boolean
);


--
-- Name: card_versions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE card_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_versions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE card_versions_id_seq OWNED BY card_versions.id;


--
-- Name: cards; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE cards (
    id integer NOT NULL,
    project_id integer NOT NULL,
    number integer NOT NULL,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer,
    card_type_name character varying(255) NOT NULL,
    has_macros boolean DEFAULT false,
    project_card_rank numeric,
    caching_stamp integer DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    created_by_user_id integer NOT NULL,
    modified_by_user_id integer NOT NULL,
    redcloth boolean
);


--
-- Name: cards_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE cards_id_seq OWNED BY cards.id;


--
-- Name: changes; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE changes (
    id integer NOT NULL,
    event_id integer NOT NULL,
    type character varying(255) DEFAULT ''::character varying NOT NULL,
    old_value character varying(255),
    new_value character varying(255),
    attachment_id integer,
    tag_id integer,
    field character varying(255) DEFAULT ''::character varying NOT NULL
);


--
-- Name: changes_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: changes_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE changes_id_seq OWNED BY changes.id;


--
-- Name: checklist_items; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE checklist_items (
    id integer NOT NULL,
    text character varying(255),
    completed boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    card_id integer,
    project_id integer,
    "position" integer
);


--
-- Name: checklist_items_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE checklist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_items_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE checklist_items_id_seq OWNED BY checklist_items.id;


--
-- Name: murmur_channels; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE murmur_channels (
    id integer NOT NULL,
    project_id integer NOT NULL,
    jabber_chat_room_id character varying(255),
    jabber_chat_room_status character varying(255),
    enabled boolean,
    type character varying(255) DEFAULT 'BuiltInChannel'::character varying
);


--
-- Name: collaboration_settings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE collaboration_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collaboration_settings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE collaboration_settings_id_seq OWNED BY murmur_channels.id;


--
-- Name: stale_prop_defs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE stale_prop_defs (
    id integer NOT NULL,
    card_id integer NOT NULL,
    prop_def_id integer NOT NULL,
    project_id integer NOT NULL
);


--
-- Name: compute_aggregate_requests_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE compute_aggregate_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: compute_aggregate_requests_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE compute_aggregate_requests_id_seq OWNED BY stale_prop_defs.id;


--
-- Name: conversations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE conversations (
    id integer NOT NULL,
    created_at timestamp without time zone,
    project_id integer
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE conversations_id_seq OWNED BY conversations.id;


--
-- Name: correction_changes; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE correction_changes (
    id integer NOT NULL,
    event_id integer,
    old_value character varying(255),
    new_value character varying(255),
    change_type character varying(255) NOT NULL,
    resource_1 integer,
    resource_2 integer
);


--
-- Name: correction_changes_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE correction_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: correction_changes_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE correction_changes_id_seq OWNED BY correction_changes.id;


--
-- Name: deliverables; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE deliverables (
    id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    identifier character varying(255) DEFAULT ''::character varying NOT NULL,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    icon character varying(255),
    created_by_user_id integer,
    modified_by_user_id integer,
    card_keywords character varying(255),
    template boolean,
    secret_key character varying(255),
    email_address character varying(255),
    email_sender_name character varying(255),
    hidden boolean DEFAULT false,
    date_format character varying(255) DEFAULT '%d %b %Y'::character varying,
    time_zone character varying(255),
    "precision" integer DEFAULT 2,
    anonymous_accessible boolean DEFAULT false,
    corruption_checked boolean,
    corruption_info text,
    auto_enroll_user_type character varying(255),
    cards_table character varying(255),
    card_versions_table character varying(255),
    membership_requestable boolean,
    type character varying(255),
    pre_defined_template boolean,
    landing_tab_id integer,
    ordered_tab_identifiers text,
    exclude_weekends_in_cta boolean DEFAULT false NOT NULL,
    accepts_dependencies boolean DEFAULT false
);


--
-- Name: dependencies; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE dependencies (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    desired_end_date date NOT NULL,
    resolving_project_id integer,
    raising_project_id integer NOT NULL,
    raising_card_id integer NOT NULL,
    number integer,
    created_at timestamp without time zone,
    raising_user_id integer,
    status character varying(255) DEFAULT 'NEW'::character varying NOT NULL,
    version integer
);


--
-- Name: dependencies_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dependencies_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE dependencies_id_seq OWNED BY dependencies.id;


--
-- Name: dependency_resolving_cards; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE dependency_resolving_cards (
    id integer NOT NULL,
    card_id integer NOT NULL,
    dependency_id integer NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    dependency_type character varying(255)
);


--
-- Name: dependency_resolving_cards_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE dependency_resolving_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dependency_resolving_cards_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE dependency_resolving_cards_id_seq OWNED BY dependency_resolving_cards.id;


--
-- Name: dependency_versions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE dependency_versions (
    id integer NOT NULL,
    dependency_id integer NOT NULL,
    version integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    desired_end_date date NOT NULL,
    resolving_project_id integer,
    raising_project_id integer NOT NULL,
    raising_card_id integer NOT NULL,
    number integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    raising_user_id integer,
    status character varying(255) NOT NULL
);


--
-- Name: dependency_versions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE dependency_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dependency_versions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE dependency_versions_id_seq OWNED BY dependency_versions.id;


--
-- Name: dependency_views; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE dependency_views (
    id integer NOT NULL,
    project_id integer NOT NULL,
    user_id integer NOT NULL,
    params character varying(4096),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: dependency_views_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE dependency_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dependency_views_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE dependency_views_id_seq OWNED BY dependency_views.id;


--
-- Name: enumeration_values; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE enumeration_values (
    id integer NOT NULL,
    value character varying(255) DEFAULT ''::character varying NOT NULL,
    property_definition_id integer,
    color character varying(255),
    "position" integer
);


--
-- Name: enumeration_values_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE enumeration_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enumeration_values_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE enumeration_values_id_seq OWNED BY enumeration_values.id;


--
-- Name: events; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE events (
    id integer NOT NULL,
    type character varying(255) NOT NULL,
    origin_type character varying(255) NOT NULL,
    origin_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    created_by_user_id integer,
    deliverable_id integer NOT NULL,
    history_generated boolean DEFAULT false,
    mingle_timestamp timestamp without time zone DEFAULT timezone('utc'::text, clock_timestamp()),
    deliverable_type character varying(255) DEFAULT 'Project'::character varying NOT NULL,
    details character varying(4096)
);


--
-- Name: events_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE events_id_seq OWNED BY events.id;


--
-- Name: favorites; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE favorites (
    id integer NOT NULL,
    project_id integer NOT NULL,
    favorited_type character varying(255) NOT NULL,
    favorited_id integer NOT NULL,
    tab_view boolean DEFAULT false NOT NULL,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE favorites_id_seq OWNED BY favorites.id;


--
-- Name: gadgets_oauth_clients; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE gadgets_oauth_clients (
    id integer NOT NULL,
    oauth_authorize_url character varying(255),
    client_id character varying(255),
    client_secret character varying(255),
    service_name character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: gadgets_oauth_clients_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE gadgets_oauth_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gadgets_oauth_clients_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE gadgets_oauth_clients_id_seq OWNED BY gadgets_oauth_clients.id;


--
-- Name: git_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE git_configurations (
    id integer NOT NULL,
    project_id integer,
    repository_path character varying(255),
    username character varying(255),
    password character varying(255),
    initialized boolean,
    card_revision_links_invalid boolean,
    marked_for_deletion boolean DEFAULT false
);


--
-- Name: git_configurations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE git_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: git_configurations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE git_configurations_id_seq OWNED BY git_configurations.id;


--
-- Name: githubs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE githubs (
    id integer NOT NULL,
    username character varying(255),
    repository character varying(255),
    project_id integer,
    webhook_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: githubs_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE githubs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: githubs_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE githubs_id_seq OWNED BY githubs.id;


--
-- Name: user_memberships; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE user_memberships (
    id integer NOT NULL,
    group_id integer,
    user_id integer
);


--
-- Name: group_memberships_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE group_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_memberships_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE group_memberships_id_seq OWNED BY user_memberships.id;


--
-- Name: groups; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE groups (
    id integer NOT NULL,
    name character varying(255),
    deliverable_id integer,
    internal boolean DEFAULT false NOT NULL
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE groups_id_seq OWNED BY groups.id;


--
-- Name: hg_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE hg_configurations (
    id integer NOT NULL,
    project_id integer,
    repository_path character varying(255),
    username character varying(255),
    password character varying(255),
    initialized boolean,
    card_revision_links_invalid boolean,
    marked_for_deletion boolean DEFAULT false
);


--
-- Name: hg_configurations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE hg_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hg_configurations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE hg_configurations_id_seq OWNED BY hg_configurations.id;


--
-- Name: history_subscriptions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE history_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer NOT NULL,
    filter_params text,
    last_max_card_version_id integer NOT NULL,
    last_max_page_version_id integer NOT NULL,
    last_max_revision_id integer NOT NULL,
    hashed_filter_params character varying(255),
    error_message character varying(255)
);


--
-- Name: history_subscriptions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE history_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: history_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE history_subscriptions_id_seq OWNED BY history_subscriptions.id;


--
-- Name: licenses; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE licenses (
    id integer NOT NULL,
    eula_accepted boolean,
    license_key text
);


--
-- Name: licenses_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE licenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: licenses_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE licenses_id_seq OWNED BY licenses.id;


--
-- Name: login_access; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE login_access (
    id integer NOT NULL,
    user_id integer NOT NULL,
    login_token character varying(255),
    last_login_at timestamp without time zone,
    lost_password_key character varying(4096),
    lost_password_reported_at timestamp without time zone,
    first_login_at timestamp without time zone
);


--
-- Name: login_access_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE login_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_access_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE login_access_id_seq OWNED BY login_access.id;


--
-- Name: luau_configs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_configs (
    id integer NOT NULL,
    base_url character varying(255),
    submitted_at timestamp without time zone,
    state character varying(255),
    client_key character varying(255),
    auth_state_explanation character varying(255),
    sync_status character varying(255),
    last_sync_time timestamp without time zone,
    marked_for_deletion boolean,
    client_digest character varying(255),
    sync_forced integer DEFAULT 0,
    last_successful_sync_time timestamp without time zone
);


--
-- Name: luau_configs_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_configs_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_configs_id_seq OWNED BY luau_configs.id;


--
-- Name: luau_group_memberships; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_group_memberships (
    id integer NOT NULL,
    luau_group_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: luau_group_memberships_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_group_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_group_memberships_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_group_memberships_id_seq OWNED BY luau_group_memberships.id;


--
-- Name: luau_group_user_mappings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_group_user_mappings (
    id integer NOT NULL,
    luau_group_id integer,
    user_login character varying(255)
);


--
-- Name: luau_group_user_mappings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_group_user_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_group_user_mappings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_group_user_mappings_id_seq OWNED BY luau_group_user_mappings.id;


--
-- Name: luau_groups; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_groups (
    id integer NOT NULL,
    identifier character varying(255) NOT NULL,
    full_name character varying(255) NOT NULL,
    restricted_to_readonly boolean DEFAULT false NOT NULL,
    name character varying(255)
);


--
-- Name: luau_groups_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_groups_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_groups_id_seq OWNED BY luau_groups.id;


--
-- Name: luau_groups_mappings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_groups_mappings (
    id integer NOT NULL,
    parent_group_id integer NOT NULL,
    child_group_id integer NOT NULL,
    direct boolean DEFAULT false NOT NULL
);


--
-- Name: luau_groups_mappings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_groups_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_groups_mappings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_groups_mappings_id_seq OWNED BY luau_groups_mappings.id;


--
-- Name: luau_lock_fail; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE luau_lock_fail (
    id integer NOT NULL,
    lock_fail character varying(1) NOT NULL
);


--
-- Name: luau_lock_fail_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_lock_fail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: luau_lock_fail_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE luau_lock_fail_id_seq OWNED BY luau_lock_fail.id;


--
-- Name: luau_transaction_counter; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE luau_transaction_counter
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    CYCLE;


--
-- Name: member_roles; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE member_roles (
    id integer NOT NULL,
    deliverable_id integer NOT NULL,
    member_type character varying(255) NOT NULL,
    member_id integer NOT NULL,
    permission character varying(255)
);


--
-- Name: member_roles_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE member_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_roles_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE member_roles_id_seq OWNED BY member_roles.id;


--
-- Name: murmurs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE murmurs (
    id integer NOT NULL,
    project_id integer NOT NULL,
    packet_id character varying(255),
    jabber_user_name character varying(255),
    created_at timestamp without time zone NOT NULL,
    murmur text NOT NULL,
    author_id integer,
    origin_type character varying(255),
    origin_id integer,
    type character varying(255) DEFAULT 'DefaultMurmur'::character varying,
    conversation_id integer
);


--
-- Name: murmurs_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE murmurs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: murmurs_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE murmurs_id_seq OWNED BY murmurs.id;


--
-- Name: murmurs_read_counts; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE murmurs_read_counts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer NOT NULL,
    read_count integer DEFAULT 0
);


--
-- Name: murmurs_read_counts_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE murmurs_read_counts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: murmurs_read_counts_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE murmurs_read_counts_id_seq OWNED BY murmurs_read_counts.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE oauth_access_tokens (
    id integer NOT NULL,
    gadgets_oauth_client_id integer,
    user_id character varying(255),
    access_token character varying(255),
    refresh_token character varying(255),
    expires_in integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE oauth_access_tokens_id_seq OWNED BY oauth_access_tokens.id;


--
-- Name: oauth_authorization_codes; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE oauth_authorization_codes (
    id integer NOT NULL,
    gadgets_oauth_client_id integer,
    user_id character varying(255),
    code character varying(255),
    expires_in integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: oauth_authorization_codes_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE oauth_authorization_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_authorization_codes_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE oauth_authorization_codes_id_seq OWNED BY oauth_authorization_codes.id;


--
-- Name: oauth_authorizations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE oauth_authorizations (
    id integer NOT NULL,
    user_id character varying(255),
    oauth_client_id integer,
    code character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    expires_at integer
);


--
-- Name: oauth_authorizations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE oauth_authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_authorizations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE oauth_authorizations_id_seq OWNED BY oauth_authorizations.id;


--
-- Name: oauth_clients; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE oauth_clients (
    id integer NOT NULL,
    name character varying(255),
    client_id character varying(255),
    client_secret character varying(255),
    redirect_uri character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: oauth_clients_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE oauth_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_clients_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE oauth_clients_id_seq OWNED BY oauth_clients.id;


--
-- Name: oauth_tokens; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE oauth_tokens (
    id integer NOT NULL,
    user_id character varying(255),
    oauth_client_id integer,
    access_token character varying(255),
    refresh_token character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    expires_at integer
);


--
-- Name: oauth_tokens_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE oauth_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_tokens_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE oauth_tokens_id_seq OWNED BY oauth_tokens.id;


--
-- Name: objective_filters; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE objective_filters (
    id integer NOT NULL,
    project_id integer,
    objective_id integer,
    params character varying(4096),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    synced boolean
);


--
-- Name: objective_filters_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE objective_filters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: objective_filters_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE objective_filters_id_seq OWNED BY objective_filters.id;


--
-- Name: objective_snapshots; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE objective_snapshots (
    id integer NOT NULL,
    total integer,
    completed integer,
    project_id integer,
    objective_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    dated date
);


--
-- Name: objective_versions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE objective_versions (
    id integer NOT NULL,
    objective_id integer,
    version integer,
    plan_id integer,
    vertical_position integer,
    identifier character varying(255),
    value_statement character varying(750),
    size integer DEFAULT 0,
    value integer DEFAULT 0,
    name character varying(255),
    start_at timestamp without time zone,
    end_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    modified_by_user_id integer,
    number integer
);


--
-- Name: objective_versions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE objective_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: objective_versions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE objective_versions_id_seq OWNED BY objective_versions.id;


--
-- Name: objectives; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE objectives (
    id integer NOT NULL,
    plan_id integer,
    name character varying(80),
    start_at date,
    end_at date,
    vertical_position integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    identifier character varying(40),
    value_statement character varying(750),
    size integer DEFAULT 0,
    value integer DEFAULT 0,
    version integer,
    modified_by_user_id integer,
    number integer
);


--
-- Name: page_versions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE page_versions (
    id integer NOT NULL,
    page_id integer,
    version integer,
    name character varying(255) DEFAULT ''::character varying,
    content text,
    project_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    created_by_user_id integer,
    modified_by_user_id integer,
    has_macros boolean DEFAULT false,
    system_generated_comment text,
    redcloth boolean
);


--
-- Name: page_versions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: page_versions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE page_versions_id_seq OWNED BY page_versions.id;


--
-- Name: pages; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE pages (
    id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    content text,
    project_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    created_by_user_id integer,
    modified_by_user_id integer,
    version integer,
    has_macros boolean DEFAULT false,
    redcloth boolean
);


--
-- Name: pages_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pages_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE pages_id_seq OWNED BY pages.id;


--
-- Name: perforce_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE perforce_configurations (
    id integer NOT NULL,
    project_id integer,
    username character varying(255),
    password character varying(255),
    port character varying(255),
    host character varying(255),
    repository_path text,
    initialized boolean,
    card_revision_links_invalid boolean,
    marked_for_deletion boolean DEFAULT false
);


--
-- Name: perforce_configurations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE perforce_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: perforce_configurations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE perforce_configurations_id_seq OWNED BY perforce_configurations.id;


--
-- Name: program_projects; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE program_projects (
    id integer NOT NULL,
    project_id integer NOT NULL,
    done_status_id integer,
    status_property_id integer,
    program_id integer,
    accepts_dependencies boolean DEFAULT true
);


--
-- Name: plan_projects_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE plan_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plan_projects_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE plan_projects_id_seq OWNED BY program_projects.id;


--
-- Name: plans; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE plans (
    id integer NOT NULL,
    start_at date,
    end_at date,
    program_id integer,
    "precision" integer DEFAULT 2,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: plans_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plans_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE plans_id_seq OWNED BY plans.id;


--
-- Name: program_dependency_views; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE program_dependency_views (
    id integer NOT NULL,
    program_id integer NOT NULL,
    user_id integer NOT NULL,
    params character varying(4096),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: program_dependency_views_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE program_dependency_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: program_dependency_views_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE program_dependency_views_id_seq OWNED BY program_dependency_views.id;


--
-- Name: project_structure_keys_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE project_structure_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_structure_keys_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE project_structure_keys_id_seq OWNED BY cache_keys.id;


--
-- Name: project_variables; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE project_variables (
    id integer NOT NULL,
    project_id integer NOT NULL,
    data_type character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    value character varying(255),
    card_type_id integer
);


--
-- Name: project_variables_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE project_variables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_variables_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE project_variables_id_seq OWNED BY project_variables.id;


--
-- Name: projects_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE projects_id_seq OWNED BY deliverables.id;


--
-- Name: projects_luau_group_memberships; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE projects_luau_group_memberships (
    id integer NOT NULL,
    project_id integer NOT NULL,
    luau_group_id integer NOT NULL
);


--
-- Name: projects_luau_group_memberships_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE projects_luau_group_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_luau_group_memberships_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE projects_luau_group_memberships_id_seq OWNED BY projects_luau_group_memberships.id;


--
-- Name: property_definitions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE property_definitions (
    id integer NOT NULL,
    type character varying(255),
    project_id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    description text,
    column_name character varying(255) DEFAULT ''::character varying NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    restricted boolean DEFAULT false NOT NULL,
    transition_only boolean DEFAULT false,
    valid_card_type_id integer,
    is_numeric boolean DEFAULT false,
    tree_configuration_id integer,
    "position" integer,
    formula text,
    aggregate_target_id integer,
    aggregate_type character varying(255),
    aggregate_card_type_id integer,
    aggregate_scope_card_type_id integer,
    ruby_name character varying(255),
    dependant_formulas character varying(4096),
    aggregate_condition text,
    null_is_zero boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: property_definitions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE property_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: property_definitions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE property_definitions_id_seq OWNED BY property_definitions.id;


--
-- Name: revisions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE revisions (
    id integer NOT NULL,
    project_id integer NOT NULL,
    number integer NOT NULL,
    commit_message text NOT NULL,
    commit_time timestamp without time zone NOT NULL,
    commit_user character varying(255) NOT NULL,
    identifier character varying(255)
);


--
-- Name: revisions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: revisions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE revisions_id_seq OWNED BY revisions.id;


--
-- Name: saas_tos; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE saas_tos (
    id integer NOT NULL,
    user_email character varying(255),
    accepted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: saas_tos_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE saas_tos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saas_tos_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE saas_tos_id_seq OWNED BY saas_tos.id;


--
-- Name: works; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE works (
    id integer NOT NULL,
    objective_id integer,
    card_number integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    plan_id integer,
    completed boolean,
    name character varying(255),
    bulk_updater_id character varying(255),
    project_id integer
);


--
-- Name: scheduled_works_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE scheduled_works_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_works_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE scheduled_works_id_seq OWNED BY works.id;


--
-- Name: table_sequences; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE table_sequences (
    id integer NOT NULL,
    name character varying(255),
    last_value integer
);


--
-- Name: sequences_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE sequences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sequences_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE sequences_id_seq OWNED BY table_sequences.id;


--
-- Name: sessions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE sessions (
    id integer NOT NULL,
    session_id character varying(255) NOT NULL,
    data text,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE sessions_id_seq OWNED BY sessions.id;


--
-- Name: stream_histories_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE stream_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stream_histories_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE stream_histories_id_seq OWNED BY objective_snapshots.id;


--
-- Name: streams_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE streams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: streams_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE streams_id_seq OWNED BY objectives.id;


--
-- Name: subversion_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE subversion_configurations (
    id integer NOT NULL,
    project_id integer,
    username character varying(255),
    password character varying(255),
    repository_path text,
    card_revision_links_invalid boolean,
    marked_for_deletion boolean DEFAULT false,
    initialized boolean
);


--
-- Name: subversion_configurations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE subversion_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subversion_configurations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE subversion_configurations_id_seq OWNED BY subversion_configurations.id;


--
-- Name: tab_positions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tab_positions (
    id integer NOT NULL,
    project_id integer,
    html_id character varying(255) NOT NULL,
    "position" integer
);


--
-- Name: tab_positions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE tab_positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tab_positions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE tab_positions_id_seq OWNED BY tab_positions.id;


--
-- Name: tabs; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tabs (
    id integer NOT NULL,
    name character varying(255),
    "position" integer,
    tab_type character varying(255) NOT NULL,
    target_type character varying(255),
    target_id integer,
    project_id integer NOT NULL
);


--
-- Name: tabs_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE tabs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tabs_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE tabs_id_seq OWNED BY tabs.id;


--
-- Name: taggings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE taggings (
    id integer NOT NULL,
    tag_id integer,
    taggable_id integer,
    taggable_type character varying(255)
);


--
-- Name: taggings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taggings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE taggings_id_seq OWNED BY taggings.id;


--
-- Name: tags; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    project_id integer NOT NULL,
    deleted_at timestamp without time zone,
    color character varying(255)
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: temporary_id_storages; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE temporary_id_storages (
    session_id character varying(255),
    id_1 integer,
    id_2 integer
);


--
-- Name: tfsscm_configurations; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE tfsscm_configurations (
    id integer NOT NULL,
    project_id integer,
    initialized boolean,
    card_revision_links_invalid boolean,
    marked_for_deletion boolean DEFAULT false,
    server_url character varying(255),
    username character varying(255),
    tfs_project character varying(255),
    password character varying(255),
    domain character varying(255),
    collection character varying(255)
);


--
-- Name: tfsscm_configurations_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE tfsscm_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tfsscm_configurations_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE tfsscm_configurations_id_seq OWNED BY tfsscm_configurations.id;


--
-- Name: todos; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE todos (
    id integer NOT NULL,
    user_id integer,
    done boolean DEFAULT false,
    content character varying(255),
    "position" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: todos_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE todos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: todos_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE todos_id_seq OWNED BY todos.id;


--
-- Name: transition_actions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE transition_actions (
    id integer NOT NULL,
    executor_id integer NOT NULL,
    target_id integer NOT NULL,
    value character varying(255) DEFAULT ''::character varying,
    executor_type character varying(255) NOT NULL,
    type character varying(255),
    variable_binding_id integer
);


--
-- Name: transition_actions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE transition_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transition_actions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE transition_actions_id_seq OWNED BY transition_actions.id;


--
-- Name: transition_prerequisites; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE transition_prerequisites (
    id integer NOT NULL,
    transition_id integer NOT NULL,
    type character varying(255) DEFAULT ''::character varying NOT NULL,
    user_id integer,
    property_definition_id integer,
    value character varying(255),
    project_variable_id integer,
    group_id integer
);


--
-- Name: transition_prerequisites_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE transition_prerequisites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transition_prerequisites_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE transition_prerequisites_id_seq OWNED BY transition_prerequisites.id;


--
-- Name: transitions; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE transitions (
    id integer NOT NULL,
    project_id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    card_type_id integer,
    require_comment boolean DEFAULT false
);


--
-- Name: transitions_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE transitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transitions_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE transitions_id_seq OWNED BY transitions.id;


--
-- Name: user_display_preferences; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE user_display_preferences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    sidebar_visible boolean NOT NULL,
    favorites_visible boolean NOT NULL,
    recent_pages_visible boolean NOT NULL,
    color_legend_visible boolean,
    filters_visible boolean,
    history_have_been_visible boolean,
    history_changed_to_visible boolean,
    excel_import_export_visible boolean,
    include_description boolean,
    show_murmurs_in_sidebar boolean,
    personal_favorites_visible boolean,
    murmur_this_comment boolean DEFAULT true NOT NULL,
    explore_mingle_tab_visible boolean DEFAULT true NOT NULL,
    contextual_help text DEFAULT ''::text NOT NULL,
    export_all_columns boolean DEFAULT false NOT NULL,
    show_deactived_users boolean DEFAULT true NOT NULL,
    timeline_granularity character varying(255),
    grid_settings boolean DEFAULT true NOT NULL,
    preferences text
);


--
-- Name: user_display_preferences_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE user_display_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_display_preferences_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE user_display_preferences_id_seq OWNED BY user_display_preferences.id;


--
-- Name: user_engagements; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE user_engagements (
    id integer NOT NULL,
    user_id integer NOT NULL,
    trial_feedback_shown boolean DEFAULT false
);


--
-- Name: user_engagements_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE user_engagements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_engagements_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE user_engagements_id_seq OWNED BY user_engagements.id;


--
-- Name: user_filter_usages; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE user_filter_usages (
    id integer NOT NULL,
    filterable_id integer,
    filterable_type character varying(255),
    user_id integer
);


--
-- Name: user_filter_usages_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE user_filter_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_filter_usages_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE user_filter_usages_id_seq OWNED BY user_filter_usages.id;


--
-- Name: users; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying(255),
    password character varying(255),
    admin boolean,
    version_control_user_name character varying(255),
    login character varying(255) DEFAULT ''::character varying NOT NULL,
    name character varying(255),
    activated boolean DEFAULT true,
    light boolean DEFAULT false,
    icon character varying(255),
    jabber_user_name character varying(255),
    jabber_password character varying(255),
    salt character varying(255),
    locked_against_delete boolean DEFAULT false,
    system boolean DEFAULT false,
    api_key character varying(255),
    read_notification_digest character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: variable_bindings; Type: TABLE; Owner: -; Tablespace: 
--

CREATE TABLE variable_bindings (
    id integer NOT NULL,
    project_variable_id integer NOT NULL,
    property_definition_id integer NOT NULL
);


--
-- Name: variable_bindings_id_seq; Type: SEQUENCE; Owner: -
--

CREATE SEQUENCE variable_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: variable_bindings_id_seq; Type: SEQUENCE OWNED BY; Owner: -
--

ALTER SEQUENCE variable_bindings_id_seq OWNED BY variable_bindings.id;


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY asynch_requests ALTER COLUMN id SET DEFAULT nextval('asynch_requests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY attachings ALTER COLUMN id SET DEFAULT nextval('attachings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY attachments ALTER COLUMN id SET DEFAULT nextval('attachments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY backlog_objectives ALTER COLUMN id SET DEFAULT nextval('backlog_objectives_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY backlogs ALTER COLUMN id SET DEFAULT nextval('backlogs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY cache_keys ALTER COLUMN id SET DEFAULT nextval('project_structure_keys_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_defaults ALTER COLUMN id SET DEFAULT nextval('card_defaults_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_list_views ALTER COLUMN id SET DEFAULT nextval('card_list_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_murmur_links ALTER COLUMN id SET DEFAULT nextval('card_murmur_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_revision_links ALTER COLUMN id SET DEFAULT nextval('card_revision_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_types ALTER COLUMN id SET DEFAULT nextval('card_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY card_versions ALTER COLUMN id SET DEFAULT nextval('card_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY cards ALTER COLUMN id SET DEFAULT nextval('cards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY changes ALTER COLUMN id SET DEFAULT nextval('changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY checklist_items ALTER COLUMN id SET DEFAULT nextval('checklist_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY conversations ALTER COLUMN id SET DEFAULT nextval('conversations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY correction_changes ALTER COLUMN id SET DEFAULT nextval('correction_changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY deliverables ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY dependencies ALTER COLUMN id SET DEFAULT nextval('dependencies_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY dependency_resolving_cards ALTER COLUMN id SET DEFAULT nextval('dependency_resolving_cards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY dependency_versions ALTER COLUMN id SET DEFAULT nextval('dependency_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY dependency_views ALTER COLUMN id SET DEFAULT nextval('dependency_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY enumeration_values ALTER COLUMN id SET DEFAULT nextval('enumeration_values_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY favorites ALTER COLUMN id SET DEFAULT nextval('favorites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY gadgets_oauth_clients ALTER COLUMN id SET DEFAULT nextval('gadgets_oauth_clients_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY git_configurations ALTER COLUMN id SET DEFAULT nextval('git_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY githubs ALTER COLUMN id SET DEFAULT nextval('githubs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY groups ALTER COLUMN id SET DEFAULT nextval('groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY hg_configurations ALTER COLUMN id SET DEFAULT nextval('hg_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY history_subscriptions ALTER COLUMN id SET DEFAULT nextval('history_subscriptions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY licenses ALTER COLUMN id SET DEFAULT nextval('licenses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY login_access ALTER COLUMN id SET DEFAULT nextval('login_access_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_configs ALTER COLUMN id SET DEFAULT nextval('luau_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_group_memberships ALTER COLUMN id SET DEFAULT nextval('luau_group_memberships_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_group_user_mappings ALTER COLUMN id SET DEFAULT nextval('luau_group_user_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_groups ALTER COLUMN id SET DEFAULT nextval('luau_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_groups_mappings ALTER COLUMN id SET DEFAULT nextval('luau_groups_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY luau_lock_fail ALTER COLUMN id SET DEFAULT nextval('luau_lock_fail_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY member_roles ALTER COLUMN id SET DEFAULT nextval('member_roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY murmur_channels ALTER COLUMN id SET DEFAULT nextval('collaboration_settings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY murmurs ALTER COLUMN id SET DEFAULT nextval('murmurs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY murmurs_read_counts ALTER COLUMN id SET DEFAULT nextval('murmurs_read_counts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('oauth_access_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY oauth_authorization_codes ALTER COLUMN id SET DEFAULT nextval('oauth_authorization_codes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY oauth_authorizations ALTER COLUMN id SET DEFAULT nextval('oauth_authorizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY oauth_clients ALTER COLUMN id SET DEFAULT nextval('oauth_clients_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY oauth_tokens ALTER COLUMN id SET DEFAULT nextval('oauth_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY objective_filters ALTER COLUMN id SET DEFAULT nextval('objective_filters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY objective_snapshots ALTER COLUMN id SET DEFAULT nextval('stream_histories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY objective_versions ALTER COLUMN id SET DEFAULT nextval('objective_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY objectives ALTER COLUMN id SET DEFAULT nextval('streams_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY page_versions ALTER COLUMN id SET DEFAULT nextval('page_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY pages ALTER COLUMN id SET DEFAULT nextval('pages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY perforce_configurations ALTER COLUMN id SET DEFAULT nextval('perforce_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY plans ALTER COLUMN id SET DEFAULT nextval('plans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY program_dependency_views ALTER COLUMN id SET DEFAULT nextval('program_dependency_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY program_projects ALTER COLUMN id SET DEFAULT nextval('plan_projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY project_variables ALTER COLUMN id SET DEFAULT nextval('project_variables_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY projects_luau_group_memberships ALTER COLUMN id SET DEFAULT nextval('projects_luau_group_memberships_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY property_definitions ALTER COLUMN id SET DEFAULT nextval('property_definitions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY property_type_mappings ALTER COLUMN id SET DEFAULT nextval('card_types_property_definitions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY revisions ALTER COLUMN id SET DEFAULT nextval('revisions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY saas_tos ALTER COLUMN id SET DEFAULT nextval('saas_tos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY sessions ALTER COLUMN id SET DEFAULT nextval('sessions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY stale_prop_defs ALTER COLUMN id SET DEFAULT nextval('compute_aggregate_requests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY subversion_configurations ALTER COLUMN id SET DEFAULT nextval('subversion_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tab_positions ALTER COLUMN id SET DEFAULT nextval('tab_positions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY table_sequences ALTER COLUMN id SET DEFAULT nextval('sequences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tabs ALTER COLUMN id SET DEFAULT nextval('tabs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY taggings ALTER COLUMN id SET DEFAULT nextval('taggings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tfsscm_configurations ALTER COLUMN id SET DEFAULT nextval('tfsscm_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY todos ALTER COLUMN id SET DEFAULT nextval('todos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY transition_actions ALTER COLUMN id SET DEFAULT nextval('transition_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY transition_prerequisites ALTER COLUMN id SET DEFAULT nextval('transition_prerequisites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY transitions ALTER COLUMN id SET DEFAULT nextval('transitions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tree_belongings ALTER COLUMN id SET DEFAULT nextval('card_trees_cards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY tree_configurations ALTER COLUMN id SET DEFAULT nextval('card_trees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY user_display_preferences ALTER COLUMN id SET DEFAULT nextval('user_display_preferences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY user_engagements ALTER COLUMN id SET DEFAULT nextval('user_engagements_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY user_filter_usages ALTER COLUMN id SET DEFAULT nextval('user_filter_usages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY user_memberships ALTER COLUMN id SET DEFAULT nextval('group_memberships_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY variable_bindings ALTER COLUMN id SET DEFAULT nextval('variable_bindings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Owner: -
--

ALTER TABLE ONLY works ALTER COLUMN id SET DEFAULT nextval('scheduled_works_id_seq'::regclass);


--
-- Name: asynch_requests_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY asynch_requests
    ADD CONSTRAINT asynch_requests_pkey PRIMARY KEY (id);


--
-- Name: attachings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY attachings
    ADD CONSTRAINT attachings_pkey PRIMARY KEY (id);


--
-- Name: attachments_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: backlog_objectives_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY backlog_objectives
    ADD CONSTRAINT backlog_objectives_pkey PRIMARY KEY (id);


--
-- Name: backlogs_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY backlogs
    ADD CONSTRAINT backlogs_pkey PRIMARY KEY (id);


--
-- Name: card_defaults_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_defaults
    ADD CONSTRAINT card_defaults_pkey PRIMARY KEY (id);


--
-- Name: card_list_views_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_list_views
    ADD CONSTRAINT card_list_views_pkey PRIMARY KEY (id);


--
-- Name: card_murmur_links_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_murmur_links
    ADD CONSTRAINT card_murmur_links_pkey PRIMARY KEY (id);


--
-- Name: card_revision_links_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_revision_links
    ADD CONSTRAINT card_revision_links_pkey PRIMARY KEY (id);


--
-- Name: card_trees_cards_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tree_belongings
    ADD CONSTRAINT card_trees_cards_pkey PRIMARY KEY (id);


--
-- Name: card_trees_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tree_configurations
    ADD CONSTRAINT card_trees_pkey PRIMARY KEY (id);


--
-- Name: card_types_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_types
    ADD CONSTRAINT card_types_pkey PRIMARY KEY (id);


--
-- Name: card_types_property_definitions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY property_type_mappings
    ADD CONSTRAINT card_types_property_definitions_pkey PRIMARY KEY (id);


--
-- Name: card_versions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY card_versions
    ADD CONSTRAINT card_versions_pkey PRIMARY KEY (id);


--
-- Name: cards_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: changes_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY changes
    ADD CONSTRAINT changes_pkey PRIMARY KEY (id);


--
-- Name: checklist_items_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY checklist_items
    ADD CONSTRAINT checklist_items_pkey PRIMARY KEY (id);


--
-- Name: collaboration_settings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY murmur_channels
    ADD CONSTRAINT collaboration_settings_pkey PRIMARY KEY (id);


--
-- Name: compute_aggregate_requests_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stale_prop_defs
    ADD CONSTRAINT compute_aggregate_requests_pkey PRIMARY KEY (id);


--
-- Name: conversations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: correction_changes_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY correction_changes
    ADD CONSTRAINT correction_changes_pkey PRIMARY KEY (id);


--
-- Name: dependencies_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dependencies
    ADD CONSTRAINT dependencies_pkey PRIMARY KEY (id);


--
-- Name: dependency_resolving_cards_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dependency_resolving_cards
    ADD CONSTRAINT dependency_resolving_cards_pkey PRIMARY KEY (id);


--
-- Name: dependency_versions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dependency_versions
    ADD CONSTRAINT dependency_versions_pkey PRIMARY KEY (id);


--
-- Name: dependency_views_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dependency_views
    ADD CONSTRAINT dependency_views_pkey PRIMARY KEY (id);


--
-- Name: enumeration_values_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY enumeration_values
    ADD CONSTRAINT enumeration_values_pkey PRIMARY KEY (id);


--
-- Name: events_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: favorites_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: gadgets_oauth_clients_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY gadgets_oauth_clients
    ADD CONSTRAINT gadgets_oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: git_configurations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY git_configurations
    ADD CONSTRAINT git_configurations_pkey PRIMARY KEY (id);


--
-- Name: githubs_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY githubs
    ADD CONSTRAINT githubs_pkey PRIMARY KEY (id);


--
-- Name: group_memberships_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_memberships
    ADD CONSTRAINT group_memberships_pkey PRIMARY KEY (id);


--
-- Name: groups_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: hg_configurations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hg_configurations
    ADD CONSTRAINT hg_configurations_pkey PRIMARY KEY (id);


--
-- Name: history_subscriptions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY history_subscriptions
    ADD CONSTRAINT history_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: licenses_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY licenses
    ADD CONSTRAINT licenses_pkey PRIMARY KEY (id);


--
-- Name: login_access_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY login_access
    ADD CONSTRAINT login_access_pkey PRIMARY KEY (id);


--
-- Name: luau_configs_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_configs
    ADD CONSTRAINT luau_configs_pkey PRIMARY KEY (id);


--
-- Name: luau_group_memberships_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_group_memberships
    ADD CONSTRAINT luau_group_memberships_pkey PRIMARY KEY (id);


--
-- Name: luau_group_user_mappings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_group_user_mappings
    ADD CONSTRAINT luau_group_user_mappings_pkey PRIMARY KEY (id);


--
-- Name: luau_groups_mappings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_groups_mappings
    ADD CONSTRAINT luau_groups_mappings_pkey PRIMARY KEY (id);


--
-- Name: luau_groups_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_groups
    ADD CONSTRAINT luau_groups_pkey PRIMARY KEY (id);


--
-- Name: luau_lock_fail_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY luau_lock_fail
    ADD CONSTRAINT luau_lock_fail_pkey PRIMARY KEY (id);


--
-- Name: member_roles_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY member_roles
    ADD CONSTRAINT member_roles_pkey PRIMARY KEY (id);


--
-- Name: murmurs_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY murmurs
    ADD CONSTRAINT murmurs_pkey PRIMARY KEY (id);


--
-- Name: murmurs_read_counts_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY murmurs_read_counts
    ADD CONSTRAINT murmurs_read_counts_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorization_codes_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_authorization_codes
    ADD CONSTRAINT oauth_authorization_codes_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_tokens_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_tokens
    ADD CONSTRAINT oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: objective_filters_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objective_filters
    ADD CONSTRAINT objective_filters_pkey PRIMARY KEY (id);


--
-- Name: objective_versions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objective_versions
    ADD CONSTRAINT objective_versions_pkey PRIMARY KEY (id);


--
-- Name: page_versions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY page_versions
    ADD CONSTRAINT page_versions_pkey PRIMARY KEY (id);


--
-- Name: pages_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pages
    ADD CONSTRAINT pages_pkey PRIMARY KEY (id);


--
-- Name: perforce_configurations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY perforce_configurations
    ADD CONSTRAINT perforce_configurations_pkey PRIMARY KEY (id);


--
-- Name: plan_projects_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY program_projects
    ADD CONSTRAINT plan_projects_pkey PRIMARY KEY (id);


--
-- Name: plans_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: program_dependency_views_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY program_dependency_views
    ADD CONSTRAINT program_dependency_views_pkey PRIMARY KEY (id);


--
-- Name: project_structure_keys_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cache_keys
    ADD CONSTRAINT project_structure_keys_pkey PRIMARY KEY (id);


--
-- Name: project_variables_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_variables
    ADD CONSTRAINT project_variables_pkey PRIMARY KEY (id);


--
-- Name: projects_luau_group_memberships_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projects_luau_group_memberships
    ADD CONSTRAINT projects_luau_group_memberships_pkey PRIMARY KEY (id);


--
-- Name: projects_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY deliverables
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: property_definitions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY property_definitions
    ADD CONSTRAINT property_definitions_pkey PRIMARY KEY (id);


--
-- Name: revisions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY revisions
    ADD CONSTRAINT revisions_pkey PRIMARY KEY (id);


--
-- Name: saas_tos_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY saas_tos
    ADD CONSTRAINT saas_tos_pkey PRIMARY KEY (id);


--
-- Name: scheduled_works_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY works
    ADD CONSTRAINT scheduled_works_pkey PRIMARY KEY (id);


--
-- Name: sequences_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY table_sequences
    ADD CONSTRAINT sequences_pkey PRIMARY KEY (id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: stream_histories_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objective_snapshots
    ADD CONSTRAINT stream_histories_pkey PRIMARY KEY (id);


--
-- Name: streams_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objectives
    ADD CONSTRAINT streams_pkey PRIMARY KEY (id);


--
-- Name: subversion_configurations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY subversion_configurations
    ADD CONSTRAINT subversion_configurations_pkey PRIMARY KEY (id);


--
-- Name: tab_positions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tab_positions
    ADD CONSTRAINT tab_positions_pkey PRIMARY KEY (id);


--
-- Name: tabs_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tabs
    ADD CONSTRAINT tabs_pkey PRIMARY KEY (id);


--
-- Name: taggings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: tfsscm_configurations_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tfsscm_configurations
    ADD CONSTRAINT tfsscm_configurations_pkey PRIMARY KEY (id);


--
-- Name: todos_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY todos
    ADD CONSTRAINT todos_pkey PRIMARY KEY (id);


--
-- Name: transition_actions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY transition_actions
    ADD CONSTRAINT transition_actions_pkey PRIMARY KEY (id);


--
-- Name: transition_prerequisites_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY transition_prerequisites
    ADD CONSTRAINT transition_prerequisites_pkey PRIMARY KEY (id);


--
-- Name: transitions_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY transitions
    ADD CONSTRAINT transitions_pkey PRIMARY KEY (id);


--
-- Name: user_display_preferences_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_display_preferences
    ADD CONSTRAINT user_display_preferences_pkey PRIMARY KEY (id);


--
-- Name: user_engagements_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_engagements
    ADD CONSTRAINT user_engagements_pkey PRIMARY KEY (id);


--
-- Name: user_filter_usages_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_filter_usages
    ADD CONSTRAINT user_filter_usages_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: variable_bindings_pkey; Type: CONSTRAINT; Owner: -; Tablespace: 
--

ALTER TABLE ONLY variable_bindings
    ADD CONSTRAINT variable_bindings_pkey PRIMARY KEY (id);


--
-- Name: M20120821135500_idx; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX "M20120821135500_idx" ON property_definitions USING btree (project_id, ruby_name);


--
-- Name: idx_async_req_on_user_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_async_req_on_user_id ON asynch_requests USING btree (user_id);


--
-- Name: idx_async_req_on_user_proj; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_async_req_on_user_proj ON asynch_requests USING btree (user_id, deliverable_identifier);


--
-- Name: idx_atchmnt_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_atchmnt_on_proj_id ON attachments USING btree (project_id);


--
-- Name: idx_attaching_on_id_and_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_attaching_on_id_and_type ON attachings USING btree (attachable_id, attachable_type);


--
-- Name: idx_card_def_on_ct_and_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_card_def_on_ct_and_proj_id ON card_defaults USING btree (card_type_id, project_id);


--
-- Name: idx_card_types_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_card_types_on_proj_id ON card_types USING btree (project_id);


--
-- Name: idx_card_work; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_card_work ON works USING btree (objective_id, card_number, project_id);


--
-- Name: idx_cml_on_card_and_mur_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_cml_on_card_and_mur_id ON card_murmur_links USING btree (card_id, murmur_id);


--
-- Name: idx_crl_on_card_and_rev_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_crl_on_card_and_rev_id ON card_revision_links USING btree (card_id, revision_id);


--
-- Name: idx_ctpd_on_ct_and_pd_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_ctpd_on_ct_and_pd_id ON property_type_mappings USING btree (card_type_id, property_definition_id);


--
-- Name: idx_events_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_events_on_proj_id ON events USING btree (deliverable_id);


--
-- Name: idx_fav_on_type_and_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_fav_on_type_and_id ON favorites USING btree (project_id, favorited_type, favorited_id);


--
-- Name: idx_hist_sub_on_proj_user; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_hist_sub_on_proj_user ON history_subscriptions USING btree (project_id, user_id);


--
-- Name: idx_luau_group_mbsps_on_proj_group_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_luau_group_mbsps_on_proj_group_id ON projects_luau_group_memberships USING btree (project_id, luau_group_id);


--
-- Name: idx_luau_groups_on_ident; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_luau_groups_on_ident ON luau_groups USING btree (identifier);


--
-- Name: idx_obj_proj_dated; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_obj_proj_dated ON objective_snapshots USING btree (objective_id, project_id, dated);


--
-- Name: idx_page_ver_on_page_ver; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_page_ver_on_page_ver ON page_versions USING btree (project_id, page_id, version);


--
-- Name: idx_parent_child; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_parent_child ON luau_groups_mappings USING btree (parent_group_id, child_group_id);


--
-- Name: idx_rev_on_commit_time; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_rev_on_commit_time ON revisions USING btree (commit_time);


--
-- Name: idx_rev_on_number; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_rev_on_number ON revisions USING btree (number);


--
-- Name: idx_rev_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_rev_on_proj_id ON revisions USING btree (project_id);


--
-- Name: idx_stagg_on_card_and_agg_pd; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_stagg_on_card_and_agg_pd ON stale_prop_defs USING btree (project_id, card_id, prop_def_id);


--
-- Name: idx_tact_on_exec_id_and_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_tact_on_exec_id_and_type ON transition_actions USING btree (executor_id, executor_type);


--
-- Name: idx_tagging_on_id_and_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_tagging_on_id_and_type ON taggings USING btree (taggable_id, taggable_type);


--
-- Name: idx_tmp_sess_on_sess_and_id1; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_tmp_sess_on_sess_and_id1 ON temporary_id_storages USING btree (session_id, id_1);


--
-- Name: idx_tpre_on_trans_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_tpre_on_trans_id ON transition_prerequisites USING btree (transition_id);


--
-- Name: idx_trans_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_trans_on_proj_id ON transitions USING btree (project_id);


--
-- Name: idx_unique_member_roles; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_member_roles ON member_roles USING btree (deliverable_id, member_type, member_id);


--
-- Name: idx_var_bind_on_pv_and_pd_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_var_bind_on_pv_and_pd_id ON variable_bindings USING btree (project_variable_id, property_definition_id);


--
-- Name: idx_works_on_plan_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_works_on_plan_id ON works USING btree (plan_id);


--
-- Name: idx_works_on_plan_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_works_on_plan_proj_id ON works USING btree (plan_id, project_id);


--
-- Name: idx_works_on_plan_stream_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_works_on_plan_stream_id ON works USING btree (plan_id, objective_id);


--
-- Name: idx_works_on_proj_card_num; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_works_on_proj_card_num ON works USING btree (project_id, card_number);


--
-- Name: idx_works_on_proj_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX idx_works_on_proj_id ON works USING btree (project_id);


--
-- Name: index_att_on_a_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_att_on_a_id ON attachings USING btree (attachment_id);


--
-- Name: index_att_on_able_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_att_on_able_id ON attachings USING btree (attachable_id);


--
-- Name: index_att_on_able_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_att_on_able_type ON attachings USING btree (attachable_type);


--
-- Name: index_attribute_definitions_on_column_name; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_attribute_definitions_on_column_name ON property_definitions USING btree (column_name);


--
-- Name: index_attribute_definitions_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_attribute_definitions_on_project_id ON property_definitions USING btree (project_id);


--
-- Name: index_card_list_views_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_card_list_views_on_project_id ON card_list_views USING btree (project_id);


--
-- Name: index_card_types_property_definitions_on_card_type_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_card_types_property_definitions_on_card_type_id ON property_type_mappings USING btree (card_type_id);


--
-- Name: index_card_types_property_definitions_on_property_definition_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_card_types_property_definitions_on_property_definition_id ON property_type_mappings USING btree (property_definition_id);


--
-- Name: index_cards_on_number; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_cards_on_number ON cards USING btree (number);


--
-- Name: index_cards_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_cards_on_project_id ON cards USING btree (project_id);


--
-- Name: index_checklist_items_on_card_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_checklist_items_on_card_id ON checklist_items USING btree (card_id);


--
-- Name: index_checklist_items_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_checklist_items_on_project_id ON checklist_items USING btree (project_id);


--
-- Name: index_conversations_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_conversations_on_project_id ON conversations USING btree (project_id);


--
-- Name: index_dependency_versions_on_dependency_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_dependency_versions_on_dependency_id ON dependency_versions USING btree (dependency_id);


--
-- Name: index_dependency_views_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_dependency_views_on_project_id ON dependency_views USING btree (project_id);


--
-- Name: index_dependency_views_on_project_id_and_user_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_dependency_views_on_project_id_and_user_id ON dependency_views USING btree (project_id, user_id);


--
-- Name: index_enumeration_values_on_position; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_enumeration_values_on_position ON enumeration_values USING btree ("position");


--
-- Name: index_enumeration_values_on_property_definition_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_enumeration_values_on_property_definition_id ON enumeration_values USING btree (property_definition_id);


--
-- Name: index_enumeration_values_on_value; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_enumeration_values_on_value ON enumeration_values USING btree (value);


--
-- Name: index_event_changes; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_event_changes ON changes USING btree (event_id, type);


--
-- Name: index_events_on_created_by_user_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_events_on_created_by_user_id ON events USING btree (created_by_user_id);


--
-- Name: index_events_on_origin_type_and_origin_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_events_on_origin_type_and_origin_id ON events USING btree (origin_type, origin_id);


--
-- Name: index_murmurs_on_conversation_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_murmurs_on_conversation_id ON murmurs USING btree (conversation_id);


--
-- Name: index_murmurs_on_project_id_and_created_at; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_murmurs_on_project_id_and_created_at ON murmurs USING btree (project_id, created_at);


--
-- Name: index_pages_on_name; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_pages_on_name ON pages USING btree (name);


--
-- Name: index_pages_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_pages_on_project_id ON pages USING btree (project_id);


--
-- Name: index_program_dependency_views_on_program_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_program_dependency_views_on_program_id ON program_dependency_views USING btree (program_id);


--
-- Name: index_program_dependency_views_on_program_id_and_user_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_program_dependency_views_on_program_id_and_user_id ON program_dependency_views USING btree (program_id, user_id);


--
-- Name: index_projects_on_identifier_and_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_projects_on_identifier_and_type ON deliverables USING btree (identifier, type);


--
-- Name: index_projects_on_name_and_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_projects_on_name_and_type ON deliverables USING btree (name, type);


--
-- Name: index_property_definitions_on_project_id_and_name; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_property_definitions_on_project_id_and_name ON property_definitions USING btree (project_id, name);


--
-- Name: index_revisions_on_identifier; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_revisions_on_identifier ON revisions USING btree (identifier);


--
-- Name: index_sequences_on_name; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_sequences_on_name ON table_sequences USING btree (name);


--
-- Name: index_sessions_on_session_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_sessions_on_session_id ON sessions USING btree (session_id);


--
-- Name: index_stream_snapshots_on_project_id_and_stream_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_stream_snapshots_on_project_id_and_stream_id ON objective_snapshots USING btree (project_id, objective_id);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_tag_id ON taggings USING btree (tag_id);


--
-- Name: index_taggings_on_taggable_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_id ON taggings USING btree (taggable_id);


--
-- Name: index_taggings_on_taggable_type; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_type ON taggings USING btree (taggable_type);


--
-- Name: index_tags_on_name; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_tags_on_name ON tags USING btree (name);


--
-- Name: index_tags_on_project_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_tags_on_project_id ON tags USING btree (project_id);


--
-- Name: index_temporary_id_storages_on_session_id; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX index_temporary_id_storages_on_session_id ON temporary_id_storages USING btree (session_id);


--
-- Name: index_users_on_login; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_login ON users USING btree (login);


--
-- Name: todo_user_id_idx; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX todo_user_id_idx ON todos USING btree (user_id);


--
-- Name: uniq_tree_name_in_project; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX uniq_tree_name_in_project ON tree_configurations USING btree (project_id, name);


--
-- Name: unique_card_in_tree; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_card_in_tree ON tree_belongings USING btree (tree_configuration_id, card_id);


--
-- Name: unique_enumeration_values; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_enumeration_values ON enumeration_values USING btree (value, property_definition_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: unique_tag_names; Type: INDEX; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_tag_names ON tags USING btree (name, project_id);


--
-- Name: user_memberships_user_id_idx; Type: INDEX; Owner: -; Tablespace: 
--

CREATE INDEX user_memberships_user_id_idx ON user_memberships USING btree (user_id);


--
-- PostgreSQL database dump complete
--

INSERT INTO schema_migrations (version) VALUES ('41');

INSERT INTO schema_migrations (version) VALUES ('42');

INSERT INTO schema_migrations (version) VALUES ('43');

INSERT INTO schema_migrations (version) VALUES ('44');

INSERT INTO schema_migrations (version) VALUES ('45');

INSERT INTO schema_migrations (version) VALUES ('46');

INSERT INTO schema_migrations (version) VALUES ('47');

INSERT INTO schema_migrations (version) VALUES ('48');

INSERT INTO schema_migrations (version) VALUES ('49');

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

INSERT INTO schema_migrations (version) VALUES ('1-mingle_git_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-mingle_hg_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('2-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('3-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('4-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('5-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('6-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('7-mingle_tfs_scm_plugin');

INSERT INTO schema_migrations (version) VALUES ('1-perforce');

INSERT INTO schema_migrations (version) VALUES ('1-subversion');
