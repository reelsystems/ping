-- MySQL initialization script for Ping Identity Manager (IDM)
-- This script creates the necessary database schema for IDM

-- Create the main openidm database if not exists
CREATE DATABASE IF NOT EXISTS openidm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use the openidm database
USE openidm;

-- Grant privileges to openidm user
GRANT ALL PRIVILEGES ON openidm.* TO 'openidm'@'%' IDENTIFIED BY 'openidm';
FLUSH PRIVILEGES;

-- IDM Schema Tables
-- These are the core tables used by ForgeRock IDM

-- Main object table for managed objects
CREATE TABLE IF NOT EXISTS managedobjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    objecttypes_id BIGINT UNSIGNED NOT NULL,
    objectid VARCHAR(255) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    fullobject MEDIUMTEXT,
    PRIMARY KEY (id),
    UNIQUE KEY idx_managedobjects_object (objecttypes_id, objectid),
    KEY idx_managedobjects_reconid (objecttypes_id, objectid, rev)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Object types lookup table
CREATE TABLE IF NOT EXISTS objecttypes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    objecttype VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY idx_objecttypes_objecttype (objecttype)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Link table for object relationships
CREATE TABLE IF NOT EXISTS links (
    objectid VARCHAR(38) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    linktype VARCHAR(50) NOT NULL,
    linkqualifier VARCHAR(50) NOT NULL,
    firstid VARCHAR(255) NOT NULL,
    secondid VARCHAR(255) NOT NULL,
    PRIMARY KEY (objectid),
    KEY idx_links_first (linktype, linkqualifier, firstid),
    KEY idx_links_second (linktype, linkqualifier, secondid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Internal user table
CREATE TABLE IF NOT EXISTS internaluser (
    objectid VARCHAR(254) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    pwd VARCHAR(510),
    PRIMARY KEY (objectid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Internal role table
CREATE TABLE IF NOT EXISTS internalrole (
    objectid VARCHAR(254) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    description VARCHAR(510),
    PRIMARY KEY (objectid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit tables
CREATE TABLE IF NOT EXISTS auditauthentication (
    objectid VARCHAR(56) NOT NULL,
    transactionid VARCHAR(255) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    userid VARCHAR(255),
    eventname VARCHAR(50),
    result VARCHAR(255),
    principals MEDIUMTEXT,
    context MEDIUMTEXT,
    entries MEDIUMTEXT,
    trackingids MEDIUMTEXT,
    PRIMARY KEY (objectid),
    KEY idx_auditauthentication_transactionid (transactionid),
    KEY idx_auditauthentication_activitydate (activitydate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditaccess (
    objectid VARCHAR(56) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    eventname VARCHAR(255),
    transactionid VARCHAR(255) NOT NULL,
    userid VARCHAR(255),
    trackingids MEDIUMTEXT,
    server_ip VARCHAR(40),
    server_port VARCHAR(5),
    client_ip VARCHAR(40),
    client_port VARCHAR(5),
    request_protocol VARCHAR(255),
    request_operation VARCHAR(255),
    request_detail MEDIUMTEXT,
    http_request_secure VARCHAR(255),
    http_request_method VARCHAR(7),
    http_request_path VARCHAR(255),
    http_request_queryparameters MEDIUMTEXT,
    http_request_headers MEDIUMTEXT,
    http_request_cookies MEDIUMTEXT,
    http_response_headers MEDIUMTEXT,
    response_status VARCHAR(255),
    response_statuscode VARCHAR(255),
    response_elapsedtime VARCHAR(255),
    response_elapsedtimeunits VARCHAR(255),
    PRIMARY KEY (objectid),
    KEY idx_auditaccess_transactionid (transactionid),
    KEY idx_auditaccess_activitydate (activitydate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditactivity (
    objectid VARCHAR(56) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    eventname VARCHAR(255),
    transactionid VARCHAR(255) NOT NULL,
    userid VARCHAR(255),
    trackingids MEDIUMTEXT,
    runas VARCHAR(255),
    objectid_column VARCHAR(255),
    operation VARCHAR(255),
    subjectbefore MEDIUMTEXT,
    subjectafter MEDIUMTEXT,
    changedfields VARCHAR(255),
    subjectrev VARCHAR(255),
    PRIMARY KEY (objectid),
    KEY idx_auditactivity_transactionid (transactionid),
    KEY idx_auditactivity_activitydate (activitydate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditrecon (
    objectid VARCHAR(56) NOT NULL,
    transactionid VARCHAR(255) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    eventname VARCHAR(255),
    userid VARCHAR(255),
    trackingids MEDIUMTEXT,
    activity VARCHAR(24),
    exceptiondetail MEDIUMTEXT,
    linkqualifier VARCHAR(255),
    mapping VARCHAR(511),
    message MEDIUMTEXT,
    messagedetail MEDIUMTEXT,
    situation VARCHAR(24),
    sourceobjectid VARCHAR(511),
    status VARCHAR(20),
    targetobjectid VARCHAR(511),
    reconciling VARCHAR(12),
    ambiguoustargetobjectids MEDIUMTEXT,
    reconaction VARCHAR(36),
    entrytype VARCHAR(7),
    reconid VARCHAR(56),
    PRIMARY KEY (objectid),
    KEY idx_auditrecon_reconid (reconid),
    KEY idx_auditrecon_transactionid (transactionid),
    KEY idx_auditrecon_activitydate (activitydate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditsync (
    objectid VARCHAR(56) NOT NULL,
    transactionid VARCHAR(255) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    eventname VARCHAR(255),
    userid VARCHAR(255),
    trackingids MEDIUMTEXT,
    activity VARCHAR(24),
    exceptiondetail MEDIUMTEXT,
    linkqualifier VARCHAR(255),
    mapping VARCHAR(511),
    message MEDIUMTEXT,
    messagedetail MEDIUMTEXT,
    situation VARCHAR(24),
    sourceobjectid VARCHAR(511),
    status VARCHAR(20),
    targetobjectid VARCHAR(511),
    PRIMARY KEY (objectid),
    KEY idx_auditsync_transactionid (transactionid),
    KEY idx_auditsync_activitydate (activitydate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auditconfig (
    objectid VARCHAR(56) NOT NULL,
    activitydate VARCHAR(29) NOT NULL,
    eventname VARCHAR(255),
    transactionid VARCHAR(255) NOT NULL,
    userid VARCHAR(255),
    trackingids MEDIUMTEXT,
    runas VARCHAR(255),
    objectid_column VARCHAR(255),
    operation VARCHAR(255),
    subjectbefore MEDIUMTEXT,
    subjectafter MEDIUMTEXT,
    changedfields VARCHAR(255),
    subjectrev VARCHAR(255),
    PRIMARY KEY (objectid),
    KEY idx_auditconfig_transactionid (transactionid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Scheduler tables
CREATE TABLE IF NOT EXISTS schedulerobjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    objecttypes_id BIGINT UNSIGNED NOT NULL,
    objectid VARCHAR(255) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    fullobject MEDIUMTEXT,
    PRIMARY KEY (id),
    UNIQUE KEY idx_schedulerobjects_object (objecttypes_id, objectid),
    CONSTRAINT fk_schedulerobjects_objecttypes FOREIGN KEY (objecttypes_id) REFERENCES objecttypes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cluster management table
CREATE TABLE IF NOT EXISTS clusterobjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    objecttypes_id BIGINT UNSIGNED NOT NULL,
    objectid VARCHAR(255) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    fullobject MEDIUMTEXT,
    PRIMARY KEY (id),
    UNIQUE KEY idx_clusterobjects_object (objecttypes_id, objectid),
    CONSTRAINT fk_clusterobjects_objecttypes FOREIGN KEY (objecttypes_id) REFERENCES objecttypes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Update objects table
CREATE TABLE IF NOT EXISTS updateobjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    objecttypes_id BIGINT UNSIGNED NOT NULL,
    objectid VARCHAR(255) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    fullobject MEDIUMTEXT,
    PRIMARY KEY (id),
    UNIQUE KEY idx_updateobjects_object (objecttypes_id, objectid),
    CONSTRAINT fk_updateobjects_objecttypes FOREIGN KEY (objecttypes_id) REFERENCES objecttypes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Security keys table
CREATE TABLE IF NOT EXISTS securitykeys (
    objectid VARCHAR(38) NOT NULL,
    rev VARCHAR(38) NOT NULL,
    keypair MEDIUMTEXT,
    PRIMARY KEY (objectid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default object types
INSERT IGNORE INTO objecttypes (objecttype) VALUES
    ('managed/user'),
    ('managed/role'),
    ('managed/assignment'),
    ('managed/organization'),
    ('internal/user'),
    ('internal/role'),
    ('link'),
    ('clusteredrecontargetids'),
    ('locks'),
    ('sync/queue'),
    ('scheduler'),
    ('cluster'),
    ('relationships');

-- Insert default admin user (password: openidm-admin)
-- Note: This is a default password and should be changed immediately
INSERT IGNORE INTO internaluser (objectid, rev, pwd) VALUES
    ('openidm-admin', '0',
     '{\"$crypto\":{\"type\":\"salted-hash\",\"algorithm\":\"SHA-256\",\"data\":\"tK8AqKhN7vVJFLdq4LqOVJrBpyB7e3HxYhqtqJXQWdE=\"}}');

-- Insert default anonymous user
INSERT IGNORE INTO internaluser (objectid, rev, pwd) VALUES
    ('anonymous', '0',
     '{\"$crypto\":{\"type\":\"salted-hash\",\"algorithm\":\"SHA-256\",\"data\":\"\"}}');

-- Create indexes for better performance
CREATE INDEX idx_json_managedobjects_userName ON managedobjects ((JSON_UNQUOTE(JSON_EXTRACT(fullobject, '$.userName'))));
CREATE INDEX idx_json_managedobjects_givenName ON managedobjects ((JSON_UNQUOTE(JSON_EXTRACT(fullobject, '$.givenName'))));
CREATE INDEX idx_json_managedobjects_sn ON managedobjects ((JSON_UNQUOTE(JSON_EXTRACT(fullobject, '$.sn'))));
CREATE INDEX idx_json_managedobjects_mail ON managedobjects ((JSON_UNQUOTE(JSON_EXTRACT(fullobject, '$.mail'))));
CREATE INDEX idx_json_managedobjects_accountStatus ON managedobjects ((JSON_UNQUOTE(JSON_EXTRACT(fullobject, '$.accountStatus'))));

COMMIT;
