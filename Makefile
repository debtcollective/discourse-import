# default command
bootstrap: setup replace version-lock bundler-install install migrate seed post-install clean

# sync discourse version with production
version-lock:
	cd ".."; git checkout stable
	cd ".."; git pull origin stable
	cd ".."; git checkout $$(curl -s https://community.debtcollective.org | sed -n '/\<meta/s/\<meta[[:space:]][[:space:]]*name="*generator"*[[:space:]][[:space:]]*content="*\([^"]*\)"*\>/\1/p' | awk '{ print $$NF }')

# install the correct version of bundler
# pulled from Gemfile.lock
bundler-install:
	export BUNDLER_VERSION=$(cat Gemfile.lock | tail -1 | tr -d " ")
	gem install bundler bundle

# clone all dependencies to plugins/
install:
	# clean up directories
	rm -R -f ../plugins/docker_manager \
	../plugins/discourse-assign \
	../plugins/discourse-staff-notes \
	../plugins/discourse-events \
	../plugins/discourse-calendar \
	../plugins/discourse-locations \
	../plugins/discourse-custom-wizard \
	../plugins/discourse-debtcollective-sso \
	../plugins/discourse-sentry \
	../plugins/discourse-skylight \
	../plugins/discourse-mailchimp-list \
	../plugins/discourse-adplugin

	# clone plugins
	git clone https://github.com/discourse/docker_manager.git ../plugins/docker_manager
	git clone https://github.com/discourse/discourse-assign.git ../plugins/discourse-assign
	git clone https://github.com/discourse/discourse-staff-notes.git ../plugins/discourse-staff-notes
	git clone https://github.com/discourse/discourse-calendar.git ../plugins/discourse-calendar
	git clone https://github.com/paviliondev/discourse-locations.git ../plugins/discourse-locations
	git clone https://github.com/debtcollective/discourse-debtcollective-sso.git ../plugins/discourse-debtcollective-sso
	git clone https://github.com/debtcollective/discourse-sentry.git ../plugins/discourse-sentry
	git clone https://github.com/debtcollective/discourse-skylight.git ../plugins/discourse-skylight
	git clone https://github.com/debtcollective/discourse-mailchimp-list.git ../plugins/discourse-mailchimp-list
	git clone https://github.com/discourse/discourse-adplugin.git ../plugins/discourse-adplugin


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
	cp *.rb ../script/import_scripts/debtcollective/

	# run seed script
	cd ".."; bundle exec ruby script/import_scripts/debtcollective/seeds.rb

migrate:
	cd ".."; bundle install; bundle exec rake db:create; bundle exec rake db:migrate

clean:
	# clear cache
	cd ".."; bundle exec rake tmp:clear

post-install:
	# install theme
	cd ".."; bundle exec rake themes:install -- '--{"debtcollective-theme": {"url": "https://github.com/debtcollective/discourse-debtcollective-theme.git", "branch": "development", "default": true}}'
