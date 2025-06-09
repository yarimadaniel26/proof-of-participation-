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
