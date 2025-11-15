#!/bin/bash

source .env

# 4. API endpoint for listing runners (Use 'runners/all' for instance runners, or scoped for project/group)
#    - For instance runners: "runners/all"
#    - For a Project (ID 123): "projects/123/runners"
#    - For a Group (ID 456): "groups/456/runners"
API_PATH="runners/all"
# 5. Number of runners to fetch per page (Max 100, crucial for 400 runners)
PER_PAGE=100
# 6. Flag for Dry Run: set to 'true' to just list runners, 'false' to delete
DRY_RUN=false

GITLAB_URL=${CI_SERVER_URL}
# --- Main Logic ---

# API Headers
AUTH_HEADER="PRIVATE-TOKEN: ${PRIVATE_TOKEN}"
BASE_URL="${GITLAB_URL}/api/v4"

# Pagination setup
PAGE=1
RUNNERS_FOUND=0
RUNNER_IDS_TO_DELETE=()

echo "--- Starting GitLab Runner Cleanup ---"
echo "GitLab URL: ${GITLAB_URL}"
echo "API Path: ${API_PATH}"
echo "Target Tag: ${RUNNER_TAG}"
echo "Dry Run Mode: ${DRY_RUN}"
echo "-------------------------------------"

# Loop through all pages
while true; do
    echo "Fetching page ${PAGE}..."

    # 1. API Call to list runners filtered by tag_list and paginated
    RESPONSE=$(curl --silent --show-error -X GET \
        --header "$AUTH_HEADER" \
        "${BASE_URL}/${API_PATH}?tag_list=${RUNNER_TAG}&per_page=${PER_PAGE}&page=${PAGE}"
    )

    # Check for empty response (end of pages)
    if [ "$(echo "$RESPONSE" | jq 'length')" -eq 0 ]; then
        echo "No more runners found."
        break
    fi

    # Extract all runner IDs from the current page
    RUNNER_IDS=$(echo "$RESPONSE" | jq -r '.[].id')

    # Add extracted IDs to the total list
    for id in $RUNNER_IDS; do
        RUNNER_IDS_TO_DELETE+=("$id")
        ((RUNNERS_FOUND++))
    done

    # Check if the last page was full (if less than PER_PAGE, it's the end)
    if [ "$(echo "$RESPONSE" | jq 'length')" -lt "$PER_PAGE" ]; then
        break
    fi

    ((PAGE++))

done

echo "Found a total of ${RUNNERS_FOUND} runner(s) with tag '${RUNNER_TAG}'."

if [ "$RUNNERS_FOUND" -eq 0 ]; then
    echo "Cleanup complete. No runners to delete."
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "DRY RUN MODE: The following runner IDs would be deleted:"
    echo "${RUNNER_IDS_TO_DELETE[@]}"
    echo ""
    echo "To perform the actual deletion, change 'DRY_RUN=true' to 'DRY_RUN=false' in the script."
    exit 0
fi

# --- Actual Deletion ---
echo "--- Starting Runner Deletion (Live) ---"
DELETED_COUNT=0
FAILED_COUNT=0

for RUNNER_ID in "${RUNNER_IDS_TO_DELETE[@]}"; do
    echo -n "Deleting runner ID ${RUNNER_ID}... "

    # 2. API Call to delete the runner by ID
    DELETE_RESPONSE=$(curl --silent -X DELETE \
        --header "$AUTH_HEADER" \
        "${BASE_URL}/runners/${RUNNER_ID}" \
        -w "%{http_code}" -o /dev/null
    )

    if [ "$DELETE_RESPONSE" -eq 204 ]; then
        echo "SUCCESS (HTTP 204)"
        ((DELETED_COUNT++))
    else
        echo "FAILED (HTTP ${DELETE_RESPONSE})"
        ((FAILED_COUNT++))
    fi

done

echo "--- Summary ---"
echo "Total Runners Found: ${RUNNERS_FOUND}"
echo "Successfully Deleted: ${DELETED_COUNT}"
echo "Failed Deletions: ${FAILED_COUNT}"
echo "Cleanup Finished."
