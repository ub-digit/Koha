(function($) {
  /* Helpers */
  function ub_koha_set_select_value_by_option_text($select, text) {
    $select.find('option').filter(function() {
      return $(this).text().trim() === text;
    }).attr('selected', 'selected');
  }

  /* Main */
  $(function() {
    // Detect stage marc import page
    if($('#tools_stage-marc-import').length) {
      // Set form values
      /*
      ub_koha_set_select_value_by_option_text(
        $('#marc_modification_template_id'),
        'TODO'
      );
      */
      ub_koha_set_select_value_by_option_text(
        $('#matcher'),
        'KohaBiblio (999$c)'
      );

      $('#to_marc_plugin').val('Koha::Plugin::Se::Ub::Gu::MarcImport');
      $('#overlay_action').val('replace');
      $('#nomatch_action').val('create_new');
      $('#parse_itemsyes').attr('checked', 'checked');; //Deselect #parseitemsno?
      $('#item_action').val('always_add');

      // Hide elements where defaults should not be changed
      var hidden_elements = [];
      hidden_elements.push($('#marc_modification_template_id').closest('fieldset').get(0));
      hidden_elements.push($('#to_marc_plugin').closest('fieldset').get(0));
      hidden_elements.push($('#overlay_action').closest('fieldset').get(0));
      hidden_elements.push($('#parse_itemsyes').closest('fieldset').get(0));
      $(hidden_elements).hide();
    }
    // Detect manage marc import page
    else if($('#tools_manage-marc-import').length) {
      // Set "Show all entities" as default
      // Possible race condition? Seems to work but does not feel
      // very robust
      dataTablesDefaults.iDisplayLength = -1;

      // Hide elements where defaults should not be changed
      if($('#new_matcher_id').length) {
        var hidden_elements = [];
        hidden_elements.push($('#new_matcher_id').closest('li').get(0));
        hidden_elements.push($('#overlay_action').closest('li').get(0));
        hidden_elements.push($('#nomatch_action').closest('li').get(0));
        hidden_elements.push($('#item_action').closest('li').get(0));
        hidden_elements.push($('#staged-record-matching-rules .action').get(0));
        $(hidden_elements).hide();
      }
    }
  });
})(jQuery);
