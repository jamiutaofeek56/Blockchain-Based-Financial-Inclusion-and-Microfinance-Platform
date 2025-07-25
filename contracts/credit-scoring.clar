;; Credit Scoring for Unbanked Contract
;; Provides alternative credit assessment for underserved populations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INSUFFICIENT-VOUCHES (err u104))

;; Data Variables
(define-data-var total-users uint u0)
(define-data-var min-vouches-required uint u3)

;; Data Maps
(define-map users
  { user-id: (string-ascii 50) }
  {
    reputation-score: uint,
    total-transactions: uint,
    successful-payments: uint,
    community-vouches: uint,
    registration-block: uint,
    is-active: bool
  }
)

(define-map vouches
  { voucher-id: (string-ascii 50), user-id: (string-ascii 50) }
  {
    vouch-amount: uint,
    vouch-block: uint,
    is-valid: bool
  }
)

;; Public Functions

;; Register a new user in the credit scoring system
(define-public (register-user (user-id (string-ascii 50)) (initial-score uint))
  (begin
    (asserts! (< initial-score u1000) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? users { user-id: user-id })) ERR-ALREADY-EXISTS)

    (map-set users
      { user-id: user-id }
      {
        reputation-score: initial-score,
        total-transactions: u0,
        successful-payments: u0,
        community-vouches: u0,
        registration-block: block-height,
        is-active: true
      }
    )

    (var-set total-users (+ (var-get total-users) u1))
    (ok true)
  )
)

;; Add a community vouch for a user
(define-public (add-vouch (user-id (string-ascii 50)) (voucher-id (string-ascii 50)) (vouch-amount uint))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user-id }) ERR-USER-NOT-FOUND))
    )
    (asserts! (> vouch-amount u0) ERR-INVALID-INPUT)
    (asserts! (< vouch-amount u1000) ERR-INVALID-INPUT)
    (asserts! (not (is-eq user-id voucher-id)) ERR-INVALID-INPUT)

    (map-set vouches
      { voucher-id: voucher-id, user-id: user-id }
      {
        vouch-amount: vouch-amount,
        vouch-block: block-height,
        is-valid: true
      }
    )

    ;; Update user's community vouches count
    (map-set users
      { user-id: user-id }
      (merge user-data { community-vouches: (+ (get community-vouches user-data) u1) })
    )

    (ok true)
  )
)

;; Calculate credit score based on multiple factors
(define-public (calculate-score (user-id (string-ascii 50)))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user-id }) ERR-USER-NOT-FOUND))
      (base-score (get reputation-score user-data))
      (transaction-bonus (* (get total-transactions user-data) u5))
      (vouch-bonus (* (get community-vouches user-data) u25))
      (final-score (+ base-score transaction-bonus vouch-bonus))
      (capped-score (if (> final-score u1000) u1000 final-score))
    )

    ;; Update the stored reputation score
    (map-set users
      { user-id: user-id }
      (merge user-data { reputation-score: capped-score })
    )

    (ok capped-score)
  )
)

;; Check loan eligibility
(define-public (check-loan-eligibility (user-id (string-ascii 50)) (loan-amount uint))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user-id }) ERR-USER-NOT-FOUND))
      (credit-score (get reputation-score user-data))
      (min-score-required (/ loan-amount u10))
    )
    (asserts! (>= (get community-vouches user-data) (var-get min-vouches-required)) ERR-INSUFFICIENT-VOUCHES)
    (asserts! (>= credit-score min-score-required) ERR-INVALID-INPUT)
    (asserts! (get is-active user-data) ERR-NOT-AUTHORIZED)

    (ok true)
  )
)

;; Read-only Functions

;; Get user information
(define-read-only (get-user-info (user-id (string-ascii 50)))
  (map-get? users { user-id: user-id })
)

;; Get vouch information
(define-read-only (get-vouch-info (voucher-id (string-ascii 50)) (user-id (string-ascii 50)))
  (map-get? vouches { voucher-id: voucher-id, user-id: user-id })
)

;; Get total users count
(define-read-only (get-total-users)
  (var-get total-users)
)
