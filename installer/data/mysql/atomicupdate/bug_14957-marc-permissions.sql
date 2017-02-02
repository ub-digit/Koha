DROP TABLE IF EXISTS `marc_permissions`;
DROP TABLE IF EXISTS `marc_permissions_modules`;

CREATE TABLE `marc_permissions_modules` (
    `id` int(11) NOT NULL auto_increment,
    `name` varchar(24) NOT NULL,
    `description` varchar(255),
    `specificity` int(11) NOT NULL DEFAULT 0, -- higher specificity will override rules with lower specificity
    PRIMARY KEY(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- a couple of useful default filter modules
-- these are used in various scripts, so don't remove them if you don't know
-- what you're doing.
-- New filter modules can be added here when needed
INSERT INTO `marc_permissions_modules` VALUES(NULL, 'source', 'source from where modification request was sent', 0);
INSERT INTO `marc_permissions_modules` VALUES(NULL, 'category', 'categorycode of user who requested modification', 1);
INSERT INTO `marc_permissions_modules` VALUES(NULL, 'borrower', 'borrowernumber of user who requested modification', 2);

CREATE TABLE `marc_permissions` (
    `id` int(11) NOT NULL auto_increment,
    `tagfield` varchar(255) NOT NULL, -- can be regexe, so need > 3 chars
    `tagsubfield` varchar(255) DEFAULT NULL, -- can be regex, so need > 1 char
    `module` int(11) NOT NULL,
    `filter` varchar(255) NOT NULL,
    `on_existing` ENUM('skip', 'overwrite', 'add', 'add_or_correct') DEFAULT NULL,
    `on_new` ENUM('skip', 'add') DEFAULT NULL,
    `on_removed` ENUM('skip', 'remove') DEFAULT NULL,
    PRIMARY KEY(`id`),
    CONSTRAINT `marc_permissions_ibfk1` FOREIGN KEY (`module`) REFERENCES `marc_permissions_modules` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
