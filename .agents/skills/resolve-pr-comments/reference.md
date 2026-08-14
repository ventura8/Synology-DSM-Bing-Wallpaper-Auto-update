# GitHub CLI reference for PR comment resolution

## Install `gh` if missing

```bash
command -v gh >/dev/null 2>&1 && gh --version

# Debian / Ubuntu
sudo apt-get update && sudo apt-get install -y gh

# Fedora
sudo dnf install -y gh

# openSUSE
sudo zypper install -y gh

# Arch
sudo pacman -S --noconfirm github-cli

# macOS
brew install gh
```

Official Linux notes:
[cli/cli install_linux.md](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)

```bash
gh auth status || gh auth login
```

## Resolve owner / repo / number

```bash
gh pr view --json number,url,headRepository,headRepositoryOwner
gh repo view --json nameWithOwner -q .nameWithOwner
```

## Fetch all review threads (paginate)

```bash
set -euo pipefail
OWNER=OWNER
REPO=REPO
NUMBER=N
CURSOR=""
ALL_NODES='[]'

GQL_THREADS='
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 50) {
            pageInfo { hasNextPage endCursor }
            nodes {
              databaseId
              author { login __typename }
              body
              createdAt
              url
              diffHunk
              outdated
            }
          }
        }
      }
    }
  }
}'

while true; do
  if [ -n "$CURSOR" ]; then
    PAGE=$(gh api graphql -f query="$GQL_THREADS" \
      -f owner="$OWNER" -f repo="$REPO" -F number="$NUMBER" -f cursor="$CURSOR")
  else
    PAGE=$(gh api graphql -f query="$GQL_THREADS" \
      -f owner="$OWNER" -f repo="$REPO" -F number="$NUMBER")
  fi

  # Fail closed on GraphQL errors or missing thread payload.
  echo "$PAGE" | jq -e '
    if (.errors? != null) then error("GraphQL errors in thread fetch")
    elif (.data.repository.pullRequest.reviewThreads.nodes | type) != "array" then
      error("missing reviewThreads.nodes")
    elif (.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage | type) != "boolean" then
      error("missing reviewThreads.pageInfo.hasNextPage")
    else . end
  ' >/dev/null

  ALL_NODES=$(jq -c --argjson acc "$ALL_NODES" \
    --argjson page "$(echo "$PAGE" | jq -c '.data.repository.pullRequest.reviewThreads.nodes')" \
    '$acc + $page')
  HAS_NEXT=$(echo "$PAGE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$PAGE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // empty')
  [ "$HAS_NEXT" = "true" ] || break
done

# Paginate nested comments(first: 50) when a thread has more than one page.
GQL_COMMENTS='
query($id: ID!, $cursor: String) {
  node(id: $id) {
    ... on PullRequestReviewThread {
      comments(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          databaseId
          author { login __typename }
          body
          createdAt
          url
          diffHunk
          outdated
        }
      }
    }
  }
}'

ALL_NODES=$(echo "$ALL_NODES" | jq -c '
  map(
    if (.comments.pageInfo.hasNextPage == true) then
      . + {_needsCommentPages: true}
    else . end
  )
')

TMP_NODES='[]'
while IFS= read -r THREAD; do
  THREAD_ID=$(echo "$THREAD" | jq -r '.id')
  COMMENTS=$(echo "$THREAD" | jq -c '.comments.nodes')
  C_HAS=$(echo "$THREAD" | jq -r '.comments.pageInfo.hasNextPage')
  C_CUR=$(echo "$THREAD" | jq -r '.comments.pageInfo.endCursor // empty')
  while [ "$C_HAS" = "true" ]; do
    CPAGE=$(gh api graphql -f query="$GQL_COMMENTS" -f id="$THREAD_ID" -f cursor="$C_CUR")
    echo "$CPAGE" | jq -e '
      if (.errors? != null) then error("GraphQL errors in comment fetch")
      elif (.data.node.comments.nodes | type) != "array" then error("missing comments.nodes")
      else . end
    ' >/dev/null
    COMMENTS=$(jq -c --argjson acc "$COMMENTS" \
      --argjson page "$(echo "$CPAGE" | jq -c '.data.node.comments.nodes')" \
      '$acc + $page')
    C_HAS=$(echo "$CPAGE" | jq -r '.data.node.comments.pageInfo.hasNextPage')
    C_CUR=$(echo "$CPAGE" | jq -r '.data.node.comments.pageInfo.endCursor // empty')
  done
  THREAD=$(echo "$THREAD" | jq -c --argjson comments "$COMMENTS" '
    .comments.nodes = $comments
    | .comments.pageInfo.hasNextPage = false
    | del(._needsCommentPages)
  ')
  TMP_NODES=$(jq -c --argjson acc "$TMP_NODES" --argjson t "$THREAD" '$acc + [$t]')
done < <(echo "$ALL_NODES" | jq -c '.[]')
ALL_NODES="$TMP_NODES"

# Aggregate complete; then filter unresolved threads
echo "$ALL_NODES" | jq '[.[] | select(.isResolved == false)]'
```

Filter to `isResolved == false` after aggregating all pages (as above).
Always run under `set -euo pipefail` and reject GraphQL `errors` / partial payloads
before aggregation so failed fetches cannot produce incomplete unresolved-thread data.

## Issue-style PR comments

```bash
gh api repos/OWNER/REPO/issues/N/comments --paginate
REPLY='Reply text goes here'
gh pr comment N --body "$REPLY"
```

## Reply to a review comment

Prefer replying in-thread so the conversation stays attached:

```bash
REPLY='Reply text goes here'
gh api repos/OWNER/REPO/pulls/N/comments/COMMENT_ID/replies \
  -f body="$REPLY"
```

`COMMENT_ID` is the review comment `databaseId` from the GraphQL payload.
Store reply text in a shell variable and pass it as data (`"$REPLY"` / `-f body="$REPLY"`);
do not interpolate untrusted reply text inside single-quoted shell syntax.


## Resolve a review thread

```bash
gh api graphql -f query='
mutation($id: ID!) {
  resolveReviewThread(input: {threadId: $id}) {
    thread { id isResolved }
  }
}' -f id=THREAD_NODE_ID
```

Never resolve until the reply succeeded. Do not resolve **Blocked** threads.

## Logs

Optional durable capture while working a large PR:

```bash
mkdir -p reports/agent-logs
```
