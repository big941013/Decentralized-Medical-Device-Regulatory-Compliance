;; Approval Management Contract
;; Manages regulatory approvals for medical devices

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_APPROVAL_NOT_FOUND (err u401))
(define-constant ERR_APPROVAL_EXISTS (err u402))
(define-constant ERR_INVALID_STATUS (err u403))

;; Approval status constants
(define-constant APPROVAL_PENDING u0)
(define-constant APPROVAL_APPROVED u1)
(define-constant APPROVAL_REJECTED u2)
(define-constant APPROVAL_SUSPENDED u3)
(define-constant APPROVAL_EXPIRED u4)

;; Approval type constants
(define-constant APPROVAL_FDA u0)
(define-constant APPROVAL_CE u1)
(define-constant APPROVAL_ISO u2)
(define-constant APPROVAL_LOCAL u3)

;; Data structures
(define-map device-approvals
  { approval-id: uint }
  {
    device-id: uint,
    approval-type: uint,
    approval-status: uint,
    application-date: uint,
    approval-date: uint,
    expiry-date: uint,
    approving-authority: principal,
    conditions: (string-ascii 500)
  }
)

(define-data-var next-approval-id uint u1)

;; Submit approval application
(define-public (submit-approval-application
  (device-id uint)
  (approval-type uint)
  (conditions (string-ascii 500))
)
  (let ((approval-id (var-get next-approval-id)))
    (asserts! (is-none (map-get? device-approvals { approval-id: approval-id })) ERR_APPROVAL_EXISTS)
    (asserts! (<= approval-type APPROVAL_LOCAL) ERR_INVALID_STATUS)
    (map-set device-approvals
      { approval-id: approval-id }
      {
        device-id: device-id,
        approval-type: approval-type,
        approval-status: APPROVAL_PENDING,
        application-date: block-height,
        approval-date: u0,
        expiry-date: u0,
        approving-authority: tx-sender,
        conditions: conditions
      }
    )
    (var-set next-approval-id (+ approval-id u1))
    (ok approval-id)
  )
)

;; Process approval decision
(define-public (process-approval
  (approval-id uint)
  (decision uint)
  (expiry-blocks uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= decision APPROVAL_EXPIRED) ERR_INVALID_STATUS)
    (match (map-get? device-approvals { approval-id: approval-id })
      approval
      (begin
        (map-set device-approvals
          { approval-id: approval-id }
          (merge approval {
            approval-status: decision,
            approval-date: block-height,
            expiry-date: (+ block-height expiry-blocks),
            approving-authority: tx-sender
          })
        )
        (ok true)
      )
      ERR_APPROVAL_NOT_FOUND
    )
  )
)

;; Update approval status
(define-public (update-approval-status
  (approval-id uint)
  (new-status uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status APPROVAL_EXPIRED) ERR_INVALID_STATUS)
    (match (map-get? device-approvals { approval-id: approval-id })
      approval
      (begin
        (map-set device-approvals
          { approval-id: approval-id }
          (merge approval { approval-status: new-status })
        )
        (ok true)
      )
      ERR_APPROVAL_NOT_FOUND
    )
  )
)

;; Get approval details
(define-read-only (get-approval-details (approval-id uint))
  (map-get? device-approvals { approval-id: approval-id })
)

;; Check if approval is valid
(define-read-only (is-approval-valid (approval-id uint))
  (match (map-get? device-approvals { approval-id: approval-id })
    approval
    (and
      (is-eq (get approval-status approval) APPROVAL_APPROVED)
      (< block-height (get expiry-date approval))
    )
    false
  )
)

;; Check if approval is expired
(define-read-only (is-approval-expired (approval-id uint))
  (match (map-get? device-approvals { approval-id: approval-id })
    approval (>= block-height (get expiry-date approval))
    false
  )
)
