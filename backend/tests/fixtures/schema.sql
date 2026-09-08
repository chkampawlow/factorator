
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `app_audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `app_audit_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) DEFAULT NULL,
  `actor_id` int(11) DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `entity_type` varchar(80) NOT NULL,
  `entity_id` varchar(100) DEFAULT NULL,
  `before_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`before_values`)),
  `after_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`after_values`)),
  `request_id` char(36) NOT NULL,
  `source` varchar(40) NOT NULL DEFAULT 'API',
  `source_ip_hash` char(64) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_audit_tenant_created` (`tenant_id`,`created_at`,`id`),
  KEY `idx_audit_actor_created` (`actor_id`,`created_at`,`id`),
  KEY `idx_audit_entity` (`tenant_id`,`entity_type`,`entity_id`,`created_at`),
  KEY `idx_audit_request` (`request_id`)
) ENGINE=InnoDB AUTO_INCREMENT=121 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER app_audit_log_no_update
BEFORE UPDATE ON app_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are immutable';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER app_audit_log_no_delete
BEFORE DELETE ON app_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are append-only';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `auth_rate_limits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_rate_limits` (
  `key_hash` char(64) NOT NULL,
  `action_name` varchar(64) NOT NULL,
  `subject_hash` char(64) NOT NULL,
  `attempts` int(10) unsigned NOT NULL DEFAULT 0,
  `window_started_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`key_hash`),
  KEY `idx_auth_rate_limits_cleanup` (`updated_at`),
  KEY `idx_auth_rate_limits_action` (`action_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_refresh_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `replaced_by_hash` char(64) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_used_at` datetime DEFAULT NULL,
  `user_agent_hash` char(64) NOT NULL,
  `ip_hash` char(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `idx_refresh_user_active` (`user_id`,`revoked_at`,`expires_at`),
  KEY `idx_refresh_cleanup` (`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=40 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `clients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clients` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reference` varchar(7) NOT NULL,
  `type` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(100) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `fiscalId` varchar(100) DEFAULT NULL,
  `cin` varchar(100) DEFAULT NULL,
  `payment_terms_days` smallint(5) unsigned NOT NULL DEFAULT 30,
  `user_id` int(11) NOT NULL,
  `is_archived` tinyint(1) NOT NULL DEFAULT 0,
  `archived_at` datetime DEFAULT NULL,
  `date_creation` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_clients_user_reference` (`user_id`,`reference`),
  KEY `idx_clients_user` (`user_id`),
  KEY `idx_client_company_name` (`user_id`,`name`),
  KEY `idx_clients_company_created` (`user_id`,`id`),
  CONSTRAINT `fk_clients_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=910006 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_accountant_review_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_accountant_review_events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `entity_type` enum('VAT_PERIOD','ACCOUNTING_PERIOD','CONTRIBUTION_PERIOD','EMPLOYER_DECLARATION','FISCAL_RECONCILIATION','TAX_SCHEDULE_ENTRY','FILING_ARCHIVE') NOT NULL,
  `entity_id` bigint(20) unsigned NOT NULL,
  `action` enum('NOTE','REQUEST_CHANGES','APPROVE','REJECT') NOT NULL,
  `note` varchar(2000) NOT NULL,
  `actor_id` int(11) NOT NULL,
  `actor_role` varchar(40) NOT NULL,
  `previous_event_hash` char(64) DEFAULT NULL,
  `event_hash` char(64) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_accountant_review_entity` (`user_id`,`entity_type`,`entity_id`,`id`),
  KEY `idx_accountant_review_action` (`user_id`,`action`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_accountant_review_no_update BEFORE UPDATE ON erp_accountant_review_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Accountant review history is immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_accountant_review_no_delete BEFORE DELETE ON erp_accountant_review_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Accountant review history is immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `erp_accounting_period_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_accounting_period_snapshots` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `period_id` bigint(20) unsigned NOT NULL,
  `user_id` int(11) NOT NULL,
  `version` int(10) unsigned NOT NULL,
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL,
  `snapshot_json` longtext NOT NULL,
  `snapshot_sha256` char(64) NOT NULL,
  `captured_by` int(11) NOT NULL,
  `captured_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_accounting_period_snapshot` (`period_id`,`version`),
  KEY `idx_accounting_period_snapshot` (`user_id`,`status`,`captured_at`),
  CONSTRAINT `fk_accounting_period_snapshot` FOREIGN KEY (`period_id`) REFERENCES `erp_accounting_periods` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_accounting_periods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_accounting_periods` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `locked_by` int(11) DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `filed_by` int(11) DEFAULT NULL,
  `filed_at` datetime DEFAULT NULL,
  `closed_by` int(11) DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_accounting_period_company_dates` (`user_id`,`period_start`,`period_end`),
  KEY `idx_accounting_period_lookup` (`user_id`,`status`,`period_start`,`period_end`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_background_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_background_jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `created_by` int(11) NOT NULL,
  `job_type` varchar(64) NOT NULL,
  `status` enum('QUEUED','RUNNING','COMPLETED','FAILED','CANCELLED') NOT NULL DEFAULT 'QUEUED',
  `payload_json` longtext NOT NULL CHECK (json_valid(`payload_json`)),
  `result_json` longtext DEFAULT NULL CHECK (`result_json` is null or json_valid(`result_json`)),
  `request_hash` char(64) NOT NULL,
  `idempotency_key` varchar(128) NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `max_attempts` tinyint(3) unsigned NOT NULL DEFAULT 3,
  `progress` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `available_at` datetime NOT NULL DEFAULT current_timestamp(),
  `locked_at` datetime DEFAULT NULL,
  `locked_by` varchar(128) DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `error_code` varchar(80) DEFAULT NULL,
  `error_message` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_background_job_request` (`user_id`,`job_type`,`idempotency_key`),
  KEY `idx_background_job_claim` (`status`,`available_at`,`id`),
  KEY `idx_background_job_tenant` (`user_id`,`created_at`,`id`),
  KEY `idx_background_job_stale` (`status`,`locked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_report_presets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_report_presets` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(80) NOT NULL,
  `period_kind` enum('CUSTOM','CURRENT_MONTH','PREVIOUS_MONTH','CURRENT_QUARTER','CURRENT_YEAR','PREVIOUS_YEAR','LAST_30_DAYS') NOT NULL DEFAULT 'CUSTOM',
  `date_from` date DEFAULT NULL,
  `date_to` date DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_report_preset_name` (`user_id`,`name`),
  KEY `idx_report_preset_tenant` (`user_id`,`updated_at`,`id`),
  CONSTRAINT `chk_report_preset_dates` CHECK (`period_kind` = 'CUSTOM' and `date_from` is not null and `date_to` is not null and `date_to` >= `date_from` or `period_kind` <> 'CUSTOM' and `date_from` is null and `date_to` is null)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_contribution_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_contribution_configs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `contribution` enum('TCL','TFP','FOPROLOS') NOT NULL,
  `basis_kind` enum('TURNOVER','GROSS_PAYROLL','MANUAL') NOT NULL,
  `rate` decimal(10,6) NOT NULL,
  `legal_basis` varchar(255) DEFAULT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_contribution_config` (`user_id`,`contribution`,`effective_from`),
  KEY `idx_contribution_config_effective` (`user_id`,`contribution`,`effective_from`,`effective_to`),
  CONSTRAINT `chk_contribution_rate` CHECK (`rate` between 0 and 100),
  CONSTRAINT `chk_contribution_config_dates` CHECK (`effective_to` is null or `effective_to` >= `effective_from`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_contribution_periods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_contribution_periods` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `config_id` bigint(20) unsigned NOT NULL,
  `contribution` enum('TCL','TFP','FOPROLOS') NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `basis_kind` enum('TURNOVER','GROSS_PAYROLL','MANUAL') NOT NULL,
  `basis_amount` decimal(20,3) NOT NULL,
  `rate` decimal(10,6) NOT NULL,
  `calculated_amount` decimal(20,3) NOT NULL,
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
  `notes` varchar(500) DEFAULT NULL,
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `locked_by` int(11) DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `filed_by` int(11) DEFAULT NULL,
  `filed_at` datetime DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_contribution_period` (`user_id`,`contribution`,`period_start`,`period_end`),
  KEY `idx_contribution_period_status` (`user_id`,`status`,`period_end`),
  KEY `fk_contribution_period_config` (`config_id`),
  CONSTRAINT `fk_contribution_period_config` FOREIGN KEY (`config_id`) REFERENCES `erp_contribution_configs` (`id`),
  CONSTRAINT `chk_contribution_period_values` CHECK (`basis_amount` >= 0 and `rate` between 0 and 100 and `calculated_amount` >= 0),
  CONSTRAINT `chk_contribution_period_dates` CHECK (`period_end` >= `period_start`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_delivery_note_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_delivery_note_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `delivery_note_id` int(11) NOT NULL,
  `product_id` int(11) DEFAULT NULL,
  `product_code` varchar(100) DEFAULT NULL,
  `product` varchar(255) NOT NULL,
  `qty` decimal(15,3) NOT NULL DEFAULT 0.000,
  `price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `discount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tva_rate` decimal(10,3) NOT NULL DEFAULT 0.000,
  `subtotal` decimal(20,3) NOT NULL DEFAULT 0.000,
  `montant_tva` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total` decimal(20,3) NOT NULL DEFAULT 0.000,
  `unit` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_delivery_items_note` (`delivery_note_id`),
  KEY `idx_delivery_items_product` (`product_id`),
  KEY `idx_delivery_item_delivery_product` (`delivery_note_id`,`product_id`),
  CONSTRAINT `fk_delivery_items_note` FOREIGN KEY (`delivery_note_id`) REFERENCES `erp_delivery_notes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_delivery_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_delivery_item_values` CHECK (`qty` > 0 and `price` >= 0 and `discount` between 0 and 100 and `tva_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=1084009 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_delivery_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_delivery_notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `delivery_number` varchar(64) NOT NULL,
  `document_type` enum('DELIVERY','EXIT') NOT NULL DEFAULT 'DELIVERY',
  `client_id` int(11) NOT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `delivery_date` date NOT NULL,
  `expected_delivery_date` date DEFAULT NULL,
  `delivery_address` varchar(255) DEFAULT NULL,
  `vehicle_registration` varchar(32) DEFAULT NULL,
  `customer_reference` varchar(120) DEFAULT NULL,
  `movement_reason` varchar(120) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('DRAFT','CONFIRMED','DELIVERED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `item_count` int(11) NOT NULL DEFAULT 0,
  `stock_applied` tinyint(1) NOT NULL DEFAULT 0,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `idempotency_key` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_delivery_number_user` (`user_id`,`delivery_number`),
  UNIQUE KEY `uq_delivery_idempotency` (`user_id`,`idempotency_key`),
  KEY `idx_delivery_notes_user` (`user_id`),
  KEY `idx_delivery_notes_client` (`client_id`),
  KEY `idx_delivery_notes_order` (`sales_order_id`),
  KEY `idx_delivery_company_status_date` (`user_id`,`status`,`delivery_date`,`id`),
  KEY `idx_delivery_company_number` (`user_id`,`delivery_number`),
  KEY `idx_delivery_company_order` (`user_id`,`sales_order_id`),
  CONSTRAINT `fk_delivery_notes_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_delivery_notes_order` FOREIGN KEY (`sales_order_id`) REFERENCES `erp_sales_orders` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_delivery_notes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1048006 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_document_number_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_document_number_sequences` (
  `user_id` int(11) NOT NULL,
  `document_type` varchar(20) NOT NULL,
  `document_year` smallint(5) unsigned NOT NULL,
  `next_number` int(10) unsigned NOT NULL DEFAULT 1,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`,`document_type`,`document_year`),
  CONSTRAINT `chk_document_sequence_type` CHECK (`document_type` in ('FACTURE','DEVIS','AVOIR','BON_COMMANDE','BON_LIVRAISON','BON_SORTIE')),
  CONSTRAINT `chk_document_sequence_year` CHECK (`document_year` between 2000 and 2200),
  CONSTRAINT `chk_document_sequence_number` CHECK (`next_number` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_entity_reference_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_entity_reference_sequences` (
  `user_id` int(11) NOT NULL,
  `entity_type` enum('CLIENT','SUPPLIER') NOT NULL,
  `next_number` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`user_id`,`entity_type`),
  CONSTRAINT `fk_entity_reference_sequence_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_einvoice_outbox`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_einvoice_outbox` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `format_version` varchar(40) NOT NULL,
  `payload_json` longtext NOT NULL,
  `payload_sha256` char(64) NOT NULL,
  `signature_value` longtext DEFAULT NULL,
  `certificate_thumbprint` varchar(128) DEFAULT NULL,
  `status` enum('SIGNATURE_REQUIRED','SIGNED','QUEUED','SUBMITTED','ACCEPTED','REJECTED','RETRY_PENDING') NOT NULL DEFAULT 'SIGNATURE_REQUIRED',
  `provider_identifier` varchar(190) DEFAULT NULL,
  `attempt_count` int(10) unsigned NOT NULL DEFAULT 0,
  `last_attempt_at` datetime DEFAULT NULL,
  `last_error_code` varchar(80) DEFAULT NULL,
  `last_error_message` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_einvoice_invoice` (`invoice_id`),
  UNIQUE KEY `uq_einvoice_hash` (`user_id`,`payload_sha256`),
  KEY `idx_einvoice_outbox` (`user_id`,`status`,`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_employer_declaration_lines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_employer_declaration_lines` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `declaration_id` bigint(20) unsigned NOT NULL,
  `user_id` int(11) NOT NULL,
  `category` enum('SUPPLIER','PAYROLL','OTHER') NOT NULL,
  `beneficiary_name` varchar(255) NOT NULL,
  `beneficiary_fiscal_id` varchar(60) DEFAULT NULL,
  `gross_amount` decimal(20,3) NOT NULL,
  `withheld_amount` decimal(20,3) NOT NULL,
  `source_supplier_payment_id` int(11) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_employer_declaration_source` (`user_id`,`source_supplier_payment_id`),
  KEY `idx_employer_declaration_lines` (`declaration_id`,`category`),
  KEY `fk_employer_line_supplier_payment` (`source_supplier_payment_id`),
  CONSTRAINT `fk_employer_line_declaration` FOREIGN KEY (`declaration_id`) REFERENCES `erp_employer_declarations` (`id`),
  CONSTRAINT `fk_employer_line_supplier_payment` FOREIGN KEY (`source_supplier_payment_id`) REFERENCES `erp_supplier_payments` (`id`),
  CONSTRAINT `chk_employer_line_amounts` CHECK (`gross_amount` >= 0 and `withheld_amount` >= 0 and `withheld_amount` <= `gross_amount`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_employer_declarations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_employer_declarations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `declaration_year` smallint(5) unsigned NOT NULL,
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
  `notes` varchar(500) DEFAULT NULL,
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `locked_by` int(11) DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `filed_by` int(11) DEFAULT NULL,
  `filed_at` datetime DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_employer_declaration` (`user_id`,`declaration_year`),
  KEY `idx_employer_declaration_status` (`user_id`,`status`,`declaration_year`),
  CONSTRAINT `chk_employer_declaration_year` CHECK (`declaration_year` between 2000 and 2200)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_filing_archives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_filing_archives` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `declaration_type` enum('VAT','ACCOUNTING_PERIOD') NOT NULL,
  `source_entity_id` bigint(20) unsigned NOT NULL,
  `filing_sequence` int(10) unsigned NOT NULL DEFAULT 1,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `report_version` varchar(40) NOT NULL,
  `source_json` longtext NOT NULL,
  `result_json` longtext NOT NULL,
  `source_sha256` char(64) NOT NULL,
  `result_sha256` char(64) NOT NULL,
  `archive_sha256` char(64) NOT NULL,
  `source_row_count` int(10) unsigned NOT NULL,
  `captured_by` int(11) NOT NULL,
  `captured_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_filing_archive_sequence` (`user_id`,`declaration_type`,`source_entity_id`,`filing_sequence`),
  KEY `idx_filing_archive_period` (`user_id`,`declaration_type`,`period_end`),
  CONSTRAINT `chk_filing_archive_rows` CHECK (`source_row_count` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_filing_archive_no_update BEFORE UPDATE ON erp_filing_archives FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Filing archives are immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_filing_archive_no_delete BEFORE DELETE ON erp_filing_archives FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Filing archives are immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `erp_fiscal_adjustments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_fiscal_adjustments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `reconciliation_id` bigint(20) unsigned NOT NULL,
  `user_id` int(11) NOT NULL,
  `adjustment_type` enum('ADDITION','DEDUCTION') NOT NULL,
  `timing` enum('PERMANENT','TEMPORARY') NOT NULL,
  `category` varchar(120) NOT NULL,
  `description` varchar(255) NOT NULL,
  `amount` decimal(20,3) NOT NULL,
  `legal_basis` varchar(255) NOT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_fiscal_adjustments` (`reconciliation_id`,`adjustment_type`,`category`),
  CONSTRAINT `fk_fiscal_adjustment_reconciliation` FOREIGN KEY (`reconciliation_id`) REFERENCES `erp_fiscal_reconciliations` (`id`),
  CONSTRAINT `chk_fiscal_adjustment_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_fiscal_reconciliations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_fiscal_reconciliations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `fiscal_year` smallint(5) unsigned NOT NULL,
  `accounting_result` decimal(20,3) NOT NULL,
  `accounting_source` enum('OPERATIONAL_LEDGER','MANUAL_STATUTORY_ACCOUNTS') NOT NULL DEFAULT 'OPERATIONAL_LEDGER',
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
  `notes` varchar(500) DEFAULT NULL,
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `locked_by` int(11) DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `filed_by` int(11) DEFAULT NULL,
  `filed_at` datetime DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_fiscal_reconciliation` (`user_id`,`fiscal_year`),
  KEY `idx_fiscal_reconciliation_status` (`user_id`,`status`,`fiscal_year`),
  CONSTRAINT `chk_fiscal_reconciliation_year` CHECK (`fiscal_year` between 2000 and 2200)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_idempotency_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_idempotency_keys` (
  `user_id` int(11) NOT NULL,
  `operation_name` varchar(64) NOT NULL,
  `idempotency_key` varchar(128) NOT NULL,
  `request_hash` char(64) NOT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`,`operation_name`,`idempotency_key`),
  KEY `idx_idempotency_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_inventory_adjustments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_inventory_adjustments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity_delta` decimal(15,3) NOT NULL,
  `reason_code` varchar(40) NOT NULL,
  `reason_detail` varchar(255) NOT NULL,
  `lot_number` varchar(100) DEFAULT NULL,
  `serial_number` varchar(150) DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_inventory_adjustment_product` (`user_id`,`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_invoice_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_invoice_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `invoice` varchar(191) NOT NULL,
  `product_id` int(11) DEFAULT NULL,
  `tax_profile_id` int(11) DEFAULT NULL,
  `product_code` varchar(255) DEFAULT NULL,
  `product` text NOT NULL,
  `qty` decimal(20,3) NOT NULL DEFAULT 1.000,
  `tva_rate` decimal(10,3) DEFAULT NULL,
  `tax_regime` varchar(20) NOT NULL DEFAULT 'STANDARD',
  `fodec_rate` decimal(10,6) NOT NULL DEFAULT 0.000000,
  `fodec_amount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `legal_basis` varchar(255) DEFAULT NULL,
  `certificate_reference` varchar(160) DEFAULT NULL,
  `montant_tva` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tax_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tva_src` decimal(20,3) DEFAULT NULL,
  `ttc_src` decimal(20,3) DEFAULT NULL,
  `diff_tva` decimal(20,3) DEFAULT NULL,
  `diff_ttc` decimal(20,3) DEFAULT NULL,
  `price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `discount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotal` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotal_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotalTTC` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `invoice_date` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_items_invoice_id` (`invoice_id`),
  KEY `idx_invoice_items_product_id` (`product_id`),
  KEY `idx_invoice_item_invoice_product` (`invoice_id`,`product_id`),
  CONSTRAINT `fk_items_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `erp_invoices` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_invoice_item_values` CHECK (`qty` > 0 and `price` >= 0 and `discount` between 0 and 100 and `tva_rate` between 0 and 100 and `fodec_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=1220012 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_invoice_payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_invoice_payments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `amount` decimal(15,3) NOT NULL,
  `exchange_rate` decimal(20,8) DEFAULT NULL,
  `exchange_rate_date` date DEFAULT NULL,
  `amount_tnd` decimal(20,3) DEFAULT NULL,
  `payment_date` date NOT NULL,
  `method` varchar(24) NOT NULL,
  `account_name` varchar(120) NOT NULL DEFAULT '',
  `reference_number` varchar(120) NOT NULL DEFAULT '',
  `proof_path` varchar(500) DEFAULT NULL,
  `proof_name` varchar(255) DEFAULT NULL,
  `proof_mime` varchar(120) DEFAULT NULL,
  `status` enum('POSTED','VOID') NOT NULL DEFAULT 'POSTED',
  `recorded_by` int(11) NOT NULL,
  `voided_by` int(11) DEFAULT NULL,
  `voided_at` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_payment_invoice_status` (`invoice_id`,`status`,`payment_date`),
  KEY `idx_payment_company` (`user_id`,`payment_date`),
  KEY `idx_customer_payment_fx_period` (`user_id`,`payment_date`,`status`,`exchange_rate`),
  CONSTRAINT `fk_payment_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `erp_invoices` (`id`),
  CONSTRAINT `chk_invoice_payment_amount` CHECK (`amount` > 0),
  CONSTRAINT `chk_customer_payment_exchange_rate` CHECK (`exchange_rate` is null or `exchange_rate` > 0),
  CONSTRAINT `chk_customer_payment_tnd` CHECK (`amount_tnd` is null or `amount_tnd` > 0),
  CONSTRAINT `chk_invoice_payment_method` CHECK (`method` in ('CASH','CHEQUE','BANK_TRANSFER','CARD','DRAFT','OTHER'))
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_invoice_withholdings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_invoice_withholdings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `withholding_type` varchar(40) NOT NULL,
  `rate` decimal(8,4) NOT NULL,
  `calculation_base` decimal(15,3) NOT NULL,
  `withheld_amount` decimal(15,3) NOT NULL,
  `certificate_number` varchar(120) NOT NULL DEFAULT '',
  `certificate_date` date DEFAULT NULL,
  `expected_certificate_date` date DEFAULT NULL,
  `certificate_status` enum('PENDING','RECEIVED','VALIDATED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  `received_at` datetime DEFAULT NULL,
  `validated_at` datetime DEFAULT NULL,
  `cancelled_at` datetime DEFAULT NULL,
  `validation_notes` varchar(500) DEFAULT NULL,
  `attachment_path` varchar(500) DEFAULT NULL,
  `attachment_name` varchar(255) DEFAULT NULL,
  `attachment_mime` varchar(120) DEFAULT NULL,
  `recorded_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_withholding_invoice_status` (`invoice_id`,`certificate_status`),
  KEY `idx_withholding_company` (`user_id`,`certificate_date`),
  KEY `idx_withholding_expected` (`user_id`,`certificate_status`,`expected_certificate_date`),
  KEY `idx_withholding_certificate_number` (`user_id`,`certificate_number`),
  KEY `idx_withholding_invoice_status_date` (`invoice_id`,`certificate_status`,`certificate_date`),
  CONSTRAINT `fk_withholding_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `erp_invoices` (`id`),
  CONSTRAINT `chk_invoice_withholding_values` CHECK (`rate` between 0 and 100 and `calculation_base` > 0 and `withheld_amount` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_invoices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_invoices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invoice` varchar(191) NOT NULL,
  `custom_email` text DEFAULT NULL,
  `custom_code` varchar(255) DEFAULT NULL,
  `salesperson_name` varchar(191) DEFAULT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `delivery_note_id` int(11) DEFAULT NULL,
  `source_invoice_id` int(11) DEFAULT NULL,
  `source_flow` enum('DIRECT','ORDER','DELIVERY') NOT NULL DEFAULT 'DIRECT',
  `tax_profile_id` int(11) DEFAULT NULL,
  `invoice_date` date NOT NULL,
  `invoice_due_date` date NOT NULL,
  `currency` char(3) NOT NULL DEFAULT 'TND',
  `exchange_rate` decimal(20,8) NOT NULL DEFAULT 1.00000000,
  `exchange_rate_date` date DEFAULT NULL,
  `subtotal` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotal_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `base_tva` decimal(20,3) DEFAULT NULL,
  `montant_tva` decimal(20,3) DEFAULT NULL,
  `tax_total_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotal_ttc` decimal(20,3) NOT NULL DEFAULT 0.000,
  `shipping` decimal(20,3) NOT NULL DEFAULT 0.000,
  `discount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `vat` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `notes` text NOT NULL,
  `invoice_type` varchar(255) NOT NULL,
  `return_to_stock` tinyint(1) NOT NULL DEFAULT 0,
  `status` varchar(50) NOT NULL DEFAULT 'open',
  `transformation_status` varchar(32) NOT NULL DEFAULT 'NOT_TRANSFORMED',
  `is_validated` tinyint(1) NOT NULL DEFAULT 0,
  `type_doc` varchar(5) DEFAULT NULL,
  `timbre` decimal(20,3) DEFAULT NULL,
  `payment_method` enum('CASH','CARD','TRANSFER','CHECK') DEFAULT NULL,
  `date_ajout` datetime NOT NULL DEFAULT current_timestamp(),
  `tx_retenue` decimal(20,3) DEFAULT NULL,
  `retenue` decimal(20,3) DEFAULT NULL,
  `net_retenue` decimal(20,3) DEFAULT NULL,
  `id_extract` int(5) DEFAULT NULL,
  `id_lettrage` int(5) DEFAULT NULL,
  `contrat_no` varchar(50) DEFAULT NULL,
  `json_finsys` longtext DEFAULT NULL,
  `json_return` longtext DEFAULT NULL,
  `json_return2` longtext DEFAULT NULL,
  `stat_api` int(5) DEFAULT NULL,
  `mnt_lettre` varchar(1000) DEFAULT NULL,
  `stat_ttn` varchar(20) DEFAULT NULL,
  `qr_code` longtext DEFAULT NULL,
  `uuid` varchar(50) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `idempotency_key` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invoice_user_number` (`user_id`,`invoice`),
  UNIQUE KEY `uq_invoice_idempotency` (`user_id`,`idempotency_key`),
  KEY `idx_inv_user` (`user_id`),
  KEY `idx_erp_invoices_sales_order` (`sales_order_id`),
  KEY `idx_erp_invoices_delivery_note` (`delivery_note_id`),
  KEY `idx_erp_invoices_source_flow` (`source_flow`),
  KEY `idx_invoice_source_invoice` (`source_invoice_id`),
  KEY `idx_invoice_company_status_date` (`user_id`,`status`,`invoice_date`,`id`),
  KEY `idx_invoice_company_type_date` (`user_id`,`invoice_type`,`invoice_date`,`id`),
  KEY `idx_invoice_company_due` (`user_id`,`invoice_due_date`,`status`),
  KEY `idx_invoice_company_source_order` (`user_id`,`sales_order_id`),
  KEY `idx_invoice_company_source_delivery` (`user_id`,`delivery_note_id`),
  KEY `idx_invoice_company_source_invoice` (`user_id`,`source_invoice_id`),
  KEY `idx_invoice_company_salesperson_date` (`user_id`,`salesperson_name`,`invoice_date`,`id`),
  CONSTRAINT `fk_erp_invoices_delivery_note` FOREIGN KEY (`delivery_note_id`) REFERENCES `erp_delivery_notes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_invoices_sales_order` FOREIGN KEY (`sales_order_id`) REFERENCES `erp_sales_orders` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_invoice_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_invoice_type` CHECK (`invoice_type` in ('DRAFT','FACTURE','DEVIS','AVOIR')),
  CONSTRAINT `chk_invoice_status` CHECK (`status` in ('DRAFT','SENT','ACCEPTED','REJECTED','UNPAID','PARTIALLY_PAID','PAID','OVERDUE','CANCELLED')),
  CONSTRAINT `chk_invoice_currency` CHECK (`currency` in ('TND','EUR','USD')),
  CONSTRAINT `chk_invoice_validation_flag` CHECK (`is_validated` in (0,1)),
  CONSTRAINT `chk_invoice_exchange_rate` CHECK (`exchange_rate` > 0),
  CONSTRAINT `chk_invoice_header_values` CHECK (`shipping` >= 0 and `discount` between 0 and 100 and `vat` >= 0 and `timbre` >= 0 and `tx_retenue` between 0 and 100 and `retenue` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=1120012 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_invoice_issuance_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_invoice_issuance_snapshots` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `document_type` enum('FACTURE','DEVIS','AVOIR') NOT NULL,
  `snapshot_version` smallint(5) unsigned NOT NULL DEFAULT 1,
  `snapshot_json` longtext NOT NULL,
  `snapshot_sha256` char(64) NOT NULL,
  `captured_by` int(11) DEFAULT NULL,
  `captured_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invoice_issuance_snapshot` (`invoice_id`),
  KEY `idx_invoice_snapshot_tenant` (`user_id`,`document_type`,`captured_at`),
  KEY `idx_invoice_snapshot_hash` (`snapshot_sha256`),
  CONSTRAINT `fk_invoice_snapshot_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `erp_invoices` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_invoice_snapshot_actor` FOREIGN KEY (`captured_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_invoice_snapshot_json` CHECK (json_valid(`snapshot_json`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_notification_reads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_notification_reads` (
  `tenant_id` int(11) NOT NULL,
  `actor_id` int(11) NOT NULL,
  `notification_key` varchar(191) NOT NULL,
  `read_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`tenant_id`,`actor_id`,`notification_key`),
  KEY `idx_notification_reads_actor` (`actor_id`,`tenant_id`,`read_at`),
  KEY `idx_notification_reads_cleanup` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_period_reopenings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_period_reopenings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `period_type` enum('VAT','ACCOUNTING_PERIOD') NOT NULL,
  `period_id` bigint(20) unsigned NOT NULL,
  `previous_status` enum('LOCKED','FILED') NOT NULL,
  `reopened_status` enum('REVIEWED') NOT NULL DEFAULT 'REVIEWED',
  `reason` varchar(1000) NOT NULL,
  `prior_snapshot_sha256` char(64) DEFAULT NULL,
  `prior_filing_archive_id` bigint(20) unsigned DEFAULT NULL,
  `reopened_by` int(11) NOT NULL,
  `reopened_by_role` varchar(40) NOT NULL,
  `reopened_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_period_reopening` (`user_id`,`period_type`,`period_id`,`id`),
  KEY `fk_reopening_archive` (`prior_filing_archive_id`),
  CONSTRAINT `fk_reopening_archive` FOREIGN KEY (`prior_filing_archive_id`) REFERENCES `erp_filing_archives` (`id`),
  CONSTRAINT `chk_reopening_reason` CHECK (char_length(`reason`) >= 20)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_period_reopening_no_update BEFORE UPDATE ON erp_period_reopenings FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Period reopening history is immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER trg_period_reopening_no_delete BEFORE DELETE ON erp_period_reopenings FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Period reopening history is immutable' */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `erp_sales_order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_sales_order_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sales_order_id` int(11) NOT NULL,
  `product_id` int(11) DEFAULT NULL,
  `product_code` varchar(100) DEFAULT NULL,
  `product` varchar(255) NOT NULL,
  `qty` decimal(15,3) NOT NULL DEFAULT 1.000,
  `price` decimal(15,3) NOT NULL DEFAULT 0.000,
  `discount` decimal(7,3) NOT NULL DEFAULT 0.000,
  `tva_rate` decimal(7,3) NOT NULL DEFAULT 0.000,
  `subtotal` decimal(15,3) NOT NULL DEFAULT 0.000,
  `montant_tva` decimal(15,3) NOT NULL DEFAULT 0.000,
  `total` decimal(15,3) NOT NULL DEFAULT 0.000,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_sales_order_item_order` (`sales_order_id`),
  KEY `idx_sales_order_item_product` (`product_id`),
  KEY `idx_order_item_order_product` (`sales_order_id`,`product_id`),
  CONSTRAINT `fk_sales_order_items_order` FOREIGN KEY (`sales_order_id`) REFERENCES `erp_sales_orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_sales_order_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_sales_order_item_values` CHECK (`qty` > 0 and `price` >= 0 and `discount` between 0 and 100 and `tva_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=1030021 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_sales_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_sales_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_number` varchar(64) NOT NULL,
  `client_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `expected_delivery_date` date DEFAULT NULL,
  `delivery_address` varchar(255) DEFAULT NULL,
  `customer_reference` varchar(120) DEFAULT NULL,
  `source_devis_id` int(11) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('DRAFT','CONFIRMED','PARTIALLY_DELIVERED','DELIVERED','CANCELLED','INVOICED') NOT NULL DEFAULT 'DRAFT',
  `subtotal` decimal(15,3) NOT NULL DEFAULT 0.000,
  `montant_tva` decimal(15,3) NOT NULL DEFAULT 0.000,
  `total` decimal(15,3) NOT NULL DEFAULT 0.000,
  `invoice_id` int(11) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `idempotency_key` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_order_user_number` (`user_id`,`order_number`),
  UNIQUE KEY `uq_order_idempotency` (`user_id`,`idempotency_key`),
  KEY `idx_sales_order_user_status` (`user_id`,`status`),
  KEY `idx_sales_order_client` (`client_id`),
  KEY `idx_sales_order_invoice` (`invoice_id`),
  KEY `idx_order_company_status_date` (`user_id`,`status`,`order_date`,`id`),
  KEY `idx_order_company_number` (`user_id`,`order_number`),
  KEY `idx_order_company_devis` (`user_id`,`source_devis_id`),
  CONSTRAINT `fk_sales_orders_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_sales_orders_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `erp_invoices` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_sales_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_sales_order_totals` CHECK (`subtotal` >= 0 and `montant_tva` >= 0 and `total` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=990007 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_credit_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_credit_notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `supplier_invoice_id` int(11) NOT NULL,
  `supplier_return_id` int(11) DEFAULT NULL,
  `credit_number` varchar(100) NOT NULL,
  `credit_date` date NOT NULL,
  `amount` decimal(20,3) NOT NULL,
  `status` enum('DRAFT','VALIDATED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_credit_number` (`user_id`,`credit_number`),
  CONSTRAINT `chk_supplier_credit_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_invoice_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_invoice_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_invoice_id` int(11) NOT NULL,
  `supplier_reception_item_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `tax_profile_id` int(11) DEFAULT NULL,
  `description` varchar(255) NOT NULL,
  `quantity` decimal(20,3) NOT NULL,
  `unit_price` decimal(20,3) NOT NULL,
  `vat_rate` decimal(10,3) NOT NULL DEFAULT 0.000,
  `fodec_rate` decimal(10,6) NOT NULL DEFAULT 0.000000,
  `fodec_amount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tax_regime` varchar(20) NOT NULL DEFAULT 'STANDARD',
  `deductibility_rate` decimal(10,3) NOT NULL DEFAULT 100.000,
  `legal_basis` varchar(255) DEFAULT NULL,
  `certificate_reference` varchar(160) DEFAULT NULL,
  `total_ht` decimal(20,3) NOT NULL,
  `total_ht_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_vat` decimal(20,3) NOT NULL,
  `deductible_vat_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `non_deductible_vat_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_tax_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_ttc` decimal(20,3) NOT NULL,
  `total_ttc_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  PRIMARY KEY (`id`),
  KEY `idx_supplier_invoice_item_invoice_product` (`supplier_invoice_id`,`product_id`),
  CONSTRAINT `fk_supplier_invoice_item` FOREIGN KEY (`supplier_invoice_id`) REFERENCES `erp_supplier_invoices` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_supplier_invoice_item_values` CHECK (`quantity` > 0 and `unit_price` >= 0 and `vat_rate` between 0 and 100 and `fodec_rate` between 0 and 100),
  CONSTRAINT `chk_supplier_item_deductibility` CHECK (`deductibility_rate` between 0 and 100),
  CONSTRAINT `chk_supplier_item_vat_buckets` CHECK (`deductible_vat_tnd` >= 0 and `non_deductible_vat_tnd` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_invoices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_invoices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `supplier_order_id` int(11) DEFAULT NULL,
  `tax_profile_id` int(11) DEFAULT NULL,
  `invoice_number` varchar(100) NOT NULL,
  `invoice_date` date NOT NULL,
  `due_date` date NOT NULL,
  `status` enum('DRAFT','VALIDATED','PARTIALLY_PAID','PAID','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `currency` char(3) NOT NULL DEFAULT 'TND',
  `exchange_rate` decimal(20,8) NOT NULL DEFAULT 1.00000000,
  `exchange_rate_date` date DEFAULT NULL,
  `total_ht` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_ht_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_vat` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_tax_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `stamp_duty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `stamp_duty_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_ttc` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_ttc_tnd` decimal(20,3) NOT NULL DEFAULT 0.000,
  `credited_amount` decimal(20,3) NOT NULL DEFAULT 0.000,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `validated_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_invoice_number` (`user_id`,`supplier_id`,`invoice_number`),
  KEY `idx_supplier_invoice_due` (`user_id`,`status`,`due_date`),
  KEY `idx_supplier_invoice_company_status_date` (`user_id`,`status`,`invoice_date`,`id`),
  KEY `idx_supplier_invoice_company_due` (`user_id`,`due_date`,`status`),
  KEY `idx_supplier_invoice_company_order` (`user_id`,`supplier_order_id`),
  CONSTRAINT `chk_supplier_invoice_currency` CHECK (`currency` in ('TND','EUR','USD')),
  CONSTRAINT `chk_supplier_invoice_values` CHECK (`exchange_rate` > 0 and `total_ht` >= 0 and `total_vat` >= 0 and `total_ttc` >= 0 and `credited_amount` >= 0 and `credited_amount` <= `total_ttc` + 0.0005),
  CONSTRAINT `chk_supplier_invoice_stamp_duty` CHECK (`stamp_duty` >= 0 and `stamp_duty_tnd` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_order_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_order_id` int(11) NOT NULL,
  `catalog_id` int(11) DEFAULT NULL,
  `product_code` varchar(120) DEFAULT NULL,
  `description` varchar(255) NOT NULL,
  `item_type` enum('PRODUCT','SERVICE') NOT NULL DEFAULT 'PRODUCT',
  `qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tva_rate` decimal(10,3) NOT NULL DEFAULT 0.000,
  `unit` varchar(100) DEFAULT NULL,
  `line_total` decimal(20,3) NOT NULL DEFAULT 0.000,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_supplier_order_items_order` (`supplier_order_id`),
  KEY `idx_supplier_order_item_order_catalog` (`supplier_order_id`,`catalog_id`),
  CONSTRAINT `fk_supplier_order_items_order` FOREIGN KEY (`supplier_order_id`) REFERENCES `erp_supplier_orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_supplier_order_item_values` CHECK (`qty` > 0 and `price` >= 0 and `tva_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=959004 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_number` varchar(40) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `expected_date` date DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('DRAFT','SENT','PARTIALLY_RECEIVED','RECEIVED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `subtotal` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_vat` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total` decimal(20,3) NOT NULL DEFAULT 0.000,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_order_number` (`order_number`),
  KEY `idx_supplier_orders_user` (`user_id`),
  KEY `idx_supplier_orders_supplier` (`supplier_id`),
  KEY `idx_supplier_order_company_status_date` (`user_id`,`status`,`order_date`,`id`),
  KEY `idx_supplier_order_company_number` (`user_id`,`order_number`),
  KEY `idx_supplier_order_company_supplier` (`user_id`,`supplier_id`),
  KEY `idx_supplier_orders_company_status_created` (`user_id`,`status`,`id`),
  CONSTRAINT `fk_supplier_orders_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_supplier_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_supplier_order_totals` CHECK (`subtotal` >= 0 and `total_vat` >= 0 and `total` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=943004 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_payments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `supplier_invoice_id` int(11) NOT NULL,
  `amount` decimal(20,3) NOT NULL,
  `exchange_rate` decimal(20,8) DEFAULT NULL,
  `exchange_rate_date` date DEFAULT NULL,
  `amount_tnd` decimal(20,3) DEFAULT NULL,
  `payment_date` date NOT NULL,
  `method` enum('CASH','CHEQUE','BANK_TRANSFER','CARD','DRAFT','OTHER') NOT NULL,
  `account` varchar(160) NOT NULL,
  `reference_number` varchar(160) DEFAULT NULL,
  `proof_path` varchar(500) DEFAULT NULL,
  `recorded_by` int(11) NOT NULL,
  `voided_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_supplier_payment_invoice` (`supplier_invoice_id`),
  KEY `idx_supplier_payment_invoice_date_voided` (`supplier_invoice_id`,`payment_date`,`voided_at`),
  KEY `idx_supplier_payment_company_date_voided` (`user_id`,`payment_date`,`voided_at`),
  KEY `idx_supplier_payment_fx_period` (`user_id`,`payment_date`,`voided_at`,`exchange_rate`),
  CONSTRAINT `fk_supplier_payment_invoice` FOREIGN KEY (`supplier_invoice_id`) REFERENCES `erp_supplier_invoices` (`id`),
  CONSTRAINT `chk_supplier_payment_amount` CHECK (`amount` > 0),
  CONSTRAINT `chk_supplier_payment_exchange_rate` CHECK (`exchange_rate` is null or `exchange_rate` > 0),
  CONSTRAINT `chk_supplier_payment_tnd` CHECK (`amount_tnd` is null or `amount_tnd` > 0)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_reception_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_reception_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_reception_id` int(11) NOT NULL,
  `catalog_id` int(11) DEFAULT NULL,
  `code` varchar(120) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `item_type` enum('PRODUCT','SERVICE') NOT NULL DEFAULT 'PRODUCT',
  `ordered_qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `accepted_qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `damaged_qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `rejected_qty` decimal(20,3) NOT NULL DEFAULT 0.000,
  `discrepancy_reason` varchar(500) DEFAULT NULL,
  `stock_impact` decimal(20,3) NOT NULL DEFAULT 0.000,
  `price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `selling_price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `subtotal` decimal(20,3) NOT NULL DEFAULT 0.000,
  `tva_rate` decimal(10,3) NOT NULL DEFAULT 0.000,
  `unit` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_supplier_reception_items_reception` (`supplier_reception_id`),
  KEY `idx_reception_item_reception_catalog` (`supplier_reception_id`,`catalog_id`),
  CONSTRAINT `fk_supplier_reception_items_reception` FOREIGN KEY (`supplier_reception_id`) REFERENCES `erp_supplier_receptions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_supplier_reception_item_values` CHECK (`qty` > 0 and `stock_impact` >= 0 and `price` >= 0 and `selling_price` >= 0 and `tva_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=979009 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_receptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_receptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_id` int(11) NOT NULL,
  `supplier_order_id` int(11) DEFAULT NULL,
  `invoice_number` varchar(80) DEFAULT NULL,
  `supplier_delivery_note_number` varchar(120) DEFAULT NULL,
  `supplier_delivery_note_date` date DEFAULT NULL,
  `invoice_date` date NOT NULL,
  `received_date` date NOT NULL,
  `notes` text DEFAULT NULL,
  `exception_type` enum('NONE','OVERDELIVERY','NO_ORDER') NOT NULL DEFAULT 'NONE',
  `exception_reason` text DEFAULT NULL,
  `discrepancy_attachment_path` varchar(500) DEFAULT NULL,
  `discrepancy_attachment_name` varchar(255) DEFAULT NULL,
  `discrepancy_attachment_mime` varchar(120) DEFAULT NULL,
  `status` enum('DRAFT','REVIEWED') NOT NULL DEFAULT 'DRAFT',
  `stock_applied` tinyint(1) NOT NULL DEFAULT 0,
  `stock_applied_at` datetime DEFAULT NULL,
  `confirmed_at` datetime DEFAULT NULL,
  `confirmed_by` int(11) DEFAULT NULL,
  `confirmation_hash` char(64) DEFAULT NULL,
  `created_expense_id` int(11) DEFAULT NULL,
  `expense_created_at` datetime DEFAULT NULL,
  `total_ht` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_vat` decimal(20,3) NOT NULL DEFAULT 0.000,
  `total_ttc` decimal(20,3) NOT NULL DEFAULT 0.000,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_supplier_receptions_user` (`user_id`),
  KEY `idx_supplier_receptions_supplier` (`supplier_id`),
  KEY `idx_supplier_receptions_order` (`supplier_order_id`),
  KEY `idx_reception_company_status_date` (`user_id`,`status`,`received_date`,`id`),
  KEY `idx_reception_company_order` (`user_id`,`supplier_order_id`),
  KEY `idx_reception_company_supplier` (`user_id`,`supplier_id`),
  KEY `idx_supplier_receptions_company_status_created` (`user_id`,`status`,`id`),
  CONSTRAINT `fk_supplier_receptions_order` FOREIGN KEY (`supplier_order_id`) REFERENCES `erp_supplier_orders` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_supplier_receptions_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_supplier_receptions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_supplier_reception_totals` CHECK (`total_ht` >= 0 and `total_vat` >= 0 and `total_ttc` >= 0),
  CONSTRAINT `chk_supplier_reception_stock_flag` CHECK (`stock_applied` in (0,1))
) ENGINE=InnoDB AUTO_INCREMENT=963005 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_return_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_return_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_return_id` int(11) NOT NULL,
  `supplier_reception_item_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` decimal(20,3) NOT NULL,
  `unit_cost` decimal(20,6) NOT NULL DEFAULT 0.000000,
  `lot_number` varchar(100) DEFAULT NULL,
  `serial_number` varchar(150) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_supplier_return_item` (`supplier_return_id`),
  CONSTRAINT `fk_supplier_return_item` FOREIGN KEY (`supplier_return_id`) REFERENCES `erp_supplier_returns` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_supplier_return_item_values` CHECK (`quantity` > 0 and `unit_cost` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_supplier_returns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_supplier_returns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `supplier_reception_id` int(11) NOT NULL,
  `return_date` date NOT NULL,
  `status` enum('DRAFT','CONFIRMED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `reason` varchar(255) NOT NULL,
  `stock_applied` tinyint(1) NOT NULL DEFAULT 0,
  `confirmed_at` datetime DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_supplier_return_stock_flag` CHECK (`stock_applied` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_tax_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_tax_profiles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(160) NOT NULL,
  `vat_rate` decimal(10,6) NOT NULL DEFAULT 0.000000,
  `vat_exempt` tinyint(1) NOT NULL DEFAULT 0,
  `fodec_applicable` tinyint(1) NOT NULL DEFAULT 0,
  `fodec_rate` decimal(10,6) NOT NULL DEFAULT 0.000000,
  `tax_regime` enum('STANDARD','SUSPENDED','EXEMPT','OUT_OF_SCOPE') NOT NULL DEFAULT 'STANDARD',
  `deductibility_rate` decimal(10,3) NOT NULL DEFAULT 100.000,
  `legal_basis` varchar(255) DEFAULT NULL,
  `certificate_reference` varchar(160) DEFAULT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tax_profile_name_period` (`user_id`,`name`,`effective_from`),
  CONSTRAINT `chk_tax_profile_deductibility` CHECK (`deductibility_rate` between 0 and 100)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_tax_schedule_entries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_tax_schedule_entries` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `fiscal_year` smallint(5) unsigned NOT NULL,
  `schedule_type` enum('DEPRECIATION','PROVISION','DONATION','SUBSIDY') NOT NULL,
  `reference` varchar(120) NOT NULL,
  `description` varchar(255) NOT NULL,
  `event_date` date NOT NULL,
  `beneficiary` varchar(255) DEFAULT NULL,
  `gross_amount` decimal(20,3) NOT NULL,
  `opening_book_value` decimal(20,3) DEFAULT NULL,
  `annual_rate` decimal(10,6) DEFAULT NULL,
  `accounting_amount` decimal(20,3) NOT NULL,
  `fiscal_amount` decimal(20,3) NOT NULL,
  `fiscal_addition` decimal(20,3) NOT NULL,
  `fiscal_deduction` decimal(20,3) NOT NULL,
  `closing_book_value` decimal(20,3) DEFAULT NULL,
  `timing` enum('PERMANENT','TEMPORARY') NOT NULL,
  `legal_basis` varchar(255) NOT NULL,
  `evidence_reference` varchar(255) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `status` enum('DRAFT','REVIEWED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  `created_by` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tax_schedule_entry` (`user_id`,`fiscal_year`,`schedule_type`,`reference`),
  KEY `idx_tax_schedule_year` (`user_id`,`fiscal_year`,`schedule_type`,`status`),
  CONSTRAINT `chk_tax_schedule_year` CHECK (`fiscal_year` between 2000 and 2200),
  CONSTRAINT `chk_tax_schedule_amounts` CHECK (`gross_amount` >= 0 and `accounting_amount` >= 0 and `fiscal_amount` >= 0 and `fiscal_addition` >= 0 and `fiscal_deduction` >= 0 and (`opening_book_value` is null or `opening_book_value` >= 0) and (`closing_book_value` is null or `closing_book_value` >= 0) and (`annual_rate` is null or `annual_rate` between 0 and 100))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `erp_vat_periods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `erp_vat_periods` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `opening_credit` decimal(20,3) NOT NULL DEFAULT 0.000,
  `vat_collected` decimal(20,3) NOT NULL DEFAULT 0.000,
  `vat_deductible` decimal(20,3) NOT NULL DEFAULT 0.000,
  `vat_payable` decimal(20,3) NOT NULL DEFAULT 0.000,
  `closing_credit` decimal(20,3) NOT NULL DEFAULT 0.000,
  `status` enum('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
  `source_period_id` bigint(20) unsigned DEFAULT NULL,
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `locked_by` int(11) DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `filed_by` int(11) DEFAULT NULL,
  `filed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vat_period_company_month` (`user_id`,`period_start`,`period_end`),
  KEY `idx_vat_period_company_status` (`user_id`,`status`,`period_end`),
  CONSTRAINT `chk_vat_period_values` CHECK (`opening_credit` >= 0 and `vat_collected` >= 0 and `vat_deductible` >= 0 and `vat_payable` >= 0 and `closing_credit` >= 0),
  CONSTRAINT `chk_vat_period_single_result` CHECK (`vat_payable` = 0 or `closing_credit` = 0)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `expense_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `expense_notes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `supplier_id` int(11) DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `category` varchar(120) NOT NULL,
  `amount` decimal(18,3) NOT NULL DEFAULT 0.000,
  `expense_date` date NOT NULL,
  `description` text DEFAULT NULL,
  `receipt_path` varchar(255) DEFAULT NULL,
  `source_document_type` varchar(50) DEFAULT NULL,
  `source_document_id` int(11) DEFAULT NULL,
  `source_document_number` varchar(100) DEFAULT NULL,
  `status` enum('PENDING','APPROVED','REJECTED','REIMBURSED') NOT NULL DEFAULT 'PENDING',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_exp_user` (`user_id`),
  KEY `idx_expense_company_status_date` (`user_id`,`status`,`expense_date`,`id`),
  KEY `idx_expense_company_source` (`user_id`,`source_document_type`,`source_document_id`),
  KEY `idx_expenses_company_date_created` (`user_id`,`expense_date`,`id`),
  CONSTRAINT `chk_expense_amount` CHECK (`amount` >= 0)
) ENGINE=InnoDB AUTO_INCREMENT=1240000 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `product_stock_movements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `product_stock_movements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `movement_type` enum('INITIAL','SUPPLIER_IN','DELIVERY_OUT','INVOICE_OUT','ADJUSTMENT','RETURN_IN','MANUAL','DELIVERY','EXIT','RETURN') NOT NULL,
  `quantity` decimal(15,3) NOT NULL,
  `unit_cost` decimal(20,6) NOT NULL DEFAULT 0.000000,
  `movement_value` decimal(20,6) NOT NULL DEFAULT 0.000000,
  `cogs_value` decimal(20,6) NOT NULL DEFAULT 0.000000,
  `reference_type` varchar(32) DEFAULT NULL,
  `reference_id` int(11) DEFAULT NULL,
  `reason_code` varchar(40) DEFAULT NULL,
  `lot_number` varchar(100) DEFAULT NULL,
  `serial_number` varchar(150) DEFAULT NULL,
  `idempotency_key` varchar(190) DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_movement_idempotency` (`user_id`,`idempotency_key`),
  KEY `idx_stock_movements_product_user` (`product_id`,`user_id`),
  KEY `idx_stock_movements_reference` (`reference_type`,`reference_id`),
  KEY `idx_stock_company_date` (`user_id`,`created_at`,`id`),
  KEY `idx_stock_company_reference` (`user_id`,`reference_type`,`reference_id`),
  KEY `idx_stock_history_product_company_date` (`product_id`,`user_id`,`created_at`,`id`),
  CONSTRAINT `fk_stock_movements_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_stock_movements_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1290517 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `products` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(100) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `category` varchar(120) DEFAULT NULL,
  `item_type` enum('PRODUCT','SERVICE') NOT NULL DEFAULT 'PRODUCT',
  `tax_profile_id` int(11) DEFAULT NULL,
  `price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `selling_price_required` tinyint(1) NOT NULL DEFAULT 0,
  `last_purchase_price` decimal(20,3) NOT NULL DEFAULT 0.000,
  `average_cost` decimal(20,6) NOT NULL DEFAULT 0.000000,
  `tva_rate` decimal(10,3) NOT NULL DEFAULT 0.000,
  `unit` varchar(100) DEFAULT NULL,
  `stock_quantity` decimal(15,3) NOT NULL DEFAULT 0.000,
  `reorder_point` decimal(15,3) NOT NULL DEFAULT 3.000,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_products_user` (`user_id`),
  KEY `idx_product_company_code` (`user_id`,`code`),
  KEY `idx_product_company_name` (`user_id`,`name`),
  KEY `idx_products_company_category` (`user_id`,`category`,`id`),
  KEY `idx_products_company_type_created` (`user_id`,`item_type`,`id`),
  KEY `idx_products_company_type_stock` (`user_id`,`item_type`,`stock_quantity`),
  KEY `idx_products_company_reorder` (`user_id`,`item_type`,`reorder_point`,`stock_quantity`,`id`),
  KEY `idx_products_company_pricing_required` (`user_id`,`item_type`,`selling_price_required`,`id`),
  CONSTRAINT `fk_products_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_product_financial_values` CHECK (`price` >= 0 and `last_purchase_price` >= 0 and `average_cost` >= 0 and `tva_rate` between 0 and 100),
  CONSTRAINT `chk_product_reorder_point` CHECK (`reorder_point` >= 0),
  CONSTRAINT `chk_service_zero_stock` CHECK (`item_type` = 'PRODUCT' or `stock_quantity` = 0)
) ENGINE=InnoDB AUTO_INCREMENT=925009 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(190) NOT NULL,
  `checksum` char(64) NOT NULL,
  `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `suppliers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `suppliers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reference` varchar(7) NOT NULL,
  `type` enum('company','individual') NOT NULL DEFAULT 'company',
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `fiscal_id` varchar(30) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_suppliers_user_reference` (`user_id`,`reference`),
  KEY `idx_suppliers_user` (`user_id`),
  KEY `idx_supplier_company_name` (`user_id`,`name`),
  KEY `idx_suppliers_company_created` (`user_id`,`id`),
  CONSTRAINT `fk_suppliers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=932003 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_tokens`;
CREATE TABLE `user_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `type` varchar(50) NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_tokens_hash_type` (`token_hash`,`type`),
  KEY `idx_user_tokens_user_type` (`user_id`,`type`,`expires_at`),
  CONSTRAINT `fk_user_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_name` varchar(191) DEFAULT NULL,
  `fiscal_id` varchar(20) NOT NULL,
  `email` varchar(191) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `fax` varchar(50) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `website` varchar(255) DEFAULT NULL,
  `email_verified_at` datetime DEFAULT NULL,
  `google2fa_secret` varchar(255) DEFAULT NULL,
  `google2fa_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `fodec` tinyint(1) NOT NULL DEFAULT 0,
  `role` enum('ADMINISTRATOR','COMMERCIAL','STOCK','ACCOUNTING') NOT NULL DEFAULT 'ADMINISTRATOR',
  `account_status` enum('PENDING','ACTIVE','ARCHIVED') NOT NULL DEFAULT 'PENDING',
  `approved_at` datetime DEFAULT NULL,
  `archived_at` datetime DEFAULT NULL,
  `archived_by` int(11) DEFAULT NULL,
  `archive_reason` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_users_account_status` (`account_status`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=62 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
