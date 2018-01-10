#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# VERSION1 -eq VERSION2 – VERSION1 is equal to VERSION2
# VERSION1 -ge VERSION2 – VERSION1 is greater than or equal to VERSION2
# VERSION1 -gt VERSION2 – VERSION1 is greater than VERSION2
# VERSION1 -le VERSION2 – VERSION1 is less than or equal to VERSION2
# VERSION1 -lt VERSION2 – VERSION1 is less than VERSION2
# VERSION1 -ne VERSION2 – VERSION1 is not equal to VERSION2

# ex: testver.sh 1.10.0 -lte 1.9.0

if [[ $# -ne 3 ]]; then
  echo >&2 "Error: Invalid Syntax"
  echo >&2 "Usage: $(basename "${0}") <version1> <operation> <version2>"
  exit 2
fi

VERSION1="${1}"
OPERATION="${2}"
VERSION2="${3}"

project_dir=$(cd "$(dirname "${BASH_SOURCE}")" && pwd -P)
cd "${project_dir}"

source ./semver.sh

#echo >&2 "testver ${VERSION1} ${OPERATION} ${VERSION2}"

set +o errexit

case "${OPERATION}" in
  -eq)
    semverEQ ${VERSION1} ${VERSION2}
    exit $?
    ;;
  -ge)
    ! semverLT ${VERSION1} ${VERSION2}
    exit $?
    ;;
  -gt)
    semverGT ${VERSION1} ${VERSION2}
    exit $?
    ;;
  -le)
    ! semverGT ${VERSION1} ${VERSION2}
    exit $?
    ;;
  -lt)
    semverLT ${VERSION1} ${VERSION2}
    exit $?
    ;;
  -ne)
    ! semverEQ ${VERSION1} ${VERSION2}
    exit $?
    ;;
  *)
    echo >&2 "Error: Invalid Operation (${OPERATION})"
    echo >&2 "Operations: -eq, -ge, -gt, -le, -lt, -ne"
    exit 2
    ;;
esac
