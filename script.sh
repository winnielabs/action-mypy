#!/bin/bash

# shellcheck disable=SC2086,SC2089,SC2090

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group:: Installing mypy ...  https://github.com/python/mypy'
if type "mypy" > /dev/null 2>&1 ; then
  echo 'already installed'
else
  echo 'install mypy'
  pip install mypy
fi

if type "mypy" > /dev/null 2>&1 ; then
  mypy --version
else
  echo 'This repository was not configured for mypy, process done.'
  exit 1
fi
echo '::endgroup::'

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"


echo '::group:: Running mypy with reviewdog 🐶 ...'
mypy_exit_val="0"
reviewdog_exit_val="0"

# shellcheck disable=SC2086
mypy_check_output="$(mypy --show-column-numbers     \
                          --show-absolute-path      \
                          ${INPUT_MYPY_FLAGS}       \
                          "${INPUT_TARGET:-.}" 2>&1 \
                          )" || mypy_exit_val="$?"

# shellcheck disable=SC2086
echo "${mypy_check_output}" | reviewdog              \
      -efm="%f:%l:%c: %t%*[^:]: %m"                  \
      -name="${INPUT_TOOL_NAME:-mypy}"               \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE}"            \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}"        \
      -level="${INPUT_LEVEL}"                        \
      ${INPUT_REVIEWDOG_FLAGS} || reviewdog_exit_val="$?"
echo '::endgroup::'

# Throw error if an error occurred and fail_on_error is true
if [[ "${INPUT_FAIL_ON_ERROR}" == "true"       \
      && ( "${mypy_exit_val}" != "0"           \
           || "${reviewdog_exit_val}" != "0" ) \
   ]]; then
  exit 1
fi

