# Copyright (c) 2026 Everypin
# GNU General Public License v3.0 (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

# Usage examples:
# make release VERSION=<VERSION>
# Ex: make release VERSION=1.2.3
#
# OR use a semantic bump rule:
# make release VERSION=patch
# make release VERSION=minor
# make release VERSION=major
#
# `pyproject.toml` holds the only copy of the version, and `poetry version`
# resolves both explicit numbers and bump rules, so no version arithmetic lives
# here. Pushing the tag is what starts `.github/workflows/release.yml`, which
# re-checks the tag against the package version before publishing.

RELEASE_BRANCH := main
REMOTE := origin
CHANGELOG := docs/changelog.md
UNRELEASED_HEADING := \#\# Unreleased

ifdef VERSION
	RELEASE_VERSION := $(shell poetry version --short --dry-run $(VERSION) 2>/dev/null)
endif

.PHONY: release
release: _validate_release
	poetry version $(RELEASE_VERSION)
	@awk -v heading='$(UNRELEASED_HEADING)' -v version='$(RELEASE_VERSION)' \
		'{ print } $$0 == heading && !stamped { print ""; print "## " version; stamped = 1 }' \
		$(CHANGELOG) > $(CHANGELOG).tmp && mv $(CHANGELOG).tmp $(CHANGELOG)
	git add pyproject.toml $(CHANGELOG)
	git commit --message "chore(release): $(RELEASE_VERSION)"
	git tag --annotate $(RELEASE_VERSION) --message "Release $(RELEASE_VERSION)"
	git push --atomic $(REMOTE) $(RELEASE_BRANCH) refs/tags/$(RELEASE_VERSION)

.PHONY: _validate_release
_validate_release:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required, either x.y.z or a bump rule (patch, minor, major)."; \
		exit 1; \
	fi
	@if [ -z "$(RELEASE_VERSION)" ]; then \
		echo "Error: '$(VERSION)' is neither a valid version number nor a bump rule."; \
		exit 1; \
	fi
	@if [ "$$(git rev-parse --abbrev-ref HEAD)" != "$(RELEASE_BRANCH)" ]; then \
		echo "Error: releases are cut from '$(RELEASE_BRANCH)', not from the current branch."; \
		exit 1; \
	fi
	@if ! git diff --quiet HEAD; then \
		echo "Error: the working tree has uncommitted changes. Commit or stash them first."; \
		exit 1; \
	fi
	@git fetch --quiet --tags $(REMOTE)
	@if [ "$$(git rev-list --count --left-only @{u}...HEAD)" != "0" ]; then \
		echo "Error: there are un-pulled commits. Pull the latest changes first."; \
		exit 1; \
	fi
	@if git rev-parse --verify --quiet refs/tags/$(RELEASE_VERSION) > /dev/null; then \
		echo "Error: tag $(RELEASE_VERSION) already exists. A published version cannot be reused."; \
		exit 1; \
	fi
	@# A release without notes ships silently, so require entries under the
	@# `Unreleased` heading of the changelog.
	@awk -v heading='$(UNRELEASED_HEADING)' \
		'/^## / { if (in_unreleased) exit; in_unreleased = ($$0 == heading); next } \
		in_unreleased && NF { has_notes = 1 } \
		END { exit !has_notes }' \
		$(CHANGELOG) || { \
		echo "Error: no entries under '$(UNRELEASED_HEADING)' in $(CHANGELOG)."; \
		exit 1; \
	}
