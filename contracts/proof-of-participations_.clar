(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-event-not-found (err u101))
(define-constant err-event-not-active (err u102))
(define-constant err-already-participated (err u103))
(define-constant err-event-already-exists (err u104))
(define-constant err-invalid-end-block (err u105))
(define-constant err-invalid-delegate (err u106))
(define-constant err-self-delegation (err u107))
(define-constant err-no-delegation-found (err u108))
(define-constant err-streak-broken (err u109))

(define-map events
  { event-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    start-block: uint,
    end-block: uint,
    is-active: bool,
    total-participants: uint
  }
)

(define-map participants
  { event-id: uint, participant: principal }
  {
    participated-at: uint,
    participation-data: (string-ascii 100)
  }
)

(define-map user-events
  { participant: principal }
  { event-count: uint }
)

(define-map leaderboard-scores
  { participant: principal }
  { 
    total-score: uint,
    last-updated: uint,
    rank-position: uint
  }
)

(define-map event-weights
  { event-id: uint }
  { weight-multiplier: uint }
)

(define-map delegation-registry
  { delegator: principal }
  { 
    delegate: principal,
    delegated-at: uint,
    is-active: bool
  }
)

(define-map participation-streaks
  { participant: principal }
  {
    current-streak: uint,
    longest-streak: uint,
    last-event-id: uint,
    streak-multiplier: uint
  }
)

(define-map streak-milestones
  { participant: principal, milestone: uint }
  { achieved-at: uint }
)

(define-data-var next-event-id uint u1)
(define-data-var streak-bonus-rate uint u2)

(define-read-only (get-event (event-id uint))
  (map-get? events { event-id: event-id })
)

(define-read-only (get-participation (event-id uint) (participant principal))
  (map-get? participants { event-id: event-id, participant: participant })
)

(define-read-only (has-participated (event-id uint) (participant principal))
  (is-some (map-get? participants { event-id: event-id, participant: participant }))
)

