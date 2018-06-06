# Discourse Import

This is the `import_script` we run to import all the user data from
debtcollective to Discourse

**This needs to be executed from the discourse folder.**

1. Copy `*.rb` to `discourse/scripts/import_scripts/`, this will copy
  * debtcollective.rb (migrate users into discourse)
  * seeds.rb (populate discourse with data)
  * tools_importer.rb (migrate from old tools)
1. Check the script `initialize` method in each file and change database and s3 connection settings.
1. Run the script with `bundle exec ruby script/import_scripts/<script_name>.rb`
