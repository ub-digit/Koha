DROP TABLE IF EXISTS `marc_merge_rules`;
DROP TABLE IF EXISTS `marc_merge_rules_modules`;

CREATE TABLE `marc_merge_rules_modules` (
    `name` varchar(127) NOT NULL,
    `description` varchar(255),
    `specificity` int(11) NOT NULL UNIQUE, -- higher specificity will override rules with lower specificity
    PRIMARY KEY(`name`)
);

-- a couple of useful default filter modules
-- these are used in various scripts, so don't remove them if you don't know
-- what you're doing.
-- New filter modules can be added here when needed
INSERT INTO `marc_merge_rules_modules` VALUES('source', 'source from where modification request was sent', 0);
INSERT INTO `marc_merge_rules_modules` VALUES('category', 'categorycode of user who requested modification', 1);
INSERT INTO `marc_merge_rules_modules` VALUES('borrower', 'borrowernumber of user who requested modification', 2);

CREATE TABLE IF NOT EXISTS `marc_merge_rules` (
    `id` int(11) NOT NULL auto_increment,
    `tag` varchar(255) NOT NULL, -- can be regexp, so need > 3 chars
    `module` varchar(127) NOT NULL,
    `filter` varchar(255) NOT NULL,
    `add` tinyint NOT NULL,
    `append` tinyint NOT NULL,
    `remove` tinyint NOT NULL,
    `delete` tinyint NOT NULL,
    PRIMARY KEY(`id`),
    CONSTRAINT `marc_merge_rules_ibfk1` FOREIGN KEY (`module`) REFERENCES `marc_merge_rules_modules` (`name`) ON DELETE CASCADE
);