(define-read-only (get-user-event-count (participant principal))
  (default-to u0 (get event-count (map-get? user-events { participant: participant })))
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

(define-read-only (is-event-active (event-id uint))
  (match (map-get? events { event-id: event-id })
    event-data (and 
      (get is-active event-data)
      (>= stacks-block-height (get start-block event-data))
      (<= stacks-block-height (get end-block event-data))
    )
    false
  )
)

(define-public (create-event (name (string-ascii 50)) (description (string-ascii 200)) (start-block uint) (end-block uint))
  (let
    (
      (event-id (var-get next-event-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> end-block start-block) err-invalid-end-block)
    (asserts! (is-none (map-get? events { event-id: event-id })) err-event-already-exists)
    
    (map-set events
      { event-id: event-id }
      {
        name: name,
        description: description,
        start-block: start-block,
        end-block: end-block,
        is-active: true,
        total-participants: u0
      }
    )
    
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (participate (event-id uint) (participation-data (string-ascii 100)))
  (let
    (
      (event-data (unwrap! (map-get? events { event-id: event-id }) err-event-not-found))
      (current-count (get-user-event-count tx-sender))
    )
    (asserts! (is-event-active event-id) err-event-not-active)
    (asserts! (not (has-participated event-id tx-sender)) err-already-participated)
    
    (map-set participants
      { event-id: event-id, participant: tx-sender }
      {
        participated-at: stacks-block-height,
        participation-data: participation-data
      }
    )
    
    (map-set events
      { event-id: event-id }
      (merge event-data { total-participants: (+ (get total-participants event-data) u1) })
    )
    
    (map-set user-events
      { participant: tx-sender }
      { event-count: (+ current-count u1) }
    )
    
    (update-streak tx-sender event-id)
    (update-leaderboard-score tx-sender event-id)
    (ok true)
  )
)

(define-public (deactivate-event (event-id uint))
  (let
    (
      (event-data (unwrap! (map-get? events { event-id: event-id }) err-event-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set events
      { event-id: event-id }
      (merge event-data { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (reactivate-event (event-id uint))
  (let
    (
      (event-data (unwrap! (map-get? events { event-id: event-id }) err-event-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set events
      { event-id: event-id }
      (merge event-data { is-active: true })
    )
    
    (ok true)
  )
)

(define-read-only (get-event-participants (event-id uint))
  (match (map-get? events { event-id: event-id })
    event-data (get total-participants event-data)
    u0
  )
)

(define-read-only (get-participation-proof (event-id uint) (participant principal))
  (match (map-get? participants { event-id: event-id, participant: participant })
    participation-data (some {
      event-id: event-id,
      participant: participant,
      participated-at: (get participated-at participation-data),
      participation-data: (get participation-data participation-data)
    })
    none
  )
)

(define-read-only (get-leaderboard-score (participant principal))
  (default-to 
    { total-score: u0, last-updated: u0, rank-position: u999999 }
    (map-get? leaderboard-scores { participant: participant })
  )
)

(define-read-only (get-event-weight (event-id uint))
  (default-to u1 (get weight-multiplier (map-get? event-weights { event-id: event-id })))
)

(define-read-only (get-delegation-info (delegator principal))
  (map-get? delegation-registry { delegator: delegator })
)

(define-read-only (has-active-delegation (delegator principal))
  (match (map-get? delegation-registry { delegator: delegator })
    delegation-info (get is-active delegation-info)
    false
  )
)

(define-read-only (get-effective-participant (participant principal))
  (match (map-get? delegation-registry { delegator: participant })
    delegation-info 
      (if (get is-active delegation-info)
        (get delegate delegation-info)
        participant
      )
    participant
  )
)

(define-read-only (get-streak-info (participant principal))
  (default-to 
    { current-streak: u0, longest-streak: u0, last-event-id: u0, streak-multiplier: u1 }
    (map-get? participation-streaks { participant: participant })
  )
)

(define-read-only (get-streak-milestone (participant principal) (milestone uint))
  (map-get? streak-milestones { participant: participant, milestone: milestone })
)

(define-read-only (calculate-streak-bonus (current-streak uint))
  (let
    (
      (bonus-rate (var-get streak-bonus-rate))
      (tier-bonus (if (>= current-streak u50) u100
                    (if (>= current-streak u25) u50
                    (if (>= current-streak u10) u20
                    (if (>= current-streak u5) u10 u0)))))
    )
    (+ (* current-streak bonus-rate) tier-bonus)
  )
)

(define-private (calculate-score-boost (event-id uint) (participation-count uint))
  (let
    (
      (base-score u10)
      (weight (get-event-weight event-id))
      (popularity-bonus (if (> participation-count u50) u5 u0))
    )
    (* (* base-score weight) (+ u1 popularity-bonus))
  )
)

(define-private (update-streak (participant principal) (event-id uint))
  (let
    (
      (streak-info (get-streak-info participant))
      (last-event (get last-event-id streak-info))
      (is-consecutive (is-eq event-id (+ last-event u1)))
      (new-streak (if is-consecutive (+ (get current-streak streak-info) u1) u1))
      (new-longest (if (> new-streak (get longest-streak streak-info)) new-streak (get longest-streak streak-info)))
      (multiplier (+ u1 (/ new-streak u5)))
    )
    (map-set participation-streaks
      { participant: participant }
      {
        current-streak: new-streak,
        longest-streak: new-longest,
        last-event-id: event-id,
        streak-multiplier: multiplier
      }
    )
    (check-and-record-milestone participant new-streak)
  )
)

(define-private (check-and-record-milestone (participant principal) (streak uint))
  (let
    (
      (milestone-thresholds (list u5 u10 u25 u50 u100))
    )
    (if (or (is-eq streak u5) (is-eq streak u10) (is-eq streak u25) (is-eq streak u50) (is-eq streak u100))
      (map-set streak-milestones
        { participant: participant, milestone: streak }
        { achieved-at: stacks-block-height }
      )
      false
    )
  )
)

(define-private (update-leaderboard-score (participant principal) (event-id uint))
  (let
    (
      (current-score (get-leaderboard-score participant))
      (event-data (unwrap-panic (map-get? events { event-id: event-id })))
      (score-boost (calculate-score-boost event-id (get total-participants event-data)))
      (streak-info (get-streak-info participant))
      (streak-bonus (calculate-streak-bonus (get current-streak streak-info)))
      (total-boost (+ score-boost streak-bonus))
      (new-total-score (+ (get total-score current-score) total-boost))
    )
    (map-set leaderboard-scores
      { participant: participant }
      {
        total-score: new-total-score,
        last-updated: stacks-block-height,
        rank-position: (get rank-position current-score)
      }
    )
  )
)

(define-public (set-event-weight (event-id uint) (weight uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? events { event-id: event-id })) err-event-not-found)
    (map-set event-weights
      { event-id: event-id }
      { weight-multiplier: weight }
    )
    (ok true)
  )
)

(define-read-only (get-top-participants (limit uint))
  (ok "leaderboard-query-not-implemented")
)

(define-public (delegate-participation (delegate principal))
  (begin
    (asserts! (not (is-eq tx-sender delegate)) err-self-delegation)
    (map-set delegation-registry
      { delegator: tx-sender }
      {
        delegate: delegate,
        delegated-at: stacks-block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let
    (
      (delegation-info (unwrap! (map-get? delegation-registry { delegator: tx-sender }) err-no-delegation-found))
    )
    (map-set delegation-registry
      { delegator: tx-sender }
      (merge delegation-info { is-active: false })
    )
    (ok true)
  )
)

(define-public (participate-as-delegate (event-id uint) (delegator principal) (participation-data (string-ascii 100)))
  (let
    (
      (event-data (unwrap! (map-get? events { event-id: event-id }) err-event-not-found))
      (delegation-info (unwrap! (map-get? delegation-registry { delegator: delegator }) err-no-delegation-found))
      (current-count (get-user-event-count delegator))
    )
    (asserts! (is-event-active event-id) err-event-not-active)
    (asserts! (get is-active delegation-info) err-invalid-delegate)
    (asserts! (is-eq tx-sender (get delegate delegation-info)) err-invalid-delegate)
    (asserts! (not (has-participated event-id delegator)) err-already-participated)
    
    (map-set participants
      { event-id: event-id, participant: delegator }
      {
        participated-at: stacks-block-height,
        participation-data: participation-data
      }
    )
    
    (map-set events
      { event-id: event-id }
      (merge event-data { total-participants: (+ (get total-participants event-data) u1) })
    )
    
    (map-set user-events
      { participant: delegator }
      { event-count: (+ current-count u1) }
    )
    
    (update-streak delegator event-id)
    (update-leaderboard-score delegator event-id)
    (ok true)
  )
)

(define-public (set-streak-bonus-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set streak-bonus-rate new-rate)
    (ok true)
  )
)


;; (define-trait nft-trait
;;   (
;;     ;; Returns the owner of the given token-id, or none if not found
;;     (get-owner? (uint) (optional principal))
;;     ;; Transfers the token-id from sender to recipient
;;     (transfer? (uint principal principal) (response bool uint))
;;     ;; Mints a new token-id to the recipient
;;     (mint? (uint principal) (response bool uint))
;;     ;; Burns the token-id
;;     (burn? (uint) (response bool uint))
;;   )
;; )
;; (impl-trait .proof-of-participations_.nft-trait)

(define-constant err-not-token-owner (err u101))
(define-constant err-milestone-not-reached (err u102))
(define-constant err-badge-already-minted (err u103))

(define-non-fungible-token participation-badge uint)

(define-data-var last-token-id uint u0)
(define-data-var token-uri (string-ascii 256) "https://api.participation-badges.com/metadata/")

(define-map token-metadata
  { token-id: uint }
  {
    milestone: uint,
    minted-at: uint,
    owner: principal
  }
)

(define-map user-badges
  { owner: principal }
  { badges: (list 20 uint) }
)

(define-constant milestones (list u1 u5 u10 u25 u50 u100))

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (var-get token-uri) (uint-to-ascii token-id))))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? participation-badge token-id))
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata { token-id: token-id })
)

(define-read-only (get-user-badges (owner principal))
  (default-to (list) (get badges (map-get? user-badges { owner: owner })))
)

(define-read-only (can-mint-milestone-badge (participant principal) (participation-count uint))
  (let
    (
      (eligible-milestones (filter check-milestone-eligibility milestones))
      (user-badges-list (get-user-badges participant))
    )
    (> (len eligible-milestones) u0)
  )
)

(define-private (check-milestone-eligibility (milestone uint))
  true
)

(define-public (mint-milestone-badge (participant principal) (participation-count uint) (milestone uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (current-badges (get-user-badges participant))
    )
    (asserts! (>= participation-count milestone) err-milestone-not-reached)
    (asserts! (is-none (index-of milestones milestone)) (err u104))
    
    (try! (nft-mint? participation-badge token-id participant))
    
    (map-set token-metadata
      { token-id: token-id }
      {
        milestone: milestone,
        minted-at: stacks-block-height,
        owner: participant
      }
    )
    
    (map-set user-badges
      { owner: participant }
      { badges: (unwrap! (as-max-len? (append current-badges token-id) u20) (err u999)) }
    )
    
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (try! (nft-transfer? participation-badge token-id sender recipient))
    
    (map-set token-metadata
      { token-id: token-id }
      (merge 
        (unwrap-panic (map-get? token-metadata { token-id: token-id }))
        { owner: recipient }
      )
    )
    
    (ok true)
  )
)

(define-public (set-token-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set token-uri new-uri)
    (ok true)
  )
)

(define-private (uint-to-ascii (value uint))
  (if (is-eq value u0) "0"
    (if (< value u10) (unwrap-panic (element-at "0123456789" value))
      "multi-digit")))