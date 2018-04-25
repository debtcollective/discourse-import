# Discourse Import

This is the `import_script` we run to import all the user data from
debtcollective to Discourse

**This needs to be executed from the discourse folder.**

1. Copy `debtcollective.rb` to `discourse/scripts/import_scripts/`
1. Check the script `initialize` method and change database and s3 connection settings.
1. Run the script with `bundle exec ruby script/import_scripts/debtcollective.rb`