UPDATE search_field sf
  LEFT JOIN search_marc_to_field smtf ON sf.id = smtf.search_field_id
  LEFT JOIN search_marc_map smm ON smtf.search_marc_map_id = smm.id
SET smtf.sort = 0 WHERE sf.name = 'title' AND index_name = 'biblios' AND marc_type = 'marc21';

INSERT INTO search_marc_to_field(search_marc_map_id, search_field_id, facet, suggestible, sort, search)
SELECT smm.id, sf.id, 0, 0, 1, 0 FROM search_field sf
JOIN search_marc_map smm ON index_name = 'biblios' AND marc_type = 'marc21' AND marc_field = '245a'
WHERE name = 'title';