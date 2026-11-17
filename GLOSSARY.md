# Crowd Setlists

A tool for a solo acoustic guitar player to find the songs each crowd wants to hear, learn them, track practice and build setlists.

## Language

### Songs and crowds

**Song**:
A cover the player has in their library, identified by a permanent song ID.
_Avoid_: Track, tune

**Crowd**:
A kind of audience the player performs for, such as Campfire Singalong or Quiet Listening.
_Avoid_: Audience, bin, category

**Library**:
Every Song the player has, at any Status.
_Avoid_: Song list, catalog

**Status**:
How far along the player is with a Song: Wishlist, Struggling, Learning, Comfortable, Solid or Performance-Ready.
_Avoid_: Stage, confidence (confidence is what a Practice Session records)

**Ready**:
A Song at Comfortable or above. Only Ready Songs count toward a Crowd's goal.
_Avoid_: Done, learned

### Discovering

**Suggestion**:
A song proposed for a Crowd that is not yet in the Library.
_Avoid_: Recommendation, card

**Deal**:
One request for a batch of Suggestions for one Crowd.
_Avoid_: Batch, fetch, refresh

**Vote**:
The player's verdict on a Suggestion for one Crowd: want it, not now, not my song, or wrong crowd.
_Avoid_: Rating, swipe

### Playing

**Practice Session**:
One sitting spent on one Song, with minutes, focus area, self-rating and confidence.
_Avoid_: Practice log entry, rehearsal

**Setlist**:
An ordered list of Songs for one performance.
_Avoid_: Set, playlist

### Environments

**Dev**:
The environment every merge to `main` deploys to automatically. It may break.
_Avoid_: Development, sandbox

**UAT**:
The environment where a build is tried as a user before release. It is the only test environment.
_Avoid_: Test, staging, QA

**Prod**:
The environment the player uses for real, at gigs.
_Avoid_: Production, live

**Promotion**:
Moving the same build from Dev to UAT, or from UAT to Prod, after approval.
_Avoid_: Release, redeploy
