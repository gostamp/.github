#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

org_name="gostamp"
repos="$(gh repo list "${org_name}" --source --json nameWithOwner --jq '.[].nameWithOwner')"

echo "Configuring the following repos:"
echo ""
echo "${repos}"
echo ""

for repo in $repos; do
    export GH_REPO="${repo}"

    echo "[${repo}] Configuring repo"
    gh api -X PATCH /repos/:owner/:repo \
        --input=".github/config/repo.json"

    echo "[${repo}] Configuring repo collaborators"
    gh api -X PUT /orgs/:owner/teams/maintainers/repos/:owner/:repo \
        -f "permission=maintain"

    echo "[${repo}] Configuring branch and tag protection rules"
    gh api -X PUT /repos/:owner/:repo/branches/main/protection \
        --input=".github/config/branch-protection.json"
    gh api -X POST /repos/:owner/:repo/tags/protection -f pattern='v.*'

    echo "[${repo}] Configuring automated security features"
    gh api -X PUT /repos/:owner/:repo/vulnerability-alerts
    gh api -X PUT /repos/:owner/:repo/automated-security-fixes

    # Check for rate limit
    remaining="$(gh api /rate_limit --jq '.rate.remaining')"
    echo "[${repo}] API calls remaining: ${remaining}"

    if ((remaining < 10)); then
        reset="$(gh api /rate_limit --jq '.rate.reset')"

        if [[ "$(uname -s)" == "Darwin" ]]; then
            formatted="$(date -r "${reset}" -Iseconds)"
        else
            formatted="$(date -d "@${reset}" -Iseconds)"
        fi
        echo ""
        echo "PAUSING UNTIL QUOTA RESET @ ${formatted}"
        echo ""

        sleep "${reset}"
    fi

    echo ""
done
