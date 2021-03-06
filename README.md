# Discourse Import

This is the scripts we run to install all of our customizations to Discourse.

## Installation

First we need to clone and install Discourse

```bash
git clone -b stable --single-branch https://github.com/discourse/discourse.git
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
env DISCOURSE_ENABLE_CORS=true DISCOURSE_DEV_HOSTS=lvh.me DISCOURSE_SSO_JWT_SECRET=jwt-secret rails s
```

## Additional Steps

### Watching emails

Discourse community use mail in order to do things such as activate an account, to simulate receiving the email you need to do the following steps:

1. install mailcatcher gem

```bash
gem install mailcatcher
```

2. run mailcatcher

```bash
mailcatcher --http-ip 0.0.0.0
```

### Themes and Theme components

We are using these themes/theme components.

- [Discourse Debt Collective](https://github.com/debtcollective/discourse-debtcollective-theme)

Follow the instructions on the repo on how to install it
