[% USE Koha %]

[% BLOCK report %]
    [% SET report = job.report %]
    [% IF report %]
        [% IF job.status == 'finished' %]
            <div class="dialog message">Search results export for the query "[% report.query_string | html %]" completed successfully</div>
            <ul>
              <li>[% report.total | html %] records exported</li>
              [% IF report.export_links.keys.size > 1 %]
                <li>Some records exceeded the maximum size supported by ISO2709 and was exported as MARCXML instead</li>
              [% END %]
              [% FOREACH format IN report.export_links.keys.sort %]
                <li>[% format %]: <a href="[% report.export_links.$format | $raw %]">[% report.export_links.$format | html %]</a></li>
              [% END %]
            </ul>
        [% ELSE %]
            <div class="dialog error alert">Search results export for the query "[% report.query_string | html %] failed with the following errors:</div>
            <ul>
            [% FOREACH error in report.errors %]
              <li>[% error | html %]</li>
            [% END %]
            </ul>
        [% END %]
    [% END %]
[% END %]

[% BLOCK detail %]
[% END %]

[% BLOCK js %]
[% END %]
