INSERT INTO marc_overlay_rules SELECT * FROM marc_merge_rules;
DROP TABLE marc_merge_rules;
DROP TABLE marc_merge_rules_modules;
