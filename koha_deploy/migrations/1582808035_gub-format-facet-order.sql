UPDATE search_field SET facet_order = facet_order + 1 WHERE facet_order IS NOT NULL;
UPDATE search_field SET facet_order = 1 WHERE name = 'author';
UPDATE search_field SET facet_order = 2 WHERE name = 'gub-format';
