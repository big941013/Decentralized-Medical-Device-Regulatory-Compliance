;; Compliance Tracking Contract
;; Tracks regulatory compliance status for medical devices

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_DEVICE_NOT_FOUND (err u201))
(define-constant ERR_COMPLIANCE_EXISTS (err u202))
(define-constant ERR_INVALID_STATUS (err u203))

;; Compliance status constants
(define-constant COMPLIANCE_PENDING u0)
(define-constant COMPLIANCE_COMPLIANT u1)
(define-constant COMPLIANCE_NON_COMPLIANT u2)
(define-constant COMPLIANCE_UNDER_REVIEW u3)

;; Data structures
(define-map device-compliance
  { device-id: uint }
  {
    manufacturer-id: uint,
    device-name: (string-ascii 100),
    compliance-status: uint,
    last-audit-date: uint,
    next-audit-due: uint,
    auditor: principal,
    notes: (string-ascii 500)
  }
)

(define-data-var next-device-id uint u1)

;; Register device for compliance tracking
(define-public (register-device-compliance
  (manufacturer-id uint)
  (device-name (string-ascii 100))
  (notes (string-ascii 500))
)
  (let ((device-id (var-get next-device-id)))
    (asserts! (is-none (map-get? device-compliance { device-id: device-id })) ERR_COMPLIANCE_EXISTS)
    (map-set device-compliance
      { device-id: device-id }
      {
        manufacturer-id: manufacturer-id,
        device-name: device-name,
        compliance-status: COMPLIANCE_PENDING,
        last-audit-date: block-height,
        next-audit-due: (+ block-height u8760), ;; ~1 year in blocks
        auditor: tx-sender,
        notes: notes
      }
    )
    (var-set next-device-id (+ device-id u1))
    (ok device-id)
  )
)

;; Update compliance status
(define-public (update-compliance-status
  (device-id uint)
  (new-status uint)
  (notes (string-ascii 500))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status COMPLIANCE_UNDER_REVIEW) ERR_INVALID_STATUS)
    (match (map-get? device-compliance { device-id: device-id })
      compliance
      (begin
        (map-set device-compliance
          { device-id: device-id }
          (merge compliance {
            compliance-status: new-status,
            last-audit-date: block-height,
            next-audit-due: (+ block-height u8760),
            auditor: tx-sender,
            notes: notes
          })
        )
        (ok true)
      )
      ERR_DEVICE_NOT_FOUND
    )
  )
)

;; Get compliance status
(define-read-only (get-compliance-status (device-id uint))
  (map-get? device-compliance { device-id: device-id })
)

;; Check if device is compliant
(define-read-only (is-device-compliant (device-id uint))
  (match (map-get? device-compliance { device-id: device-id })
    compliance (is-eq (get compliance-status compliance) COMPLIANCE_COMPLIANT)
    false
  )
)

;; Get devices due for audit
(define-read-only (is-audit-due (device-id uint))
  (match (map-get? device-compliance { device-id: device-id })
    compliance (>= block-height (get next-audit-due compliance))
    false
  )
)
