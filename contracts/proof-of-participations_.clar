(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-event-not-found (err u101))
(define-constant err-event-not-active (err u102))
(define-constant err-already-participated (err u103))
(define-constant err-event-already-exists (err u104))
(define-constant err-invalid-end-block (err u105))

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

(define-data-var next-event-id uint u1)

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

(define-private (update-leaderboard-score (participant principal) (event-id uint))
  (let
    (
      (current-score (get-leaderboard-score participant))
      (event-data (unwrap-panic (map-get? events { event-id: event-id })))
      (score-boost (calculate-score-boost event-id (get total-participants event-data)))
      (new-total-score (+ (get total-score current-score) score-boost))
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