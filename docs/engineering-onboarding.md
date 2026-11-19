# Engineering onboarding (iOS app)

How an intern ships a Covela iOS change. The code lives in the `LoveTrail` repo. Read this once, then follow it for every ticket. For what the product is and how the code is laid out, read `docs/Onboarding.MD` and `CLAUDE.md` first.

The Jira project is [BAB](https://linkedspaces.atlassian.net/jira/software/projects/BAB). The git repo is [LS-Yoobin/LoveTrail](https://github.com/LS-Yoobin/LoveTrail). `main` is the shared branch. The backend is a separate repo (`pocketverse`) that deploys to Heroku. App work does not change the server.

Checks happen on your machine. Nothing builds or tests the app on GitHub. There is no CI workflow and no TestFlight upload from a merge. Before you open a pull request, build the app, run the GardenCore tests if you touched `GardenCore/`, and run your change in the simulator or on a phone. A merge is still a review decision.

## Where work lives

| Thing | Where |
| --- | --- |
| What to build | A BAB ticket. If it has no ticket, it is not assigned work. |
| Code | This repo, on a branch named after the ticket. |
| Design and behavior | The ticket, then `docs/superpowers/specs/` for the feature area. |
| Questions | Team Slack. Put the ticket key in the message. |
| Test accounts and passwords | From your mentor. Never in git, Slack, a screenshot, or a Jira comment. |

## Setup

1. Install Xcode 26.2 or later. The deployment target is iOS 26.2, so use a simulator or phone on that version or newer.
2. Clone:

```bash
git clone https://github.com/LS-Yoobin/LoveTrail.git
cd LoveTrail
open Covela.xcodeproj
```

3. Open `Covela.xcodeproj`, not `BabyTown.xcodeproj`. `BabyTown.xcodeproj` is the old project and is no longer updated. The `BabyTown/` source folder name is legacy too. The app is Covela.
4. Wait for Swift Package Manager to resolve `WebRTC`. `GardenCore` is a local package in this repo and needs no download.
5. Pick the `Covela` scheme and an iPhone simulator. Press Run.
6. To run on your own phone, your mentor adds your Apple ID to the team. Signing uses team `N3L5LBGNK2` and bundle id `LS.Covela`. Do not change either in the project to make signing work. Ask instead.

By default the app talks to the production backend (`https://pocketverse.herokuapp.com/covela/api`) and the production file server. Anything you create there is real data. Use the test accounts your mentor gives you, not your personal Apple ID or email.

## Jira

BAB stories move through five statuses. The button name and the status name differ for one of them.

| You are… | Move the ticket to | Button you click |
| --- | --- | --- |
| About to start | **In Progress** | In Progress |
| Blocked on a person, a decision, a server change, or another ticket | **OnHold** | On hold |
| Unblocked again | **In Progress** | In Progress |
| You ran it on a simulator or phone, and the pull request is open | **Ready for QA** | New build ready |
| Pull request is merged to `main` | **Done** | Done |

Tasks on the same board use To Do, In Progress, OnHold, and Done. They do not have Ready for QA. Use the same meaning: In Progress while you code, Done after the pull request is merged.

Rules that keep the board honest:

- Assign the ticket to yourself before you write code.
- OnHold needs a comment that says what you are waiting on. A silent OnHold looks like abandoned work.
- Done means merged. Ready for QA means the pull request is open and you have run the change yourself.
- One ticket, one branch, one pull request. A ticket that needs two unrelated changes should be split.
- iOS tickets start with `[iOS]` in the summary. If the change needs a new endpoint or a server fix, that is a separate backend ticket. Link it and move yours to OnHold until it ships.
- Epics (for example BAB-47 Couple Cloud Sync) are parents. You work a Story or Task under them, and you put that child key in the commit and the pull request.

Release checks for sync, pairing, purchases, and push are on [BAB-122](https://linkedspaces.atlassian.net/browse/BAB-122), an end-to-end pass on two physical phones. If your change touches one of those areas, read its test plan before you start so you know what QA will try.

## Branch

`main` is integration. You do not commit on it.

```bash
git checkout main
git pull origin main
git checkout -b bab-125-date-plans
```

Branch name: `bab-<number>-<a-few-words>`. Lowercase, hyphens, no spaces.

Update your branch when `main` has moved:

```bash
git checkout main
git pull origin main
git checkout bab-125-date-plans
git merge main
```

Fix conflicts in your branch, then push. Do not rebase unless a reviewer asks you to. Do not force-push `main`.

`project.pbxproj` conflicts are the common ones. They happen when two people add files. Keep both sides' entries, then open the project in Xcode and build. If Xcode will not open the project after a merge, stop and ask. Do not delete the file and regenerate it.

Other branches on `origin` (`Cat-scrapbook`, `ScrapbookV2`, `covela-forever-paywall`, `feat/babytown-map-upgrade`, `feature/couple-cloud-sync-app`) are older feature branches. New work starts from `main`, not from those.

## Commits

Commit on your branch as you finish a coherent slice. Message format, matching current history:

```text
BAB-125: date plan list shows the partner's plans after pull to refresh
```

The key comes first, then a short line about the behavior. A second paragraph is useful when the reason is not obvious.

Before every commit:

```bash
git status
git diff
```

You are checking that the diff is your ticket, and that these are absent:

- `xcuserdata/`, `DerivedData/`, `.DS_Store` (they are in `.gitignore`, but check).
- Signing changes in `project.pbxproj`: `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, or `CODE_SIGN_*`.
- A changed `COVELA_API_BASE_URL` in `Covela.xcodeproj/xcshareddata/xcschemes/Covela.xcscheme`. See "Point the app at a local server" below.
- Test account passwords, tokens, or screenshots with personal photos.

## Pull request

Push the branch and open a pull request into `main` on GitHub.

```bash
git push -u origin bab-125-date-plans
```

The description needs four things:

1. The ticket link, in the title or the body.
2. What changed, in a few lines.
3. How you checked it: simulator or phone, iOS version, which account state (Prelude, paired, in the breakup window), the steps you took, and what you saw. A screenshot or short screen recording for any UI change, taken in both Pink and Blue themes.
4. Anything a reviewer must know: a new permission prompt, a new `Info.plist` key, a new entitlement, a new package, a change to what is stored in `DataPersistenceManager`, or a server ticket this depends on.

A description that works:

```markdown
## Summary
- Date plans list pulls the partner's plans on pull to refresh.
- Empty state uses the Together copy from Voice.MD.

## How I checked it
- [ ] Covela scheme builds with no new warnings
- [ ] iPhone 16 Pro simulator, iOS 26.2, paired test account
- [ ] Added a plan on account A, pulled to refresh on account B, the plan appeared
- [ ] Deleted it on A, refreshed on B, it was gone
- [ ] Pink and Blue screenshots attached
- [ ] Not checked: push when the partner adds a plan (needs a phone; simulator has no push)

Ticket: https://linkedspaces.atlassian.net/browse/BAB-125
```

Move the Jira story to Ready for QA when the pull request is open.

Review comments get a reply or a new commit. Push more commits to the same branch. GitHub updates the pull request. You do not open a second one.

Merge happens after a reviewer approves. Interns do not merge their own pull request. After it is merged, move the ticket to Done and delete the branch on GitHub.

## Build it

Building in Xcode is enough day to day. Before you open the pull request, also build from the command line once. It catches a file you forgot to add to the target.

```bash
xcodebuild -project Covela.xcodeproj -scheme Covela \
  -destination 'generic/platform=iOS Simulator' build
```

The last line must be `** BUILD SUCCEEDED **`. The build already has warnings. Do not add new ones, and say in the pull request if you could not avoid one.

## Run it

A pull request does not build anything. Before you open it, run the app and use the behavior you changed.

Check the case the ticket cares about, and one nearby case that should stay the same. Then check the things this app breaks most often:

- **Both themes.** Switch between Pink and Blue in Settings. Every color comes from `BabyTownTheme.*`. A hardcoded color shows up wrong in one of them.
- **The right phase.** Prelude, Together, and Breakup show different screens and different copy. Run your change in the phase the ticket names. Copy must follow `Voice.MD`, and must not contain ` - ` (space dash space).
- **A fresh install.** Settings has a Reset option that clears local data and onboarding. Use it, or delete the app from the simulator, to see what a new user sees.
- **Small and large phones.** Run once on a small simulator (iPhone 16e) and once on a large one (iPhone 16 Pro Max).

In Debug builds, every server call prints a line to the Xcode console:

```text
[CovelaAPIClient] POST /covela/api/couple/moments -> 201
```

Read those when something does not appear on the other account. A `401` means the session expired. Log out and log in again. A `409` `couple_archived` means the couple is in the breakup window and writes are refused on purpose.

### Two accounts

Anything shared between partners (moments, letters, pet, coins, date plans) needs two signed-in accounts that are paired. Ask your mentor for a pair of test accounts that are already paired. Run one on a simulator and one on your phone, or on two simulators. Change something on one, pull to refresh on the other, and check it arrived.

Some things cannot be exercised on a simulator:

- Push notifications, including the silent push that triggers a sync.
- Background refresh, such as the 9 PM polaroid reveal.
- Sign in with Apple, unless the simulator is signed in to an Apple ID.
- Real purchases. The `Products.storekit` file is local StoreKit test data for purchase screens only.

Say that in the pull request, and write down what you did run. Do not claim a check you did not do.

### Point the app at a local server

You only need this when a backend ticket is not deployed yet and your mentor asks you to run `pocketverse` locally. Start that server by following its own `docs/engineering-onboarding.md`. Then in Xcode, Product > Scheme > Edit Scheme > Run > Arguments, set:

```text
COVELA_API_BASE_URL = http://127.0.0.1:5001/covela/api
```

Use the port from the server's listen log. On a phone, use your Mac's LAN IP instead of `127.0.0.1`. Media uploads still go to the production file server unless you also set `COVELA_FILE_SERVER_BASE_URL`.

That variable is saved in the shared scheme file, which is tracked in git. Set it back to `https://pocketverse.herokuapp.com/covela/api` before you commit, or leave the scheme file out of the commit.

## Unit tests

The app target has no unit tests. The tests that exist are in the `GardenCore` package: garden composers, season and milestone rules, the litter schedule, and notification planning. They are plain Swift functions with no UI and no network.

Run them when you touch anything in `GardenCore/`:

```bash
cd GardenCore
swift test
```

This runs on your Mac. It does not need a simulator. A pass looks like this:

```text
Executed 71 tests, with 0 failures (0 unexpected)
```

If you add logic to `GardenCore`, add a test next to the existing ones in `GardenCore/Tests/GardenCoreTests/`. One file per type, named `SomethingTests.swift`. Cover the normal value, the failure value, and one edge, such as a date at midnight or an empty list. Copy the shape of `LitterScheduleTests.swift`.

Logic that is easy to test but lives in `BabyTown/` (a date rule, a parser, a calculation) can move into `GardenCore` so it gets a test. Ask your mentor before you move code between the app and the package.

## One ticket, start to finish

Using a date plans story as the example:

1. Open the ticket. Read what "done" means and the linked spec in `docs/superpowers/specs/`. Assign it to yourself. Move it to In Progress.
2. `git checkout main && git pull origin main && git checkout -b bab-125-date-plans`
3. Read the files `CLAUDE.md` lists for the feature area. Implement the change.
4. Build from the command line. Run `swift test` in `GardenCore/` if you touched it. Run the app in both themes, in the right phase, and on two paired accounts if the data is shared.
5. Commit: `BAB-125: date plan list shows the partner's plans after pull to refresh`
6. Push and open the pull request into `main`. Attach screenshots and write what you ran. If you could not run something, say why. Move the ticket to Ready for QA.
7. Answer review. Push fixes to the same branch.
8. After merge, move the ticket to Done and delete the branch.

## Asking for help

Say which ticket, which simulator or phone and iOS version, which account and phase, what you tapped, what you expected, and what happened. Paste the `[CovelaAPIClient]` lines or the crash from the Xcode console. "The app is broken" is not enough to start from.

If you are stuck for more than half a day, move the ticket to OnHold and write the blocker in the ticket. Keep going on something else only if your mentor points you at another key.
