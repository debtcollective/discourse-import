# default command
bootstrap: setup replace migrate install seed

# clone all dependencies to plugins/
install:
	# clean up directories
	rm -R -f ../plugins/docker_manager \
	../plugins/discourse-assign \
	../plugins/discourse-staff-notes \
	../plugins/discourse-events \
	../plugins/discourse-locations \
	../plugins/discourse-custom-wizard \
	../plugins/discourse-debtcollective-theme \
	../plugins/discourse-debtcollective-wizards \
	../plugins/discourse-debtcollective-private-message \
	../plugins/discourse-debtcollective-sso \
	../plugins/discourse-debtcollective-signup-fields	\
	../plugins/discourse-debtcollective-collectives \
	../plugins/discourse-sentry

	# clone plugins
	git clone https://github.com/discourse/docker_manager.git ../plugins/docker_manager
	git clone https://github.com/discourse/discourse-assign.git ../plugins/discourse-assign
	git clone https://github.com/discourse/discourse-staff-notes.git ../plugins/discourse-staff-notes
	git clone https://github.com/angusmcleod/discourse-events.git ../plugins/discourse-events
	git clone https://github.com/angusmcleod/discourse-locations.git ../plugins/discourse-locations
	git clone https://github.com/angusmcleod/discourse-custom-wizard.git ../plugins/discourse-custom-wizard
	git clone https://github.com/debtcollective/discourse-debtcollective-theme.git ../plugins/discourse-debtcollective-theme
	git clone https://github.com/debtcollective/discourse-debtcollective-wizards.git ../plugins/discourse-debtcollective-wizards
	git clone https://github.com/debtcollective/discourse-debtcollective-private-message.git ../plugins/discourse-debtcollective-private-message
	git clone https://github.com/debtcollective/discourse-debtcollective-sso.git ../plugins/discourse-debtcollective-sso
	git clone https://github.com/debtcollective/discourse-debtcollective-signup-fields.git ../plugins/discourse-debtcollective-signup-fields
	git clone https://github.com/debtcollective/discourse-debtcollective-collectives.git ../plugins/discourse-debtcollective-collectives
	git clone https://github.com/debtcollective/discourse-sentry.git ../plugins/discourse-sentry

# setup discourse environment
setup:
	cd ".."; cp .ruby-gemset.sample .ruby-gemset
	cd ".."; cp .ruby-version.sample .ruby-version

# replace configuration files
replace:
	sed -i '' -e "s/\'discourse_development\'/\'debtcollective_discourse_development\'/" ../config/database.yml

# seed Discourse database
seed:
	# copy files to script/import_scripts/debtcollective
	cd ".."; mkdir -p script/import_scripts/debtcollective
	cp -R *.rb *.json data ../script/import_scripts/debtcollective

	# run seed script
	cd ".."; bundle exec ruby script/import_scripts/debtcollective/seeds.rb

migrate:
	cd ".."; bundle install; rake db:create; rake db:migrate
