# we must use absolute paths because we want to mount them on containers
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# used to ensure files/directories are created with the correct user:group
UID := $(shell id -u)
GID := $(shell id -g)
UNAME := $(shell whoami)

# container tags
DEV_ENG_TAG := mirandatz/playground:dev_env
PROJECT_NAME := playground
PYTHON_VERSION := 3.10.10

# using buildkit improves build times and decreases image sizes
export DOCKER_BUILDKIT=1

.PHONY: dev_env
dev_env:
	docker build \
		--build-arg UNAME=$(UNAME) \
    	--build-arg UID=$(UID) \
    	--build-arg GID=$(GID) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		-f Dockerfile \
		-t $(DEV_ENG_TAG) .

.PHONY: run_tests
run_tests: dev_env
	docker run \
		--rm \
		--user $(UID):$(GID) \
		-v $(ROOT_DIR):/app/$(PROJECT_NAME) \
		--workdir /app/$(PROJECT_NAME) \
		$(DEV_ENG_TAG) \
		bash -c "pytest ./$(PROJECT_NAME)/tests"


.PHONY: playground
playground: dev_env
	docker run \
		--rm \
		--user $(UID):$(GID) \
		-it \
		-v $(ROOT_DIR):/$(PROJECT_NAME) \
		$(DEV_ENG_TAG) \
		/bin/bash

.PHONY: update_requirements
update_requirements:
	docker run \
		--rm \
		--env HOST_UID=$(UID) \
		--env HOST_GID=$(GID) \
		-v $(ROOT_DIR)/requirements:/requirements \
		python:$(PYTHON_VERSION)-slim-buster \
			/bin/bash -c 'python -m pip install --upgrade pip \
			&& python -m pip install pip-compile-multi \
			&& pip-compile-multi \
			&& chown -R "$${HOST_UID}":"$${HOST_GID}" /requirements'

.PHONY: clean
clean:
	docker rmi $(DEV_ENG_TAG)
