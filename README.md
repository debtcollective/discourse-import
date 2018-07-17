# Discourse Import

This is the `import_script` we run to import all the user data from
debtcollective to Discourse

**This needs to be executed from the discourse folder.**

1.  Copy everything to `discourse/scripts/import_scripts/debtcollective`, this will copy:

- seeds.rb (populate discourse with data)
- debtcollective.rb (migrate users into discourse)
- tools_importer.rb (migrate everything from old tools to new)
- any other file used by the files above

1.  Run Discourse and import the wizard theme using the admin interface (`wizard.dcstyle.json`)
1.  Check the script `initialize` method (if present) in each file and change database and s3 connection settings.
1.  Run the script with `bundle exec ruby script/import_scripts/debtcollective/<script_name>.rb`, in the same order as above
