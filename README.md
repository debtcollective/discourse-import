# Discourse Import

This is the scripts we run to install all of our customizations to Discourse.

## Installation

### Discourse

First we need to clone and install Discourse

```bash
git clone -b tests-passed --single-branch https://github.com/discourse/discourse.git
```

Then we clone this repo to the Discourse directory

```bash
cd discourse
git clone https://github.com/debtcollective/discourse-import.git
```

We run `make` inside the discourse-import folder

```bash
cd discourse-import
make
```

At this point, we continue with the Discourse setup

```bash
rake admin:create
```

and we run the server

```bash
env DISCOURSE_ENABLE_CORS=true rails s
```
