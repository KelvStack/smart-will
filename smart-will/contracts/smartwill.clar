
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
(define-constant ERR_INVALID_BENEFICIARY (err u413))
(define-constant ERR_MAX_BENEFICIARIES_REACHED (err u414))
(define-constant ERR_PERCENTAGE_TOTAL_INVALID (err u415))
(define-constant ERR_BENEFICIARY_EXISTS (err u416))

;; Maximum number of beneficiaries per will
(define-constant MAX_BENEFICIARIES u10)

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

;; Beneficiary management
(define-map beneficiaries
    {
        will-id: uint,
        beneficiary-address: principal,
    }
    ;; composite key
    {
        percentage: uint, ;; Percentage allocation (0-10000 for 0-100.00%)
        is-active: bool,
        added-at: uint,
        notes: (optional (string-ascii 256)),
    }
)

;; Track beneficiary addresses for each will
(define-map will-beneficiary-list
    uint ;; will-id
    (list 10 principal) ;; list of beneficiary addresses
)

;; Beneficiary count per will (for quick access)
(define-map beneficiary-counts
    uint ;; will-id
    uint ;; count
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

;; Add a beneficiary to a will
(define-public (add-beneficiary
        (will-id uint)
        (beneficiary-address principal)
        (percentage uint)
        (notes (optional (string-ascii 256)))
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (current-beneficiaries (default-to (list) (map-get? will-beneficiary-list will-id)))
            (beneficiary-count (get beneficiary-count will-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Check beneficiary limit
        (asserts! (< beneficiary-count MAX_BENEFICIARIES)
            ERR_MAX_BENEFICIARIES_REACHED
        )

        ;; Validate percentage (0-10000 for 0-100.00%)
        (asserts! (<= percentage u10000) ERR_INVALID_PERCENTAGE)
        (asserts! (> percentage u0) ERR_INVALID_PERCENTAGE)

        ;; Ensure beneficiary doesn't already exist
        (asserts!
            (is-none (map-get? beneficiaries {
                will-id: will-id,
                beneficiary-address: beneficiary-address,
            }))
            ERR_BENEFICIARY_EXISTS
        )

        ;; Validate total percentage doesn't exceed 100%
        (let ((new-total (+ (get-total-percentage will-id) percentage)))
            (asserts! (<= new-total u10000) ERR_PERCENTAGE_TOTAL_INVALID)
        )

        ;; Add beneficiary
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        } {
            percentage: percentage,
            is-active: true,
            added-at: stacks-block-height,
            notes: notes,
        })

        ;; Update beneficiary list
        (map-set will-beneficiary-list will-id
            (unwrap!
                (as-max-len? (append current-beneficiaries beneficiary-address)
                    u10
                )
                ERR_MAX_BENEFICIARIES_REACHED
            ))

        ;; Update will beneficiary count
        (map-set wills will-id
            (merge will-data {
                beneficiary-count: (+ beneficiary-count u1),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Remove a beneficiary from a will
(define-public (remove-beneficiary
        (will-id uint)
        (beneficiary-address principal)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (beneficiary-data (unwrap!
                (map-get? beneficiaries {
                    will-id: will-id,
                    beneficiary-address: beneficiary-address,
                })
                ERR_NOT_FOUND
            ))
            (beneficiary-count (get beneficiary-count will-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Remove beneficiary
        (map-delete beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })

        ;; Note: For simplicity, we'll rebuild the beneficiary list when needed
        ;; In a production environment, you'd implement proper list management

        ;; Update will beneficiary count
        (map-set wills will-id
            (merge will-data {
                beneficiary-count: (- beneficiary-count u1),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Update beneficiary percentage
(define-public (update-beneficiary-percentage
        (will-id uint)
        (beneficiary-address principal)
        (new-percentage uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (beneficiary-data (unwrap!
                (map-get? beneficiaries {
                    will-id: will-id,
                    beneficiary-address: beneficiary-address,
                })
                ERR_NOT_FOUND
            ))
            (old-percentage (get percentage beneficiary-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Validate percentage
        (asserts! (<= new-percentage u10000) ERR_INVALID_PERCENTAGE)
        (asserts! (> new-percentage u0) ERR_INVALID_PERCENTAGE)

        ;; Validate total percentage doesn't exceed 100%
        (let (
                (current-total (get-total-percentage will-id))
                (adjusted-total (+ (- current-total old-percentage) new-percentage))
            )
            (asserts! (<= adjusted-total u10000) ERR_PERCENTAGE_TOTAL_INVALID)
        )

        ;; Update beneficiary
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        }
            (merge beneficiary-data { percentage: new-percentage })
        )

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; Distribute assets to beneficiaries (simplified STX distribution)
(define-public (distribute-assets (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (total-amount (get total-stx-amount will-data))
            (beneficiary-list (default-to (list) (map-get? will-beneficiary-list will-id)))
        )
        ;; Verify ownership or authorized executor
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is active and ready for execution
        (asserts! (get is-active will-data) ERR_WILL_NOT_READY)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure there are beneficiaries and total percentage is 100%
        (asserts! (> (len beneficiary-list) u0) ERR_INVALID_BENEFICIARY)
        (asserts! (is-eq (get-total-percentage will-id) u10000)
            ERR_PERCENTAGE_TOTAL_INVALID
        )

        ;; Distribute to each beneficiary
        (fold distribute-to-beneficiary beneficiary-list {
            will-id: will-id,
            total-amount: total-amount,
        })

        ;; Mark will as executed
        (map-set wills will-id
            (merge will-data {
                is-executed: true,
                execution-block: (some stacks-block-height),
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

;; Get beneficiary details
(define-read-only (get-beneficiary-details
        (will-id uint)
        (beneficiary-address principal)
    )
    (map-get? beneficiaries {
        will-id: will-id,
        beneficiary-address: beneficiary-address,
    })
)

;; Get all beneficiaries for a will
(define-read-only (get-will-beneficiaries (will-id uint))
    (map-get? will-beneficiary-list will-id)
)

;; Calculate total percentage allocated
(define-read-only (get-total-percentage (will-id uint))
    (match (map-get? will-beneficiary-list will-id)
        beneficiary-list (get total
            (fold sum-beneficiary-percentage beneficiary-list {
                will-id: will-id,
                total: u0,
            })
        )
        u0
    )
)

;; Get beneficiary allocation amount in STX
(define-read-only (get-beneficiary-allocation
        (will-id uint)
        (beneficiary-address principal)
    )
    (match (map-get? wills will-id)
        will-data (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data (let (
                    (total-amount (get total-stx-amount will-data))
                    (percentage (get percentage beneficiary-data))
                )
                (ok (/ (* total-amount percentage) u10000))
            )
            ERR_NOT_FOUND
        )
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

;; Helper function to sum beneficiary percentages
(define-private (sum-beneficiary-percentage
        (beneficiary-address principal)
        (acc {
            will-id: uint,
            total: uint,
        })
    )
    (let (
            (will-id (get will-id acc))
            (current-total (get total acc))
        )
        (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data (merge acc { total: (+ current-total (get percentage beneficiary-data)) })
            acc
        )
    )
)

;; Helper function to distribute to a single beneficiary
(define-private (distribute-to-beneficiary
        (beneficiary-address principal)
        (context {
            will-id: uint,
            total-amount: uint,
        })
    )
    (let (
            (will-id (get will-id context))
            (total-amount (get total-amount context))
        )
        (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data
            (let (
                    (percentage (get percentage beneficiary-data))
                    (amount (/ (* total-amount percentage) u10000))
                )
                (begin
                    (and
                        (> amount u0)
                        (is-ok (as-contract (stx-transfer? amount tx-sender beneficiary-address)))
                    )
                    context ;; Return the context for fold
                )
            )
            context ;; Return the context for fold
        )
    )
)

