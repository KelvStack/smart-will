
;; title: smart-will
;; version: 1.0.0
;; summary: A blockchain-based digital estate planning platform for secure asset inheritance
;; description: SmartWill enables users to create digital wills with beneficiary management,
;;              asset distribution, time locks, and social recovery features

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_PERCENTAGE (err u400))
(define-constant ERR_WILL_ALREADY_EXECUTED (err u410))
(define-constant ERR_WILL_NOT_READY (err u411))
(define-constant ERR_INSUFFICIENT_BALANCE (err u412))

;; data vars
(define-data-var next-will-id uint u1)
(define-data-var contract-fee uint u1000000) ;; 1 STX fee for will creation

;; data maps
;; Main will storage
(define-map wills
    uint ;; will-id
    {
        creator: principal,
        is-active: bool,
        created-at: uint,
        last-updated: uint,
        total-stx-amount: uint,
        beneficiary-count: uint,
        is-executed: bool,
        execution-block: (optional uint),
        metadata-uri: (optional (string-ascii 256)),
    }
)

;; User to will mapping (one will per user for now)
(define-map user-will
    principal ;; user address
    uint ;; will-id
)

;; Will ownership verification
(define-map will-owners
    uint ;; will-id
    principal ;; owner address
)

;; public functions

;; Create a new digital will
(define-public (create-will (metadata-uri (optional (string-ascii 256))))
    (let (
            (caller tx-sender)
            (will-id (var-get next-will-id))
            (current-block stacks-block-height)
        )
        ;; Check if user already has a will
        (asserts! (is-none (map-get? user-will caller)) ERR_ALREADY_EXISTS)

        ;; Transfer contract fee
        (try! (stx-transfer? (var-get contract-fee) caller CONTRACT_OWNER))

        ;; Create the will record
        (map-set wills will-id {
            creator: caller,
            is-active: true,
            created-at: current-block,
            last-updated: current-block,
            total-stx-amount: u0,
            beneficiary-count: u0,
            is-executed: false,
            execution-block: none,
            metadata-uri: metadata-uri,
        })

        ;; Map user to will
        (map-set user-will caller will-id)
        (map-set will-owners will-id caller)

        ;; Increment will counter
        (var-set next-will-id (+ will-id u1))

        (ok will-id)
    )
)

;; Update will metadata
(define-public (update-will-metadata
        (will-id uint)
        (new-metadata-uri (optional (string-ascii 256)))
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Update the will
        (map-set wills will-id
            (merge will-data {
                last-updated: stacks-block-height,
                metadata-uri: new-metadata-uri,
            })
        )

        (ok true)
    )
)

;; Activate or deactivate a will
(define-public (toggle-will-status (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Toggle status
        (map-set wills will-id
            (merge will-data {
                is-active: (not (get is-active will-data)),
                last-updated: stacks-block-height,
            })
        )

        (ok (not (get is-active will-data)))
    )
)

;; Deposit STX into will
(define-public (deposit-stx
        (will-id uint)
        (amount uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is active and not executed
        (asserts! (get is-active will-data) ERR_WILL_NOT_READY)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure amount is greater than 0
        (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)

        ;; Transfer STX to contract
        (try! (stx-transfer? amount caller (as-contract tx-sender)))

        ;; Update will balance
        (map-set wills will-id
            (merge will-data {
                total-stx-amount: (+ (get total-stx-amount will-data) amount),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; read only functions

;; Get will details by ID
(define-read-only (get-will-details (will-id uint))
    (map-get? wills will-id)
)

;; Get will ID for a user
(define-read-only (get-user-will-id (user principal))
    (map-get? user-will user)
)

;; Get will owner by will ID
(define-read-only (get-will-owner (will-id uint))
    (map-get? will-owners will-id)
)

;; Get next available will ID
(define-read-only (get-next-will-id)
    (var-get next-will-id)
)

;; Get contract fee
(define-read-only (get-contract-fee)
    (var-get contract-fee)
)

;; Check if user has a will
(define-read-only (has-will (user principal))
    (is-some (map-get? user-will user))
)

;; Get will status
(define-read-only (get-will-status (will-id uint))
    (match (map-get? wills will-id)
        will-data (ok {
            is-active: (get is-active will-data),
            is-executed: (get is-executed will-data),
            beneficiary-count: (get beneficiary-count will-data),
            total-stx-amount: (get total-stx-amount will-data),
        })
        ERR_NOT_FOUND
    )
)

;; private functions

;; Verify will ownership (internal helper)
(define-private (verify-will-ownership
        (will-id uint)
        (caller principal)
    )
    (match (map-get? will-owners will-id)
        owner (is-eq owner caller)
        false
    )
)

