#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

org_name="gostamp"
repos="$(gh repo list "${org_name}" --source --no-archived --json nameWithOwner --jq '.[].nameWithOwner')"

{
    echo ""
    echo "Configured the following repos :wrench: :tada:"
    echo ""
} >>"${GITHUB_STEP_SUMMARY}"

for repo in $repos; do
    export GH_REPO="${repo}"

    echo "- [${repo}](https://github.com/${repo})" >>"${GITHUB_STEP_SUMMARY}"

    echo "[${repo}] Configuring repo"
    gh api -X PATCH /repos/:owner/:repo \
        --input=".github/config/repo.json" >/dev/null

    echo "[${repo}] Configuring repo collaborators"
    gh api -X PUT /orgs/:owner/teams/maintainers/repos/:owner/:repo \
        -f "permission=maintain" >/dev/null

    echo "[${repo}] Configuring branch and tag protection rules"
    gh api -X PUT /repos/:owner/:repo/branches/main/protection \
        --input=".github/config/branch-protection.json" >/dev/null
    # There doesn't appear to be an idempotent way to set tag protection rules,
    # so we have to check to see if one exists first.
    rule_id=$(gh api /repos/:owner/:repo/tags/protection \
        --jq '.[] | select(.pattern=="v.*") | .id')
    if [[ "${rule_id}" == "" ]]; then
        gh api -X POST /repos/:owner/:repo/tags/protection -f pattern='v.*' >/dev/null
    fi

    echo "[${repo}] Configuring automated security features"
    gh api -X PUT /repos/:owner/:repo/vulnerability-alerts >/dev/null
    gh api -X PUT /repos/:owner/:repo/automated-security-fixes >/dev/null

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

{
    echo ""
    echo "Using"
    echo ""
    echo "- [branch-protection.json](https://github.com/gostamp/.github/blob/main/.github/config/branch-protection.json)"
    echo "- [repo.json](https://github.com/gostamp/.github/blob/main/.github/config/repo.json)"
    echo ""
} >>"${GITHUB_STEP_SUMMARY}"
